extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node3D = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.time_of_day_mode = 1
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	var fixtures := 0
	var splits := 0
	var rules := preload("res://city_road_rules.gd")
	for visual in city.get_node("Roads").find_children("*", "MeshInstance3D", true, false):
		var label := str(visual.get_meta("surface_decal", visual.name))
		if label.begins_with("SewerGrate") or label in ["ManholeCovers", "ManholeInsets"]:
			assert(visual.get_child_count() == 0, "Fixtures must not add collision")
			for vertex in visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var world: Vector3 = visual.to_global(vertex)
				assert(city.on_grid_road(Vector2(world.x, world.z), -0.1))
				assert(absf(world.y - city.terrain_surface_height_at(world.x, world.z) - 0.17) < 0.011)
			fixtures += 1
		if label == "ApproachLaneSplits":
			var road: Node3D = visual.get_parent()
			var vertical := str(road.name).begins_with("Road_V")
			for vertex in visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var along: float = vertex.z if vertical else vertex.x
				for cross in ([-144, -80, -16, 48, 112, 176] if vertical else [-128, -64, 0, 64, 128]):
					var sign := 1.0 if along < cross else -1.0
					var axis := Vector3(0, 0, sign) if vertical else Vector3(sign, 0, 0)
					var junction := Vector3(road.position.x, 0, cross) if vertical else Vector3(cross, 0, road.position.z)
					assert(absf(along - cross) > rules.stop_boundary(city, axis, junction) + 0.21)
			splits += 1
	assert(fixtures > 30 and splits > 0)
	print("STREET FIXTURES PASS: ", fixtures, " fixture meshes follow terrain without collision; ", splits, " approach meshes clear stop boundaries")
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.position = Vector3(88, city.height_at(64, -16) + 42, -48)
		camera.look_at(Vector3(64, city.height_at(64, -16), -16))
		camera.make_current()
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/street_fixtures_preview.png")
	quit()
