extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	scene.truck.set_physics_process(false)
	var poles: Array[Node] = city.find_children("KnockablePole", "RigidBody3D", true, false)
	assert(poles.size() > 100)
	var street_found := false
	var traffic_found := false
	for pole in poles:
		var street: bool = pole.visual.name.begins_with("StreetLight") or pole.visual.name == "KenneyStreetLight"
		if (street and street_found) or (not street and traffic_found):
			continue
		assert(pole.freeze)
		assert(not pole.impact_knock_down(Vector3.RIGHT, 9.9))
		assert(not pole.fallen)
		assert(pole.impact_knock_down(Vector3.RIGHT, 12.0))
		assert(not pole.impact_knock_down(Vector3.RIGHT, 12.0))
		await process_frame
		assert(not pole.freeze)
		for light in pole.visual.find_children("*", "Light3D", true, false):
			assert(light.light_energy == 0.0)
		for step in 40:
			await physics_frame
		assert(absf(pole.global_basis.y.x) > 0.05)
		assert(pole.visual.global_position.distance_to(pole.global_position - pole.global_basis.y * pole.height * 0.5) < 0.5)
		street_found = street_found or street
		traffic_found = traffic_found or not street
		if street_found and traffic_found:
			break
	assert(street_found and traffic_found)
	print("POLE KNOCKDOWN PASS: speed threshold, street/traffic poles, tumble, attached visuals, lights off")
	quit()
