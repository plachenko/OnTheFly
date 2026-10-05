extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	scene.get_node("ProceduralCity").randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	scene.set_free_camera_look(true)
	scene.camera.global_position = scene.truck.global_position + Vector3(12, 8, 16)
	scene.focus_free_camera_on_truck()
	var overlay := CanvasLayer.new()
	overlay.layer = 99
	scene.add_child(overlay)
	var marker := ColorRect.new()
	marker.color = Color.MAGENTA
	marker.size = Vector2(80, 80)
	overlay.add_child(marker)
	var capture = root.get_node("ScreenshotCapture")
	capture.screenshot_directory = "res://.godot/camera-capture-test"
	capture.last_camera_path = "res://.godot/camera-capture-test/last_camera.json"
	await process_frame
	await RenderingServer.frame_post_draw
	assert(not overlay.visible, "Camera mode hides newly created gameplay overlays")
	var saved_path := ""
	capture.screenshot_saved.connect(func(path: String): capture.set_meta("test_saved_path", path))
	await capture.capture_screenshot(true)
	saved_path = capture.get_meta("test_saved_path")
	var image := Image.load_from_file(saved_path)
	assert(not image.get_pixel(20, 20).is_equal_approx(Color.MAGENTA), "Clean image must exclude the overlay")
	assert(not overlay.visible and capture.screenshot_button_layer.visible)
	var state = JSON.parse_string(FileAccess.get_file_as_string(saved_path.get_basename() + ".camera.json"))
	assert(state.version == 2 and state.has("truck_relative_position"))
	assert(Vector3(state.position[0], state.position[1], state.position[2]).distance_to(scene.camera.global_position) < .001)
	var timeline = capture.camera_timeline
	timeline.start_record()
	for index in 10:
		scene.camera.global_position += Vector3(.1, 0, 0)
		await process_frame
	timeline.stop_record()
	assert(paused and timeline.document.keys.size() >= 2)
	assert(timeline.save_json("res://.godot/camera-capture-test/camera_timeline.json") == OK)
	capture.set_screenshot_mode(true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/camera-capture-test/camera-tools-preview.png")
	capture.set_screenshot_mode(false)
	timeline.resume_game()
	scene.set_free_camera_look(false)
	assert(overlay.visible and not capture.screenshot_button_layer.visible)
	print("CAMERA CAPTURE RENDER PASS: overlay removed from PNG, UI restored, matching truck-relative metadata, recorded timeline JSON saved")
	quit()
