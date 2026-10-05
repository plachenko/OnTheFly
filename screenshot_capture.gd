extends Node

## Captures the live game viewport from any scene, including paused menus.
const SCREENSHOT_DIRECTORY := "user://screenshots"
var screenshot_mode: bool = false
var hidden_ui: Dictionary = {}
var capture_in_progress := false
var screenshot_button_layer: CanvasLayer
signal screenshot_saved(path: String)
var camera_context: Label
var mode_button: Button
var free_button: Button
var lock_button: Button
var last_camera_state: Dictionary = {}
const LAST_CAMERA_PATH := "user://screenshots/last_camera.json"
var screenshot_directory := SCREENSHOT_DIRECTORY
var last_camera_path := LAST_CAMERA_PATH
var camera_timeline: PanelContainer
var last_bumper_press := -100000
var bumper_recording := false
var bumper_down := false
var last_screenshot_path := ""
var drive_folder := ""
var drive_config_path := "user://screenshot_drive.cfg"
var drive_button: Button
var drive_status: Label
var drive_folder_dialog: FileDialog
var startup_camera_path := "user://startup_menu.camera.json"
var startup_camera_state: Dictionary = {}
var startup_status: Label
var camera_tools_frame: PanelContainer
var codex_menu: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	codex_menu = preload("res://codex_game_menu.gd").new()
	add_child(codex_menu)
	codex_menu.bumper_forwarded.connect(forward_left_bumper)
	startup_camera_state = preload("res://startup_camera_store.gd").read_pose(startup_camera_path)
	screenshot_button_layer = CanvasLayer.new()
	screenshot_button_layer.name = "ScreenshotButton"
	screenshot_button_layer.layer = 3
	add_child(screenshot_button_layer)
	var button := Button.new()
	button.name = "CaptureWithoutUI"
	button.text = "Screenshot"
	button.tooltip_text = "Save a screenshot without the UI"
	screenshot_button_layer.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -180
	button.offset_right = -16
	button.offset_top = 16
	button.offset_bottom = 68
	button.pressed.connect(func(): capture_screenshot.call_deferred(true))
	screenshot_button_layer.hide()
	var frame := PanelContainer.new()
	camera_tools_frame = frame
	frame.name = "CameraTools"
	screenshot_button_layer.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	frame.offset_left = -340
	frame.offset_right = -16
	frame.offset_top = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025, .06, .08, .9)
	style.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", style)
	var panel := VBoxContainer.new()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	camera_context = Label.new()
	camera_context.add_theme_font_size_override("font_size", 14)
	panel.add_child(camera_context)
	mode_button = Button.new()
	mode_button.text = "Exit camera mode / C / R3 / F10"
	mode_button.pressed.connect(func():
		var scene := camera_scene()
		if scene != null: scene.set_free_camera_look(false)
		set_screenshot_mode(false))
	panel.add_child(mode_button)
	free_button = Button.new()
	free_button.text = "Move camera / C / R3"
	free_button.toggle_mode = true
	free_button.toggled.connect(func(enabled: bool):
		var scene := camera_scene()
		if scene != null: scene.set_free_camera_look(enabled))
	panel.add_child(free_button)
	lock_button = Button.new()
	lock_button.text = "Lock angle and position to truck"
	lock_button.toggle_mode = true
	lock_button.toggled.connect(func(enabled: bool):
		var scene := camera_scene()
		if scene != null: scene.set_camera_reference_lock(enabled))
	panel.add_child(lock_button)
	var restore := Button.new()
	restore.text = "Restore last screenshot angle"
	restore.pressed.connect(restore_last_camera)
	panel.add_child(restore)
	var bake := Button.new()
	bake.text = "Bake current view as startup menu"
	bake.pressed.connect(bake_startup_camera)
	panel.add_child(bake)
	var load_baked := Button.new()
	load_baked.text = "Load baked startup camera"
	load_baked.pressed.connect(load_startup_camera)
	panel.add_child(load_baked)
	var import_camera := Button.new()
	import_camera.text = "Load camera JSON…"
	import_camera.pressed.connect(choose_camera_json)
	panel.add_child(import_camera)
	startup_status = Label.new()
	startup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	startup_status.text = "Baked view applies to the next startup menu."
	panel.add_child(startup_status)
	if OS.get_name() == "Windows":
		var config := ConfigFile.new()
		if config.load(drive_config_path) == OK:
			drive_folder = str(config.get_value("drive", "folder", ""))
		drive_button = Button.new()
		drive_button.text = "Save to Google Drive folder"
		drive_button.tooltip_text = "Copy the latest PNG and camera JSON to a folder synced by Google Drive for desktop."
		drive_button.disabled = true
		drive_button.pressed.connect(save_to_drive_folder)
		panel.add_child(drive_button)
		var choose_folder := Button.new()
		choose_folder.text = "Choose Google Drive folder…"
		choose_folder.pressed.connect(func(): choose_drive_folder(false))
		panel.add_child(choose_folder)
		drive_status = Label.new()
		drive_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		drive_status.text = "Choose a folder synced by Google Drive for desktop."
		panel.add_child(drive_status)
	camera_timeline = preload("res://camera_timeline.gd").new()
	camera_timeline.name = "CameraTimeline"
	screenshot_button_layer.add_child(camera_timeline)
	camera_timeline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	camera_timeline.offset_left = 16
	camera_timeline.offset_right = -16
	camera_timeline.offset_top = -320
	camera_timeline.offset_bottom = -16
	camera_timeline.hide()
	var timeline_button := Button.new()
	timeline_button.text = "Camera timeline / double LB"
	timeline_button.pressed.connect(func(): camera_timeline.visible = not camera_timeline.visible)
	panel.add_child(timeline_button)
	if FileAccess.file_exists(last_camera_path):
		var camera_json := JSON.new()
		var camera_error := camera_json.parse(FileAccess.get_file_as_string(last_camera_path))
		var saved: Variant = camera_json.data if camera_error == OK else null
		if saved is Dictionary:
			last_camera_state = saved
			var filename := str(saved.get("screenshot", "")).get_file()
			if not filename.is_empty():
				var candidate := screenshot_directory.path_join(filename)
				if FileAccess.file_exists(candidate): last_screenshot_path = candidate
	if drive_button != null: drive_button.disabled = last_screenshot_path.is_empty()
	if not InputMap.has_action("screenshot_mode"):
		InputMap.add_action("screenshot_mode")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F10
		InputMap.action_add_event("screenshot_mode", key)

func _input(event: InputEvent) -> void:
	if codex_menu.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	var diagnostics := get_node_or_null("/root/PerformanceDiagnostics")
	if diagnostics != null and diagnostics.profile_shortcut != null and diagnostics.profile_shortcut.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		forward_left_bumper(event, Time.get_ticks_msec())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("screenshot_mode") and not event.is_echo():
		var scene := camera_scene()
		if scene != null: scene.set_free_camera_look(not scene.free_camera_look)
		get_viewport().set_input_as_handled()
		return
	var keyboard_camera: bool = event is InputEventKey and event.physical_keycode == KEY_C and event.pressed and not event.echo
	if keyboard_camera or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_STICK and event.pressed):
		var scene := camera_scene()
		if scene != null: scene.set_free_camera_look(not scene.free_camera_look)
		get_viewport().set_input_as_handled()
		return
	# LB always captures without UI; debug replay retains keyboard F9.
	var replay_button: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER
	var replay_key: bool = event is InputEventKey and event.physical_keycode == KEY_F9 and not event.echo
	if replay_button or replay_key:
		var recorder := get_node_or_null("/root/ReplayRecorder")
		if replay_key and recorder != null and recorder.has_method("capture_frame"): return
		if event.pressed:
			get_viewport().set_input_as_handled()
			capture_screenshot.call_deferred(true)
		return
	if event.is_action_pressed("screenshot") and not event.is_echo():
		get_viewport().set_input_as_handled()
		capture_screenshot.call_deferred(true)

func forward_left_bumper(event: InputEventJoypadButton, started_ms: int) -> void:
	var diagnostics := get_node_or_null("/root/PerformanceDiagnostics")
	if diagnostics != null and diagnostics.profile_shortcut.handle_input(event):
		if event.pressed and codex_menu.forwarded_hold:
			diagnostics.profile_shortcut.pressed_at = started_ms * 1000
		return
	var recorder := get_node_or_null("/root/ReplayRecorder")
	if recorder != null:
		if event.pressed and recorder.has_method("enable_capture"): recorder.enable_capture()
		if recorder.has_method("capture_frame"):
			recorder._input(event)
			if event.pressed and codex_menu.forwarded_hold:
				recorder.held_started = started_ms
				recorder.update_hold(Time.get_ticks_msec())
			return
	# Release builds keep the single clean screenshot action.
	if not event.pressed: capture_screenshot.call_deferred(true)

func set_screenshot_mode(enabled: bool) -> void:
	screenshot_mode = enabled
	refresh_camera_ui()

func refresh_camera_ui() -> void:
	var scene := camera_scene()
	var camera_mode: bool = scene != null and scene.free_camera_look
	screenshot_button_layer.visible = camera_mode and not capture_in_progress
	if camera_mode or screenshot_mode or capture_in_progress:
		hide_game_ui()
	else:
		for node in hidden_ui:
			if is_instance_valid(node):
				node.visible = hidden_ui[node]
		hidden_ui.clear()

func _process(delta: float) -> void:
	refresh_camera_ui()
	camera_timeline.offset_top = -maxf(320.0, camera_timeline.get_combined_minimum_size().y + 16.0)
	camera_tools_frame.offset_bottom = maxf(160.0, get_viewport().get_visible_rect().size.y + (camera_timeline.offset_top - 8.0 if camera_timeline.visible else -16.0))
	var scene := camera_scene()
	free_button.disabled = scene == null
	lock_button.disabled = scene == null
	if scene != null:
		if scene.loading_ready and scene.free_camera_look and (get_tree().paused or not scene.is_processing()): scene.update_free_camera(delta)
		var state: Dictionary = scene.camera_view_state(get_viewport().get_camera_3d())
		var offset: Array = state.truck_relative_position
		camera_context.text = "CAMERA FROM TRUCK: %.2f, %.2f, %.2f m\nYaw %.1f° · pitch %.1f° · range %.2f m\nFOV %.1f° · LB: clean screenshot\nWASD + Q/E · mouse / arrows look\nSticks: move / look · LT/RT: down/up" % [offset[0], offset[1], offset[2], state.orbit_yaw_degrees, state.orbit_pitch_degrees, state.orbit_distance, state.fov]
		free_button.set_pressed_no_signal(scene.free_camera_look)
		lock_button.set_pressed_no_signal(scene.camera_reference_lock)
	else:
		camera_context.text = "LB: clean screenshot · F10: hide UI"
	if screenshot_mode or (scene != null and scene.free_camera_look):
		# Apply after HUD/patron updates so world meters cannot reappear this frame.
		hide_game_ui.call_deferred()

func hide_game_ui() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	# Include paused menus, debug overlays, update notices and the capture button.
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if layer == screenshot_button_layer and not capture_in_progress: continue
		if codex_menu.opened and codex_menu.is_ancestor_of(layer) and not capture_in_progress: continue
		if layer.get_viewport() == get_viewport(): hide_ui_node(layer)
	# Menus can be plain Controls rather than CanvasLayers.
	for control in get_tree().root.find_children("*", "Control", true, false):
		if control.get_viewport() != get_viewport() or is_ancestor_of(control): continue
		if not control.get_parent() is Control: hide_ui_node(control)
	for label in scene.find_children("*", "Label3D", true, false):
		var ancestor: Node = label.get_parent()
		var street_sign := false
		while ancestor != null and ancestor != scene:
			if str(ancestor.name).begins_with("StreetName_"): street_sign = true; break
			ancestor = ancestor.get_parent()
		if street_sign: continue
		hide_ui_node(label)
	for bubble in scene.find_children("SpeechBubble*", "Node3D", true, false): hide_ui_node(bubble)
	for item_name in ["HUD", "MobileControls"]:
		var node := scene.get_node_or_null(item_name)
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

func capture_screenshot(clean_ui: bool = true) -> void:
	if capture_in_progress: return
	capture_in_progress = true
	var was_screenshot_mode := screenshot_mode
	if clean_ui: set_screenshot_mode(true)
	if screenshot_mode:
		hide_game_ui()
	# Capture after the hidden UI has actually disappeared from the rendered frame.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var scene := camera_scene()
	var state: Dictionary = scene.camera_view_state(get_viewport().get_camera_3d()) if scene != null else viewport_camera_state()
	if camera_timeline != null:
		state["timeline_cursor_seconds"] = camera_timeline.cursor
		state["timeline_space"] = camera_timeline.document.space
	if clean_ui and not was_screenshot_mode: set_screenshot_mode(false)
	if hidden_ui.has(screenshot_button_layer):
		screenshot_button_layer.visible = hidden_ui[screenshot_button_layer]
		hidden_ui.erase(screenshot_button_layer)
	capture_in_progress = false
	refresh_camera_ui()
	var directory := ProjectSettings.globalize_path(screenshot_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		push_error("Could not create screenshot folder: %s" % error_string(directory_error))
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/OnTheFly_%s_%d.png" % [screenshot_directory, stamp, Time.get_ticks_msec()]
	var save_error := image.save_png(path)
	if save_error == OK:
		last_screenshot_path = path
		if drive_button != null: drive_button.disabled = false
		print("Screenshot saved: ", ProjectSettings.globalize_path(path))
		if not state.is_empty():
			state["screenshot"] = path.get_file()
			var camera_path := path.get_basename() + ".camera.json"
			var file := FileAccess.open(camera_path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(state, "\t"))
				last_camera_state = state.duplicate(true)
				var latest := FileAccess.open(last_camera_path, FileAccess.WRITE)
				if latest: latest.store_string(JSON.stringify(state, "\t"))
				print("Camera state saved: ", ProjectSettings.globalize_path(camera_path))
			else:
				push_error("Could not save screenshot camera state")
		screenshot_saved.emit(ProjectSettings.globalize_path(path))
	else:
		push_error("Could not save screenshot: %s" % error_string(save_error))

func choose_drive_folder(save_after: bool) -> void:
	if is_instance_valid(drive_folder_dialog):
		drive_folder_dialog.popup_centered_ratio(.7)
		return
	drive_folder_dialog = FileDialog.new()
	drive_folder_dialog.title = "Choose a Google Drive synced folder"
	drive_folder_dialog.use_native_dialog = true
	drive_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	drive_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	if DirAccess.dir_exists_absolute(drive_folder): drive_folder_dialog.current_dir = drive_folder
	add_child(drive_folder_dialog)
	var dialog := drive_folder_dialog
	dialog.dir_selected.connect(func(folder: String):
		drive_folder = folder
		var config := ConfigFile.new()
		config.set_value("drive", "folder", folder)
		var error := config.save(drive_config_path)
		drive_status.text = "Folder selected: " + folder if error == OK else "Folder selected; could not remember it: " + error_string(error)
		dialog.queue_free()
		if save_after: save_to_drive_folder())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(.7)

func save_to_drive_folder() -> void:
	if drive_folder.is_empty() or not DirAccess.dir_exists_absolute(drive_folder):
		choose_drive_folder(true)
		return
	var result := preload("res://screenshot_drive_export.gd").copy_capture(last_screenshot_path, drive_folder)
	drive_status.text = result.error if not result.error.is_empty() else "PNG + camera JSON saved. Google Drive handles syncing."

func camera_scene() -> Node:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene): return null
	if scene.has_method("camera_view_state"): return scene
	for child in scene.find_children("*", "", true, false):
		if child.has_method("camera_view_state"): return child
	return null

func viewport_camera_state() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return {}
	var position := camera.global_position
	var rotation := camera.global_rotation * (180.0 / PI)
	return {"version": 2, "position": [position.x, position.y, position.z], "rotation_degrees": [rotation.x, rotation.y, rotation.z], "fov": camera.fov}

func restore_last_camera() -> void:
	var scene := camera_scene()
	if scene == null or not last_camera_state.has("basis_x"): return
	scene.restore_camera_view(last_camera_state, last_camera_state.has("truck_relative_basis_x"))
	scene.set_camera_reference_lock(true)

func bake_startup_camera() -> void:
	var scene := camera_scene()
	if scene == null: return
	var state: Dictionary = scene.camera_view_state(get_viewport().get_camera_3d())
	var error := preload("res://startup_camera_store.gd").write_pose(startup_camera_path, state)
	if error != OK:
		startup_status.text = "Could not bake camera: " + error_string(error)
		return
	startup_camera_state = state.duplicate(true)
	startup_status.text = "Baked truck-relative view. Startup menu will use it."

func load_startup_camera() -> void:
	var state := preload("res://startup_camera_store.gd").read_pose(startup_camera_path)
	if state.is_empty():
		startup_status.text = "No valid baked camera yet."
		return
	startup_camera_state = state
	apply_loaded_camera(state)

func apply_loaded_camera(state: Dictionary) -> void:
	var scene := camera_scene()
	if scene == null: return
	scene.restore_camera_view(state, true)
	scene.set_camera_reference_lock(true)
	startup_status.text = "Camera loaded relative to this truck. Bake to save for startup."

func choose_camera_json() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Load truck-relative camera JSON"
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Camera JSON"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var state := preload("res://startup_camera_store.gd").read_pose(path)
		if state.is_empty(): startup_status.text = "Invalid camera JSON; view unchanged."
		else: apply_loaded_camera(state)
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(.7)

func handle_left_bumper(pressed: bool, now: int) -> void:
	if pressed:
		if bumper_down: return
		bumper_down = true
		if now - last_bumper_press <= 350 and camera_scene() != null:
			last_bumper_press = -100000
			camera_timeline.start_record()
			bumper_recording = camera_timeline.recording
		else:
			last_bumper_press = now
			capture_screenshot.call_deferred(true)
	else:
		bumper_down = false
		if bumper_recording:
			bumper_recording = false
			camera_timeline.stop_record(true)
