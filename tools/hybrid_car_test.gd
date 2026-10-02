extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/hybrid_car_demo.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	scene.set_process(false)
	var car = scene.car
	car.set_physics_process(false)
	assert(scene.controller_drive(Vector2(0.1, -0.1)) == Vector2.ZERO)
	var analog: Vector2 = scene.controller_drive(Vector2(0.5, -0.5))
	assert(analog.x > 0 and analog.x < 1 and analog.y > 0 and analog.y < 1)
	assert(scene.controller_drive(Vector2(-1, 1)) == Vector2(-1, -1))
	for stick in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, -1)]:
		scene.aim_right_stick(stick)
		var expected := Vector3(stick.x, 0, stick.y).normalized()
		assert(scene.impact_aim.is_equal_approx(expected))
		scene.aim_right_stick(Vector2(0.01, 0.01))
		assert(scene.impact_aim.is_equal_approx(expected), "Right-stick deadzone must retain aim")
	assert(scene.axis_value(0.01, scene.trigger_deadzone) == 0)
	assert(scene.controller_command(JOY_BUTTON_A) == "impact")
	assert(scene.controller_command(JOY_BUTTON_B) == "reset")
	assert(scene.controller_command(JOY_BUTTON_LEFT_SHOULDER) == "previous_model")
	assert(scene.controller_command(JOY_BUTTON_RIGHT_SHOULDER) == "next_model")
	assert(scene.controller_command(JOY_BUTTON_DPAD_UP) == "up_impact")
	assert(scene.controller_command(JOY_BUTTON_DPAD_DOWN) == "down_impact")
	assert(scene.arrow_length(40) > scene.arrow_length(3))
	assert(is_equal_approx(scene.arrow_length(20), 3.0))
	car.rotation.y = 0.6
	scene.update_aim_arrow()
	assert(scene.aim_arrow.global_basis.y.is_equal_approx((car.global_basis * scene.impact_aim).normalized()))
	assert(scene.aim_arrow.find_children("*", "CollisionObject3D", true, false).is_empty())
	car.rotation = Vector3.ZERO
	scene.select_direction(0)
	# Driving channels ease into targets and ring down proportionally to force.
	car.update_driving_pose(1.0 / 60.0, 10.0)
	assert(car.driving_pose.x > 0 and car.driving_pose.x < 0.01, "Start pose must ease, not snap to 0.12 radians")
	for index in 60:
		car.update_driving_pose(1.0 / 60.0, 10.0)
	var hard_peak: float = car.driving_pose.x
	var before_stop: float = car.driving_pose.x
	car.update_driving_pose(1.0 / 60.0, 0.0)
	assert(absf(car.driving_pose.x - before_stop) < 0.01, "Stop transition must preserve pose continuity")
	var minimum := 0.0
	for index in 240:
		car.update_driving_pose(1.0 / 60.0, 0.0)
		minimum = minf(minimum, car.driving_pose.x)
	assert(minimum < -0.0001, "Hard maneuver must have a small settling bounce")
	assert(car.driving_pose.length() < 0.001 and car.driving_pose_velocity.length() < 0.001)
	for index in 60:
		car.update_driving_pose(1.0 / 60.0, 1.0)
	assert(car.driving_pose.x < hard_peak * 0.2, "Gentle maneuver should stay subtle")
	for index in 240:
		car.update_driving_pose(1.0 / 60.0, 0.0)
	# Every existing model must fit, retain its rig, and clear flat/sloped planes.
	for model_index in car.MODELS.size():
		car.set_model(model_index)
		assert(car.chassis_pivot.y > car.model_bounds.position.y)
		for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3(1, 0, -1).normalized()]:
			car.stop_disabled_cue()
			car.collision_layer = 1
			car.collision_mask = 1
			car.driving_shape.disabled = false
			car.state = car.State.DRIVING
			car.pose = Vector3.ZERO
			car.pose_velocity = Vector3.ZERO
			car.velocity = Vector3.ZERO
			car.receive_impact(direction * 3.0, direction)
			car._physics_process(1.0 / 60.0)
			assert(signf(car.pose.x) == signf(direction.z))
			var roll_input: float = direction.x
			assert(signf(car.pose.z) == -signf(roll_input))
			var peak := 0.0
			for tick in 360:
				car._physics_process(1.0 / 60.0)
				peak = maxf(peak, Vector2(car.pose.x, car.pose.z).length())
			assert(peak > 0.08 and peak < car.light_tip_cap + 0.01, "Light jolt should use a small controlled tip")
			assert(car.state == car.State.DRIVING and car.pose == Vector3.ZERO)
		# In free space, the chosen pivot remains fixed while the mesh rotates.
		car.apply_ground_pose({}, Vector3(0.04, 0, -0.04))
		assert((car.visual.transform * car.chassis_pivot).is_equal_approx(car.chassis_pivot + Vector3.UP * car.driving_pose.y))
		for direction in [Vector3.LEFT, Vector3.RIGHT]:
			car.stop_disabled_cue()
			car.collision_layer = 1
			car.collision_mask = 1
			car.driving_shape.disabled = false
			car.state = car.State.DRIVING
			car.contact_locked = false
			car.pose = Vector3.ZERO
			car.pose_velocity = Vector3.ZERO
			car.velocity = Vector3.ZERO
			car.tire_friction = 0.3
			car.receive_impact(direction * 5.0, direction)
			for tick in 420:
				car._physics_process(1.0 / 60.0)
			assert(car.state == car.State.DRIVING, 'Below-balance medium tip must recover')
			car.tire_friction = 0.85
			car.receive_impact(direction * 11.8, direction)
			for tick in 180:
				car._physics_process(1.0 / 60.0)
			assert(car.state == car.State.DISABLED, 'Crossed balance must continue into rollover')
			assert(signf(car.pose.z) == -signf(direction.x))
			assert(absf(car.pose.z) >= deg_to_rad(89))
		car.stop_disabled_cue()
		car.collision_layer = 1
		car.collision_mask = 1
		car.driving_shape.disabled = false
		car.state = car.State.DRIVING
		car.contact_locked = false
		car.pose = Vector3.ZERO
		car.pose_velocity = Vector3.ZERO
		assert(car.model_bounds.size.x > 0.5 and car.model_bounds.size.y > 0.3)
		var skeletons = car.model_root.find_children("*", "Skeleton3D", true, false)
		assert(not skeletons.is_empty(), "Selected existing rig must load")
		assert(skeletons[0].find_bone("Chassis") >= 0)
		assert(skeletons[0].find_bone("Spring_FL") >= 0)
		for normal in [Vector3.UP, Vector3(0.2, 1, 0.3).normalized()]:
			car.apply_ground_pose({"normal": normal, "position": car.global_position}, Vector3(0.25, 0, -0.3))
			for vertex in car.body_points:
				assert(normal.dot(car.visual.global_transform * vertex - car.global_position) >= 0.019, "Body vertices must clear support plane")
			for wheel in car.wheels:
				for offset in wheel.points:
					assert(normal.dot(wheel.world_center + wheel.world_basis * offset - car.global_position) >= 0.019, "Wheel vertices must clear support plane")
	car.set_model(0)
	# Seed repeatably for tests; demo randomizes per car instance.
	car.spin_rng.seed = 42
	var axes: Array[Vector3] = []
	for direction in scene.DIRECTIONS:
		car.stop_disabled_cue()
		car.collision_layer = 1
		car.collision_mask = 1
		car.driving_shape.disabled = false
		car.state = car.State.DRIVING
		car.pose_velocity = Vector3.ZERO
		car.velocity = Vector3.ZERO
		car.rotation.y = 0.7
		var world_direction: Vector3 = car.global_basis * direction.normalized()
		car.receive_impact(world_direction * 20, world_direction)
		assert(car.state == car.State.FLIGHT)
		assert(absf(car.tumble_axis.x) > 0.05 and absf(car.tumble_axis.z) > 0.05, "Strong impacts must blend pitch and roll")
		if absf(direction.z) > 0.1:
			assert(signf(car.tumble_axis.x) == signf(direction.z))
		if absf(direction.x) > 0.1:
			assert(signf(car.tumble_axis.z) == -signf(direction.x))
		assert(car.local_impact.is_equal_approx(direction.normalized()), "Direction must be car-local even at rotated heading")
		axes.append(car.tumble_axis)
	car.stop_disabled_cue()
	car.collision_layer = 1
	car.collision_mask = 1
	car.driving_shape.disabled = false
	car.state = car.State.DRIVING
	car.velocity = Vector3.ZERO
	car.receive_impact(car.global_basis * Vector3.FORWARD * 20, car.global_basis * Vector3.FORWARD)
	assert(not car.tumble_axis.is_equal_approx(axes[0]), "Repeated directional hits should vary")
	car.stop_disabled_cue()
	car.collision_layer = 1
	car.collision_mask = 1
	car.driving_shape.disabled = false
	car.state = car.State.DRIVING
	car.pose_velocity = Vector3.ZERO
	car.rotation = Vector3.ZERO
	car.velocity = Vector3.ZERO
	car.visual.rotation = Vector3.ZERO
	car.throttle = 1.0
	for index in 60:
		car._physics_process(1.0 / 60.0)
	assert(car.speed > 4.0 and car.global_position.z < 10.0)
	car.throttle = 0.0
	for index in 60:
		car._physics_process(1.0 / 60.0)
	assert(is_zero_approx(car.speed), "Release throttle must brake")
	car.throttle = -1.0
	for index in 60:
		car._physics_process(1.0 / 60.0)
	assert(car.speed < -4.0, "Reverse must use signed speed")
	car.throttle = 1.0
	car.speed = 8.0
	car.steering = 1.0
	var start_heading: float = car.rotation.y
	car._physics_process(0.1)
	assert(car.rotation.y < start_heading)
	car.steering = -1.0
	start_heading = car.rotation.y
	car._physics_process(0.1)
	assert(car.rotation.y > start_heading)
	car.throttle = 0.0
	car.steering = 0.0
	car.speed = 0.0
	car.rotation = Vector3.ZERO
	car.global_position = Vector3(0, 0.05, 10)
	car.velocity = Vector3.ZERO
	car.receive_impact(Vector3.RIGHT * 3, Vector3.RIGHT)
	assert(car.state == car.State.REACTION and car.pose_velocity.z < 0)
	for index in 360:
		car._physics_process(1.0 / 60.0)
	assert(car.state == car.State.DRIVING, "Reaction must settle and disable spring integration")
	car.tire_friction = 0.3
	car.receive_impact(Vector3.LEFT * 5, Vector3.LEFT)
	assert(car.pose_velocity.z > 0, "Opposite impact must mirror roll")
	for index in 360:
		car._physics_process(1.0 / 60.0)
	assert(car.state == car.State.DRIVING)
	car.global_position = Vector3(12, 4, -12)
	await physics_frame
	var ground: Dictionary = car.ground_sample()
	assert(not ground.is_empty() and ground.normal.y < 0.999, "Ramp collision must provide slope normal")
	assert(car.crash_intersects(Vector3(-10, 4, -5), Vector3(-10, 4, -30)), "Sweep must catch a building between endpoints")
	assert(car.crash_intersects(Vector3(-10, 4, -18), Vector3(-10, 4, -18)), "Overlap must catch initial penetration")
	car.global_position = Vector3(0, 0.05, 10)
	car.velocity = Vector3.ZERO
	car.receive_impact(Vector3.RIGHT * 20, Vector3.RIGHT)
	assert(car.state == car.State.FLIGHT and car.velocity.y > 0 and car.tumble_axis.z < 0)
	for index in 600:
		if car.state == car.State.EXPLODED:
			break
		car._physics_process(1.0 / 60.0)
	assert(car.state == car.State.EXPLODED, "Flight must explode on ground contact")
	car.explode_once()
	assert(car.explosion_count == 1 and not car.visual.visible)
	scene.selected_model = 3
	scene.reset_car()
	assert(scene.car.model_index == 3)
	scene.reset_car()
	assert(scene.car.model_index == 3, "Reset must retain selected model")
	print("HYBRID PASS: six-model friction-scaled medium roll, opposite signs, bounded recovery; controller mapping, arrow, light tips, driving easing, mesh/tire clearance, mixed strong spin, crash/explosion")
	quit()

