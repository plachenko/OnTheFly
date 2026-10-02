extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu: Node = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for frame in 5: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/multiplayer_menu_preview.png")
	menu.multiplayer_dialog.open(true)
	for frame in 3: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/multiplayer_dialog_preview.png")
	menu.multiplayer_dialog.hide()
	assert(root.get_node("NetworkSession").start_host(24570, "Local driver") == OK)
	while root.get_node("LoadingScreen").busy or not is_instance_valid(root.get_node("NetworkSession").level):
		await process_frame
	var session := root.get_node("NetworkSession")
	session.register_player(88, "Second truck")
	session.level.trucks[88].global_position = session.level.local_truck.global_position + Vector3(8, 0, 1)
	for frame in 5: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/multiplayer_world_preview.png")
	print("MULTIPLAYER PREVIEW SAVED")
	session.close()
	quit()
