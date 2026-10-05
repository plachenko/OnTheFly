extends Node

signal bumper_forwarded(event: InputEventJoypadButton, started_ms: int)
const DIRECTORY := "res://.godot/codex_chat/dictation"
const HOLD_MS := 500
var double_tap_ms := 350
var opened := false
var send_requested := false
var pending_press: InputEventJoypadButton
var press_ms := 0
var release_ms := -1
var forwarded_hold := false
var ignore_release := false
var up_device := -1
var up_press_ms := 0
var up_started_recording := false
var ignore_left_release := false
var speech: Node
var panel: PanelContainer
var status: Label
var draft: TextEdit
var send_button: Button
var dictate_button: Button
var dictate_notch: Control
var flying_notch: Control
var notch_tween: Tween
var dictation_highlighted := false
var draft_idle_style: StyleBox
var draft_idle_focus: StyleBox
var voice_spectrum: Control
var frame_capture: Node
var capture_list: VBoxContainer
var capture_scroll: ScrollContainer
var rb_device := -1
var rb_press_ms := 0
var rb_capturing := false
var chime: AudioStreamPlayer
var settings_path := "user://codex_game_menu.cfg"
var note_store := preload("res://codex_note_store.gd").new()
var save_note_requested := false
var last_saved_note := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		double_tap_ms = clampi(int(config.get_value("controls", "double_tap_ms", 350)), 150, 800)
	speech = make_speech()
	speech.bus_name = "CodexGameDictation"
	add_child(speech)
	speech.status_changed.connect(func(message): status.text = message)
	speech.transcribed.connect(func(text):
		if not opened: return
		draft.text = text
		update_send_button()
		if send_requested: queue_message()
		finish_pending_note())
	speech.state_changed.connect(func():
		if send_requested and not speech.recording and not speech.working:
			send_requested = false
		update_send_button()
		finish_pending_note())
	speech.state_changed.connect(update_dictation_highlight)
	var layer := CanvasLayer.new()
	layer.layer = 1250
	add_child(layer)
	panel = PanelContainer.new()
	panel.name = "CodexGameMenu"
	layer.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.065, 0.96)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var contents := VBoxContainer.new()
	panel.add_child(contents)
	frame_capture = make_frame_capture()
	add_child(frame_capture)
	frame_capture.changed.connect(rebuild_capture_list)
	frame_capture.changed.connect(finish_pending_note)
	frame_capture.status_changed.connect(func(message):
		status.text = message
		if not opened: panel.hide())
	capture_scroll = ScrollContainer.new()
	capture_scroll.custom_minimum_size.y = 120
	capture_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contents.add_child(capture_scroll)
	capture_list = VBoxContainer.new()
	capture_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capture_scroll.add_child(capture_list)
	capture_scroll.hide()
	var title := Label.new()
	title.text = "Codex · Up: tap/hold dictation · Left: cancel · RB: send"
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(status)
	draft = TextEdit.new()
	draft.placeholder_text = "Speak your message, or type here."
	draft.custom_minimum_size.y = 80
	draft.add_theme_font_size_override("font_size", 20)
	contents.add_child(draft)
	draft_idle_style = draft.get_theme_stylebox("normal").duplicate()
	draft_idle_focus = draft.get_theme_stylebox("focus").duplicate()
	draft.text_changed.connect(update_send_button)
	voice_spectrum = preload("res://codex_voice_spectrum.gd").new()
	voice_spectrum.speech = speech
	draft.add_child(voice_spectrum)
	voice_spectrum.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	voice_spectrum.offset_left = -224
	voice_spectrum.offset_right = -12
	voice_spectrum.offset_top = -46
	voice_spectrum.offset_bottom = -12
	voice_spectrum.hide()
	var controls := HBoxContainer.new()
	controls.name = "CommandButtons"
	controls.add_theme_constant_override("separation", 12)
	contents.add_child(controls)
	for item in [["Cancel / LB", cancel_menu], ["Dictate / Up", toggle_dictation], ["Send / RB", send_message]]:
		var button := Button.new()
		button.text = item[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 72
		button.add_theme_font_size_override("font_size", 20)
		if item[0] == "Cancel / LB":
			style_bumper_button(button, Color(0.62, 0.10, 0.15), true)
			button.tooltip_text = "Cancel and close (LB or D-pad Left)."
		elif item[0] == "Send / RB":
			send_button = button
			style_bumper_button(button, Color(0.07, 0.42, 0.22), false)
		else:
			dictate_button = button
			button.text = "Dictate"
			button.tooltip_text = "D-pad Up: tap to toggle dictation; hold to dictate until release."
			style_bumper_button(button, Color(0.10, 0.18, 0.25), false)
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				(button.get_theme_stylebox(state) as StyleBoxFlat).set_corner_radius_all(14)
			dictate_notch = preload("res://codex_direction_notch.gd").new()
			button.add_child(dictate_notch)
			dictate_notch.position = Vector2(12, 26)
		if item[0] == "Send / RB":
			button.button_down.connect(func(): begin_rb(-2, Time.get_ticks_msec()))
			button.button_up.connect(func(): end_rb(-2, Time.get_ticks_msec()))
		else: button.pressed.connect(item[1])
		controls.add_child(button)
	update_send_button()
	flying_notch = preload("res://codex_direction_notch.gd").new()
	layer.add_child(flying_notch)
	flying_notch.hide()
	var save_note_button := Button.new()
	save_note_button.text = "Save Note / D-pad Down"
	save_note_button.tooltip_text = "Save text and captured frames locally without sending to Codex."
	save_note_button.pressed.connect(save_note)
	contents.add_child(save_note_button)
	var timing := SpinBox.new()
	timing.min_value = 150
	timing.max_value = 800
	timing.step = 25
	timing.value = double_tap_ms
	timing.suffix = "ms double-tap"
	timing.tooltip_text = "How long a single LB photo waits for a second tap."
	contents.add_child(timing)
	timing.value_changed.connect(func(value):
		double_tap_ms = int(value)
		var saved := ConfigFile.new()
		saved.set_value("controls", "double_tap_ms", double_tap_ms)
		saved.save(settings_path))
	chime = AudioStreamPlayer.new()
	chime.volume_db = -15
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(4410 * 2)
	for index in 4410:
		var envelope := sin(PI * index / 4410.0)
		data.encode_s16(index * 2, int(sin(TAU * 660.0 * index / 22050.0) * envelope * 12000))
	tone.data = data
	chime.stream = tone
	add_child(chime)
	get_viewport().size_changed.connect(layout_panel)
	panel.minimum_size_changed.connect(layout_panel.call_deferred)
	panel.hide()

func make_speech() -> Node:
	return preload("res://addons/codex_chat/dictation.gd").new()

func make_frame_capture() -> Node:
	return preload("res://codex_frame_capture.gd").new()

func rebuild_capture_list() -> void:
	for child in capture_list.get_children():
		capture_list.remove_child(child)
		child.queue_free()
	capture_scroll.visible = not frame_capture.captures.is_empty()
	for index in frame_capture.captures.size():
		var capture: Dictionary = frame_capture.captures[index]
		var row := HBoxContainer.new()
		capture_list.add_child(row)
		var thumbnail := TextureRect.new()
		thumbnail.custom_minimum_size = Vector2(160, 90)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.texture = capture.thumbnail
		row.add_child(thumbnail)
		var caption := Label.new()
		caption.text = "Capture %d · %d frame(s)" % [index + 1, capture.paths.size()]
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var remove := Button.new()
		remove.text = "Remove"
		remove.pressed.connect(func(): frame_capture.captures.remove_at(index); rebuild_capture_list())
		row.add_child(remove)
	layout_panel.call_deferred()

func begin_rb(device: int, now: int) -> void:
	if rb_device != -1 or frame_capture.capturing or frame_capture.recording: return
	if not draft.text.strip_edges().is_empty():
		send_message()
		return
	rb_device = device
	rb_press_ms = now
	rb_capturing = false

func end_rb(device: int, now: int) -> void:
	if rb_device != device: return
	if not rb_capturing:
		frame_capture.begin()
	frame_capture.finish()
	rb_device = -1
	rb_capturing = false

func advance_rb(now: int) -> void:
	if rb_device != -1 and not rb_capturing and now - rb_press_ms >= HOLD_MS:
		rb_capturing = true
		frame_capture.begin()

func style_bumper_button(button: Button, color: Color, left: bool) -> void:
	preload("res://addons/codex_chat/bumper_button_style.gd").apply(button, color, left)

func update_dictation_highlight() -> void:
	if dictate_button == null or flying_notch == null: return
	var active: bool = opened and speech.recording
	if active == dictation_highlighted: return
	dictation_highlighted = active
	voice_spectrum.visible = active
	for state in ["normal", "hover", "pressed"]:
		var style := dictate_button.get_theme_stylebox(state) as StyleBoxFlat
		style.bg_color = Color(0.04, 0.38, 0.50) if active else Color(0.10, 0.18, 0.25)
		style.set_border_width_all(2 if active else 0)
		style.border_color = Color(0.55, 0.94, 1.0)
	if notch_tween != null: notch_tween.kill()
	flying_notch.hide()
	if active:
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color(0.035, 0.13, 0.19)
		highlight.set_corner_radius_all(12)
		highlight.set_border_width_all(2)
		highlight.border_color = Color(0.55, 0.94, 1.0)
		highlight.set_content_margin_all(10)
		highlight.content_margin_bottom = 50
		draft.add_theme_stylebox_override("normal", highlight)
		draft.add_theme_stylebox_override("focus", highlight)
		animate_dictation_notch.call_deferred()
	else:
		draft.add_theme_stylebox_override("normal", draft_idle_style)
		draft.add_theme_stylebox_override("focus", draft_idle_focus)

func animate_dictation_notch() -> void:
	if not dictation_highlighted: return
	flying_notch.global_position = dictate_notch.global_position
	flying_notch.modulate.a = 1.0
	flying_notch.show()
	notch_tween = create_tween()
	notch_tween.tween_property(flying_notch, "global_position", Vector2(dictate_notch.global_position.x, draft.global_position.y + draft.size.y - 26), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	notch_tween.tween_property(flying_notch, "modulate:a", 0.0, 0.15)
	notch_tween.tween_callback(flying_notch.hide)

func update_send_button() -> void:
	if send_button == null: return
	send_button.disabled = send_requested
	send_button.text = "Capture / RB" if draft.text.strip_edges().is_empty() else "Send / RB"
	send_button.tooltip_text = "Tap RB to capture a frame; hold for a sequence (5 frames/sec, up to 30 seconds)." if draft.text.strip_edges().is_empty() else "Send message and captured frames to Codex (RB)."

func layout_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(720, maxf(200, viewport_size.x - 40)), panel.get_combined_minimum_size().y)
	panel.position = Vector2((viewport_size.x - panel.size.x) * 0.5, maxf(20, viewport_size.y - panel.size.y - 32))

func handle_input(event: InputEvent, now: int = -1) -> bool:
	if not event is InputEventJoypadButton: return false
	if now < 0: now = Time.get_ticks_msec()
	if opened and event.button_index == JOY_BUTTON_DPAD_DOWN:
		if event.pressed: save_note()
		return true
	if event.button_index == JOY_BUTTON_DPAD_UP:
		# Only finish a press already owned by this menu after it closes.
		if not opened and (event.pressed or event.device != up_device): return false
		if event.pressed:
			if up_device != -1: return true
			up_device = event.device
			up_press_ms = now
			up_started_recording = false
			if not speech.working and not send_requested:
				if speech.recording:
					speech.finish()
				else:
					restart_dictation()
					up_started_recording = speech.recording
		elif event.device == up_device:
			if up_started_recording and now - up_press_ms >= HOLD_MS and speech.recording:
				speech.finish()
			up_device = -1
			up_started_recording = false
		return true
	if event.button_index == JOY_BUTTON_DPAD_LEFT:
		if opened:
			if event.pressed:
				ignore_left_release = true
				cancel_menu()
			return true
		if ignore_left_release and not event.pressed:
			ignore_left_release = false
			return true
	if ignore_release and event.button_index == JOY_BUTTON_LEFT_SHOULDER and not event.pressed:
		ignore_release = false
		return true
	if opened:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			if event.pressed:
				ignore_release = true
				cancel_menu()
			return true
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			if event.pressed: begin_rb(event.device, now)
			else:
				advance_rb(now)
				end_rb(event.device, now)
			return true
		return false
	if event.button_index != JOY_BUTTON_LEFT_SHOULDER: return false
	if event.pressed:
		if pending_press != null and release_ms >= 0:
			if event.device == pending_press.device and now - release_ms <= double_tap_ms:
				pending_press = null
				release_ms = -1
				ignore_release = true
				open_menu()
				return true
			flush_tap()
		if pending_press == null:
			pending_press = event.duplicate()
			press_ms = now
			forwarded_hold = false
	elif pending_press != null and event.device == pending_press.device:
		advance(now)
		if forwarded_hold:
			bumper_forwarded.emit(event, press_ms)
			pending_press = null
		else: release_ms = now
	return true

func advance(now: int) -> void:
	if pending_press == null: return
	if release_ms >= 0:
		if now - release_ms > double_tap_ms: flush_tap()
	elif not forwarded_hold and now - press_ms >= HOLD_MS:
		forwarded_hold = true
		bumper_forwarded.emit(pending_press, press_ms)

func flush_tap() -> void:
	bumper_forwarded.emit(pending_press, press_ms)
	var released: InputEventJoypadButton = pending_press.duplicate()
	released.pressed = false
	bumper_forwarded.emit(released, press_ms)
	pending_press = null
	release_ms = -1

func _process(_delta: float) -> void:
	advance(Time.get_ticks_msec())
	advance_rb(Time.get_ticks_msec())
	finish_pending_note()

func save_note() -> void:
	if not opened or save_note_requested: return
	if send_requested:
		status.text = "A message is being sent. Wait before saving a note."
		return
	save_note_requested = true
	frame_capture.finish()
	rb_device = -1
	rb_capturing = false
	if speech.recording: speech.finish()
	finish_pending_note()

func finish_pending_note() -> void:
	if not save_note_requested or speech.recording or speech.working or frame_capture.recording or frame_capture.capturing: return
	save_note_requested = false
	if draft.text.strip_edges().is_empty() and frame_capture.captures.is_empty():
		status.text = "Nothing to save yet. Dictate, type, or capture frames first."
		return
	last_saved_note = note_store.save(draft.text, frame_capture.attachments())
	status.text = "Note saved locally: " + last_saved_note.get_file() if not last_saved_note.is_empty() else "Could not save note. Press Down to retry."

func open_menu() -> void:
	opened = true
	send_requested = false
	draft.text = ""
	update_send_button()
	panel.get_parent().show()
	panel.show()
	layout_panel.call_deferred()
	chime.play()
	status.text = "Tap Up to dictate; tap again to finish. Hold Up to finish on release. Left cancels; RB sends."

func restart_dictation() -> void:
	if opened and not speech.recording and not speech.working:
		speech.start()
		update_dictation_highlight()

func toggle_dictation() -> void:
	if not opened or speech.working or send_requested: return
	if speech.recording: speech.finish()
	else: restart_dictation()

func cancel_menu() -> void:
	save_note_requested = false
	frame_capture.finish()
	rb_device = -1
	rb_capturing = false
	send_requested = false
	up_started_recording = false
	speech.cancel()
	opened = false
	update_dictation_highlight()
	draft.text = ""
	panel.hide()

func send_message() -> void:
	if save_note_requested: return
	if send_requested or draft.text.strip_edges().is_empty(): return
	if frame_capture.recording or frame_capture.capturing:
		status.text = "Finish capturing frames before sending."
		return
	if speech.recording:
		send_requested = true
		speech.finish()
	elif speech.working:
		send_requested = true
	else: queue_message()
	update_send_button()

func queue_message() -> void:
	var text := draft.text.strip_edges()
	if text.is_empty():
		send_requested = false
		status.text = "No message yet. Use Mic again or type a message."
		return
	var path := DIRECTORY + "/request.json"
	if FileAccess.file_exists(path):
		send_requested = false
		status.text = "A message is already queued. Wait, then press RB again."
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		send_requested = false
		status.text = "Could not queue message. Press RB to retry."
		return
	file.store_string(JSON.stringify({"format": "onthefly.dictation_message", "id": "%d_%d" % [Time.get_ticks_usec(), OS.get_process_id()], "text": text, "captures": frame_capture.attachments()}))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		send_requested = false
		status.text = "Could not queue message. Press RB to retry."
		return
	frame_capture.clear()
	cancel_menu()
