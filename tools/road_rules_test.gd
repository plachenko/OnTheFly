extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var rules := preload("res://city_road_rules.gd")
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.time_of_day_mode = 1
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	assert(city.get_node("Roads/Road_V_0").get_meta("road_type") == "double_yellow")
	assert(city.get_node("Roads/Road_V_64").get_meta("road_type") == "passing")
	assert(city.get_node("Roads/Road_H_112").get_meta("road_type") == "one_way")
	assert(city.get_node("StreetSigns").find_children("*OneWaySign*", "Node3D", false, false).size() == 11)
	assert(city.on_grid_road(Vector2(54, 0)))
	assert(not rules.allows(Vector3.RIGHT, Vector3(0, 0, 112)))
	assert(not rules.allows(Vector3.FORWARD, Vector3(-64, 0, 0)))
	assert(rules.approach_kind(Vector3.BACK, Vector3(64, 0, -144)) == "left")
	assert(rules.approach_kind(Vector3.BACK, Vector3(64, 0, -80)) == "straight_left")
	assert(rules.approach_kind(Vector3.BACK, Vector3(64, 0, 112)) == "straight")
	assert(not rules.passing_allowed(Vector3.BACK, Vector3(-4, 0, 0)))
	assert(rules.passing_allowed(Vector3.BACK, Vector3(60, 0, 0)))
	assert(rules.approach_kind(Vector3.BACK, Vector3(-64, 0, -80), 4) == "straight")
	assert(rules.approach_kind(Vector3.BACK, Vector3(-64, 0, -80), -4) == "straight_left")
	var car: Node
	for body in city.get_node("Traffic").get_children():
		body.set_physics_process(false)
		assert(rules.allows(body.travel_axis, body.lane_center))
		if car == null: car = body
	car.travel_axis = Vector3.BACK
	car.lane_center = Vector3(60, 0, 0)
	car.progress = -162.0
	car.turn_intent = 0
	car.considered_intersections.clear()
	car.intersection_turn_chance = 0.01
	car.plan_intersection_turn()
	assert(car.turn_intent == -1) # Left-only approach forces the turn.
	car.begin_turn()
	assert(rules.allows(car.turn_exit_axis, car.turn_center))
	car.travel_axis = Vector3.BACK
	car.lane_center = Vector3(-68, 0, 0)
	car.progress = 94.0
	car.turn_intent = 0
	car.considered_intersections.clear()
	car.intersection_turn_chance = 1.0
	car.plan_intersection_turn()
	assert(car.turn_intent == 0) # No left turn into an opposing one-way street.
	print("ROAD RULES PASS: double yellow, widened passing side, 11 one-way signs, legal traffic spawns, forced left-only and combined approaches")
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 95
		camera.position = Vector3(64, 180, -98)
		camera.look_at(Vector3(64, 0, -98), Vector3.FORWARD)
		camera.make_current()
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/road_rules_preview.png")
	quit()
