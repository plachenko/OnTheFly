extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	assert(scene.cops.size() == 1)
	scene.add_cop()
	scene.add_cop()
	assert(scene.cops.size() == 3)
	scene.police_role = true
	scene.apply_role()
	var original = scene.cop
	scene.cycle_cop()
	assert(scene.cop != original)
	assert(original.is_physics_processing() and not scene.cop.is_physics_processing())
	assert(not scene.truck.is_physics_processing())
	scene.start_pursuit()
	var dispatch = root.get_node("PoliceDispatch")
	assert(dispatch.pursuing)
	for officer in scene.cops:
		assert(officer.get_node("PoliceCircle").pursuing)
		assert(officer.get_node("VehicleLights").police_enabled)
	Input.action_press("accelerate")
	var start: Vector3 = scene.cop.global_position
	for frame in 30:
		await physics_frame
	Input.action_release("accelerate")
	assert(scene.cop.global_position.distance_to(start) > 0.1)
	scene.police_role = false
	scene.apply_role()
	assert(scene.truck.is_physics_processing())
	scene.truck.global_position = Vector3(11, 0.15, 22)
	scene.truck.speed = 0.0
	scene.truck.set_physics_process(false)
	dispatch._physics_process(2.1)
	assert(not dispatch.pursuing and scene.money == 500)
	for officer in scene.cops:
		assert(not officer.get_node("PoliceCircle").pursuing)
		assert(not officer.get_node("VehicleLights").police_enabled)
	print("POLICE SCENE PASS: spawn cops, switch roles and cars, manual driving, group pursuit and voluntary warning")
	quit()
