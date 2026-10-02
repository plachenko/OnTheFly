extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	while not scene.is_loading_ready(): await process_frame
	scene.truck.set_physics_process(false)
	for car in city.get_node("Traffic").get_children():
		car.set_physics_process(false)
	var car = city.get_node("Traffic").get_child(0)
	car.obey_crosswalks = false
	car.intersection_turn_chance = 0.0
	car.turning = false
	car.turn_intent = 0
	car.travel_axis = Vector3.BACK
	car.lane_center = Vector3(-220, 0, 0)
	car.progress = -16.0
	car.driving_speed = 8.0
	car.loop_extent = 500.0
	car.update_car_pose(0.0)
	scene.truck.global_position = Vector3(-220, city.height_at(-220, 0) + 0.2, 0)
	scene.truck.rotation.y = 0.0
	scene.truck.speed = 0.0
	scene.truck.parking_pad = null
	car.patience_depletion_rate = 100.0 / 15.0
	for step in 50:
		car._physics_process(0.1)
	assert(car.patience_ratio < 0.95 and car.patience_ratio > 0.1)
	assert(not car.passing_truck)
	assert(not car.truck_blocks_motion(car.global_position, car.global_position, 0.0))
	car.patience_depletion_rate = 100.0
	var obstacle := StaticBody3D.new()
	var obstacle_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 3.0, 5.0)
	obstacle_shape.shape = box
	obstacle.add_child(obstacle_shape)
	root.add_child(obstacle)
	obstacle.global_position = car.route_position() + Vector3(4.8, 2.0, 8.0)
	obstacle.global_position.y += city.height_at(obstacle.position.x, obstacle.position.z)
	await physics_frame
	assert(not car.passing_lane_clear(-4.8))
	obstacle.free()
	var honked := false
	var saw_steering := false
	for step in 160:
		var previous_position: Vector3 = car.position
		var previous_yaw: float = car.rotation.y
		var previous_steer: float = car.steering_angle
		car._physics_process(0.1)
		assert(absf(car.steering_angle - previous_steer) <= 0.091)
		if car.current_driving_speed > 0.1:
			saw_steering = saw_steering or absf(car.steering_angle) > 0.1
			var expected_yaw: float = car.current_driving_speed / car.wheelbase * tan(car.steering_angle) * 0.1
			assert(absf(car.rotation.y - previous_yaw - expected_yaw) < 0.001)
		elif car.current_driving_speed == 0.0:
			assert(car.position.distance_to(previous_position) < 0.001)

		honked = honked or car.horn_cooldown > 0.0
		assert(not car.truck_blocks_motion(car.global_position, car.global_position, 0.0))
	assert(car.progress > 12.0)
	assert(absf(car.passing_offset) < 0.05)
	assert(honked and saw_steering)
	var bay = city.get_node("ParkingSpaces").get_child(0)
	var axis: Vector3 = bay.get_meta("parking_axis")
	scene.truck.global_position = bay.global_position
	scene.truck.global_position.y = city.height_at(bay.position.x, bay.position.z) + 0.2
	scene.truck.rotation.y = atan2(-axis.x, -axis.z)
	assert(car.truck_is_in_parking_bay())
	assert(car.truck_blocks_motion(scene.truck.global_position - axis * 20.0, scene.truck.global_position + axis * 20.0))
	assert(not car.truck_blocks_motion(scene.truck.global_position + Vector3(-axis.z, 0, axis.x) * 8.0, scene.truck.global_position + Vector3(-axis.z, 0, axis.x) * 8.0))
	print("TRAFFIC AVOIDANCE PASS: patient waiting, honking pass, safe return, parked clearance, swept no-clipping guard")
	quit()
