extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check_contacts(car) -> void:
	var normal: Vector3 = car.contact_ground.normal
	var plane: Vector3 = car.contact_ground.position
	for wheel in car.wheels:
		var rest_point: Vector3 = car.wheel_rig.global_transform.affine_inverse() * (car.visual.global_transform * wheel.center)
		var actual: Vector3 = car.wheel_rig.global_transform * (car.wheel_rig.get_bone_global_pose(wheel.bone) * (wheel.rest.affine_inverse() * rest_point))
		assert(actual.distance_to(wheel.world_center) < 0.002, "Actual skinned wheel bone must match contact solution")
		if wheel.planted:
			assert(actual.distance_to(wheel.anchor) < 0.002, "Loaded tire must not slip")
		for offset in wheel.points:
			assert(normal.dot(wheel.world_center + wheel.world_basis * offset - plane) >= 0.018, "Tire geometry must not penetrate support plane")
	for vertex in car.body_points:
		assert(normal.dot(car.visual.global_transform * vertex - plane) >= 0.018)

func run() -> void:
	var scene = load("res://scenes/hybrid_car_demo.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_process(false)
	for model_index in 6:
		for ramp in [false, true]:
			scene.selected_model = model_index
			scene.reset_car()
			var car = scene.car
			car.set_physics_process(false)
			car.position = Vector3(12, 4, -12) if ramp else Vector3(0, 0.15, 10)
			await physics_frame
			car.spin_rng.seed = 8
			car.receive_impact(Vector3.RIGHT * 3, Vector3.RIGHT)
			var root_start: Vector3 = car.position
			for tick in 180:
				if tick % 12 == 0:
					car.receive_impact(Vector3.RIGHT * 3, Vector3.RIGHT)
				car._physics_process(1.0 / 60.0)
				assert(car.state == car.State.REACTION and absf(car.pose.z) <= car.light_tip_cap)
				assert(car.rollover_energy == 0 and car.position.is_equal_approx(root_start))
				check_contacts(car)
			for tick in 360:
				car._physics_process(1.0 / 60.0)
			assert(car.state == car.State.DRIVING, "Repeated light tips must recover")
			car.tire_friction = 0.3
			car.receive_impact(Vector3.LEFT * 5, Vector3.LEFT)
			assert(car.medium_tip_target > 0 and car.medium_tip_target < deg_to_rad(30))
			for tick in 420:
				car._physics_process(1.0 / 60.0)
				if car.contact_locked:
					check_contacts(car)
			assert(car.state == car.State.DRIVING, "Moderate stable tip must recover")
			car.tire_friction = 1.0
			car.receive_impact(Vector3.RIGHT * 11.8, Vector3.RIGHT)
			assert(car.medium_tip_target < 0)
			for tick in 240:
				car._physics_process(1.0 / 60.0)
				check_contacts(car)
			assert(car.state == car.State.DISABLED and car.explosion_count == 0)
			assert(absf(car.pose.z) > deg_to_rad(89))
			var disabled_position: Vector3 = car.position
			car.throttle = 1.0
			car.steering = 1.0
			car.receive_impact(Vector3.LEFT * 30, Vector3.LEFT)
			for tick in 60:
				car._physics_process(1.0 / 60.0)
			assert(car.position.is_equal_approx(disabled_position) and car.speed == 0 and car.state == car.State.DISABLED)
	# Grip and cross-slope bias change tipping resistance/target without changing signs.
	scene.reset_car()
	var car = scene.car
	car.set_physics_process(false)
	car.position = Vector3(12, 4, -12)
	car.rotation.y = PI * 0.5
	await physics_frame
	car.receive_impact(car.global_basis * Vector3.RIGHT * 8, car.global_basis * Vector3.RIGHT)
	var biased_right: float = absf(car.medium_tip_target)
	car.state = car.State.DRIVING
	car.pose = Vector3.ZERO
	car.receive_impact(car.global_basis * Vector3.LEFT * 8, car.global_basis * Vector3.LEFT)
	assert(not is_equal_approx(absf(car.medium_tip_target), biased_right), "Cross-slope must bias direction")
	car.tire_friction = 0.4
	car.state = car.State.DRIVING
	car.receive_impact(car.global_basis * Vector3.LEFT * 8, car.global_basis * Vector3.LEFT)
	assert(absf(car.medium_tip_target) < biased_right)
	print("TIRE PASS: all six rigs on flat/ramp; actual wheel bones planted, tire/body clearance, repeated light caps/recovery, medium recovery, energetic rollover, disabled driving, friction and cross-slope bias")
	quit()
