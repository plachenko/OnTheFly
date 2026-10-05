extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var loader = root.get_node("LoadingScreen")
	loader.begin_cover()
	await loader.transition.finished
	assert(loader.text_layer.get_node("LoadingTitle").text == "On the Fly!")
	for code in range(32,127): assert(ThemeDB.fallback_font.has_char(code))
	assert(loader.map_preview.visible and loader.map_preview.plan.exits.size() >= 3 and not loader.spinner.visible)
	assert(loader.backdrop.smoothing_at < 0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/loading_truck_drive.png")
	loader.busy = true
	await loader.stage("Smoothing road visuals...")
	print("SMOOTH CLOCK ",loader.backdrop.smoothing_at," start=",loader.backdrop.material.get_shader_parameter("run_started")," travel=",loader.backdrop.finish_travel_seconds)
	assert(loader.backdrop.smoothing_at >= 0)
	loader.backdrop.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(loader.backdrop.finish_travel_seconds+.7).timeout
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	before.save_png("res://.godot/loading_truck_donuts.png")
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var changed := 0
	for y in range(int(before.get_height()*.62),int(before.get_height()*.85),2):
		for x in range(int(before.get_width()*.81),int(before.get_width()*.94),2):
			if before.get_pixel(x,y) != after.get_pixel(x,y): changed += 1
	print("ANIM CHANGED ",changed," elapsed=",loader.backdrop.elapsed)
	assert(changed > 20)
	loader.busy = false
	await loader.finish_cover()
	assert(not loader.panel.visible)
	print("LOADING TRUCK PASS: title, ASCII glyphs, clean background, smoothing gate, GPU donuts and smoke with processing disabled")
	quit()
