extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node3D = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.time_of_day_mode = 1
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: city.fixed_seed = int(args[0])
	if args.size() > 1: city.multi_crosswalk_fraction = float(args[1])
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	var rules := preload("res://city_road_rules.gd")
	var bars := 0
	var crossed := 0
	var uncrossed := 0
	for visual in city.get_node("Roads").get_children():
		if not visual is MeshInstance3D: continue
		var label: String = visual.get_meta("surface_decal", "")
		if not label.begins_with("StopLine_"): continue
		var bounds: AABB = visual.mesh.get_aabb()
		var center: Vector3 = visual.to_global(bounds.get_center())
		var axis := Vector3.BACK if label == "StopLine_Southbound" else Vector3.FORWARD
		if label == "StopLine_Eastbound": axis = Vector3.RIGHT
		if label == "StopLine_Westbound": axis = Vector3.LEFT
		var junction := Vector3(roundf((center.x + 128) / 64) * 64 - 128, 0, roundf((center.z + 144) / 64) * 64 - 144)
		var distance := (junction - center).dot(axis)
		assert(absf(distance - rules.stop_boundary(city, axis, junction)) < 0.002)
		if rules.has_approach_crosswalk(city, axis, junction):
			assert(distance - 0.21 > city.crosswalk_setback + 1.8)
			crossed += 1
		else:
			assert(absf(distance - 0.21 - rules.approach_edge(city, axis, junction) - 1.0) < 0.002)
			uncrossed += 1
		bars += 1
	assert(crossed > 0 and uncrossed > crossed)
	var asphalt: MeshInstance3D = city.get_node("Roads/Asphalt")
	for vertex in asphalt.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert(absf(vertex.y - city.terrain_surface_height_at(vertex.x, vertex.z) - 0.12) < 0.003, "Asphalt vertex mismatch %s" % vertex)
	await physics_frame
	await physics_frame
	var pockets := 0
	for x in range(-96, 97, 64):
		for z in range(-112, 145, 64):
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var edge_x: float = x + sx * (32.0 - city.road_width * 0.5 - rules.extra_width(true, x + sx * 32, -sx))
					var edge_z: float = z + sz * (32.0 - city.road_width * 0.5 - rules.extra_width(false, z + sz * 32, -sz))
					# Sample inside the infill rather than exactly on a shared
					# terrain-triangle edge, where ray precision is ambiguous.
					var point := Vector2(edge_x - sx * 0.65, edge_z - sz * 0.55)
					var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 1000, point.y), Vector3(point.x, -100, point.y), 1)
					var hit := root.world_3d.direct_space_state.intersect_ray(query)
					assert(not hit.is_empty() and hit.collider.get_parent().name == "Asphalt", "Rounded pocket must have asphalt at %s" % point)
					assert(absf(hit.position.y - city.terrain_surface_height_at(point.x, point.y) - 0.12) < 0.003, "Pocket height %s: got %s expected %s" % [point, hit.position.y, city.terrain_surface_height_at(point.x, point.y) + 0.12])
					pockets += 1
	print("INTERSECTION GEOMETRY PASS: ", bars, " bars (", crossed, " crossed, ", uncrossed, " uncrossed); ", pockets, " terrain-following asphalt corner pockets")
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 56
		camera.position = Vector3(0, city.height_at(0, -16) + 120, -16)
		camera.look_at(Vector3(0, city.height_at(0, -16), -16), Vector3.FORWARD)
		camera.make_current()
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/intersection_geometry_preview.png")
	quit()
