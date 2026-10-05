extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var level = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for index in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Shadow/Documents/Codex/2026-10-05/le/outputs/cockpit-interface.png")
	print("COCKPIT GAME RENDER PASS")
	quit()
