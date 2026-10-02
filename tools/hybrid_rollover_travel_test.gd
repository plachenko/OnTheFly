extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func check_clearance(car) -> void:
	var normal: Vector3 = car.contact_ground.normal
	var plane: Vector3 = car.contact_ground.position
	for point in car.body_points:
		assert(normal.dot(car.visual.global_transform * point - plane) >= 0.018)
	for wheel in car.wheels:
		if wheel.planted:
			assert(wheel.world_center.distance_to(wheel.anchor) < 0.002)
		for offset in wheel.points:
			assert(normal.dot(wheel.world_center + wheel.world_basis * offset - plane) >= 0.018)

func run() -> void:
	var scene = load("res://scenes/hybrid_car_demo.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_process(false)
	var directions := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(1, 0, -1).normalized(), Vector3(-1, 0, -1).normalized()]
	for model_index in 6:
		for direction in directions:
			scene.selected_model = model_index
			scene.reset_car()
			var car = scene.car
			car.set_physics_process(false)
			car.rotation.y = 0.35
			car.tire_friction = 1.0
			var push: Vector3 = car.global_basis * direction
			var start: Vector3 = car.global_position
			var crossed := Vector3.ZERO
			var seen := false
			car.receive_impact(push * 11.8, push)
			for tick in 240:
				car._physics_process(1.0 / 60.0)
				if car.state == car.State.DISABLED and not seen:
					seen = true
					crossed = car.global_position
					assert(car.rollover_velocity.length() > 0 and car.disabled_cue.age == 0)
				check_clearance(car)
			assert(seen and car.explosion_count == 0)
			assert((car.global_position - start).dot(push) > 0.5, "All directional rollovers must advance with push")
			assert((car.global_position - crossed).dot(push) > 0.5, "Disabled transition must retain travel")
			assert(car.rollover_settled and car.rollover_velocity.length() < 0.05 and car.velocity.length() < 0.1)
			assert(car.rollover_distance < 12.01 and car.disabled_cue.age < 3)
	var distances: Array[float] = []
	for strength in [10.0, 11.8]:
		scene.reset_car()
		var car = scene.car
		car.set_physics_process(false)
		car.tire_friction = 1
		var start: Vector3 = car.global_position
		car.receive_impact(Vector3.RIGHT * strength, Vector3.RIGHT)
		for tick in 240:
			car._physics_process(1.0 / 60.0)
		distances.append((car.global_position - start).x)
	assert(distances[1] > distances[0], "Higher medium strength must produce more travel")
	scene.reset_car()
	var moving = scene.car
	moving.set_physics_process(false)
	moving.velocity = Vector3.RIGHT * 2
	moving.rollover_inherited_velocity = Vector3.RIGHT * 4
	moving.receive_impact(moving.velocity + Vector3.RIGHT * 11.8, Vector3.RIGHT)
	assert(moving.rollover_velocity.x > 11.8 * 0.32, "Preimpact route momentum must survive initial anchoring")
	for direction in [Vector3.RIGHT, Vector3.LEFT]:
		scene.reset_car()
		var car = scene.car
		car.set_physics_process(false)
		car.position = Vector3(12, 4, -12)
		car.tire_friction = 1
		await physics_frame
		var start: Vector3 = car.global_position
		car.receive_impact(direction * 11.8, direction)
		for tick in 240:
			car._physics_process(1.0 / 60.0)
			check_clearance(car)
		assert((car.global_position - start).dot(direction) > 0.5)
	print("ROLLOVER TRAVEL PASS: six models/eight rotated directions, planted phase, continued disabled displacement, frictional rest, strength scaling, ramp clearance, bounded distance and held cue")
	quit()
