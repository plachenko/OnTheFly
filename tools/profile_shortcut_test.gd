extends SceneTree

class TestShortcut extends "res://profile_shortcut.gd":
	var sent := 0
	func queue_report() -> void:
		sent += 1
		pending_report.clear()

class TickProbe extends Node:
	func _physics_process(_delta: float) -> void:
		var diagnostics := get_node("/root/PerformanceDiagnostics")
		diagnostics.record_section("Tick probe", 1000)
		diagnostics.record_section("Tick probe", 2000)

func _initialize() -> void: run.call_deferred()

func button(index: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index as JoyButton
	event.device = 3
	event.pressed = pressed
	return event

func run() -> void:
	await process_frame
	await process_frame
	var diagnostics := root.get_node("PerformanceDiagnostics")
	var shortcut := TestShortcut.new()
	diagnostics.add_child(shortcut)
	shortcut.set_process(false)
	shortcut.enabled = true
	shortcut.auto_send = false
	shortcut.context = "Standing still"
	assert(not shortcut.handle_input(button(JOY_BUTTON_DPAD_RIGHT, true)), "Idle profiling must preserve D-pad navigation")
	assert(not shortcut.handle_input(button(JOY_BUTTON_DPAD_DOWN, true)))
	assert(not shortcut.handle_input(button(JOY_BUTTON_DPAD_RIGHT, false)))
	assert(not shortcut.handle_input(button(JOY_BUTTON_DPAD_DOWN, false)))
	assert(shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true)))
	assert(shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, false)))
	assert(not shortcut.pending_report.is_empty() and shortcut.sent == 0)
	assert(shortcut.pending_report.mode == "snap" and shortcut.pending_report.context == "Standing still")
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, false))
	assert(shortcut.pending_report.is_empty() and shortcut.sent == 0)
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, false))
	shortcut.handle_input(button(JOY_BUTTON_RIGHT_SHOULDER, true))
	assert(shortcut.sent == 1 and shortcut.pending_report.is_empty())
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.pressed_at -= 600000
	shortcut.record_sample(diagnostics.recent_samples.back())
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, false))
	assert(shortcut.pending_report.mode == "hold" and shortcut.sent == 1)
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.auto_send = true
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, false))
	assert(shortcut.sent == 2 and shortcut.pending_report.is_empty())
	# The late physics collector must produce independent samples, not frame totals.
	var live_shortcut = diagnostics.profile_shortcut
	live_shortcut.set_process(false)
	live_shortcut.enabled = true
	live_shortcut.auto_send = false
	var probe := TickProbe.new()
	root.add_child(probe)
	for index in 5:
		await physics_frame
	await process_frame
	assert(diagnostics.recent_physics_samples.size() >= 4)
	var ticks: Array[Dictionary] = []
	for sample in diagnostics.recent_physics_samples:
		if not sample.sections_ms.has("Tick probe"): continue
		assert(is_equal_approx(sample.sections_ms["Tick probe"], 3.0))
		assert(sample.section_calls["Tick probe"] == 2)
		if not ticks.is_empty(): assert(sample.physics_tick > ticks.back().physics_tick)
		ticks.append(sample)
	assert(ticks.size() >= 3)
	probe.set_physics_process(false)
	# Render-only work must not appear in physics samples.
	diagnostics.record_section("Render probe", 9000)
	await physics_frame
	await process_frame
	assert(not diagnostics.recent_physics_samples.back().sections_ms.has("Render probe"))
	shortcut.auto_send = false
	shortcut.finish_capture([diagnostics.recent_samples.back()], "hold", ticks)
	assert(shortcut.pending_report.sample_kind == "rendered_frames")
	assert(shortcut.handle_input(button(JOY_BUTTON_DPAD_DOWN, true)))
	assert(shortcut.pending_report.sample_kind == "physics_ticks")
	assert(shortcut.pending_report.frames.size() == ticks.size())
	assert(shortcut.pending_report.columns[1] == "physics_tick")
	assert(shortcut.pending_report.frames[0][5]["Tick probe"] == 3.0)
	var encoded := JSON.stringify(shortcut.pending_report)
	assert(JSON.parse_string(encoded).sample_kind == "physics_ticks")
	shortcut.handle_input(button(JOY_BUTTON_DPAD_RIGHT, true))
	assert(shortcut.pending_report.frames.size() == 1 and shortcut.pending_report.columns[1] == "frame_ms")
	shortcut.handle_input(button(JOY_BUTTON_DPAD_DOWN, true))
	shortcut.handle_input(button(JOY_BUTTON_RIGHT_SHOULDER, true))
	assert(shortcut.sent == 3)
	# A physics snap selects the physics history without mixing rendered-frame rows.
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, false))
	assert(shortcut.pending_report.mode == "snap" and shortcut.pending_report.sample_kind == "physics_ticks")
	assert(not shortcut.pending_report.frames.is_empty())
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	shortcut.pressed_at -= 600000
	shortcut.record_sample(diagnostics.recent_physics_samples.back(), true)
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, false))
	assert(shortcut.pending_report.mode == "hold" and shortcut.pending_report.sample_kind == "physics_ticks")
	assert(shortcut.pending_report.frames.size() == 1)
	shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true))
	# Notice bounds and styling work in landscape and portrait.
	shortcut.finish_capture([diagnostics.recent_samples.back()], "hold", ticks)
	assert(shortcut.command_buttons.visible and not shortcut.send_button.disabled)
	for dimensions in [Vector2i(1280,720), Vector2i(720,1280)]:
		root.size = dimensions
		shortcut.show_notice("Captured 600 physics ticks\nD-pad Right: frames / Down: physics ticks\nRB: Send to Codex / LB: cancel")
		await process_frame
		await process_frame
		shortcut.layout_notice()
		var viewport_size := root.get_visible_rect().size
		var panel := shortcut.notice_panel
		assert(absf(panel.position.x + panel.size.x * 0.5 - viewport_size.x * 0.5) < 1.0)
		assert(panel.position.y > viewport_size.y * 0.6)
		assert(panel.position.y + panel.size.y < viewport_size.y)
		assert(panel.size.x <= viewport_size.x - 39)
		assert(shortcut.notice.get_theme_font_size("font_size") == 22)
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert(style.corner_radius_top_left == 16 and style.content_margin_left == 22)
		assert(shortcut.cancel_button.global_position.x < shortcut.send_button.global_position.x)
		var cancel_style := shortcut.cancel_button.get_theme_stylebox("normal") as StyleBoxFlat
		var send_style := shortcut.send_button.get_theme_stylebox("normal") as StyleBoxFlat
		assert(cancel_style.bg_color.r > cancel_style.bg_color.g and cancel_style.corner_radius_top_left == 56)
		assert(send_style.bg_color.g > send_style.bg_color.r and send_style.corner_radius_top_right == 56)
	shortcut.cancel_button.pressed.emit()
	assert(shortcut.pending_report.is_empty() and not shortcut.command_buttons.visible)
	shortcut._process(7.0)
	assert(not shortcut.notice_panel.visible)
	probe.queue_free()
	assert(load("res://addons/codex_chat/dock.gd") != null)
	shortcut.enabled = false
	assert(not shortcut.handle_input(button(JOY_BUTTON_LEFT_SHOULDER, true)))
	shortcut.queue_free()
	print("PROFILE SHORTCUT PASS: frame/physics snap and hold, directional selection, per-tick isolation and update counts, JSON, confirm/cancel/auto-send, padded bottom-center landscape/portrait notice")
	quit()
