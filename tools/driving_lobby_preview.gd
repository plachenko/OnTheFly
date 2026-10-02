extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session: Node = root.get_node("NetworkSession")
	assert(session.start_host(24581, "Chef Alex") == OK)
	while not is_instance_valid(session.level): await process_frame
	var world: Node = session.level
	session.register_player(2, "Chef Sam")
	session.loaded_players[2] = true
	session.update_lobby_player(2, true, 4)
	world.lobby_menu.hide()
	await create_timer(0.5).timeout
	session.send_chat("Let's cook!")
	await create_timer(0.4).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/driving_lobby_preview.png")
	print("DRIVING LOBBY PREVIEW SAVED")
	quit()
