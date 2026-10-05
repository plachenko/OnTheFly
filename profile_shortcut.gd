extends Node

const DIRECTORY := "res://.godot/codex_chat/profiling"
const SETTINGS := DIRECTORY + "/settings.json"
var enabled := false
var auto_send := false
var seconds := 10.0
var context := ""
var refresh := 0.0
var held_device := -1
var pressed_at := 0
var held := false
var samples: Array[Dictionary] = []
var physics_samples: Array[Dictionary] = []
var physics_ticks := false
var captured_frames: Array[Dictionary] = []
var captured_ticks: Array[Dictionary] = []
var pending_report: Dictionary = {}
var notice: Label
var notice_panel: PanelContainer
var notice_remaining := 0.0
var command_buttons: HBoxContainer
var cancel_button: Button
var send_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 1200
	add_child(layer)
	notice_panel = PanelContainer.new()
	notice_panel.name = "ProfileNotice"
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.065, 0.94)
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	notice_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(notice_panel)
	notice = Label.new()
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 22)
	notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	notice.add_theme_constant_override("shadow_offset_x", 1)
	notice.add_theme_constant_override("shadow_offset_y", 1)
	var contents := VBoxContainer.new()
	notice_panel.add_child(contents)
	contents.add_child(notice)
	command_buttons = HBoxContainer.new()
	command_buttons.name = "CommandButtons"
	command_buttons.add_theme_constant_override("separation", 12)
	contents.add_child(command_buttons)
	for left in [true, false]:
		var button := Button.new()
		button.text = "Cancel / LB" if left else "Send / RB"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 72
		button.add_theme_font_size_override("font_size", 20)
		preload("res://addons/codex_chat/bumper_button_style.gd").apply(button, Color(0.62, 0.10, 0.15) if left else Color(0.07, 0.42, 0.22), left)
		command_buttons.add_child(button)
		if left:
			cancel_button = button
			button.pressed.connect(cancel_report)
		else:
			send_button = button
			button.pressed.connect(queue_report)
	command_buttons.hide()
	get_viewport().size_changed.connect(layout_notice)
	notice_panel.minimum_size_changed.connect(layout_notice.call_deferred)
	notice_panel.hide()
	load_settings()

func layout_notice() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	notice_panel.size.x = minf(760, maxf(120, viewport_size.x - 40))
	notice_panel.size.y = notice_panel.get_combined_minimum_size().y
	notice_panel.position = Vector2((viewport_size.x - notice_panel.size.x) * 0.5, viewport_size.y - notice_panel.size.y - maxf(28, viewport_size.y * 0.08))

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS): return
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	if not config is Dictionary: return
	var was_enabled := enabled
	enabled = bool(config.get("enabled", false))
	auto_send = bool(config.get("auto_send", false))
	seconds = clampf(float(config.get("seconds", 10)), 1, 30)
	context = str(config.get("context", "")).left(4000)
	if was_enabled and not enabled:
		held_device = -1
		held = false
		samples.clear()
		physics_samples.clear()
		captured_frames.clear()
		captured_ticks.clear()
		pending_report.clear()
		show_notice("Profiling shortcut disabled")

func show_notice(text: String) -> void:
	notice_remaining = 6.0
	notice_panel.visible = not text.is_empty()
	command_buttons.visible = not pending_report.is_empty()
	send_button.disabled = pending_report.get("frames", []).is_empty()
	if notice.text == text: return
	notice.text = text
	layout_notice.call_deferred()

func cancel_report() -> void:
	pending_report.clear()
	captured_frames.clear()
	captured_ticks.clear()
	show_notice("Profile sending cancelled")

func handle_input(event: InputEvent) -> bool:
	if not enabled or not event is InputEventJoypadButton: return false
	if event.button_index in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]:
		if pending_report.is_empty() and held_device == -1: return false
		if event.pressed:
			physics_ticks = event.button_index == JOY_BUTTON_DPAD_DOWN
			if not pending_report.is_empty():
				select_report_samples()
			else:
				show_notice("Capture: %s\nD-pad Right: frames / Down: physics ticks\nTap LB: recent / hold LB: record" % ("physics ticks" if physics_ticks else "frames"))
		return true
	if not pending_report.is_empty():
		if event.button_index not in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]: return false
		if event.pressed:
			if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
				cancel_report()
			else: queue_report()
		return true
	if event.button_index != JOY_BUTTON_LEFT_SHOULDER: return false
	if event.pressed and held_device == -1:
		held_device = event.device
		pressed_at = Time.get_ticks_usec()
		held = false
		samples.clear()
		physics_samples.clear()
	elif not event.pressed and event.device == held_device:
		var duration := (Time.get_ticks_usec() - pressed_at) / 1000000.0
		if held or duration >= 0.5:
			finish_capture(samples, "hold", physics_samples)
		else:
			var recent: Array[Dictionary] = []
			var recent_ticks: Array[Dictionary] = []
			var cutoff := Time.get_ticks_usec() - int(seconds * 1000000)
			for sample in get_parent().recent_samples:
				if int(sample.time_us) >= cutoff: recent.append(sample)
			for sample in get_parent().recent_physics_samples:
				if int(sample.time_us) >= cutoff: recent_ticks.append(sample)
			finish_capture(recent, "snap", recent_ticks)
		held_device = -1
		held = false
	return true

func record_sample(sample: Dictionary, physics: bool = false) -> void:
	if held_device == -1: return
	if physics: physics_samples.append(sample)
	else: samples.append(sample)
	var duration := (int(sample.time_us) - pressed_at) / 1000000.0
	if duration >= 0.5:
		held = true
		show_notice("Capturing %s %.1f / %.0fs\nRelease LB to finish / D-pad Right: frames / Down: ticks" % ["physics ticks" if physics_ticks else "frames", duration, seconds])
	if duration >= seconds:
		finish_capture(samples, "hold", physics_samples)
		held_device = -1
		held = false

func finish_capture(frames: Array[Dictionary], mode: String, ticks: Array[Dictionary] = []) -> void:
	if frames.is_empty() and ticks.is_empty():
		show_notice("Profile warming up - try again shortly")
		return
	captured_frames = frames.duplicate()
	captured_ticks = ticks.duplicate()
	var scene := get_tree().current_scene
	var camera := get_viewport().get_camera_3d()
	var game_context := {"scene": scene.scene_file_path if scene != null else "", "camera_position": str(camera.global_position) if camera != null else "", "camera_rotation": str(camera.global_rotation) if camera != null else ""}
	if scene != null:
		var truck := scene.get_node_or_null("FoodTruck") as Node3D
		if truck != null: game_context["truck_position"] = str(truck.global_position)
	pending_report = {"id": "%d_%d" % [Time.get_ticks_usec(), OS.get_process_id()], "format": "onthefly.profile_context", "mode": mode, "context": context, "game": game_context}
	select_report_samples()
	if auto_send and not pending_report.get("frames", []).is_empty(): queue_report()

func select_report_samples() -> void:
	var selected := captured_ticks if physics_ticks else captured_frames
	var compact: Array = []
	var origin := int(selected[0].time_us) if not selected.is_empty() else 0
	for sample in selected:
		var time_ms := (int(sample.time_us) - origin) / 1000.0
		if physics_ticks:
			compact.append([time_ms, sample.physics_tick, sample.process_frame, sample.step_ms, sample.tick_interval_ms, sample.sections_ms, sample.section_calls, sample.get("patron_count", 0)])
		else:
			compact.append([time_ms, sample.frame_ms, sample.process_ms, sample.physics_ms, sample.draw_calls, sample.primitives, sample.sections_ms, sample.get("patron_count", 0)])
	pending_report["sample_kind"] = "physics_ticks" if physics_ticks else "rendered_frames"
	pending_report["columns"] = ["time_ms", "physics_tick", "process_frame", "step_ms", "tick_interval_ms", "sections_ms", "section_calls", "patron_count"] if physics_ticks else ["time_ms", "frame_ms", "process_ms", "physics_ms", "draw_calls", "primitives", "sections_ms", "patron_count"]
	pending_report["frames"] = compact
	pending_report["settings_first"] = selected[0] if not selected.is_empty() else {}
	pending_report["settings_last"] = selected.back() if not selected.is_empty() else {}
	pending_report["note"] = "One row per physics tick. sections_ms contains instrumented callback CPU time for that tick; section_calls counts updates for each section. process_frame groups catch-up ticks. step_ms is simulation delta; tick_interval_ms is wall time between samples, not CPU duration. Engine solver and GPU times are unmeasured. No video/image readback performed." if physics_ticks else "CPU monitors may lag; GPU time is unmeasured. No video/image readback performed."
	show_notice("Captured %d %s\nD-pad Right: frames / Down: physics ticks\nRB: Send to Codex / LB: cancel" % [selected.size(), "physics ticks" if physics_ticks else "frames"])

func queue_report() -> void:
	if pending_report.is_empty(): return
	if pending_report.get("frames", []).is_empty():
		show_notice("No samples in this mode\nD-pad Right: frames / Down: physics ticks / LB: cancel")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var path := DIRECTORY + "/request.json"
	if FileAccess.file_exists(path):
		show_notice("Codex profile pending - RB: retry / LB: cancel")
		return
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		show_notice("Could not queue profile - RB: retry / LB: cancel")
		return
	file.store_string(JSON.stringify(pending_report))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error != OK:
		show_notice("Could not queue profile - RB: retry / LB: cancel")
		return
	pending_report.clear()
	captured_frames.clear()
	captured_ticks.clear()
	show_notice("Captured - queued for the Godot Codex dock")

func _process(delta: float) -> void:
	refresh -= delta
	if refresh <= 0:
		refresh = 0.5
		load_settings()
	notice_remaining -= delta
	if held_device == -1 and pending_report.is_empty() and notice_remaining <= 0:
		notice.text = ""
		notice_panel.hide()
