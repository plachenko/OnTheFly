extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var session: Node = root.get_node("NetworkSession")
	assert(session.start_host(24575, "Chef Alex") == OK)
	await process_frame
	await process_frame
	session.register_player(2, "Chef Sam")
	session.update_lobby_player(2, true, 4)
	session.send_chat("Let's cook!")
	await create_timer(0.4).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/lobby_preview.png")
	assert(current_scene.lobby_menu.bubbles.get_child_count() == 1)
	await create_timer(1.1).timeout
	assert(current_scene.lobby_menu.bubbles.get_child_count() == 0)
	print("LOBBY BUBBLES PASS: preview saved, bubble removed after rising and fading")
	quit()
