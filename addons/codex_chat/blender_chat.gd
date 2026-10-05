@tool
extends Node
var dock: Control
var http: HTTPRequest
var elapsed := 0.0
var polling := false
var active_id := ""
var last_id := ""
var phase := ""
const ROOT := "res://.godot/codex_chat/blender"

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 3
	add_child(http)
	http.request_completed.connect(completed)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 1.0 or polling or dock == null: return
	elapsed = 0.0
	if dock.blender_bridge.remote_url.is_empty():
		if not dock.blender_bridge.connected(): return
		var path := ROOT + "/chat_request.json"
		if FileAccess.file_exists(path):
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if value is Dictionary: accept(value)
		write_status()
	else:
		phase = "get"
		send(HTTPClient.METHOD_GET, "/chat")

func send(method: HTTPClient.Method, endpoint: String, body: String = "") -> void:
	polling = true
	var error := http.request(dock.blender_bridge.remote_url + endpoint, PackedStringArray(["Authorization: Bearer " + dock.blender_bridge.remote_token, "Content-Type: application/json"]), method, body)
	if error != OK: polling = false

func completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	polling = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200: return
	if phase == "get":
		var value: Variant = JSON.parse_string(body.get_string_from_utf8())
		if value is Dictionary: accept(value)
		phase = "status"
		send(HTTPClient.METHOD_POST, "/chat/status", JSON.stringify(snapshot()))

func accept(value: Dictionary) -> void:
	var id := str(value.get("id", ""))
	var text := str(value.get("text", "")).strip_edges()
	if Time.get_unix_time_from_system() - float(value.get("created", 0)) > 120: return
	if id.is_empty() or id == last_id or text.is_empty() or text.length() > 10000: return
	if dock.busy or not dock.bridge.initialized: return
	last_id = id
	active_id = id
	dock.blender_bridge.scene_data = value.get("scene", {})
	dock.submit_or_queue({"text": text, "images": [], "contexts": {}, "dictated": false})

func snapshot() -> Dictionary:
	return {"id": active_id, "busy": dock.busy, "connected": dock.bridge.initialized, "status": dock.status.text, "response": dock.latest_reply if not active_id.is_empty() else ""}

func write_status() -> void:
	var file := FileAccess.open(ROOT + "/chat_status.json.tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(ROOT + "/chat_status.json.tmp"), ProjectSettings.globalize_path(ROOT + "/chat_status.json"))
