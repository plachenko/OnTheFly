extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session := root.get_node("NetworkSession")
	var host_mode := "--host" in OS.get_cmdline_user_args()
	var error: Error = session.start_host(24578, "Grid host") if host_mode else session.start_join("127.0.0.1", 24578, "Grid guest")
	assert(error == OK)
	var configured := false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 60000:
		await process_frame
		if not session.started:
			if host_mode and session.roster.size() == 2:
				if not configured:
					session.choose_level("Hilly City")
					session.choose_city_size(0)
					session.choose_original_grid(true)
					configured = true
				elif session.can_start(): session.start_session()
			elif not host_mode and session.original_grid and session.roster.has(session.multiplayer.get_unique_id()):
				session.set_lobby_options(true, 1)
		if not is_instance_valid(session.level) or root.get_node("LoadingScreen").busy or not session.started: continue
		if not session.level.has_node("ProceduralCity"): continue
		var city: Node = session.level.get_node("ProceduralCity")
		assert(session.original_grid and city.original_grid)
		assert(root.get_node("CityStore").last_source.ends_with("grid_small.res"))
		assert(session.level.trucks.size() == 2)
		var preview: Control = root.get_node("LoadingScreen").map_preview
		var body: Node3D = session.level.local_truck
		assert(preview.spawn.distance_to(Vector2(body.spawn_transform.origin.x,body.spawn_transform.origin.z)) < .5)
		print("GRID MULTIPLAYER PASS: ", "host" if host_mode else "guest", "; shared layout/size, shipped grid city, local spawn zoom")
		if host_mode:
			session.roster[1]["grid_test_ready"] = true
			session.broadcast_roster()
			await create_timer(2.0).timeout
		else:
			while not session.roster.get(1, {}).get("grid_test_ready", false): await process_frame
		session.close()
		quit()
		return
	push_error("Grid multiplayer check timed out")
	quit(1)
