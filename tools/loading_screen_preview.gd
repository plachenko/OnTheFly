extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var loader := root.get_node("LoadingScreen")
	loader.begin_cover()
	await loader.transition.finished
	loader.status.text = "Loading assets…"
	for frame in 3:
		await process_frame
	RenderingServer.force_draw(false)
	get_root().get_texture().get_image().save_png("res://.godot/loading_screen_preview.png")
	print("LOADING PREVIEW SAVED")
	quit()
