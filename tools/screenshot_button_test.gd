extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var truck := Node3D.new()
	truck.name = "FoodTruck"
	scene.add_child(truck)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	scene.add_child(hud)
	var hidden_menu := CanvasLayer.new()
	hidden_menu.hide()
	scene.add_child(hidden_menu)
	var status := Label3D.new()
	scene.add_child(status)
	var street_sign := Node3D.new()
	street_sign.name = "StreetName_0_0"
	scene.add_child(street_sign)
	var street_label := Label3D.new()
	street_sign.add_child(street_label)
	var bubble := Node3D.new()
	bubble.name = "SpeechBubble"
	scene.add_child(bubble)
	var capture = root.get_node("ScreenshotCapture")
	capture._process(0.0)
	assert(not capture.screenshot_button_layer.visible)
	var button = capture.screenshot_button_layer.get_node("CaptureWithoutUI")
	assert(button.pressed.get_connections().size() == 1)
	capture.set_screenshot_mode(true)
	assert(not hud.visible and not capture.screenshot_button_layer.visible, "Capture hides UI without opening camera controls")
	capture.capture_in_progress = true
	capture.hide_game_ui()
	assert(not capture.screenshot_button_layer.visible, "Screenshot tools disappear during clean capture")
	capture.capture_in_progress = false
	assert(not status.visible and not bubble.visible)
	assert(street_label.visible, "Physical street signage remains in the screenshot")
	capture.set_screenshot_mode(false)
	assert(hud.visible and status.visible and bubble.visible)
	assert(not hidden_menu.visible, "Originally hidden menus stay hidden")
	capture._process(0.0)
	assert(not capture.screenshot_button_layer.visible)
	print("SCREENSHOT BUTTON PASS: controls hidden outside camera mode, capture action connected, UI hidden for capture, original visibility restored, street signage retained")
	quit()
