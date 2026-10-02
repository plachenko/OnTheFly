extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session: Node = root.get_node("NetworkSession")
	assert(session.start_host(24577, "Host") == OK)
	while not is_instance_valid(session.level): await process_frame
	var world: Node = session.level
	assert(world.lobby_world and not session.started)
	session.register_player(2, "Guest")
	session.loaded_players[2] = true
	world.set_physics_process(false)
	world.set_process(false)
	assert(world.trucks.size() == 2)
	assert(world.lobby_menu.visible)
	world.lobby_menu.hide()
	assert(world.lobby_driving_enabled())
	world.lobby_menu.show()
	assert(not world.lobby_driving_enabled())
	world.receive_controls(2, {"accelerate": 1.0})
	assert(world.incoming[2].is_empty())
	session.update_lobby_player(2, true, 4)
	world.receive_controls(2, {"accelerate": 1.0})
	assert(world.incoming[2].accelerate == 1.0)
	world.received_at[2] = Time.get_ticks_msec()
	var before: Vector3 = world.trucks[2].global_position
	var timer: float = world.accounts[2].remaining_time
	for frame in 90:
		world.received_at[2] = Time.get_ticks_msec()
		world._physics_process(1.0 / 60.0)
		await physics_frame
	assert(world.trucks[2].global_position.distance_to(before) > 1.0)
	assert(world.accounts[2].remaining_time == timer and world.accounts[2].money_earned == 0)
	assert(world.service_waves.wave == 0)
	session.update_lobby_player(2, false, 4)
	world._physics_process(1.0 / 60.0)
	assert(world.trucks[2].speed == 0.0)
	# Exercise local guest readiness and menu behavior without changing peer authority.
	var menu: Control = world.lobby_menu
	var saved: Dictionary = session.roster[1].duplicate()
	session.roster[1].ready = false
	menu.refresh()
	assert(menu.visible)
	session.roster[1].ready = true
	menu.refresh()
	assert(not menu.visible)
	session.roster[1] = saved
	session.accept_chat(2, "Hello!")
	assert(world.trucks[2].has_node("SpeechBubble"))
	var bubble: Node3D = world.trucks[2].get_node("SpeechBubble")
	assert(bubble.get_parent() == world.trucks[2])
	await create_timer(0.4).timeout
	assert(bubble.position.y > 5.6)
	await create_timer(1.1).timeout
	assert(not is_instance_valid(bubble))
	var snapshot: Dictionary = world.make_snapshot()
	assert(snapshot.phase == "lobby")
	print("DRIVING LOBBY PASS: ready-only driving, unready stop/menu, manual menu, no match clock/economy, world bubbles rise and expire")
	quit()
