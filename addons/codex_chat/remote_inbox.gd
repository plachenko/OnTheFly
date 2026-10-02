@tool
extends Node
signal prompt_received(text: String, references: PackedStringArray)
signal interrupt_received
signal refresh_received
var enabled := false
var dock: Control
var elapsed := 0.0
var last_request := ""
var active_request := ""
const DIRECTORY := "res://.godot/codex_chat/remote"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/status.json")) if FileAccess.file_exists(DIRECTORY + "/status.json") else null
	if previous is Dictionary: last_request = str(previous.get("last_request", ""))
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 1.0 or dock == null: return
	elapsed = 0
	poll()
func poll() -> void:
	if enabled and not dock.busy and dock.bridge.initialized and FileAccess.file_exists(DIRECTORY + "/request.json"):
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/request.json"))
		if request is Dictionary: accept_request(request)
	# Stop can be requested even while a turn is active.
	elif enabled and dock.busy and FileAccess.file_exists(DIRECTORY + "/request.json"):
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/request.json"))
		if request is Dictionary and request.get("action") == "interrupt": accept_request(request)
	publish_status()
func accept_request(request: Dictionary) -> bool:
	var id := str(request.get("id", "")).strip_edges()
	if not enabled or id.is_empty() or id == last_request: return false
	var action := str(request.get("action", ""))
	if action == "prompt":
		var text := str(request.get("text", "")).strip_edges()
		if text.is_empty() or text.length() > 100000 or dock.busy or not dock.bridge.initialized: return false
		var references := PackedStringArray()
		var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/") + "/"
		for path in request.get("images", []):
			var full := str(path).replace("\\", "/").simplify_path()
			if full.is_absolute_path() and full.begins_with(project) and FileAccess.file_exists(full): references.append(full)
		last_request = id
		active_request = id
		# Acknowledge before handing off, so retries cannot create duplicate turns.
		publish_status()
		prompt_received.emit(text, references)
	elif action == "interrupt":
		last_request = id
		interrupt_received.emit()
	elif action == "refresh":
		last_request = id
		refresh_received.emit()
	else: return false
	return true
func publish_status() -> void:
	if dock == null: return
	var scene: Node = dock.editor.get_edited_scene_root() if dock.editor != null else null
	var state := {"enabled": enabled, "connected": dock.bridge.initialized, "busy": dock.busy, "last_request": last_request, "active_request": active_request, "thread_id": dock.thread_id, "status": dock.status.text, "transcript": dock.transcript.get_parsed_text().right(100000), "scene": scene.scene_file_path if scene != null else "", "editor_context": dock.scene_context(), "updated_at": Time.get_datetime_string_from_system(true), "request_file": ProjectSettings.globalize_path(DIRECTORY + "/request.json")}
	var path := DIRECTORY + "/status.json"
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state, "  "))
		file.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
