extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var loader = root.get_node("LoadingScreen")
	loader.begin_cover()
	await loader.transition.finished
	# Prove animation does not depend on the backdrop's script processing.
	loader.backdrop.process_mode = Node.PROCESS_MODE_DISABLED
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	for y in [int(before.get_height() * 0.03), int(before.get_height() * 0.97)]:
		var changed := 0
		for x in range(0, before.get_width(), 4):
			if before.get_pixel(x, y) != after.get_pixel(x, y): changed += 1
		assert(changed > 20, "Shader must animate stripes and checkers with script processing disabled")
	after.save_png("res://.godot/loading_shader_preview.png")
	assert(loader.backdrop.scale == Vector2.ONE)
	print("LOADING_SHADER_PASS: stripe/checker loop moves without script processing")
	quit()
