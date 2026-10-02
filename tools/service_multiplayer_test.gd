extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session: Node = root.get_node("NetworkSession")
	assert(session.start_host(24571, "Host") == OK)
	assert(session.start_session())
	while not is_instance_valid(session.level) or root.get_node("LoadingScreen").busy:
		await process_frame
	var world: Node = session.level
	world.set_process(false)
	world.set_physics_process(false)
	world.get_node("PatronManager").set_process(false)
	world.apply_roster({1: {"name": "Host", "slot": 0}, 2: {"name": "Two", "slot": 1}, 3: {"name": "Three", "slot": 2}, 4: {"name": "Four", "slot": 3}})
	world.service_window_seconds = 5.0
	world.service_pause_seconds = 30.0
	var waves: Node = world.service_waves
	waves.initialized = false
	waves.rotation.clear()
	waves.tick(0.0)
	var counts: Array = [waves.rotation.size()]
	for cycle in 6:
		waves.mark_used(waves.rotation[0])
		waves.tick(5.0)
		waves.tick(30.0)
		counts.append(waves.rotation.size())
	assert(counts == [6, 5, 4, 3, 3, 2, 1])
	var pad: Node3D = waves.rotation[0]
	var body: CharacterBody3D = world.trucks[1]
	body.global_position = Vector3(pad.global_position.x, body.spawn_transform.origin.y, pad.global_position.z)
	body.parking_pad = pad
	body.deployed = true
	body.opening = 1.0
	body.speed = 0.0
	world.update_service_protection()
	assert(body.get_collision_exceptions().has(world.trucks[2]))
	assert(world.trucks[2].get_collision_exceptions().has(body))
	world.trucks[2].parking_pad = pad
	world.trucks[2].global_position = body.global_position
	assert(not world.can_open_shop(world.trucks[2]))
	waves.tick(5.0)
	world.update_service_protection()
	assert(body.get_collision_exceptions().has(world.trucks[2]))
	body.deployed = false
	world.update_service_protection()
	assert(not body.get_collision_exceptions().has(world.trucks[2]))
	var snapshot: Dictionary = world.make_snapshot()
	assert(not snapshot.waves.in_service and snapshot.waves.rotation.size() == 1)
	print("MULTIPLAYER WAVES PASS: 6→5→4→3→3→2→1, exclusive bays, collision protection, break protection, snapshot state")
	quit()
