extends SceneTree
var dock
var failure := ""
var settings_before: PackedByteArray
var had_settings := false
class RecordingBridge extends "res://addons/codex_chat/bridge.gd":
	var messages: Array[Dictionary] = []
	func send(message: Dictionary) -> void: messages.append(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	had_settings = FileAccess.file_exists("res://.godot/codex_chat/settings.cfg")
	if had_settings: settings_before = FileAccess.get_file_as_bytes("res://.godot/codex_chat/settings.cfg")
	dock = load("res://addons/codex_chat/dock.gd").new()
	root.add_child(dock)
	assert(not dock.busy)
	dock.handle_message({"method": "item/agentMessage/delta", "params": {"itemId": "message", "delta": "Streamed reply"}})
	assert(dock.transcript.get_parsed_text().contains("Streamed reply"))
	dock.handle_message({"method": "item/completed", "params": {"item": {"type": "agentMessage", "id": "message", "text": "Streamed reply"}}})
	assert(dock.transcript.get_parsed_text().count("Streamed reply") == 1)
	dock.set_busy(true)
	dock.handle_message({"method": "turn/completed", "params": {"turn": {"status": "failed", "error": {"message": "Expected test error"}}}})
	assert(not dock.busy and dock.transcript.get_parsed_text().contains("Expected test error"))
	dock.handle_message({"id": 80, "method": "item/commandExecution/requestApproval", "params": {"command": "example test command", "reason": "test approval"}})
	assert(dock.active_request.id == 80 and dock.approval.visible)
	dock.answer_request({"decision": "decline"})
	dock.approval.hide()
	assert(dock.active_request.is_empty())
	var canvas = dock.paintover.canvas
	var original := Image.create(100, 80, false, Image.FORMAT_RGBA8)
	original.fill(Color.WHITE)
	canvas.set_image(original)
	canvas.strokes.append({"color": Color.RED, "width": 8.0, "points": PackedVector2Array([Vector2(10,20), Vector2(70,20)])})
	var painted: Image = canvas.painted_image()
	assert(painted.get_pixel(40,20).r > 0.99 and painted.get_pixel(40,20).g < 0.01)
	assert(original.get_pixel(40,20) == Color.WHITE)
	assert(painted.get_pixel(90,70) == Color.WHITE)
	dock.paintover.brush_size.value = 15
	assert(canvas.pen_width == 15)
	canvas.size = Vector2(100,80)
	dock.paintover.sample_button.button_pressed = true
	var sample_event := InputEventMouseButton.new()
	sample_event.button_index = MOUSE_BUTTON_LEFT
	sample_event.pressed = true
	sample_event.position = Vector2(40,20)
	canvas._gui_input(sample_event)
	assert(canvas.pen_color.r > 0.99 and canvas.pen_color.g < 0.01)
	assert(not canvas.sampling and not dock.paintover.sample_button.button_pressed)
	assert(canvas.strokes.size() == 1)
	dock.paintover.choose_color(Color.BLUE)
	assert(canvas.pen_color == Color.BLUE)
	dock.paintover.original_context.text = "Current road markings"
	dock.paintover.painted_context.text = "Red line shows the desired marking"
	dock.paintover.attach_image()
	assert(dock.attachment_paths.size() == 2)
	var original_file := Image.load_from_file(dock.attachment_paths[0])
	var painted_file := Image.load_from_file(dock.attachment_paths[1])
	assert(original_file.get_pixel(40,20) == Color.WHITE)
	assert(painted_file.get_pixel(40,20).g < 0.01)
	assert(str(dock.attachment_contexts[dock.attachment_paths[0]]).contains("Current road markings"))
	assert(str(dock.attachment_contexts[dock.attachment_paths[1]]).contains("Red line shows the desired marking"))
	canvas.undo()
	assert(canvas.painted_image().get_pixel(40,20) == Color.WHITE)
	dock.import_references(PackedStringArray([dock.attachment_paths[0]]))
	assert(dock.attachment_paths.size() == 3)
	var reference: String = dock.attachment_paths[2]
	assert(str(dock.attachment_contexts[reference]).contains("Reference image:"))
	dock.remove_attachment(reference)
	assert(dock.attachment_paths.size() == 2 and not dock.attachment_contexts.has(reference))
	dock.add_attachment(reference, "Reference showing the intended layout")
	var recorded := RecordingBridge.new()
	dock.bridge.free()
	dock.bridge = recorded
	dock.add_child(recorded)
	dock.thread_id = "test-thread"
	dock.queued_prompt = "Please change this area"
	dock.queued_images.assign(dock.attachment_paths)
	dock.queued_contexts = dock.attachment_contexts.duplicate()
	dock.begin_turn()
	var input: Array = recorded.messages[-1].params.input
	assert(input.size() == 7)
	assert(input[1].text.contains("Current road markings") and input[2].type == "localImage")
	assert(input[3].text.contains("Red line shows the desired marking") and input[4].type == "localImage")
	assert(input[2].path.is_absolute_path() and input[4].path.is_absolute_path())
	assert(input[5].text.contains("Reference showing the intended layout") and input[6].type == "localImage")
	print("PAINT-OVER PASS: slider, palette, sampled annotated pixel, stroke rendering, undo, paired images, reference import/removal, and per-image context in turn")
	dock.thread_id = ""
	dock.bridge.free()
	dock.bridge = load("res://addons/codex_chat/bridge.gd").new()
	dock.add_child(dock.bridge)
	dock.bridge.connected.connect(dock.handshake)
	dock.bridge.received.connect(dock.handle_message)
	dock.bridge.failed.connect(dock.connection_failed)
	var received_remote := [0]
	var inbox: Node = load("res://addons/codex_chat/remote_inbox.gd").new()
	inbox.dock = dock
	root.add_child(inbox)
	inbox.prompt_received.connect(func(_text, _images): received_remote[0] += 1)
	dock.bridge.initialized = true
	dock.set_busy(false)
	inbox.last_request = ""
	inbox.enabled = false
	assert(not inbox.accept_request({"id": "test-remote", "action": "prompt", "text": "Test"}))
	inbox.enabled = true
	assert(inbox.accept_request({"id": "test-remote", "action": "prompt", "text": "Test"}))
	assert(not inbox.accept_request({"id": "test-remote", "action": "prompt", "text": "Test"}))
	assert(received_remote[0] == 1)
	dock.set_busy(true)
	assert(not inbox.accept_request({"id": "test-busy", "action": "prompt", "text": "Test"}))
	var interrupted := [false]
	inbox.interrupt_received.connect(func(): interrupted[0] = true)
	assert(inbox.accept_request({"id": "test-stop", "action": "interrupt"}) and interrupted[0])
	inbox.free()
	dock.set_busy(false)
	dock.bridge.initialized = false
	print("REMOTE INBOX PASS: disabled by default, opt-in handoff, duplicate protection, busy guard, interrupt")
	print("CODEX DOCK PASS: loaded, streaming without duplicate final message, error recovery, approval dialog")
	if OS.get_cmdline_user_args().has("--live"):
		dock.bridge.failed.connect(func(message): failure = message)
		dock.executable.text = OS.get_cmdline_user_args()[1]
		dock.connect_server()
		var deadline := Time.get_ticks_msec() + 20000
		while not dock.bridge.initialized and failure.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		assert(failure.is_empty(), failure)
		assert(dock.bridge.initialized, "Live Codex initialization timed out")
		await create_timer(1).timeout
		var options: Dictionary = dock.thread_options()
		options["ephemeral"] = true
		var completed := [false]
		var thread_ok := [false]
		var request_id: int = dock.bridge.request("thread/start", options)
		dock.bridge.received.connect(func(message):
			if message.get("id", -1) == request_id:
				completed[0] = true
				thread_ok[0] = message.has("result") and message.result.has("thread")
				if message.has("error"): push_error(str(message.error.get("message", "Thread error")))
		)
		var thread_deadline := Time.get_ticks_msec() + 10000
		while not completed[0] and Time.get_ticks_msec() < thread_deadline: await process_frame
		if not thread_ok[0]:
			dock.bridge.stop()
			push_error("Live thread configuration failed")
			quit(1)
			return
		print("CODEX LIVE PASS: authenticated local WebSocket and app-server initialization")
	if DisplayServer.get_name() != "headless":
		dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/codex_chat_preview.png")
	# Tests should not replace the user's saved executable or conversation.
	dock.bridge.stop()
	dock.free()
	if had_settings:
		var file := FileAccess.open("res://.godot/codex_chat/settings.cfg", FileAccess.WRITE)
		file.store_buffer(settings_before)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godot/codex_chat/settings.cfg"))
	quit()
