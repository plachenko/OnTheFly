extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.truck.set_physics_process(false)
	var city = scene.get_node("ProceduralCity")
	var traffic = city.get_node("Traffic")
	var cars: Array = []
	for index in 3:
		var car = city.traffic_car_scene.instantiate()
		car.model_scene = load(city.traffic_car_models[0])
		car.parked = true
		traffic.add_child(car)
		car.set_physics_process(false)
		car.gravity_scale = 0.0
		car.global_position = Vector3(300 + index * 7, city.terrain_surface_height_at(300 + index * 7, 300) + 0.1, 300)
		cars.append(car)
	assert(not cars[1].receive_car_impact(1.0, Vector3.RIGHT, cars[1].global_position))
	assert(cars[0].disable_from_impact(20.0, Vector3.RIGHT, cars[0].global_position))
	cars[0].linear_velocity = Vector3.RIGHT * 28.0
	cars[0].incoming_velocity = cars[0].linear_velocity
	cars[0].angular_velocity = Vector3.ZERO
	for frame in 60:
		await physics_frame
		if cars[1].disabled:
			break
	assert(cars[1].disabled, "An actual rigid-body collision must ignite the second car")
	# Aim the second wreck at the third to keep random tumble from making this flaky.
	cars[1].linear_velocity = Vector3.RIGHT * 28.0
	cars[1].incoming_velocity = cars[1].linear_velocity
	cars[1].angular_velocity = Vector3.ZERO
	cars[2].global_position = cars[1].global_position + Vector3.RIGHT * 7.0
	for frame in 60:
		await physics_frame
		if cars[2].disabled:
			break
	assert(cars[2].disabled, "The second car must propagate the chain reaction")
	for car in cars:
		car.disabled_elapsed = 1.0
		assert(not car.receive_car_impact(10.0, Vector3.RIGHT, car.global_position))
		assert(car.disabled_elapsed == 1.0, "Repeated impacts must not restart the fuse")
		car._physics_process(3.1)
		assert(car.exploded)
	print("CAR CHAIN PASS: low-speed guard, real collision, three-car propagation, fixed fuses, explosions")
	quit()
