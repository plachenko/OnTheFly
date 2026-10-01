extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shoulder(_recorder: Node, device: int = 0, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = pressed
	event.device = device
	root.push_input(event, true)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var guides = scene.get_node("HUD/Layout/POIGuides")
	var script = load("res://poi_guides.gd")
	assert(is_equal_approx(script.bearing(Vector3.FORWARD, Basis.IDENTITY), 0.0))
	assert(is_equal_approx(script.bearing(Vector3.RIGHT, Basis.IDENTITY), PI / 2))
	assert(is_equal_approx(script.bearing(Vector3.BACK, Basis.IDENTITY), PI))
	assert(is_equal_approx(script.bearing(Vector3.FORWARD, Basis(Vector3.UP, PI / 2)), PI / 2))
	var first = guides.serving_destination()
	assert(first != null and first != scene.repair_pad)
	first.expired = true
	assert(guides.serving_destination() != first)
	first.expired = false
	scene.truck.fsd_enabled = true
	scene.truck.get_node("FSDNavigator").destination = first
	assert(guides.serving_destination() == first)
	scene.truck.fsd_enabled = false
	paused = true
	await process_frame
	await process_frame
	assert(not guides.visible)
	paused = false
	var recorder = root.get_node("ReplayRecorder")
	var screenshot_count := [0]
	if DisplayServer.get_name() == "headless":
		recorder.screenshot_requested.disconnect(root.get_node("ScreenshotCapture").capture_screenshot.call_deferred)
	recorder.screenshot_requested.connect(func(): screenshot_count[0] += 1)
	if DisplayServer.get_name() == "headless":
		var image := Image.create(640, 360, false, Image.FORMAT_RGB8)
		image.fill(Color.GREEN)
		for i in 75:
			recorder.frames.append(image.save_jpg_to_buffer())
	else:
		await create_timer(5.5).timeout
		assert(recorder.frames.size() == 75, "Rolling buffer must remain bounded to five seconds")
		root.get_texture().get_image().save_png("res://tools/guides_replay_preview.png")
	shoulder(recorder)
	assert(recorder.recording == null and screenshot_count[0] == 0, "Press must wait for tap versus hold")
	shoulder(recorder, 0, false)
	assert(screenshot_count[0] == 1 and recorder.recording == null, "Quick release must take one screenshot")
	shoulder(recorder, 1)
	if DisplayServer.get_name() == "headless":
		recorder.update_hold(recorder.held_started + recorder.HOLD_MS)
	else:
		await create_timer(0.6).timeout
	assert(recorder.recording != null and recorder.frame_count >= 75, "Hold must start and prepend the five-second buffer")
	assert(screenshot_count[0] == 1, "Holding must not also take a screenshot")
	shoulder(recorder, 0, false)
	assert(recorder.recording != null, "Another controller must not stop the active hold")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(720, 1280)
		await create_timer(1.0).timeout
		assert(recorder.frame_count >= 85, "Recording must append live viewport frames")
		root.size = Vector2i(1280, 800)
	shoulder(recorder, 1, false)
	assert(recorder.recording == null and screenshot_count[0] == 1, "Releasing the held button must save without a screenshot")
	var file := FileAccess.open(recorder.clip_path, FileAccess.READ)
	var data := file.get_buffer(file.get_length())
	assert(data.slice(0, 4).get_string_from_ascii() == "RIFF")
	assert(data.decode_u32(4) == data.size() - 8)
	assert(data.decode_u32(48) == recorder.frame_count, "AVI header must report all frames")
	assert(data.slice(data.size() - recorder.frame_count * 16 - 8, data.size() - recorder.frame_count * 16 - 4).get_string_from_ascii() == "idx1")
	file.close()
	print("GUIDES_REPLAY_TEST PASS: ", recorder.frame_count, " frames; ", ProjectSettings.globalize_path(recorder.clip_path))
	# Check generated city pads, arrival, depletion, and touch HUD placement.
	recorder.start_clip()
	scene.queue_free()
	await process_frame
	scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	assert(recorder.recording != null, "Recording must survive scene changes")
	guides = scene.get_node("HUD/Layout/POIGuides")
	assert(guides.serving_destination() != null)
	for pad in scene.get_node("ParkingPads").get_children():
		if pad != scene.repair_pad:
			pad.expired = true
	assert(guides.serving_destination() == null)
	guides.update_guide(guides.cards[0], null)
	assert(guides.cards[0].label.text.contains("None available"))
	scene.truck.global_position = scene.repair_pad.global_position
	guides.update_guide(guides.cards[1], scene.repair_pad)
	assert(guides.cards[1].label.text.contains("HERE") and not guides.cards[1].arrow.visible)
	var controls = scene.get_node("MobileControls")
	if controls.enabled:
		for screen_size in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(640, 360)]:
			root.size = screen_size
			await process_frame
			controls.arrange()
			var layout: Control = scene.get_node("HUD/Layout")
			assert(root.get_visible_rect().encloses(Rect2(layout.position + guides.position * layout.scale, guides.size * layout.scale)))
	print("CITY_GUIDES_TEST PASS")
	recorder._exit_tree()
	assert(recorder.recording == null, "Normal tree exit must finalize the active clip")
	quit()
