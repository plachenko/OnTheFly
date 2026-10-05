extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var capture := root.get_node("ScreenshotCapture")
	var recorder := root.get_node("ReplayRecorder")
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_LEFT_SHOULDER
	press.device = 2
	press.pressed = true
	capture._input(press)
	assert(recorder.has_method("capture_frame"))
	assert(recorder.held_device == 2)
	assert(not capture.bumper_down)
	recorder.update_hold(recorder.held_started + 499)
	assert(not recorder.held_video)
	recorder.update_hold(recorder.held_started + 500)
	assert(recorder.held_video)
	var screenshots: Array[bool] = []
	recorder.screenshot_requested.connect(func(): screenshots.append(true))
	press.pressed = false
	capture._input(press)
	assert(recorder.held_device == -999 and not recorder.held_video)
	assert(screenshots.is_empty(), "Holding must not take a screenshot on release")
	print("REPLAY BUMPER PASS: lazy activation, device routing, hold threshold, release")
	quit()
