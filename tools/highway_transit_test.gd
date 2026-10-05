extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.get_node("ProceduralCity").set_physics_process(false)
	scene.truck.set_physics_process(false)
	var city = scene.get_node("ProceduralCity")
	var signs := Node3D.new()
	signs.name = "HighwayApproaches"
	city.add_child(signs)
	for axis in [0, 2]:
		for side in [-1.0, 1.0]:
			var road_sign := Node3D.new()
			road_sign.position[axis] = side * 152.0
			road_sign.set_meta("highway_axis", axis)
			road_sign.set_meta("highway_side", side)
			signs.add_child(road_sign)
	var driver = scene.truck.highway_transit
	var layer: int = scene.truck.collision_layer
	var mask: int = scene.truck.collision_mask
	for axis in [0, 2]:
		for side in [-1.0, 1.0]:
			scene.truck.global_position = Vector3.ZERO
			scene.truck.global_position[axis] = side * 153.0
			var lateral := 2 if axis == 0 else 0
			scene.truck.global_position[lateral] = 10.0
			assert(driver.drive(1.0 / 60.0))
			assert(scene.truck.global_position[lateral] > 9.9, "Lane alignment must ease rather than snap")
			for tick in 60: driver.drive(1.0/60.0)
			var lane: float = (side*4.0 if axis == 0 else -side*4.0) * city.road_width / 16.0
			assert(is_equal_approx(scene.truck.global_position[lateral],lane))
			assert(is_equal_approx(scene.truck.global_position.y,driver.surface_height(scene.truck.global_position)+.05))
			assert(driver.active and scene.truck.speed == scene.truck.forward_speed)
			assert(scene.truck.collision_layer == 0 and scene.truck.collision_mask == 0)
			var health: float = scene.truck.health
			scene.truck.take_damage(50.0)
			assert(scene.truck.health == health)
			scene.truck.global_position[axis] = -side * 173.0
			assert(driver.drive(1.0 / 60.0))
			assert(driver.wrapped)
			assert(is_equal_approx(scene.truck.global_position[lateral],lane), "Return must emerge in the driving lane")
			for i in 4:
				var wheel: Vector3 = scene.truck.skeleton.to_global(scene.truck.skeleton.get_bone_global_pose(scene.truck.suspension_bones[i]).origin)
				assert(absf(wheel.y-.59-driver.surface_height(wheel)) < .12, "Wheel must meet road during highway transit")
			for tick in range(120):
				if not driver.drive(1.0 / 60.0): break
			assert(not driver.active)
			assert(scene.truck.collision_layer == layer and scene.truck.collision_mask == mask)
	var controls = root.get_node("DrivingControls")
	controls.gear = 1
	controls.update_brake_shortcut(1.0, 1000)
	assert(controls.gear == 1)
	controls.update_brake_shortcut(1.0, 1100)
	assert(controls.gear == 1, "Holding brake must not count as another tap")
	controls.update_brake_shortcut(0.0, 1150)
	Input.action_press("brake")
	controls.update_brake_shortcut(1.0, 1200)
	assert(controls.gear == -1)
	assert(controls.action_strength("brake") == 0.0)
	assert(controls.action_strength("reverse") == 1.0)
	Input.action_release("brake")
	assert(controls.action_strength("reverse") == 0.0)
	controls.select_gear(-1.0)
	controls.update_brake_shortcut(0.0, 1300)
	controls.update_brake_shortcut(1.0, 2000)
	controls.update_brake_shortcut(0.0, 2100)
	controls.update_brake_shortcut(1.0, 2400)
	assert(controls.gear == 1, "Slow taps keep Drive")
	print("HIGHWAY_TRANSIT_PASS: full-speed/no-collision trip in four directions, control restoration; brake double-tap Reverse")
	quit()
