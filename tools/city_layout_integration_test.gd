extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var preferences := [1,0]
	var args := OS.get_cmdline_user_args()
	if "--map-size" in args: preferences = [int(args[args.find("--map-size")+1])]
	for preference in preferences:
		var level: Node = load("res://procedural_city.tscn").instantiate()
		var city: Node = level.get_node("ProceduralCity")
		city.randomize_each_load = false
		city.map_size = preference
		level.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(level)
		current_scene = level
		while city.generating: await process_frame
		assert(root.get_node("CityStore").last_source == root.get_node("CityStore").bundled_path(city))
		assert(city.topology.directed_connected())
		assert(city.topology.blocks.size() == (20 if preference == 1 else 12))
		assert(city.get_node("Roads/Asphalt") != null)
		var plots := 0
		for node in city.get_node("Parks").get_children():
			if node.has_meta("plot_kind"): plots += 1
		assert(plots > 5)
		var lamps := 0
		for node in city.get_node("StreetSigns").get_children():
			if node.get_meta("street_furniture","") == "lamp" or str(node.name).begins_with("StreetLight"):
				assert(city.furniture_on_sidewalk(Vector2(node.position.x,node.position.z)))
				lamps += 1
		assert(lamps > 0)
		var bridge_lamps := 0
		for node in city.get_node("StreetSigns").get_children():
			if node.get_meta("street_furniture", "") == "lamp":
				var p: Vector3 = node.position
				if absf(p.x - roundf(p.x / 64) * 64) < 16 and city.topology.artery_kind(true,roundf(p.x/64)*64) == "bridge": bridge_lamps += 1
				if absf(p.z - (roundf((p.z+16)/64)*64-16)) < 16 and city.topology.artery_kind(false,roundf((p.z+16)/64)*64-16) == "bridge": bridge_lamps += 1
			if str(node.name).begins_with("StopSign"):
				var parts := str(node.name).split("_")
				assert(city.topology.artery_kind(true,float(parts[1])) == "inner")
				assert(city.topology.artery_kind(false,float(parts[2])) == "inner")
		assert(bridge_lamps > 0, "Bridge arteries retain street lamps")
		for crossing in city.get_node("Crosswalks").get_children():
			if crossing.get("intersection_center_x") == null: continue
			var junction := Vector3(crossing.intersection_center_x,0,crossing.position.z + (city.crosswalk_setback if crossing.crosses_vertical_road else 0))
			assert(not city.bridge_intersection(junction), "Bridge junctions have no traffic signals")
		var forest := 0
		var wall := 0
		for node in city.get_node("HighwayApproaches").get_children():
			if str(node.name).begins_with("EdgeForest"): forest += 1
			if str(node.name).begins_with("EdgeWall"): wall += 1
		assert(forest == 0 and wall > 0)
		assert(city.find_children("ParkTree*", "", true, false).is_empty())
		await physics_frame
		await process_frame
		for index in city.topology.exits.size():
			var exit: Dictionary = city.topology.exits[index]
			var arrival: Dictionary = city.topology.exits[(index + 1) % city.topology.exits.size()]
			var axis: int = 2 if exit.vertical else 0
			level.truck.global_position = Vector3(exit.center.x,0,exit.center.y)
			level.truck.global_position[axis] += exit.side
			var transit: Node = level.truck.highway_transit
			assert(transit.drive(1.0/60))
			for step in 400:
				transit.drive(1.0/60)
				city._physics_process(1.0/60)
				if not transit.active: break
			assert(not transit.active and transit.wrapped,"Every exit must return through an actual highway")
			assert(level.truck.collision_layer != 0)
			var lateral: float = level.truck.global_position.x if arrival.vertical else level.truck.global_position.z
			assert(absf(lateral-(arrival.center.x if arrival.vertical else arrival.center.y)) <= 6.1)
		print("LAYOUT_CITY_PASS size=",preference," plots=",plots," sidewalk_lamps=",lamps," forests=",forest," walls=",wall," connected exits=",city.topology.exits.size())
		if DisplayServer.get_name() != "headless":
			level.get_node("HUD").hide()
			level.get_node("MobileControls").hide()
			var camera := Camera3D.new()
			level.add_child(camera)
			var center: Vector2 = city.topology.bounds.get_center()
			camera.position = Vector3(center.x+80,260,center.y+100)
			camera.look_at(Vector3(center.x,15,center.y))
			camera.projection=Camera3D.PROJECTION_ORTHOGONAL
			camera.size=city.topology.bounds.size.y+60
			camera.make_current()
			await create_timer(.3).timeout
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://.godot/city_layout_%d.png" % preference)
		level.queue_free()
		await process_frame
	quit()
