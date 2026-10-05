extends Node

const FORMAT_VERSION := 3
const BUNDLED := "res://generated_city/default_city.res"
const LOCAL := "user://cities/current_city.res"
var generate_next := false
var pending_generation_seed := -1
var bake_path := ""
var last_source := ""
var last_save_error: Error = FAILED
var local_path := LOCAL
var preferred_size := 1
var original_grid := false
var earlier_style := false
var progressive_loading := true
var card_bake_queue: Array[Dictionary] = []
var card_bake_running := false

func bundled_path(city: Node) -> String:
	if city.earlier_style: return "res://generated_city/earlier_%s_%s.res" % ["grid" if city.original_grid else "bridges", "large" if city.map_size == 1 else "small"]
	if city.original_grid: return "res://generated_city/grid_%s.res" % ("large" if city.map_size == 1 else "small")
	return BUNDLED if city.map_size == 1 else "res://generated_city/small_city.res"

func private_path(city: Node) -> String:
	if local_path != LOCAL: return local_path
	if city.earlier_style: return "user://cities/earlier_%s_%s.res" % ["grid" if city.original_grid else "bridges", "large" if city.map_size == 1 else "small"]
	if city.original_grid: return "user://cities/grid_%s.res" % ("large" if city.map_size == 1 else "small")
	return LOCAL if city.map_size == 1 else "user://cities/current_city_small.res"

func settings_hash(city: Node) -> String:
	var settings := {}
	for property in city.get_property_list():
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or not property.usage & PROPERTY_USAGE_STORAGE: continue
		var key: String = property.name
		if key in ["randomize_each_load", "fixed_seed", "use_saved_city", "use_bundled_seed", "earlier_style"]: continue
		var value: Variant = city.get(key)
		settings[key] = value.resource_path if value is Resource else value
	if city.original_grid: settings["original_grid"] = true
	if city.earlier_style: settings["earlier_style"] = true
	return var_to_bytes(settings).hex_encode().sha256_text()

func city_file_available(path: String) -> bool:
	# A private save can exist but be unreadable (for example, after a permission change).
	if path.begins_with("user://"):
		var private_save := FileAccess.open(path, FileAccess.READ)
		if private_save == null: return false
		private_save.close()
	return ResourceLoader.exists(path)

func restore(city: Node) -> bool:
	if not city.use_saved_city or not bake_path.is_empty(): return false
	if generate_next and city.randomize_each_load:
		generate_next = false
		return false
	# Multiplayer always uses the shipped city; private maps never affect peers.
	var paths := [private_path(city), bundled_path(city)] if city.randomize_each_load else [bundled_path(city)]
	for path in paths:
		if not city_file_available(path): continue
		if ResourceLoader.load_threaded_request(path, "Resource", false) != OK: continue
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var data: Resource = ResourceLoader.load_threaded_get(path)
		if data == null or data.get("format_version") != FORMAT_VERSION or data.get("settings_hash") != settings_hash(city): continue
		if data.snapshot == null and data.sections.is_empty(): continue
		if not data.sections.is_empty() and (data.section_centers.size() != data.sections.size() or data.section_global.size() != data.sections.size() or data.sections.has(null)): continue
		if not city.randomize_each_load and not city.use_bundled_seed and data.seed != city.fixed_seed: continue
		var saved: Node = data.snapshot.instantiate() if data.snapshot != null else null
		city.actual_seed = data.seed
		city.noise.seed = data.seed
		city.detail_noise.seed = data.seed + 101
		city.hill_centers.assign(data.hills)
		city.is_night = data.night
		city.configure_time_of_day()
		city.topology.generate(data.seed, city.park_block_centers, city.map_size, city.boundary_margin_min, city.boundary_margin_max)
		if city.earlier_style: city.topology.use_earlier_islands()
		elif city.original_grid: city.topology.use_original_grid()
		var loader := city.get_node_or_null("/root/LoadingScreen")
		if loader != null and loader.busy:
			for step in 4:
				await loader.city_stage(city.topology, step, ["Loading city boundary…", "Loading highway exits…", "Loading main arteries…", "Loading inner streets…"][step])
		city.sidewalks_ready = true
		city.rng.state = data.traffic_state
		if not data.sections.is_empty():
			if data.section_centers.size() != data.sections.size() or data.section_global.size() != data.sections.size(): return false
			for item_name in ["ParkingPads", "PatronSpawns"]:
				for child in city.get_parent().get_node(item_name).get_children():
					if str(child.name).begins_with("City"):
						child.get_parent().remove_child(child)
						child.free()
			var stream := preload("res://city_section_stream.gd").new()
			stream.name = "CityStream"
			stream.city = city
			city.add_child(stream)
			await stream.load_initial(data, not progressive_loading or NetworkSession.active or city.get_meta("full_city_required", false))
		else:
			var reveal_phase := 3
			var containers := saved.get_children()
			var order := ["Terrain", "Roads", "HighwayApproaches", "Buildings", "Parks", "NearSkyline"]
			containers.sort_custom(func(a, b): return (order.find(str(a.name)) if str(a.name) in order else 99) < (order.find(str(b.name)) if str(b.name) in order else 99))
			for container in containers:
				if loader != null and loader.busy:
					var phase := 4 if str(container.name) in ["Buildings", "Parks", "NearSkyline"] else (3 if str(container.name) in ["Terrain", "Roads", "HighwayApproaches"] else 5)
					reveal_phase = maxi(reveal_phase, phase)
					await loader.city_stage(city.topology, reveal_phase, "Loading saved city: %s…" % container.name)
				var target: Node = city.get_parent().get_node(str(container.name)) if str(container.name) in ["ParkingPads", "PatronSpawns"] else city.get_node(str(container.name))
				for old in target.get_children():
					if str(container.name) in ["ParkingPads", "PatronSpawns"] and not str(old.name).begins_with("City"): continue
					target.remove_child(old)
					old.free()
				for child in container.get_children():
					if str(container.name) in ["ParkingPads", "PatronSpawns"] and not str(child.name).begins_with("City"):
						var original: Node = target.get_node(str(child.name))
						original.position = child.position
						var surface: Node = child.get_node_or_null("ServiceSurface")
						if surface != null: original.get_node("ServiceSurface").mesh = surface.mesh
						continue
					container.remove_child(child)
					clear_owners(child)
					target.add_child(child)
					await city.loading_checkpoint()
			saved.free()
		await preload("res://city_edge_boundary.gd").refresh_saved(city)
		preload("res://city_road_rules.gd").refresh_saved_markings(city)
		city.visual_surfaces_ready = not city.earlier_style
		if loader != null and loader.busy: await loader.city_stage(city.topology, 6, "Preparing traffic and street furniture…")
		await city.make_traffic()
		city.make_fog_boundary()
		# Cached pads already have shaped surfaces. Only align the truck.
		var truck: Node3D = city.get_parent().get_node("FoodTruck")
		truck.position.y = city.height_at(truck.position.x, truck.position.z) + 0.2
		truck.spawn_transform = truck.global_transform
		city.get_parent().get_node("RoadMarkings").hide()
		last_source = path
		if data.block_cards.is_empty() and DisplayServer.get_name() != "headless" and not data.sections.is_empty():
			card_bake_queue.append({"city": weakref(city), "data": data, "path": private_path(city)})
			if not card_bake_running:
				card_bake_running = true
				bake_saved_cards.call_deferred()
		city.get_parent().set_meta("saved_city_loaded", true)
		city.set_meta("upgrade_legacy_city", data.sections.is_empty() and path == private_path(city) and not NetworkSession.active)
		print("CITY_CACHE loaded ", path, " seed=", data.seed)
		return true
	return false

func clear_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children(): clear_owners(child)

func own_tree(node: Node, owner_node: Node) -> void:
	if node.has_meta("block_card_managed"):
		node.remove_meta("block_card_managed")
		node.visible = true
	for child in node.get_children():
		# Runtime representations are rebuilt against the current detail policy.
		if str(child.name) in ["BuildingVisualLOD","TrafficVisualLOD","LotCarVisual"]:
			node.remove_child(child)
			child.free()
			continue
		child.owner = owner_node
		child.scene_file_path = ""
		if child is Sprite3D and child.texture is ViewportTexture: child.texture = null
		own_tree(child, owner_node)

func save(city: Node) -> Error:
	if city.get_meta("streaming_city", false): return ERR_BUSY
	var saved := Node3D.new()
	saved.name = "SavedCity"
	for item_name in ["Terrain", "Roads", "ParkingSpaces", "ParkedCars", "HighwayApproaches", "Buildings", "NearSkyline", "Crosswalks", "StreetSigns", "Parks", "ParkingPads", "PatronSpawns"]:
		var source: Node = city.get_parent().get_node(item_name) if item_name in ["ParkingPads", "PatronSpawns"] else city.get_node(item_name)
		var container := Node3D.new()
		container.name = item_name
		saved.add_child(container)
		for child in source.get_children():
			var copy: Node
			if item_name == "ParkedCars" and child is RigidBody3D:
				copy = city.traffic_car_scene.instantiate()
				copy.name = child.name
				for property in child.get_property_list():
					if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script": copy.set(property.name, child.get(property.name))
			else: copy = child.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
			container.add_child(copy)
	own_tree(saved, saved)
	var partition := preload("res://city_section_stream.gd").partition(saved)
	saved.free()
	var error: Error = partition.error
	if error != OK:
		last_save_error = error
		return error
	var data := preload("res://saved_city.gd").new()
	data.settings_hash = settings_hash(city)
	data.seed = city.actual_seed
	data.map_size = city.map_size
	data.original_grid = city.original_grid
	data.night = city.is_night
	data.hills.assign(city.hill_centers)
	data.traffic_state = city.get_meta("traffic_initial_state", city.rng.state)
	data.sections.assign(partition.scenes)
	data.section_centers = partition.centers
	data.section_global = partition.global
	var cards := city.get_node_or_null("BlockRenderCards")
	if cards != null: data.block_cards = cards.export_for_sections(data.sections)
	var path := bake_path if not bake_path.is_empty() else private_path(city)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# Replace only after a complete successful save, preserving the old city on failure.
	var temporary := path.get_basename() + ".pending.res"
	error = ResourceSaver.save(data, temporary, ResourceSaver.FLAG_COMPRESS)
	if error == OK: error = DirAccess.rename_absolute(temporary, path)
	if error == OK: print("CITY_CACHE saved ", path, " seed=", data.seed)
	else: push_warning("City could not be saved: " + error_string(error))
	last_save_error = error
	if error == OK and data.block_cards.is_empty() and DisplayServer.get_name() != "headless":
		card_bake_queue.append({"city": weakref(city), "data": data, "path": path})
		if not card_bake_running:
			card_bake_running = true
			bake_saved_cards.call_deferred()
	return error

func bake_saved_cards() -> void:
	while not card_bake_queue.is_empty():
		var job: Dictionary = card_bake_queue.pop_front()
		var city: Node3D = job.city.get_ref()
		if city == null: continue
		while is_instance_valid(city) and (city.generating or city.get_meta("streaming_city", false) or not city.get_parent().is_loading_ready()):
			await get_tree().process_frame
		if not is_instance_valid(city): continue
		var data: Resource = job.data
		data.block_cards = await preload("res://block_card_baker.gd").bake(get_tree(), data)
		# A newer save for the same path wins over an older background bake.
		var superseded := false
		for pending_job in card_bake_queue:
			if pending_job.path == job.path: superseded = true
		if superseded: continue
		DirAccess.make_dir_recursive_absolute(str(job.path).get_base_dir())
		var temporary: String = str(job.path).get_basename() + ".cards.pending.res"
		var save_error := ResourceSaver.save(data, temporary, ResourceSaver.FLAG_COMPRESS)
		if save_error == OK:
			if DirAccess.rename_absolute(temporary, job.path) != OK:
				push_warning("Could not persist building render cards")
		else:
			push_warning("Could not save building render cards: " + error_string(save_error))
		if is_instance_valid(city) and city.actual_seed == data.seed:
			preload("res://block_cards.gd").install_loaded(city, data)
	card_bake_running = false
