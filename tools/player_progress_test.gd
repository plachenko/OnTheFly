extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var progress := root.get_node("PlayerProgress")
	progress.save_path = "res://.godot/test_player_progress.cfg"
	progress.experience = 0
	progress.license_points = 0
	var level: Node = load("res://procedural_city.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	current_scene = level
	while not level.is_loading_ready(): await process_frame
	level.process_mode = Node.PROCESS_MODE_INHERIT
	level.set_process(false)
	level.truck.set_physics_process(false)
	await physics_frame
	await physics_frame
	level.experience = 0
	level.license_points = 0
	var truck: CharacterBody3D = level.truck
	var city: Node3D = level.get_node("ProceduralCity")
	for car in get_nodes_in_group("traffic_motion"):
		car.set_physics_process(false)
		car.collision_layer = 0
		car.collision_mask = 0
	var car: Node3D = load("res://scenes/traffic_car.tscn").instantiate()
	car.model_scene = load("res://assets/kenney_city/cars_rigged/sedan.glb")
	car.parked = true
	car.hybrid_reactions_enabled = false
	city.get_node("Traffic").add_child(car)
	car.set_physics_process(false)
	truck.global_position = Vector3(-128,city.height_at(-128,0)+.2,0)
	truck.rotation.y = 0
	truck.travel_heading = 0
	truck.speed = 18
	truck.test_controls_enabled = true
	truck.test_controls = {}
	truck.parking_pad = null
	car.global_position = Vector3(-128,city.height_at(-128,-12)+.09,-12)
	await physics_frame
	for tick in 90:
		truck._physics_process(1.0/60.0)
		if level.license_points > 0: break
	assert(level.license_points == 1, "Driving into a real car must add a license point")
	assert(level.experience == 0, "Crashing must not award experience")
	assert(not level.register_car_collision(truck,car,18), "Same collision must not count again")
	assert(not level.register_car_collision(truck,car,.1), "Stationary contact must not add points")
	var pad: Area3D = level.get_node("ParkingPads/ParkingPad_02")
	pad.expired = false
	pad.service_remaining = 60
	truck.parking_pad = pad
	truck.deployed = true
	truck.opening = 1
	truck.speed = 0
	truck.global_position = pad.global_position
	var manager: Node = level.get_node("PatronManager")
	var patron: Node = manager.patron_scene.instantiate()
	patron.manager = manager
	level.get_node("Patrons").add_child(patron)
	patron.set_physics_process(false)
	patron.accept_order(pad, {"items":["Burger"],"total":10,"quantity":1})
	patron.service_elapsed = 2
	patron.global_position = patron.queue_target()
	assert(manager.complete_order(patron))
	assert(not manager.complete_order(patron))
	assert(level.experience == 10)
	level.money_earned = level.earnings_target
	level.advance_round(0)
	level.advance_round(0)
	assert(level.experience == 60, "Round bonus must be awarded once")
	level.award_experience(40)
	level._process(0.0)
	assert(level.progress_label.text.begins_with("LEVEL 2 · XP 100"))
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/player_progress_hud.png")
	assert(progress.save_progress() == OK)
	progress.experience = 0
	progress.license_points = 0
	progress.load_progress()
	assert(progress.experience == 100 and progress.license_points == 1)
	print("PLAYER PROGRESS PASS: real car crash, contact deduplication, order XP, one round bonus, persisted reload")
	quit()
