extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/hybrid_car_demo.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_process(false)
	for model in 6:
		scene.selected_model = model
		for aim in scene.DIRECTIONS.slice(0, 8):
			scene.reset_car()
			var car = scene.car
			car.set_physics_process(false)
			car.rotation.y = 0.7
			await physics_frame
			scene.impact_aim = aim.normalized()
			scene.impact_strength = 3
			scene.update_aim_arrow()
			var world_push: Vector3 = car.global_basis * scene.impact_aim
			assert(scene.aim_arrow.global_basis.y.is_equal_approx(world_push))
			scene.trigger_impact()
			assert(scene.last_push.is_equal_approx(world_push))
			assert(car.tip_axis.is_equal_approx(Vector3(aim.z, 0, -aim.x).normalized()))
			for wheel in car.wheels:
				if wheel.loaded:
					assert(wheel.center.dot(aim.normalized()) > 0, "Loaded support must lie in push direction")
			for tick in 10:
				car._physics_process(1.0 / 60.0)
			assert(signf(car.pose.x) == signf(aim.z) and signf(car.pose.z) == -signf(aim.x))
			for tick in 300:
				car._physics_process(1.0 / 60.0)
			assert(car.state == car.State.DRIVING)
	# Charging is release-once, capped, cancellable, and uses current aim/heading.
	scene.reset_car()
	scene.car.set_physics_process(false)
	await physics_frame
	scene.impact_aim = Vector3.RIGHT
	scene.impact_strength = 3
	var baseline: int = scene.committed_impacts
	scene.begin_charge("keyboard")
	scene.advance_charge(1.0)
	assert(scene.effective_strength() > 3 and scene.effective_strength() < 11.8)
	assert(scene.committed_impacts == baseline)
	var halfway: float = scene.effective_strength()
	assert(scene.car.tip_angle_for_strength(halfway) > scene.car.tip_angle_for_strength(3))
	scene.advance_charge(10.0)
	assert(is_equal_approx(scene.effective_strength(), 11.8))
	assert(scene.car.tip_angle_for_strength(scene.effective_strength()) > scene.car.tip_angle_for_strength(halfway))
	assert(scene.arrow_length(scene.effective_strength()) > scene.arrow_length(halfway))
	scene.car.rotation.y = 0.5
	scene.release_charge("keyboard")
	scene.release_charge("keyboard")
	assert(scene.committed_impacts == baseline + 1)
	assert(scene.last_push.is_equal_approx(scene.car.global_basis * Vector3.RIGHT))
	scene.car.rollover_energy = 0 # Crossing support must supersede the obsolete energy gate.
	var previous_disabled_angle := 0.0
	for tick in 180:
		scene.car._physics_process(1.0 / 60.0)
		if scene.car.state == scene.car.State.DISABLED:
			assert(scene.car.disabled_angle >= previous_disabled_angle)
			previous_disabled_angle = scene.car.disabled_angle
	assert(scene.car.state == scene.car.State.DISABLED, "Charged light base must graduate to rollover")
	assert(scene.car.balance_margin > 0)
	scene.begin_charge("pad")
	scene.advance_charge(1)
	scene.reset_car()
	scene.release_charge("pad")
	assert(scene.committed_impacts == baseline + 1 and not scene.charging)
	scene.aim_right_stick(Vector2.LEFT)
	scene.aim_right_stick(Vector2.ZERO)
	assert(scene.impact_aim == Vector3.LEFT)
	# Strong launch displacement and spin must agree with the same push chain.
	scene.car.set_physics_process(false)
	await physics_frame
	scene.impact_aim = Vector3(1, 0, -1).normalized()
	scene.trigger_impact(20)
	assert(scene.car.velocity.dot(scene.last_push) > 0)
	assert(scene.car.tumble_axis.x < 0 and scene.car.tumble_axis.z < 0)
	var before_flight: Vector3 = scene.car.global_position
	scene.car._physics_process(1.0 / 60.0)
	assert((scene.car.global_position - before_flight).dot(scene.last_push) > 0, "Actual flight displacement must follow arrow push")
	print("DIRECTION CHARGE PASS: six models/eight directions, arrow/impulse/local torque/loaded supports, light recovery, hold scaling/cap/release once/cancel, balance continuation, strong push/spin")
	quit()
