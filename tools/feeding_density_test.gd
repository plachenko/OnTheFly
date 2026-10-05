extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func active_cars(city: Node) -> int:
	var count := 0
	for car in city.feeding_traffic:
		if car.ambient_active: count += 1
	return count

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	if not is_instance_valid(scene.service_waves):
		await scene.ready
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	var waves = scene.service_waves
	var manager = scene.get_node("PatronManager")
	manager.set_process(false)
	waves.initialized = true
	waves.in_service = false
	waves.remaining = 30.0
	assert(waves.traffic_pressure() == 0.0)
	assert(active_cars(city) == city.traffic_target(0.0))
	manager.spawn_patrons(100.0)
	assert(scene.get_node("Patrons").get_child_count() <= 3)
	waves.remaining = 6.0
	assert(is_equal_approx(waves.traffic_pressure(), 0.5))
	assert(city.traffic_target(0.5) > city.traffic_target(0.0))
	# Move all players clear so density adjustment is not blocked by pop-in protection.
	scene.truck.global_position = Vector3(500, 0, 500)
	for car in city.feeding_traffic: car.set_physics_process(false)
	for step in 30: city.update_feeding_traffic(1.0)
	assert(active_cars(city) > city.traffic_target(0.0))
	waves.in_service = true
	assert(waves.traffic_pressure() == 1.0)
	manager.spawn_patrons(100.0)
	assert(scene.get_node("Patrons").get_child_count() > 3)
	waves.in_service = false
	for patron in scene.get_node("Patrons").get_children(): patron.crossing_phase = 0
	manager.spawn_patrons(100.0)
	await process_frame
	assert(scene.get_node("Patrons").get_child_count() <= 3)
	for step in 30: city.update_feeding_traffic(0.0)
	assert(active_cars(city) == city.traffic_target(0.0))
	for car in city.feeding_traffic:
		if not car.ambient_active:
			assert(not car.get_node("Visual").visible and car.collision_layer == 0)
	print("FEEDING DENSITY PASS: quiet patrons/traffic, approaching-window ramp, busy service, quiet recovery, inactive cars hidden and noncolliding")
	quit()
