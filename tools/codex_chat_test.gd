@tool
extends SceneTree
var dock
var failure := ""
var settings_before: PackedByteArray
var had_settings := false
var profile_settings_before: PackedByteArray
var had_profile_settings := false
class RecordingBridge extends "res://addons/codex_chat/bridge.gd":
	var messages: Array[Dictionary] = []
	var started_executable := ""
	func start(path: String) -> void: started_executable = path
	func send(message: Dictionary) -> void: messages.append(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var profile_path := "res://.godot/codex_chat/profiling/settings.json"
	had_profile_settings = FileAccess.file_exists(profile_path)
	if had_profile_settings: profile_settings_before = FileAccess.get_file_as_bytes(profile_path)
	had_settings = FileAccess.file_exists("res://.godot/codex_chat/settings.cfg")
	if had_settings: settings_before = FileAccess.get_file_as_bytes("res://.godot/codex_chat/settings.cfg")
	var isolated_settings := ConfigFile.new()
	isolated_settings.load("res://.godot/codex_chat/settings.cfg")
	isolated_settings.set_value("archive", "enabled", false)
	isolated_settings.set_value("connection", "auto_connect", false)
	isolated_settings.set_value("blender", "remote", false)
	isolated_settings.save("res://.godot/codex_chat/test_settings.cfg")
	dock = load("res://addons/codex_chat/dock.gd").new()
	dock.state_path = "res://.godot/codex_chat/test_settings.cfg"
	root.add_child(dock)
	assert(not dock.busy)
	dock.handle_message({"method": "item/agentMessage/delta", "params": {"itemId": "message", "delta": "Streamed reply"}})
	dock.render_transcript()
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
	recorded.initialized = true
	dock.set_busy(false)
	dock.list_project_chats("")
	assert(recorded.messages[-1].method == "thread/list")
	assert(recorded.messages[-1].params.cwd.size() == 2)
	dock.handle_message({"id": recorded.messages[-1].id, "result": {"data": [{"id": "existing", "name": "Project performance", "cwd": "test"}], "nextCursor": "page2"}})
	assert(dock.history_picker.chats.item_count == 1 and dock.history_picker.next_cursor == "page2")
	dock.select_project_history("existing", false)
	var history := {"id": "existing", "turns": [{"items": [{"type": "userMessage", "content": [{"type": "text", "text": "Simplify patrons"}]}, {"type": "agentMessage", "text": "Three building entrances implemented"}]}]}
	dock.handle_message({"id": recorded.messages[-1].id, "result": {"thread": history}})
	assert(dock.thread_id == "test-thread" and dock.imported_history.contains("Simplify patrons"))
	dock.prompt.text = "Continue profiling"
	dock.send_prompt()
	assert(recorded.messages[-1].params.input[0].text.contains("Three building entrances implemented"))
	assert(dock.imported_history.is_empty())
	dock.set_busy(false)
	dock.select_project_history("existing", true)
	dock.handle_message({"id": recorded.messages[-1].id, "result": {"thread": {"id": "existing", "status": {"type": "active"}}}})
	assert(not dock.busy and dock.thread_id == "test-thread")
	dock.select_project_history("existing", true)
	dock.handle_message({"id": recorded.messages[-1].id, "result": {"thread": {"id": "existing", "status": {"type": "idle"}}}})
	assert(recorded.messages[-1].method == "thread/resume")
	dock.handle_message({"id": recorded.messages[-1].id, "error": {"message": "History format unsupported"}})
	assert(not dock.busy and dock.thread_id == "test-thread")
	dock.select_project_history("existing", true)
	dock.handle_message({"id": recorded.messages[-1].id, "result": {"thread": {"id": "existing", "status": {"type": "idle"}}}})
	dock.handle_message({"id": recorded.messages[-1].id, "result": {"thread": history}})
	assert(dock.thread_id == "existing" and dock.transcript.get_parsed_text().contains("Simplify patrons"))
	print("PROJECT HISTORY PASS: project scopes, pagination, imported context in prompt, active guard, failed resume preserves chat, successful resume")
	dock.prompt.text = "Unsent draft"
	dock.add_attachment(reference, "Preserve this reference")
	var attachment_count: int = dock.attachment_paths.size()
	dock.set_busy(false)
	dock.send_profile_report({"id": "profile-test", "mode": "snap", "frames": [[0, 25]], "context": "Standing still"})
	assert(dock.prompt.text == "Unsent draft" and dock.attachment_paths.size() == attachment_count)
	assert(recorded.messages[-1].params.input.size() == 1)
	assert(recorded.messages[-1].params.input[0].text.contains("Standing still"))
	dock.set_busy(false)
	dock.termux_mode.button_pressed = true
	dock.executable.text = OS.get_executable_path()
	dock.connect_windows()
	assert(not dock.termux_mode.button_pressed)
	assert(recorded.started_executable != OS.get_executable_path())
	assert(not dock.executable.text.get_file().to_lower().contains("godot"))
	print("PROFILE/WINDOWS PASS: structured context, preserved draft/attachments, local Windows selection overrides Termux")
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
	dock.update_command({"id": "command-ui-test", "command": "echo example", "aggregatedOutput": null}, true)
	var command_key: String = dock.command_items["command-ui-test"]
	dock.render_transcript()
	assert(dock.transcript.get_parsed_text().contains("Running"))
	assert(not dock.transcript.get_parsed_text().contains("echo example"))
	dock.update_command({"id": "second-command-ui-test", "command": "echo second"}, false)
	dock.render_transcript()
	assert(dock.transcript.get_parsed_text().contains("Commands (2)"))
	assert(not dock.transcript.get_parsed_text().contains("Copy command"))
	dock.transcript_link("command-group:" + dock.active_command_group)
	assert(dock.transcript.get_parsed_text().contains("Copy command"))
	assert(not dock.transcript.get_parsed_text().contains("echo second"))
	var spinner_before: int = dock.spinner_frame
	for tick in 6:
		dock.transcript_dirty = true
		dock._process(0.1)
	assert(dock.spinner_frame > spinner_before)
	dock.transcript_link("command:toggle:" + command_key)
	assert(dock.transcript.get_parsed_text().contains("echo example"))
	dock.handle_message({"method": "item/commandExecution/outputDelta", "params": {"itemId": "command-ui-test", "delta": "example output"}})
	dock.update_command({"id": "command-ui-test", "command": "echo example", "aggregatedOutput": null, "status": "completed", "exitCode": 0}, false)
	dock.render_transcript()
	assert(dock.transcript.get_parsed_text().contains("example output"))
	assert(dock.transcript.get_parsed_text().contains("exit 0"))
	assert(not dock.command_entries[command_key].running)
	print("COMMAND UI PASS: collapsed commands, expansion, streamed output and completion")
	var follow := preload("res://addons/codex_chat/auto_drive.gd")
	assert(follow.changed_line("@@ -4,3 +8,4 @@\n context\n+new line\n context") == 9)
	assert(follow.changed_line("@@ -0,0 +1,2 @@\n+new file") == 1)
	assert(follow.project_path("addons/codex_chat/dock.gd") == "res://addons/codex_chat/dock.gd")
	assert(follow.project_path("../outside.gd").is_empty())
	dock.auto_drive.set_enabled(false)
	dock.auto_drive.queue_change({"path": "addons/codex_chat/dock.gd", "diff": "@@ -1 +3 @@\n+change"})
	assert(dock.auto_drive.pending_change.is_empty())
	dock.auto_drive.set_enabled(true)
	dock.auto_drive.queue_change({"path": "addons/codex_chat/dock.gd", "diff": "@@ -1 +3 @@\n+change"})
	assert(dock.auto_drive.pending_change.line == 3)
	dock.auto_drive.set_enabled(false)
	print("AUTO DRIVE PASS: changed lines, project paths, opt-in and queued navigation")
	dock.changed_file_link({"path": "addons/codex_chat/dock.gd", "diff": "@@ -1 +7 @@\n+change"})
	assert(dock.transcript.text.contains("[url=godot-file:"))
	assert(dock.transcript.text.contains("#7]addons/codex_chat/dock.gd[/url]"))
	assert(not dock.auto_drive.enabled)
	print("FILE LINK PASS: clickable project file with changed-line target")
	dock.bridge.initialized = true
	dock.sync_connection_controls()
	dock.auto_refresh_toggle.button_pressed = false
	assert(dock.refresh_button.visible)
	assert(dock.send_button.get_parent() == dock.prompt.get_parent())
	assert(dock.mic_button.get_parent() == dock.prompt.get_parent())
	dock.auto_refresh_toggle.button_pressed = true
	assert(not dock.refresh_button.visible and dock.refresh_pending)
	dock._process(0.5)
	assert(not dock.refresh_pending)
	dock.handle_message({"method": "item/completed", "params": {"item": {"type": "fileChange", "changes": []}}})
	assert(dock.refresh_pending)
	dock.auto_refresh_toggle.button_pressed = false
	assert(dock.refresh_button.visible and not dock.refresh_pending)
	print("REFRESH UI PASS: manual footer button, auto visibility and file-change refresh")
	var previous_draft: String = dock.prompt.text
	dock.dictation.transcribed.emit("test dictation")
	assert(dock.prompt.text.ends_with("test dictation"))
	assert(dock.prompt.text.begins_with(previous_draft))
	dock.dictation.recording = true
	dock.dictation.state_changed.emit()
	assert(dock.mic_button.text == "Transcribe" and dock.cancel_dictation_button.visible)
	dock.dictation.cancel()
	assert(dock.mic_button.text == "Mic" and not dock.cancel_dictation_button.visible)
	dock.prompt.text = previous_draft
	print("DICTATION UI PASS: preserved draft, record controls and cancellation")
	dock.new_chat()
	dock.archive_shared_toggle.set_pressed_no_signal(false)
	dock.line("You", "Archive test conversation")
	dock.record_archive_change({"path": "addons/codex_chat/dock.gd", "diff": "@@ -1 +4 @@\n+archive test"}, "archive-test-item")
	dock.record_archive_change({"path": "addons/codex_chat/dock.gd", "diff": "@@ -1 +4 @@\n+archive test"}, "archive-test-item")
	assert(dock.archive_changes.size() == 1)
	dock.archive_toggle.button_pressed = true
	var saved_archive_path: String = dock.Archive.LOCAL.path_join(dock.archive_id + ".json")
	var archived: Dictionary = dock.Archive.read(saved_archive_path)
	assert(archived.title == "Archive test conversation" and archived.file_changes.size() == 1)
	dock.archive_toggle.button_pressed = false
	dock.set_busy(true)
	var prior_thread: String = dock.thread_id
	dock.continue_archive(archived)
	assert(dock.thread_id == prior_thread)
	dock.set_busy(false)
	var kept_draft: String = dock.prompt.text
	dock.continue_archive(archived)
	assert(dock.thread_id.is_empty() and dock.archive_parent == archived.id)
	assert(dock.imported_history.contains("+archive test") and dock.prompt.text == kept_draft)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_archive_path))
	print("ARCHIVE UI PASS: opt-in snapshot, diff deduplication, busy guard and portable continuation")
	dock.bridge.initialized = false
	dock.sync_connection_controls()
	assert(not dock.composer.visible and not dock.refresh_button.visible and not dock.new_button.visible)
	assert(dock.connect_button.visible and dock.settings_button.visible)
	dock.bridge.initialized = true
	dock.set_busy(true)
	var send_size: Vector2 = dock.send_button.custom_minimum_size
	assert(send_size == dock.stop_button.custom_minimum_size)
	var spinner_start: int = dock.spinner_frame
	dock._process(0.2)
	assert(dock.spinner_frame > spinner_start)
	dock.set_busy(false)
	assert(dock.send_button.visible and not dock.stop_button.visible and dock.send_button.text == "↵")
	assert(dock.text_zoom_label.get_parent() != dock.send_button.get_parent())
	print("COMPOSER PASS: disconnected controls, stable send/stop size and working spinner")
	dock.bridge.stop()
	dock.bridge.free()
	var interaction_bridge := RecordingBridge.new()
	dock.bridge = interaction_bridge
	dock.add_child(interaction_bridge)
	interaction_bridge.initialized = true
	dock.thread_id = "interaction-test"
	dock.turn_id = "running-test"
	dock.set_busy(true)
	assert(dock.interrupt_prompt_button.visible and not dock.prompt.visible)
	dock.interrupt()
	assert(dock.prompt.visible and not dock.interrupt_prompt_button.visible)
	assert(interaction_bridge.messages[-1].method == "turn/interrupt")
	dock.prompt.text = "Queued follow-up"
	dock.send_prompt()
	assert(dock.message_queue.size() == 1 and dock.prompt.text.is_empty())
	dock.set_busy(false)
	dock.send_next_queued()
	assert(dock.message_queue.is_empty() and interaction_bridge.messages[-1].method == "turn/start")
	dock.interrupt_requested = true
	dock.handle_message({"id": interaction_bridge.messages[-1].id, "result": {"turn": {"id": "late-turn"}}})
	assert(interaction_bridge.messages[-1].method == "turn/interrupt")
	dock.offer_yes_no("Would you like me to continue?")
	assert(dock.yes_button.visible and dock.no_button.visible)
	dock.set_busy(false)
	dock.quick_reply("No")
	assert(interaction_bridge.messages[-1].params.input[0].text.begins_with("No"))
	dock.set_busy(false)
	assert(dock.stop_button.text.ends_with("Stop"))
	print("INTERACTION PASS: interrupt restores prompt, queued follow-up, late turn interrupt and quick replies")
	if DisplayServer.get_name() != "headless":
		dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/codex_chat_preview.png")
	# Tests should not replace the user's saved executable or conversation.
	dock.bridge.stop()
	dock.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godot/codex_chat/test_settings.cfg"))
	if had_settings:
		var file := FileAccess.open("res://.godot/codex_chat/settings.cfg", FileAccess.WRITE)
		file.store_buffer(settings_before)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godot/codex_chat/settings.cfg"))
	if had_profile_settings:
		var profile_file := FileAccess.open(profile_path, FileAccess.WRITE)
		profile_file.store_buffer(profile_settings_before)
		profile_file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	quit()
