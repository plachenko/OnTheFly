extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var host := "--mp-host" in OS.get_cmdline_user_args()
	var session: Node = root.get_node("NetworkSession")
	assert((session.start_host(24579, "Host") if host else session.start_join("127.0.0.1", 24579, "Guest")) == OK)
	var phase := 0
	var timeout := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < timeout:
		await process_frame
		if session.roster.size() != 2 or not is_instance_valid(session.level): continue
		var world: Node = session.level
		if not session.started:
			if not is_instance_valid(world.lobby_menu) or world.trucks.size() != 2: continue
			var guest: int = session.roster.keys().filter(func(id): return id != 1)[0]
			var body: CharacterBody3D = world.trucks[guest]
			if host:
				if phase == 0 and session.roster[guest].ready and body.global_position.distance_to(body.spawn_transform.origin) > 2:
					assert(world.service_waves.wave == 0 and world.accounts[guest].money_earned == 0)
					session.send_chat("Nice truck!")
					phase = 1
				elif phase == 1 and not session.roster[guest].ready and body.speed == 0:
					if Time.get_ticks_msec() - session.chat_times.get(1, 0) < 450: continue
					assert(not session.can_start())
					session.send_chat("Ready to roll!")
					phase = 2
				elif phase == 2 and session.roster[guest].ready:
					assert(session.start_session())
					phase = 3
			else:
				if phase == 0:
					session.set_lobby_options(true, 4)
					phase = 1
				elif phase == 1 and session.roster[guest].ready:
					assert(not world.lobby_menu.visible)
					Input.action_press("accelerate")
					session.send_chat("Hello!")
					phase = 2
				elif phase == 2 and session.chat_history.any(func(entry): return entry[1] == "Nice truck!"):
					Input.action_release("accelerate")
					session.set_lobby_options(false, 4)
					phase = 3
				elif phase == 3 and not session.roster[guest].ready and session.chat_history.any(func(entry): return entry[1] == "Ready to roll!"):
					assert(world.lobby_menu.visible)
					session.set_lobby_options(true, 4)
					phase = 4
			continue
		Input.action_release("accelerate")
		if world.lobby_world or root.get_node("LoadingScreen").busy: continue
		if not host and session.last_snapshot.get("phase", "") != "game": continue
		assert(world.trucks.size() == 2)
		print("NETWORK DRIVING LOBBY %s PASS: ready movement replicated, unready stops and opens menu, re-ready, match transition and fresh snapshots" % ["HOST" if host else "CLIENT"])
		await create_timer(2.0 if host else 5.0).timeout
		quit()
		return
	push_error("Network driving lobby test timed out at phase %d" % phase)
	quit(1)
