extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func make_car(parent: Node3D):
	var city := Node3D.new()
	parent.add_child(city)
	var traffic := Node3D.new()
	city.add_child(traffic)
	var car = load("res://scenes/traffic_car.tscn").instantiate()
	car.model_scene = load("res://assets/kenney_city/cars_rigged/sedan.glb")
	car.parked = true
	traffic.add_child(car)
	car.set_physics_process(false)
	return car

func run() -> void:
	var host_root := Node3D.new()
	host_root.name = "TestHost"
	root.add_child(host_root)
	current_scene = host_root
	var host = make_car(host_root)
	host.hybrid.state = host.hybrid.State.DISABLED
	host.disabled = true
	host.global_position = Vector3(4, 0.1, 2)
	host.hybrid.rollover_velocity = Vector3.RIGHT * 2
	host.hybrid.rollover_distance = 1.5
	host.hybrid.pose.z = PI * 0.5
	host.hybrid.apply_ground_pose({"normal": Vector3.UP, "position": Vector3.ZERO}, host.hybrid.pose)
	var disabled_payload: Dictionary = host.get_hybrid_snapshot()
	host.hybrid.disabled_cue.set_age(4.0)
	disabled_payload = host.get_hybrid_snapshot() # Joining during the fade, not its beginning.
	assert(host.consume_truck_landing())
	assert(not host.consume_truck_landing() and host.hybrid.explosion_count == 1)
	var explosion_payload: Dictionary = host.get_hybrid_snapshot()
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var server_peers: Array[int] = []
	server.peer_connected.connect(func(id: int): server_peers.append(id))
	assert(server.create_server(24573, 1) == OK)
	assert(client.create_client("127.0.0.1", 24573) == OK)
	var deadline := Time.get_ticks_msec() + 5000
	while (client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or server_peers.is_empty()) and Time.get_ticks_msec() < deadline:
		server.poll()
		client.poll()
		await process_frame
	assert(client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	assert(not server_peers.is_empty())
	server.poll()
	server.set_target_peer(server_peers[0])
	assert(server.put_packet(var_to_bytes([disabled_payload, explosion_payload])) == OK)
	while client.get_available_packet_count() == 0 and Time.get_ticks_msec() < deadline:
		server.poll()
		client.poll()
		await process_frame
	assert(client.get_available_packet_count() > 0)
	var payloads: Array = bytes_to_var(client.get_packet())
	var client_root := Node3D.new()
	client_root.name = "TestClient"
	root.add_child(client_root)
	var api := MultiplayerAPI.create_default_interface()
	api.multiplayer_peer = client
	set_multiplayer(api, client_root.get_path())
	var guest = make_car(client_root)
	assert(not guest.multiplayer.is_server())
	assert(not guest.consume_truck_landing(), "Client must not author landing explosion")
	var guest_truck = load("res://scenes/truck.tscn").instantiate()
	client_root.add_child(guest_truck)
	guest_truck.set_physics_process(false)
	assert(not guest_truck.try_car_landing_launch(guest, Vector3.UP, Vector3.ZERO, Vector3.DOWN * 20), "Client must not author truck launch")
	assert(not guest.receive_vehicle_contact(Vector3.RIGHT * 20, Vector3.RIGHT, Vector3.ZERO), "Client must not author impacts")
	guest.apply_hybrid_snapshot(payloads[0])
	guest.apply_hybrid_snapshot(payloads[0])
	assert(guest.disabled and guest.hybrid.state == guest.hybrid.State.DISABLED)
	assert(guest.global_transform.is_equal_approx(disabled_payload.root))
	assert(guest.hybrid.rollover_velocity.is_equal_approx(disabled_payload.rolling.momentum))
	assert(is_equal_approx(guest.hybrid.rollover_distance, 1.5))
	assert(guest.collision_layer == 0 and guest.collision_mask == 0)
	assert(guest.hybrid.disabled_cue.start_count == 1 and is_equal_approx(guest.hybrid.disabled_cue.opacity, 0.5))
	assert(guest.hybrid.disabled_cue.smoke.emitting, "Late fade snapshot must initialize smoke/cue age")
	assert(guest.get_node("Visual").transform.is_equal_approx(disabled_payload.visual))
	for pose in disabled_payload.wheels:
		assert(guest.hybrid.wheel_rig.get_bone_pose_position(pose[0]).is_equal_approx(pose[1]))
	var effects_before := root.find_children("*", "AnimatedSprite3D", true, false).size()
	guest.apply_hybrid_snapshot(payloads[1])
	guest.apply_hybrid_snapshot(payloads[1])
	assert(guest.exploded and not guest.get_node("Visual").visible and guest.collision_layer == 0)
	assert(guest.hybrid.disabled_cue == null)
	assert(root.find_children("*", "AnimatedSprite3D", true, false).size() == effects_before + 1, "One client explosion despite repeated payload")
	server.close()
	client.close()
	print("HYBRID REPLICATION PASS: real loopback ENet payload, server-owned impacts, disabled/visual/wheel state, one client explosion and collision removal; not a full multiplayer session test")
	quit()
