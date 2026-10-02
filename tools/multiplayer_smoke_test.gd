extends SceneTree

var host_mode := false
var four_players := false

func _initialize() -> void:
	run.call_deferred()

func sell_to(world: Node, guest: int) -> void:
	var body: CharacterBody3D = world.trucks[guest]
	var previous: int = world.select_player(guest)
	body.network_controls = {}
	world.incoming[guest] = {}
	var pad: Area3D = world.get_node("ParkingPads/ParkingPad_02")
	body.global_position = Vector3(pad.global_position.x, body.spawn_transform.origin.y, pad.global_position.z)
	body.speed = 0.0
	body.velocity = Vector3.ZERO
	body.parking_pad = pad
	body.deployed = true
	body.opening = 1.0
	var manager: Node = world.get_node("PatronManager")
	var patron: Node = manager.patron_scene.instantiate()
	patron.manager = manager
	world.get_node("Patrons").add_child(patron)
	patron.set_physics_process(false)
	patron.set_meta("player_id", guest)
	patron.accept_order(pad, {"items": ["Burger"], "total": 10, "quantity": 1})
	patron.service_elapsed = 2.0
	patron.global_position = patron.queue_target()
	var before: int = world.money
	var completed: bool = manager.complete_order(patron)
	var duplicate: bool = manager.complete_order(patron)
	assert(completed)
	assert(not duplicate) # The same order cannot pay twice.
	assert(world.money == before + 10)
	world.select_player(previous)
	assert(world.accounts[guest].money_earned == 10)

func run() -> void:
	host_mode = "--mp-host" in OS.get_cmdline_user_args()
	four_players = "--mp-four" in OS.get_cmdline_user_args()
	var expected := 4 if four_players else 2
	var session := root.get_node("NetworkSession")
	root.get_node("GameOptions").round_balance = 321
	var error: Error = session.start_host(24569, "Host") if host_mode else session.start_join("127.0.0.1", 24569, "Guest")
	assert(error == OK)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 45000:
		await process_frame
		if not session.started:
			if not host_mode and session.roster.has(session.multiplayer.get_unique_id()): session.set_lobby_options(true, 1)
			if host_mode and session.roster.size() == expected and session.can_start(): session.start_session()
		if not is_instance_valid(session.level): continue
		var world: Node = session.level
		if world.trucks.size() != expected or root.get_node("LoadingScreen").busy: continue
		if host_mode:
			var guests: Array = []
			var all_moving := true
			for id in world.trucks:
				if id != 1:
					guests.append(id)
					var body: CharacterBody3D = world.trucks[id]
					if body.global_position.distance_to(body.spawn_transform.origin) < 2.0: all_moving = false
			if not all_moving: continue
			# Validate ownership and malformed input before completing real orders.
			world.receive_controls(guests[0], {"accelerate": NAN})
			world.receive_action(-1, "upgrade", 0)
			for guest in guests: sell_to(world, guest)
			assert(world.accounts[1].money == 200 and world.accounts[1].money_earned == 0)
			print("MP HOST PASS: %d trucks, remote driving, guest-only sales, no duplicate payouts, host funds isolated" % expected)
			await create_timer(3.0).timeout
			session.leave()
			await process_frame
			assert(root.get_node("GameOptions").round_balance == 321)
			assert(not session.active)
			quit()
			return
		else:
			if world.accounts[world.local_player].money_earned >= 10:
				Input.action_release("accelerate")
				assert(world.accounts[1].money == 200)
				assert(world.get_node("Patrons").get_child_count() > 0)
				print("MP CLIENT PASS: %d-truck roster, remote movement, personal earnings and compressed customer snapshots" % expected)
				await create_timer(0.5).timeout
				session.leave()
				await process_frame
				assert(root.get_node("GameOptions").round_balance == 321)
				quit()
				return
			Input.action_press("accelerate")
	push_error("Multiplayer smoke test timed out")
	quit(1)
