extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_process(false)
	var truck = scene.get_node("FoodTruck")
	truck.set_physics_process(false)
	for car in get_nodes_in_group("traffic_motion"):
		car.set_physics_process(false)
	var cop = load("res://scenes/traffic_car.tscn").instantiate()
	cop.model_scene = load("res://assets/kenney_city/cars_rigged/police.glb")
	city.get_node("Traffic").add_child(cop)
	cop.set_physics_process(false)
	cop.global_position = Vector3(-220, city.height_at(-220, 0) + 0.09, 0)
	var circle = cop.get_node("PoliceCircle")
	var dispatch = root.get_node("PoliceDispatch")
	dispatch.set_physics_process(false)
	circle.update_ring()
	var green_point: Vector3 = circle.mesh.get_faces()[0]
	assert(is_equal_approx(Vector2(green_point.x + 220, green_point.z).length(), circle.radius * 0.5 - 0.08))
	truck.global_position = cop.global_position + Vector3(0, 0, 5)
	truck.speed = 4.0
	circle._process(0.5)
	assert(circle.yellow_remaining > 0.0)
	var victim = city.get_node("Traffic").get_child(0)
	victim.global_position = cop.global_position + Vector3(0, 0, 4)
	dispatch.report_collision(victim)
	assert(dispatch.pursuing and circle.pursuing and cop.get_node("VehicleLights").police_enabled)
	circle._process(0.5)
	assert(circle.material_override.albedo_color.is_equal_approx(Color("ff3838")))
	var old_position: Vector3 = cop.global_position
	cop.update_police_chase(0.1)
	assert(cop.global_position.distance_to(old_position) > 0.0)
	var money: int = scene.money
	truck.speed = 0.0
	dispatch._physics_process(2.1)
	assert(not dispatch.pursuing and scene.money == money)
	assert("warning" in truck.message)
	# A repeat voluntary stop incurs the smaller fine.
	circle.yellow_remaining = 2.5
	dispatch.report_collision(victim)
	dispatch.resolve(truck, true)
	assert(scene.money == money - 25)
	# Forced pullover uses damage BEFORE contact, then applies contact damage.
	circle.yellow_remaining = 2.5
	dispatch.report_collision(victim)
	truck.health = 75.0
	dispatch.hit_cooldown = 0.0
	dispatch.police_hit(truck)
	assert(truck.health == 65.0 and not dispatch.pursuing)
	assert(scene.money == money - 125)
	circle.yellow_remaining = 2.5
	dispatch.report_collision(victim)
	truck.health = 74.0
	dispatch.hit_cooldown = 0.0
	dispatch.police_hit(truck)
	assert(truck.health == 64.0 and dispatch.pursuing)
	print("POLICE PURSUIT PASS: circle sizes/colors, chase, flashing lights, clean warning, repeat discount, damage threshold and fines")
	quit()
