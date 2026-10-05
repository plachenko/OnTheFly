extends SceneTree

class FakeSpeech extends Node:
	signal status_changed(message: String)
	signal transcribed(text: String)
	signal state_changed
	var bus_name := ""
	var recording := false
	var working := false
	var starts := 0
	func start() -> void:
		recording = true
		starts += 1
	func finish() -> void:
		recording = false
		working = true
		state_changed.emit()
	func cancel() -> void:
		recording = false
	func complete(text: String) -> void:
		working = false
		transcribed.emit(text)
		state_changed.emit()

class TestMenu extends "res://codex_game_menu.gd":
	var sent: Array[String] = []
	func make_speech() -> Node:
		return FakeSpeech.new()
	func make_frame_capture() -> Node:
		return FakeCapture.new()
	func queue_message() -> void:
		sent.append(draft.text)
		cancel_menu()

class FakeCapture extends "res://codex_frame_capture.gd":
	func read_frame() -> Dictionary:
		var image := Image.create(16, 9, false, Image.FORMAT_RGB8)
		image.fill(Color.BLUE)
		image.save_png("res://.godot/codex_capture_test.png")
		return {"path": "res://.godot/codex_capture_test.png", "time_us": Time.get_ticks_usec()}

func _initialize() -> void:
	run.call_deferred()

func bumper(index: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index as JoyButton
	event.pressed = pressed
	event.device = 2
	return event

func run() -> void:
	var menu := TestMenu.new()
	menu.settings_path = "res://.godot/codex-game-menu-test.cfg"
	menu.note_store.directory = "res://.godot/codex-note-test"
	root.add_child(menu)
	menu.set_process(false)
	menu.double_tap_ms = 600
	for direction in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		assert(not menu.handle_input(bumper(direction, true), 800), "Closed Codex menu must preserve D-pad navigation")
		assert(not menu.handle_input(bumper(direction, false), 850))
	assert(not menu.opened and menu.speech.starts == 0)
	var forwarded: Array[bool] = []
	menu.bumper_forwarded.connect(func(event, _started): forwarded.append(event.pressed))
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, true), 1000)
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, false), 1050)
	menu.advance(1600)
	assert(forwarded.is_empty(), "Single capture must wait for the configured double-tap delay")
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, true), 1620)
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, false), 1650)
	assert(menu.opened and not menu.speech.recording and menu.speech.starts == 0, "Double LB opens without dictation")
	assert(not menu.send_button.disabled and menu.send_button.text == "Capture / RB")
	menu.send_message()
	assert(menu.sent.is_empty() and not menu.send_requested, "RB must not send an empty draft")
	menu.handle_input(bumper(JOY_BUTTON_RIGHT_SHOULDER, true), 1660)
	menu.handle_input(bumper(JOY_BUTTON_RIGHT_SHOULDER, false), 1680)
	assert(menu.frame_capture.captures.size() == 1 and menu.frame_capture.captures[0].paths.size() == 1)
	assert(menu.frame_capture.captures[0].thumbnail != null and menu.capture_list.get_child_count() == 1)
	menu.handle_input(bumper(JOY_BUTTON_RIGHT_SHOULDER, true), 1681)
	menu.advance_rb(2181)
	menu.frame_capture._process(0.21)
	menu.handle_input(bumper(JOY_BUTTON_RIGHT_SHOULDER, false), 2400)
	assert(menu.frame_capture.captures.size() == 2 and menu.frame_capture.captures[1].paths.size() == 2)
	assert(menu.sent.is_empty(), "Capturing must never send a message")
	menu.cancel_menu()
	menu.open_menu()
	assert(menu.frame_capture.captures.size() == 2, "Closing the menu preserves the capture list")
	menu.capture_list.get_child(0).get_child(2).pressed.emit()
	assert(menu.frame_capture.captures.size() == 1, "Remove affects only the chosen capture")
	assert(forwarded.is_empty(), "Opening Codex must not produce accidental captures")
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, true), 1700)
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, false), 1750)
	assert(not menu.opened and not menu.speech.recording and menu.sent.is_empty())
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, true), 2000)
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, false), 2050)
	menu.advance(2651)
	assert(forwarded == [true, false])
	forwarded.clear()
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, true), 3000)
	menu.advance(3500)
	assert(forwarded == [true])
	menu.handle_input(bumper(JOY_BUTTON_LEFT_SHOULDER, false), 4000)
	assert(forwarded == [true, false], "Holds must still reach the existing capture handler")
	menu.open_menu()
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, true), 4010)
	assert(menu.opened and menu.speech.recording)
	assert(menu.dictation_highlighted)
	assert(menu.voice_spectrum.visible)
	assert((menu.draft.get_theme_stylebox("normal") as StyleBoxFlat).border_width_top == 2)
	await process_frame
	await process_frame
	assert(menu.flying_notch.visible and menu.notch_tween.is_running())
	await create_timer(0.65).timeout
	assert(not menu.flying_notch.visible, "Notch animation completes in the text field")
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, false), 4050)
	assert(menu.speech.recording, "Short tap keeps recording after release")
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, true), 4060)
	assert(menu.speech.working and not menu.speech.recording, "Second tap finishes recording")
	assert(not menu.dictation_highlighted and not menu.flying_notch.visible)
	assert(not menu.voice_spectrum.visible)
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, false), 4070)
	menu.speech.complete("Tap transcript")
	assert(not menu.send_button.disabled, "Completed dictation enables Send")
	assert(menu.draft.text == "Tap transcript" and menu.sent.is_empty(), "Finishing dictation does not send")
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, true), 4080)
	menu.handle_input(bumper(JOY_BUTTON_RIGHT_SHOULDER, true), 4100)
	assert(menu.send_requested and menu.speech.working and menu.sent.is_empty())
	menu.speech.complete("Please inspect the traffic.")
	assert(menu.sent == ["Please inspect the traffic."] and not menu.opened)
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, false), 4110)
	assert(not menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, true), 4150))
	assert(not menu.opened, "D-pad must not reopen dictation after sending")
	menu.open_menu()
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, true), 4200)
	menu.handle_input(bumper(JOY_BUTTON_DPAD_UP, false), 4700)
	assert(not menu.speech.recording and menu.speech.working, "Held Up finishes on release")
	menu.handle_input(bumper(JOY_BUTTON_DPAD_LEFT, true), 4710)
	assert(not menu.opened and not menu.send_requested)
	assert(menu.handle_input(bumper(JOY_BUTTON_DPAD_LEFT, false), 4720), "Cancel release must not reach profiling")
	menu.speech.complete("Cancelled hold")
	assert(menu.draft.text.is_empty() and menu.sent.size() == 1)
	menu.open_menu()
	assert(not menu.send_button.disabled and menu.send_button.text == "Capture / RB")
	menu.restart_dictation()
	menu.send_message()
	menu.cancel_menu()
	menu.speech.complete("Cancelled audio must not send.")
	assert(menu.sent.size() == 1)
	menu.open_menu()
	menu.draft.text = "Save this observation"
	assert(menu.handle_input(bumper(JOY_BUTTON_DPAD_DOWN, true), 5000))
	assert(menu.handle_input(bumper(JOY_BUTTON_DPAD_DOWN, false), 5050))
	assert(not menu.last_saved_note.is_empty() and menu.sent.size() == 1)
	var note: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(menu.last_saved_note))
	assert(note.format == "onthefly.codex_note" and note.text == "Save this observation")
	assert(note.captures.size() == menu.frame_capture.attachments().size())
	assert(note.captures[0].has("camera") and note.captures[0].has("time_us"))
	assert(menu.draft.text == note.text and menu.opened, "Saving preserves the current draft")
	menu.restart_dictation()
	menu.handle_input(bumper(JOY_BUTTON_DPAD_DOWN, true), 5100)
	assert(menu.save_note_requested and menu.speech.working)
	menu.speech.complete("Finished dictation saved locally")
	assert(not menu.save_note_requested and menu.sent.size() == 1)
	note = JSON.parse_string(FileAccess.get_file_as_string(menu.last_saved_note))
	assert(note.text == "Finished dictation saved locally")
	for dimensions in [Vector2i(1280,720), Vector2i(720,1280)]:
		root.size = dimensions
		await process_frame
		await process_frame
		menu.layout_panel()
		var viewport_size := root.get_visible_rect().size
		assert(absf(menu.panel.position.x + menu.panel.size.x * .5 - viewport_size.x * .5) < 1)
		assert(menu.panel.position.y + menu.panel.size.y <= viewport_size.y - 30)
	menu.cancel_menu()
	menu.free()
	assert(load("res://addons/codex_chat/profile_relay.gd") != null)
	assert(load("res://addons/codex_chat/dock.gd") != null)
	print("CODEX GAME MENU PASS: RB tap/hold captures, thumbnails, preserved list/remove, dictation controls, explicit send, bottom-center layout")
	quit()
