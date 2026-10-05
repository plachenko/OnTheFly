extends SceneTree
func _initialize() -> void: verify.call_deferred()
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var config_path := "res://.godot/codex_chat/blender/remote_connection.json"
	var existed := FileAccess.file_exists(config_path)
	var before := FileAccess.get_file_as_bytes(config_path) if existed else PackedByteArray()
	var bridge := preload("res://addons/codex_chat/blender_bridge.gd").new()
	root.add_child(bridge)
	var responses: Array = []
	var errors: Array = []
	bridge.result_received.connect(func(action, data): responses.append({"action": action, "data": data}))
	bridge.failed.connect(func(message): errors.append(message))
	bridge.configure_remote(args[0], args[1])
	bridge.request("inspect")
	var deadline := Time.get_ticks_msec() + 20000
	while responses.is_empty() and errors.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	assert(errors.is_empty(), str(errors))
	assert(responses.size() == 1 and bridge.connected())
	var path := "res://assets/blender_exports/remote_test_%d.glb" % Time.get_ticks_usec()
	bridge.request("export_selected", path.trim_prefix("res://"))
	while responses.size() < 2 and errors.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	assert(errors.is_empty(), str(errors))
	assert(responses.size() == 2 and FileAccess.file_exists(path))
	assert(not responses[1].data.has("glb_base64"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	bridge.configure_remote("", "")
	bridge.free()
	if existed:
		var file := FileAccess.open(config_path, FileAccess.WRITE)
		file.store_buffer(before)
	print("GODOT REMOTE PASS: HTTP pairing, async polling, scene inspection and local GLB transfer")
	quit()
