extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	scene.get_node("ProceduralCity").randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.truck.set_physics_process(false)
	var city = scene.get_node("ProceduralCity")
	for car in get_nodes_in_group("traffic_motion"):
		car.set_physics_process(false)
	var models := 0
	for path in city.traffic_car_models:
		var car = city.traffic_car_scene.instantiate()
		car.model_scene = load(path)
		car.parked = true
		city.get_node("Traffic").add_child(car)
		car.set_physics_process(false)
		assert(car.hybrid != null and car.freeze and car.hybrid.wheels.size() == 4)
		assert(is_zero_approx(car.hybrid.model_root.rotation.y), "Production +Z orientation must be preserved")
		car.global_position = Vector3(300, city.height_at(300, 300) + 0.09, 300)
		await physics_frame
		assert(car.receive_vehicle_contact(Vector3.RIGHT * 3, Vector3.RIGHT, car.global_position))
		assert(not car.disabled and car.hybrid.state == car.hybrid.State.REACTION)
		for tick in 300:
			car._physics_process(1.0 / 60.0)
		assert(not car.disabled and car.hybrid.state == car.hybrid.State.DRIVING)
		for local_push in [Vector3.FORWARD, Vector3.BACK, Vector3(1, 0, -1).normalized()]:
			car.hybrid_hit_cooldown = 0
			var world_push: Vector3 = car.global_basis * local_push
			assert(car.receive_vehicle_contact(world_push * 3, world_push, car.global_position))
			for tick in 10:
				car._physics_process(1.0 / 60.0)
			assert(signf(car.hybrid.pose.x) == signf(local_push.z))
			assert(signf(car.hybrid.pose.z) == -signf(local_push.x))
			for tick in 300:
				car._physics_process(1.0 / 60.0)
			assert(not car.disabled and car.hybrid.state == car.hybrid.State.DRIVING)
		car.hybrid_hit_cooldown = 0
		car.hybrid.tire_friction = 1.0
		var rollover_start: Vector3 = car.global_position
		assert(car.receive_vehicle_contact(Vector3.RIGHT * 11.8, Vector3.RIGHT, car.global_position))
		for tick in 80:
			car._physics_process(1.0 / 60.0)
		assert(car.disabled and car.hybrid.state == car.hybrid.State.DISABLED and not car.exploded)
		assert((car.global_position - rollover_start).dot(Vector3.RIGHT) > 0.2, "Production owner must move with rollover")
		var state: Dictionary = car.get_hybrid_snapshot()
		assert(state.root.is_equal_approx(car.global_transform) and state.rolling.distance > 0)
		assert(state.disabled and state.wheels.size() == 4 and state.state == car.hybrid.State.DISABLED)
		car.queue_free()
		models += 1
	# Moving traffic brakes under the existing controller before contact anchoring.
	var car = city.get_node("Traffic").get_child(0)
	car.distant_mode = false
	car.current_driving_speed = 8.0
	car.hybrid_hit_cooldown = 0
	var preimpact_motion: Vector3 = car.motion_vector
	assert(car.receive_vehicle_contact(car.motion_vector + Vector3.RIGHT * 3, Vector3.RIGHT, car.global_position))
	assert(car.hybrid_pending_strength > 0 and not car.hybrid.contact_locked)
	assert(car.hybrid_pending_motion.is_equal_approx(preimpact_motion), "Brake queue must retain preimpact movement")
	var start: Vector3 = car.global_position
	car._physics_process(1.0 / 60.0)
	assert(car.current_driving_speed > 0 and car.global_position.distance_to(start) > 0)
	for tick in 300:
		car._physics_process(1.0 / 60.0)
	assert(car.hybrid_pending_strength == 0)
	# Engine flight excludes both the shared controller and owning rigid body.
	car.hybrid_hit_cooldown = 0
	assert(car.disable_from_impact(20, Vector3(1, 0, -1).normalized(), car.global_position))
	assert(car.disabled and car.freeze and car.hybrid.state == car.hybrid.State.FLIGHT)
	assert(car.hybrid.excluded_bodies().has(car.get_rid()))
	for tick in 180:
		if car.exploded:
			break
		car._physics_process(1.0 / 60.0)
	assert(car.exploded and car.hybrid.explosion_count == 1 and car.collision_layer == 0)
	car.explode()
	assert(car.hybrid.explosion_count == 1)
	# Actual swept flight contact must propagate a chain hit to another traffic car.
	var chain: Array = []
	for i in 2:
		var target = city.traffic_car_scene.instantiate()
		target.model_scene = load(city.traffic_car_models[0])
		target.parked = true
		city.get_node("Traffic").add_child(target)
		target.set_physics_process(false)
		target.global_position = Vector3(350 + i * 6, city.height_at(350 + i * 6, 350) + 0.09, 350)
		chain.append(target)
	await physics_frame
	assert(chain[0].disable_from_impact(20, Vector3.RIGHT, chain[0].global_position))
	chain[0].hybrid.velocity = Vector3.RIGHT * 24 + Vector3.UP
	for tick in 30:
		if chain[0].exploded:
			break
		chain[0]._physics_process(1.0 / 60.0)
		await physics_frame
	await process_frame # Deferred chain callback.
	assert(chain[1].disabled, "Swept engine flight must preserve car-to-car chain hits")
	assert(chain[0].exploded)
	print("HYBRID TRAFFIC PASS: ", models, " production rigs, correct orientation, light recovery, rollover, snapshots, moving traction braking, frozen-body engine flight, self exclusion, one explosion")
	quit()
