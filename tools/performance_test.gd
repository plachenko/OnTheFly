extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session: Node = root.get_node("NetworkSession")
	var diagnostics: Node = root.get_node("PerformanceDiagnostics")
	assert(session.start_host(24581, "Performance test") == OK)
	while not is_instance_valid(session.level) or root.get_node("LoadingScreen").busy: await process_frame
	session.choose_level("Hilly City")
	assert(session.start_session())
	while root.get_node("LoadingScreen").busy or session.level.lobby_world: await process_frame
	var world: Node = session.level
	world.set_physics_process(false)
	world.set_process(false)
	var cars := get_nodes_in_group("traffic_motion")
	assert(not cars.is_empty())
	var car: Node = cars[0]
	for candidate in cars:
		if not candidate.parked:
			car = candidate
			break
	car.set_physics_process(false)
	world.truck.global_position = car.global_position + Vector3(1000, 0, 1000)
	car.update_proximity_mode()
	assert(car.distant_mode and car.collision_layer == 0)
	var position_before: Vector3 = car.position
	car.step_distant_route(1.0)
	assert(car.position.distance_to(position_before) > 0.1)
	world.truck.global_position = car.global_position + Vector3(0, 0, 10)
	car.update_proximity_mode()
	assert(not car.distant_mode and car.collision_layer != 0)
	world.truck.global_position = car.global_position + Vector3(1000, 0, 1000)
	diagnostics.traffic_lod_enabled = false
	car.update_proximity_mode()
	assert(not car.distant_mode)
	diagnostics.traffic_lod_enabled = true
	car.update_proximity_mode()
	var other_player := CharacterBody3D.new()
	world.add_child(other_player)
	other_player.global_position = car.global_position
	world.trucks[999] = other_player
	car.update_proximity_mode()
	assert(not car.distant_mode)
	world.trucks.erase(999)
	other_player.queue_free()
	car.update_proximity_mode()
	assert(car.distant_mode)
	assert(car.disable_from_impact(30.0, Vector3.RIGHT, car.global_position))
	car.update_proximity_mode()
	assert(not car.distant_mode and not car.freeze and car.collision_layer != 0)
	var legacy: Dictionary
	var optimized: Dictionary
	for enabled in [false, true]:
		diagnostics.optimized_snapshots = enabled
		var started := Time.get_ticks_usec()
		for iteration in 30:
			var snapshot: Dictionary = world.make_snapshot()
			if enabled: optimized = snapshot
			else: legacy = snapshot
		var sample: Dictionary = optimized if enabled else legacy
		print("SNAPSHOT optimized=", enabled, " avg_us=", (Time.get_ticks_usec() - started) / 30.0, " props=", sample.props.size(), " compressed_bytes=", var_to_bytes(sample).compress(FileAccess.COMPRESSION_DEFLATE).size())
	assert(optimized.props.size() < legacy.props.size())
	for candidate in cars:
		assert(optimized.props.has(str(world.get_path_to(candidate))))
	diagnostics.start_capture(0.1, "res://.godot/performance_test")
	assert(diagnostics.capture != null)
	await create_timer(0.3).timeout
	assert(diagnostics.capture == null)
	var file := FileAccess.open(diagnostics.capture_path, FileAccess.READ)
	assert(file.get_as_text().contains("frame_ms"))
	assert(file.get_length() > 300)
	print("PERFORMANCE PASS: distant routing, collision wake-up, comparison switches, smaller snapshots retaining traffic, frame capture")
	quit()
