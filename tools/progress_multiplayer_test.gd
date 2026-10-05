extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session := root.get_node("NetworkSession")
	var host_mode := "--mp-host" in OS.get_cmdline_user_args()
	var error: Error = session.start_host(24581,"XP host") if host_mode else session.start_join("127.0.0.1",24581,"XP guest")
	assert(error == OK)
	var award_time := 0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 60000:
		await process_frame
		if not session.started:
			if host_mode and session.roster.size() == 2 and session.can_start(): session.start_session()
			elif not host_mode and session.roster.has(session.multiplayer.get_unique_id()): session.set_lobby_options(true,1)
		if not is_instance_valid(session.level) or not session.started or session.level.lobby_world or root.get_node("LoadingScreen").busy: continue
		var world: Node = session.level
		if world.trucks.size() != 2:
			if host_mode and award_time > 0:
				session.close()
				quit()
				return
			continue
		if host_mode:
			if award_time == 0:
				var guest: int = session.roster.keys().filter(func(id): return id != 1)[0]
				var previous: int = world.select_player(guest)
				world.award_experience(10)
				assert(world.register_car_collision(world.trucks[guest],world.trucks[1],12))
				assert(not world.register_car_collision(world.trucks[guest],world.trucks[1],12))
				world.select_player(previous)
				assert(world.accounts[guest].experience == 10 and world.accounts[guest].license_points == 1)
				assert(world.accounts[1].experience == 0 and world.accounts[1].license_points == 0)
				award_time = Time.get_ticks_msec()
				print("PROGRESS MP HOST PASS: authoritative per-driver XP and license points")
			if Time.get_ticks_msec() - award_time < 15000: continue
		else:
			var account: Dictionary = world.accounts[world.local_player]
			if account.experience != 10 or account.license_points != 1: continue
			assert(world.accounts[1].experience == 0 and world.accounts[1].license_points == 0)
			assert(root.get_node("PlayerProgress").experience == 0 and root.get_node("PlayerProgress").license_points == 0)
			print("PROGRESS MP CLIENT PASS: XP/license snapshot ownership; offline save unchanged")
		session.close()
		quit()
		return
	push_error("Progress multiplayer test timed out")
	quit(1)
