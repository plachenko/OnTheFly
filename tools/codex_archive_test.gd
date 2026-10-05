extends SceneTree
const Archive = preload("res://addons/codex_chat/conversation_archive.gd")
func _initialize() -> void: verify.call_deferred()
func verify() -> void:
	var id := Archive.new_id()
	var directory := "res://.godot/codex_chat/archive_test_" + id
	var snapshot := {"id": id, "title": "Portable archive", "updated_at": 1, "transcript_source": "**You**\nChange a script\n**Codex**\nDone\n<!--godot-command-group:0-->", "commands": {"0": {"command": "echo hello", "output": null, "running": true}}, "command_groups": {"0": {"commands": ["0"]}}, "file_changes": [{"path": "res://addons/codex_chat/dock.gd", "diff": "@@ -1 +4 @@\n+new line"}]}
	assert(Archive.save(snapshot, false, directory) == OK)
	var loaded := Archive.read(directory.path_join(id + ".json"))
	assert(loaded.schema == Archive.SCHEMA and loaded.file_changes[0].path.begins_with("res://"))
	assert(loaded.commands["0"].output == "" and not loaded.commands["0"].running)
	snapshot.updated_at = 2
	assert(Archive.save(snapshot, false, directory) == OK)
	var records := Archive.list_snapshots([directory])
	assert(records.size() == 1 and records[0].updated_at == 2)
	assert(Archive.save({"id": "../escape"}, true, directory) == ERR_INVALID_PARAMETER)
	var context := Archive.context(loaded)
	assert(context.contains("Done") and context.contains("echo hello") and context.contains("+new line"))
	assert(not context.contains("<!--godot-command"))
	var picker := preload("res://addons/codex_chat/archive_picker.gd").new()
	root.add_child(picker)
	picker.records = records
	picker.chats.add_item("Portable archive")
	picker.select_snapshot(0)
	assert(picker.files.item_count == 1 and picker.preview.get_parsed_text().contains("Done"))
	picker.files.item_selected.emit(0)
	assert(picker.diff.text.contains("+new line"))
	var continued := [false]
	picker.continue_requested.connect(func(value): continued[0] = value.id == id)
	picker.continue_chat()
	assert(continued[0])
	var target := [0]
	picker.file_requested.connect(func(_path, line_number): target[0] = line_number)
	picker.open_selected_file(0)
	assert(target[0] == 4)
	if DisplayServer.get_name() != "headless":
		root.gui_embed_subwindows = true
		picker.popup_centered(Vector2i(800, 650))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/codex_archive_preview.png")
	picker.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(id + ".json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join("README.md")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("ARCHIVE PASS: atomic snapshots, portable diffs, safe filenames, context continuation and browser")
	quit()
