extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func has_axis(action: String, axis: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis: return true
	return false

func run() -> void:
	var controls = root.get_node("DrivingControls")
	assert(has_axis("gear_accelerate", JOY_AXIS_TRIGGER_RIGHT))
	assert(has_axis("brake", JOY_AXIS_TRIGGER_LEFT))
	assert(not has_axis("reverse", JOY_AXIS_TRIGGER_LEFT))
	assert(not has_axis("accelerate", JOY_AXIS_TRIGGER_RIGHT))
	var horn_mapped := false
	for event in InputMap.action_get_events("truck_horn"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_STICK: horn_mapped = true
	assert(horn_mapped)
	controls.select_gear(-1.0)
	controls.select_gear(0.0)
	assert(controls.gear == 1)
	Input.action_press("gear_accelerate", 0.8)
	assert(is_equal_approx(controls.action_strength("accelerate"), 0.8))
	assert(controls.action_strength("reverse") == 0.0)
	controls.select_gear(1.0)
	controls.select_gear(0.2)
	assert(controls.gear == -1)
	assert(is_equal_approx(controls.action_strength("reverse"), 0.8))
	assert(controls.action_strength("accelerate") == 0.0)
	assert(controls.reverse_view_requested(), "Reverse gear immediately looks rearward")
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	assert(scene.get_node("ProceduralCity/ParkingSpaces").get_child_count() == 6)
	for frame in 30: await physics_frame
	assert(scene.truck.speed < 0.0)
	scene._process(1.0 / 60.0)
	assert((scene.camera.global_position - scene.truck.global_position).dot(scene.truck.global_basis.z) < 0.0)
	Input.action_press("camera_up")
	assert(not controls.reverse_view_requested())
	scene._process(1.0/60)
	assert((scene.camera.global_position-scene.truck.global_position).dot(scene.truck.global_basis.z) > 0)
	Input.action_release("camera_up")
	assert(not controls.reverse_view_requested(), "Forward flick remains latched")
	controls.select_gear(-1.0)
	assert(not controls.reverse_view_requested())
	controls.select_gear(1.0)
	assert(controls.reverse_view_requested(), "New reverse selection restores rear view")
	var speed: float = absf(scene.truck.speed)
	Input.action_press("brake")
	for frame in 10: await physics_frame
	assert(absf(scene.truck.speed) < speed)
	Input.action_release("gear_accelerate")
	Input.action_release("brake")
	Input.action_press("truck_horn")
	for frame in 10: await physics_frame
	assert(scene.truck.horn_count == 1 and scene.truck.horn_player.stream != null)
	Input.action_release("truck_horn")
	controls.select_gear(-1.0)
	Input.action_press("gear_accelerate")
	for frame in 30: await physics_frame
	assert(scene.truck.speed > 0.0)
	Input.action_release("gear_accelerate")
	controls.last_brake_press_msec = -100000
	for frame in 2: await physics_frame
	Input.action_press("brake")
	for frame in 3: await physics_frame
	Input.action_release("brake")
	for frame in 2: await physics_frame
	Input.action_press("brake")
	for frame in 45: await physics_frame
	assert(scene.truck.speed < 0.0, "Second brake tap held must accelerate backward")
	assert(controls.action_strength("brake") == 0.0)
	Input.action_press("gear_accelerate", 0.8)
	assert(is_equal_approx(controls.action_strength("accelerate"), 0.8))
	assert(controls.gear == 1 and not controls.brake_reverse_active)
	assert(controls.action_strength("reverse") == 0.0)
	assert(controls.action_strength("brake") == 0.0, "Held reverse shortcut must not brake against forward acceleration")
	for frame in 90: await physics_frame
	assert(scene.truck.speed > 0.0, "Gas must return to forward driving while LT remains held")
	Input.action_release("gear_accelerate")
	assert(controls.action_strength("brake") == 0.0)
	Input.action_release("brake")
	for frame in 2: await physics_frame
	assert(not controls.brake_reverse_active and not controls.brake_reverse_drive_override)
	Input.action_press("brake")
	assert(controls.action_strength("brake") == 1.0, "Next LT press must brake normally")
	Input.action_release("brake")
	# RT also overrides shortcut reverse after LT has already been released.
	controls.update_brake_shortcut(0.0,999900)
	controls.last_brake_press_msec = -100000
	controls.update_brake_shortcut(1.0,1000000)
	controls.update_brake_shortcut(0.0,1000050)
	controls.update_brake_shortcut(1.0,1000100)
	assert(controls.shortcut_reverse_selected and controls.gear == -1)
	controls.update_brake_shortcut(0.0,1000150)
	Input.action_press("gear_accelerate",0.8)
	assert(is_equal_approx(controls.action_strength("accelerate"),0.8))
	assert(controls.gear == 1 and controls.action_strength("reverse") == 0.0)
	assert(not controls.brake_reverse_drive_override)
	Input.action_release("gear_accelerate")
	print("CONTROLLER GEARS PASS: D/R latch, directional RT throttle, LT braking, immediate reverse camera / persistent forward flick, one horn per press, six test bays")
	scene.truck.horn_player.stop()
	quit()
