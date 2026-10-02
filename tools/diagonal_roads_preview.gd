extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.time_of_day_mode = 2 if "--night" in OS.get_cmdline_user_args() else 1
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.truck.set_physics_process(false)
	scene.get_node("HUD").hide()
	scene.get_node("MobileControls").hide()
	assert(city.get_node("Roads").find_children("DiagonalRoad_*", "Node3D", false, false).size() == 3)
	var diagonal_counts: Dictionary = {}
	assert(city.get_node("Parks").find_children("DiagonalGrassPlot_*", "Node3D", false, false).size() > 0)
	for building in city.get_node("Buildings").get_children():
		if building.has_node("BuildingCollision"):
			var center := Vector2i(roundi((building.position.x - 32.0) / 64.0) * 64 + 32, roundi((building.position.z - 16.0) / 64.0) * 64 + 16)
			if city.is_diagonal_plot(Vector2(center)):
				diagonal_counts[center] = int(diagonal_counts.get(center, 0)) + 1
				assert(diagonal_counts[center] <= city.diagonal_plot_building_limit)
			var width: float = building.get_node("BuildingCollision").shape.size.x * 0.5
			assert(city.distance_to_diagonal_road(Vector2(building.position.x, building.position.z)) > city.diagonal_road_width * 0.5 + width)
	for bay in city.get_node("ParkingSpaces").get_children():
		assert(city.distance_to_diagonal_road(Vector2(bay.position.x, bay.position.z)) >= city.diagonal_road_width * 0.5 + 5.0)
	print("DIAGONAL ROADS PASS: three connected roads, clear buildings and parking")
	if DisplayServer.get_name() == "headless":
		quit()
		return
	scene.set_process(false)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 390.0
	camera.position = Vector3(0, 400, 16)
	camera.look_at(Vector3(0, 0, 16), Vector3.FORWARD)
	if "--windows" in OS.get_cmdline_user_args():
		camera.size = 85.0
		camera.position = Vector3(-32, 45, 15)
		camera.look_at(Vector3(-32, 0, -48))
	camera.make_current()
	root.size = Vector2i(1100, 1000)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/diagonal_roads_preview.png")
	quit()
