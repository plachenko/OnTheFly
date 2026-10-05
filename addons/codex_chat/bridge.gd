@tool
extends Node
signal connected
signal received(message: Dictionary)
signal failed(message: String)
var socket: WebSocketPeer
var pid := -1
var port := 0
var deadline := 0
var retry_at := 0
var opened := false
var sequence := 0
var token := ""
var token_path := ""
var initialized := false
var external_connection := false
var connection_url := ""

static func find_codex() -> String:
	var executable := "codex.exe" if OS.get_name() == "Windows" else "codex"
	for directory in OS.get_environment("PATH").split(";" if OS.get_name() == "Windows" else ":"):
		var candidate := directory.path_join(executable)
		if FileAccess.file_exists(candidate): return candidate
	var bundled := OS.get_environment("LOCALAPPDATA").path_join("OpenAI/Codex/bin")
	if DirAccess.dir_exists_absolute(bundled):
		var versions := DirAccess.get_directories_at(bundled)
		versions.reverse()
		for version in versions:
			var candidate := bundled.path_join(version).path_join("codex.exe")
			if FileAccess.file_exists(candidate): return candidate
	# Microsoft Store desktop distributions bundle the CLI in the app package.
	if OS.get_name() == "Windows":
		var packages := OS.get_environment("ProgramFiles").path_join("WindowsApps")
		var installed := DirAccess.get_directories_at(packages)
		installed.reverse()
		for package in installed:
			if not package.begins_with("OpenAI.Codex_"): continue
			for relative in ["app/resources/codex.exe", "app/resources/bin/codex.exe", "resources/codex.exe"]:
				var candidate := packages.path_join(package).path_join(relative)
				if FileAccess.file_exists(candidate): return candidate
	return ""

func start(executable: String) -> void:
	stop()
	if executable.get_file().to_lower().contains("godot"):
		failed.emit("The selected executable is Godot. Select codex.exe in Settings, then reconnect.")
		return
	if not FileAccess.file_exists(executable):
		failed.emit("Select your Codex executable in Settings.")
		return
	var probe := TCPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		failed.emit("Could not reserve a local port.")
		return
	port = probe.get_local_port()
	probe.stop()
	token = Crypto.new().generate_random_bytes(32).hex_encode()
	var directory := ProjectSettings.globalize_path("res://.godot/codex_chat")
	DirAccess.make_dir_recursive_absolute(directory)
	token_path = directory.path_join("token_%s" % token.substr(0, 12))
	var file := FileAccess.open(token_path, FileAccess.WRITE)
	if file == null:
		failed.emit("Could not create the local connection token.")
		return
	file.store_string(token)
	file.close()
	pid = OS.create_process(executable, ["app-server", "--listen", "ws://127.0.0.1:%d" % port, "--ws-auth", "capability-token", "--ws-token-file", token_path], false)
	if pid < 0:
		stop()
		failed.emit("Could not launch Codex.")
		return
	connection_url = "ws://127.0.0.1:%d" % port
	deadline = Time.get_ticks_msec() + 15000
	retry_at = 0
	set_process(true)

func connect_existing(url: String, credential: String) -> void:
	stop()
	if not url.begins_with("ws://127.0.0.1:") or credential.is_empty():
		failed.emit("Pair with the local Termux helper first.")
		return
	external_connection = true
	connection_url = url
	token = credential
	deadline = Time.get_ticks_msec() + 15000
	retry_at = 0
	set_process(true)

func _process(_delta: float) -> void:
	if pid < 0 and not external_connection: return
	if not opened and Time.get_ticks_msec() > deadline:
		stop()
		failed.emit("Codex did not connect. Check the executable and CLI login; reconnect to retry.")
		return
	if socket == null:
		if Time.get_ticks_msec() < retry_at: return
		socket = WebSocketPeer.new()
		socket.inbound_buffer_size = 16 * 1024 * 1024
		socket.outbound_buffer_size = 16 * 1024 * 1024
		socket.handshake_headers = PackedStringArray(["Authorization: Bearer " + token])
		socket.connect_to_url(connection_url)
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not opened:
			opened = true
			connected.emit()
		while socket.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if parsed is Dictionary:
				if parsed.get("id") is float: parsed.id = int(parsed.id)
				received.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED:
		socket = null
		if opened:
			stop()
			failed.emit("Codex disconnected. Reconnect to continue.")
		else: retry_at = Time.get_ticks_msec() + 250

func send(message: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))
func request(method: String, params: Dictionary = {}) -> int:
	sequence += 1
	send({"id": sequence, "method": method, "params": params})
	return sequence
func stop() -> void:
	set_process(false)
	if socket != null: socket.close()
	socket = null
	if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	pid = -1
	opened = false
	initialized = false
	external_connection = false
	connection_url = ""
	if not token_path.is_empty(): DirAccess.remove_absolute(token_path)
	token = ""
	token_path = ""
