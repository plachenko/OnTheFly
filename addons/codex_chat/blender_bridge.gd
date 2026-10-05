@tool
extends Node
signal result_received(action: String, result: Dictionary)
signal failed(message: String)
const DIRECTORY := "res://.godot/codex_chat/blender"
var remote_url := ""
var remote_token := ""
var remote_ready := false
var http: HTTPRequest
var remote_job := ""
var remote_polling := false
var pending: Dictionary = {}

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 10
	http.body_size_limit = 100 * 1024 * 1024
	add_child(http)
	http.request_completed.connect(remote_completed)

func configure_remote(url: String, token: String) -> void:
	if http != null: http.cancel_request()
	pending.clear()
	remote_job = ""
	remote_polling = false
	remote_ready = false
	scene_data.clear()
	remote_url = url.strip_edges().trim_suffix("/")
	remote_token = token.strip_edges()
	var path := DIRECTORY + "/remote_connection.json"
	if remote_url.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"url": remote_url, "token": remote_token}))

func remote_send(method: HTTPClient.Method, endpoint: String, body: String = "") -> void:
	remote_polling = true
	var error := http.request(remote_url + endpoint, PackedStringArray(["Authorization: Bearer " + remote_token, "Content-Type: application/json"]), method, body)
	if error != OK:
		remote_error(error_string(error))

func remote_error(message: String) -> void:
	remote_ready = false
	remote_polling = false
	pending.clear()
	remote_job = ""
	failed.emit(message)

func remote_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	remote_polling = false
	if pending.is_empty(): return
	if result != HTTPRequest.RESULT_SUCCESS or body.is_empty():
		remote_error("Remote Blender connection failed. Check the address, port and firewall.")
		return
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or not value is Dictionary:
		remote_error("Remote Blender connection failed. Check the address, port and firewall.")
		return
	if code == 202:
		if value.has("id"): remote_job = str(value.id)
		return
	if code != 200 or not value.get("ok", false):
		remote_error(str(value.get("error", "Remote Blender request failed")))
		return
	var action := str(pending.action)
	var data: Dictionary = value.get("result", {})
	if action == "export_selected":
		var path := preload("res://addons/codex_chat/auto_drive.gd").project_path(str(pending.path))
		var bytes := Marshalls.base64_to_raw(str(data.get("glb_base64", "")))
		if not path.begins_with("res://assets/") or path.get_extension() != "glb" or FileAccess.file_exists(path) or bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
			remote_error("Invalid export or target file already exists.")
			return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		if file == null:
			remote_error("Could not save the transferred GLB.")
			return
		file.store_buffer(bytes)
		file.close()
		var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
		if error != OK:
			remote_error(error_string(error))
			return
		data.erase("glb_base64")
		data.path = path.trim_prefix("res://")
	pending.clear()
	remote_job = ""
	remote_ready = true
	if action == "inspect": scene_data = data
	result_received.emit(action, data)
var elapsed := 0.0
var scene_data: Dictionary = {}

func connected() -> bool:
	if not remote_url.is_empty(): return remote_ready
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/status.json")) if FileAccess.file_exists(DIRECTORY + "/status.json") else null
	return value is Dictionary and absf(Time.get_unix_time_from_system() - float(value.get("updated_at", 0))) < 5.0

func request(action: String, path: String = "") -> void:
	if not remote_url.is_empty():
		if not pending.is_empty():
			failed.emit("Wait for the current Blender request to finish.")
			return
		if not remote_url.begins_with("http://") and not remote_url.begins_with("https://"):
			failed.emit("Enter a Blender HTTP address, such as http://192.168.1.10:45002")
			return
		if remote_token.is_empty():
			failed.emit("Enter the pairing token shown in Blender.")
			return
		pending = {"action": action, "path": path, "started": Time.get_unix_time_from_system()}
		remote_send(HTTPClient.METHOD_POST, "/request", JSON.stringify({"action": action, "path": path}))
		return
	if not connected():
		failed.emit("Start the Blender bridge in Blender's Codex sidebar with this Godot project selected.")
		return
	if not pending.is_empty():
		failed.emit("Wait for the current Blender request to finish.")
		return
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	var filename := DIRECTORY + "/requests/" + id + ".json"
	var file := FileAccess.open(filename + ".tmp", FileAccess.WRITE)
	if file == null:
		failed.emit("Could not write a Blender request.")
		return
	file.store_string(JSON.stringify({"action": action, "path": path}))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(filename + ".tmp"), ProjectSettings.globalize_path(filename))
	if error != OK:
		failed.emit(error_string(error))
		return
	pending = {"id": id, "action": action, "started": Time.get_unix_time_from_system()}

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.25 or pending.is_empty(): return
	elapsed = 0.0
	if not remote_url.is_empty():
		if Time.get_unix_time_from_system() - float(pending.started) > 60:
			http.cancel_request()
			remote_error("Remote Blender request timed out. An export may still finish on the host.")
		elif not remote_polling and not remote_job.is_empty():
			remote_send(HTTPClient.METHOD_GET, "/response/" + remote_job)
		return
	var path := DIRECTORY + "/responses/" + str(pending.id) + ".json"
	if FileAccess.file_exists(path):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var action := str(pending.action)
		pending.clear()
		if not value is Dictionary or not value.get("ok", false):
			failed.emit(str(value.get("error", "Invalid Blender response")) if value is Dictionary else "Invalid Blender response")
			return
		var result: Dictionary = value.get("result", {})
		if action == "inspect": scene_data = result
		result_received.emit(action, result)
	elif Time.get_unix_time_from_system() - float(pending.started) > 30:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIRECTORY + "/requests/" + str(pending.id) + ".json"))
		pending.clear()
		failed.emit("Blender request timed out. A started export may still finish.")
