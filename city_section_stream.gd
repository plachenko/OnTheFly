extends Node

const INITIAL_RADIUS := 128.0
const GLOBAL := ["Terrain", "Roads", "HighwayApproaches", "Crosswalks", "ParkingSpaces", "ParkingPads", "PatronSpawns", "NearSkyline"]
var city: Node3D
var sections: Array[PackedScene] = []
var centers: PackedVector3Array
var pending: Array[int] = []
var loaded_sections := 0
var total_sections := 0
var initial_sections := 0
var anchor := Vector3.ZERO
var cards: Node3D
signal finished

static func partition(saved: Node3D) -> Dictionary:
	var scenes: Array[PackedScene] = []
	var positions := PackedVector3Array()
	var globals := PackedByteArray()
	for container in saved.get_children():
		var groups := {}
		for child in container.get_children():
			var position: Vector3 = child.position if child is Node3D else Vector3.ZERO
			var cell := Vector2i(floori(position.x / 64.0), floori(position.z / 64.0))
			var key := str(cell)
			if not groups.has(key): groups[key] = []
			groups[key].append(child)
		for group in groups.values():
			for start in range(0, group.size(), 24):
				var root := Node3D.new()
				root.name = "CitySection"
				var target := Node3D.new()
				target.name = container.name
				root.add_child(target)
				target.owner = root
				var center := Vector3.ZERO
				var count := 0
				for child in group.slice(start, start + 24):
					if child is Node3D: center += child.position
					count += 1
					container.remove_child(child)
					clear_owner(child)
					target.add_child(child)
					own(child, root)
				var packed := PackedScene.new()
				var error := packed.pack(root)
				root.free()
				if error != OK: return {"error": error}
				scenes.append(packed)
				positions.append(center / maxf(1.0, count))
				globals.append(1 if str(container.name) in GLOBAL or str(container.name) == "ParkedCars" else 0)
	return {"error": OK, "scenes": scenes, "centers": positions, "global": globals}

static func own(node: Node, root: Node) -> void:
	node.owner = root
	node.scene_file_path = ""
	for child in node.get_children(): own(child, root)

static func clear_owner(node: Node) -> void:
	node.owner = null
	for child in node.get_children(): clear_owner(child)

func load_initial(data: Resource, all: bool) -> void:
	sections.assign(data.sections)
	centers = data.section_centers
	total_sections = sections.size()
	if not data.block_cards.is_empty():
		cards = preload("res://block_cards.gd").new()
		cards.name = "BlockRenderCards"
		city.add_child(cards)
		for card in data.block_cards: cards.add_card(card, data.night)
	anchor = city.get_parent().get_node("FoodTruck").global_position
	# Gameplay selects a service pad at startup, so load all pad positions first.
	for index in sections.size():
		if data.section_global[index] != 0: await attach_section(index, true)
	var nearest := INF
	var spawn_position := anchor
	for pad in city.get_parent().get_node("ParkingPads").get_children():
		if not pad is Node3D: continue
		var distance: float = pad.global_position.distance_squared_to(spawn_position)
		if distance < nearest: nearest = distance; self.anchor = pad.global_position
	for index in sections.size():
		if sections[index] == null: continue
		if all or Vector2(centers[index].x - anchor.x, centers[index].z - anchor.z).length() <= INITIAL_RADIUS:
			await attach_section(index, true)
		else: pending.append(index)
	initial_sections = loaded_sections
	city.set_meta("stream_anchor", anchor)
	city.set_meta("stream_initial_sections", initial_sections)
	city.set_meta("stream_total_sections", total_sections)
	city.set_meta("streaming_city", not pending.is_empty())
	if not pending.is_empty(): fill_background.call_deferred()

func attach_section(index: int, initial: bool) -> void:
	var root := sections[index].instantiate()
	var models: Array[Node3D] = []
	for container in root.get_children():
		var target: Node = city.get_parent().get_node(str(container.name)) if str(container.name) in ["ParkingPads", "PatronSpawns"] else city.get_node(str(container.name))
		for child in container.get_children():
			if str(container.name) in ["ParkingPads", "PatronSpawns"] and not str(child.name).begins_with("City"):
				var original: Node = target.get_node(str(child.name))
				original.position = child.position
				var surface := child.get_node_or_null("ServiceSurface")
				if surface != null: original.get_node("ServiceSurface").mesh = surface.mesh
				continue
			container.remove_child(child)
			city.get_node("/root/CityStore").clear_owners(child)
			target.add_child(child)
			if str(container.name) == "Buildings":
				var model := child.get_node_or_null("KenneyBuilding")
				if model != null: models.append(child)
	if cards != null: cards.section_loaded(index, models)
	for body in models: load("res://building_visual_lod.gd").attach(body, body.get_node("KenneyBuilding"))
	root.free()
	sections[index] = null
	loaded_sections += 1
	city.set_meta("stream_loaded_sections", loaded_sections)
	if initial: await city.loading_checkpoint()

func fill_background() -> void:
	while city.generating or not city.get_parent().is_loading_ready(): await get_tree().process_frame
	while not pending.is_empty():
		await get_tree().process_frame
		if get_tree().paused: continue
		var truck: Node3D = city.get_parent().get_node("FoodTruck")
		pending.sort_custom(func(a: int, b: int): return centers[a].distance_squared_to(truck.global_position) < centers[b].distance_squared_to(truck.global_position))
		await attach_section(pending.pop_front(), false)
	await load("res://city_parking_lots.gd").generate(city)
	city.set_meta("streaming_city", false)
	sections.clear()
	finished.emit()
