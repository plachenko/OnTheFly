extends Node

## Captures the live game viewport from any scene, including paused menus.
const SCREENSHOT_DIRECTORY := "user://screenshots"
var screenshot_mode: bool = false
var hidden_ui: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("screenshot_mode"):
		InputMap.add_action("screenshot_mode")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F10
		InputMap.action_add_event("screenshot_mode", key)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot_mode") and not event.is_echo():
		set_screenshot_mode(not screenshot_mode)
		get_viewport().set_input_as_handled()
		return
	# ReplayRecorder decides tap versus hold and requests a screenshot on release.
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		return
	if event.is_action_pressed("screenshot") and not event.is_echo():
		get_viewport().set_input_as_handled()
		capture_screenshot.call_deferred()

func set_screenshot_mode(enabled: bool) -> void:
	screenshot_mode = enabled
	if enabled:
		hide_game_ui()
	else:
		for node in hidden_ui:
			if is_instance_valid(node):
				node.visible = hidden_ui[node]
		hidden_ui.clear()

func _process(_delta: float) -> void:
	if screenshot_mode:
		# Apply after HUD/patron updates so world meters cannot reappear this frame.
		hide_game_ui.call_deferred()

func hide_game_ui() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene) or not scene.has_node("FoodTruck"):
		set_screenshot_mode(false)
		return
	for name in ["HUD", "MobileControls"]:
		var node := scene.get_node_or_null(name)
		if node:
			hide_ui_node(node)
	var recorder := get_node_or_null("/root/ReplayRecorder")
	if recorder:
		for child in recorder.get_children():
			if child is CanvasLayer:
				hide_ui_node(child)
	var pads := scene.get_node_or_null("ParkingPads")
	if pads:
		for pad in pads.get_children():
			var meter := pad.get_node_or_null("WorldMeter")
			if meter:
				hide_ui_node(meter)

func hide_ui_node(node: Node) -> void:
	if not hidden_ui.has(node):
		hidden_ui[node] = node.visible
	node.visible = false

func capture_screenshot() -> void:
	if screenshot_mode:
		hide_game_ui()
	# Capture after the hidden UI has actually disappeared from the rendered frame.
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(SCREENSHOT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		push_error("Could not create screenshot folder: %s" % error_string(directory_error))
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/OnTheFly_%s_%d.png" % [SCREENSHOT_DIRECTORY, stamp, Time.get_ticks_msec()]
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(path)
	if save_error == OK:
		print("Screenshot saved: ", ProjectSettings.globalize_path(path))
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.has_method("camera_view_state"):
			var state: Dictionary = scene.camera_view_state()
			state["screenshot"] = path.get_file()
			var camera_path := path.get_basename() + ".camera.json"
			var file := FileAccess.open(camera_path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(state, "\t"))
				print("Camera state saved: ", ProjectSettings.globalize_path(camera_path))
			else:
				push_error("Could not save screenshot camera state")
	else:
		push_error("Could not save screenshot: %s" % error_string(save_error))
