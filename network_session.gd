extends Node

signal status_changed(message: String)
signal lobby_changed
signal chat_received(sender: String, message: String)
signal world_message_received(player_id: int, message: String)
const PORT := 24567
const VERSION := 7
const MAX_PLAYERS := 4
const SCENE := "res://multiplayer_game.tscn"
var active := false
var level: Node
var roster: Dictionary = {}
var pending_ready: Dictionary = {}
var previous_balance := -1
var last_error := ""
var player_name := "Driver"
var joining := false
var join_timeout := 0.0
var last_snapshot: Dictionary = {}
var snapshot_parts: Dictionary = {}
const LEVELS := {"Plaza": "res://multiplayer_game.tscn", "Hilly City": "res://multiplayer_city.tscn"}
const COLORS := [Color("dd4435"), Color("278acf"), Color("35b779"), Color("ffd166"), Color("ae77da"), Color("eeeeee")]
const MESSAGES := ["Hello!", "Ready to roll!", "One moment!", "Let's cook!", "Good luck!", "Nice truck!"]
var selected_level := "Plaza"
var city_size := 1
var original_grid := false
var host_port := PORT

func choose_original_grid(value: bool) -> void:
	if not active or not multiplayer.is_server() or started: return
	original_grid = value
	for id in roster:
		if id != 1: roster[id].ready = false
	receive_original_grid.rpc(value)
	broadcast_roster()
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func receive_original_grid(value: bool) -> void:
	original_grid = value
	lobby_changed.emit()


func choose_city_size(value: int) -> void:
	if not active or not multiplayer.is_server() or started or value not in [0,1]: return
	city_size = value
	for id in roster:
		if id != 1: roster[id].ready = false
	receive_city_size.rpc(value)
	broadcast_roster()
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func receive_city_size(value: int) -> void:
	if value in [0,1]: city_size = value
	lobby_changed.emit()
var started := false
var chat_history: Array = []
var chat_times: Dictionary = {}
var loaded_players: Dictionary = {}

func world_ready() -> bool:
	for id in roster:
		if not loaded_players.has(id): return false
	return active and not roster.is_empty()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(connected)
	multiplayer.connection_failed.connect(func(): fail("Could not connect. Check the host address and UDP port."))
	multiplayer.server_disconnected.connect(func(): fail("The host disconnected. The multiplayer session has ended."))
	multiplayer.peer_disconnected.connect(peer_left)

func start_host(port: int = PORT, nickname: String = "Host") -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1, 3)
	if error != OK:
		last_error = "Could not host on UDP port %d: %s" % [port, error_string(error)]
		status_changed.emit(last_error)
		return error
	begin(peer, nickname)
	host_port = port
	status_changed.emit("Hosting on UDP port %d…" % port)
	register_player(1, player_name)
	open_lobby.call_deferred()
	return OK

func start_join(address: String, port: int = PORT, nickname: String = "Driver") -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port, 3)
	if error != OK:
		last_error = "Could not start connection: " + error_string(error)
		status_changed.emit(last_error)
		return error
	begin(peer, nickname)
	joining = true
	join_timeout = 12.0
	status_changed.emit("Connecting to %s:%d…" % [address, port])
	return OK

func begin(peer: MultiplayerPeer, nickname: String) -> void:
	previous_balance = GameOptions.round_balance
	player_name = nickname.strip_edges().left(24)
	if player_name.is_empty(): player_name = "Driver"
	active = true
	multiplayer.multiplayer_peer = peer

func connected() -> void:
	joining = false
	status_changed.emit("Connected. Entering lobby…")
	open_lobby.call_deferred()

func open_lobby() -> void:
	if active: get_tree().change_scene_to_file("res://lobby_world.tscn")

func set_lobby_options(ready_state: bool, color_index: int) -> void:
	if multiplayer.is_server(): update_lobby_player(1, ready_state, color_index)
	else: lobby_options.rpc_id(1, ready_state, color_index)

@rpc("any_peer", "call_remote", "reliable")
func lobby_options(ready_state: bool, color_index: int) -> void:
	if multiplayer.is_server(): update_lobby_player(multiplayer.get_remote_sender_id(), ready_state, color_index)

func update_lobby_player(id: int, ready_state: bool, color_index: int) -> void:
	if started or not roster.has(id) or color_index < 0 or color_index >= COLORS.size(): return
	roster[id].ready = ready_state if id != 1 else true
	roster[id].color = color_index
	if is_instance_valid(level): level.apply_roster(roster)
	broadcast_roster()
	lobby_changed.emit()

func choose_level(value: String) -> void:
	if not active or not multiplayer.is_server() or started or not LEVELS.has(value): return
	selected_level = value
	for id in roster:
		if id != 1: roster[id].ready = false
	if is_instance_valid(level): level.apply_roster(roster)
	receive_level.rpc(value)
	broadcast_roster()
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func receive_level(value: String) -> void:
	if LEVELS.has(value): selected_level = value
	lobby_changed.emit()

func can_start() -> bool:
	if not active or not multiplayer.is_server() or started or roster.is_empty(): return false
	for id in roster:
		if id != 1 and not roster[id].ready: return false
	return true

func start_session() -> bool:
	if not can_start(): return false
	started = true
	reset_world_stream()
	begin_game.rpc(selected_level)
	load_world.call_deferred()
	return true

@rpc("authority", "call_remote", "reliable")
func begin_game(value: String) -> void:
	if not LEVELS.has(value) or started: return
	selected_level = value
	started = true
	reset_world_stream()
	load_world.call_deferred()

func reset_world_stream() -> void:
	loaded_players.clear()
	last_snapshot.clear()
	snapshot_parts.clear()

func send_chat(message: String) -> void:
	if multiplayer.is_server(): accept_chat(1, message)
	else: submit_chat.rpc_id(1, message)

@rpc("any_peer", "call_remote", "reliable")
func submit_chat(message: String) -> void:
	if multiplayer.is_server(): accept_chat(multiplayer.get_remote_sender_id(), message)

func accept_chat(id: int, message: String) -> void:
	if not active or not roster.has(id): return
	if not message in MESSAGES: return
	var now := Time.get_ticks_msec()
	if now - chat_times.get(id, -1000) < 400: return
	message = message.strip_edges().replace("\n", " ").replace("\r", " ").left(240)
	if message.is_empty(): return
	chat_times[id] = now
	receive_chat(roster[id].name, message)
	receive_chat.rpc(roster[id].name, message)
	receive_world_message(id, message)
	receive_world_message.rpc(id, message)

@rpc("authority", "call_remote", "reliable")
func receive_world_message(id: int, message: String) -> void:
	if roster.has(id) and message in MESSAGES: world_message_received.emit(id, message)

@rpc("authority", "call_remote", "reliable")
func receive_chat(sender: String, message: String) -> void:
	chat_history.append([sender, message])
	if chat_history.size() > 100: chat_history.pop_front()
	chat_received.emit(sender, message)

func load_world() -> void:
	if not active: return
	var success: bool = await LoadingScreen.load_scene(LEVELS[selected_level])
	if not success: fail("Could not load the multiplayer playground.")

func attach_world(world: Node) -> void:
	level = world
	if multiplayer.is_server():
		loaded_players[1] = true
		register_player(1, player_name)
		for id in pending_ready.keys(): register_player(id, pending_ready[id])
		pending_ready.clear()
		level.apply_roster(roster)
	else:
		ready_for_world.rpc_id(1, VERSION, player_name)
		if not roster.is_empty(): level.apply_roster(roster)
		if not last_snapshot.is_empty(): level.apply_snapshot(last_snapshot)

@rpc("any_peer", "call_remote", "reliable")
func ready_for_world(version: int, nickname: String) -> void:
	if not active or not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if version != VERSION:
		rejected.rpc_id(id, "The host and client builds do not match.")
		return
	if roster.has(id):
		loaded_players[id] = true
		return
	if started:
		rejected.rpc_id(id, "This session has already started. Join the next lobby.")
		return
	register_player(id, nickname)
	loaded_players[id] = true
	receive_level.rpc_id(id, selected_level)
	receive_city_size.rpc_id(id, city_size)
	receive_original_grid.rpc_id(id, original_grid)

func register_player(id: int, nickname: String) -> void:
	if roster.size() >= MAX_PLAYERS or roster.has(id): return
	var used: Array = []
	for entry in roster.values(): used.append(entry.slot)
	var slot := 0
	while slot in used: slot += 1
	roster[id] = {"name": nickname.strip_edges().left(24), "slot": slot, "ready": id == 1, "color": slot % COLORS.size()}
	if is_instance_valid(level): level.apply_roster(roster)
	receive_roster.rpc(roster)
	lobby_changed.emit()
	status_changed.emit("%d/%d trucks connected" % [roster.size(), MAX_PLAYERS])

@rpc("authority", "call_remote", "reliable")
func receive_roster(players: Dictionary) -> void:
	roster = players
	lobby_changed.emit()
	if is_instance_valid(level): level.apply_roster(roster)

func peer_left(id: int) -> void:
	pending_ready.erase(id)
	if not active or not multiplayer.is_server(): return
	roster.erase(id)
	loaded_players.erase(id)
	lobby_changed.emit()
	if is_instance_valid(level): level.apply_roster(roster)
	broadcast_roster.call_deferred()

func broadcast_roster() -> void:
	if active and multiplayer.is_server() and not multiplayer.get_peers().is_empty(): receive_roster.rpc(roster)

@rpc("authority", "call_remote", "reliable")
func rejected(message: String) -> void:
	fail(message)

func send_controls(controls: Dictionary) -> void:
	if not active or not is_instance_valid(level): return
	if multiplayer.is_server(): level.receive_controls(1, controls)
	else: driving_input.rpc_id(1, controls)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func driving_input(controls: Dictionary) -> void:
	if active and multiplayer.is_server() and is_instance_valid(level):
		level.receive_controls(multiplayer.get_remote_sender_id(), controls)

func request_action(action: String, argument: int = 0) -> void:
	if not active or not is_instance_valid(level): return
	if multiplayer.is_server(): level.receive_action(1, action, argument)
	else: player_action.rpc_id(1, action, argument)

@rpc("any_peer", "call_remote", "reliable")
func player_action(action: String, argument: int = 0) -> void:
	if active and multiplayer.is_server() and is_instance_valid(level):
		level.receive_action(multiplayer.get_remote_sender_id(), action, argument)

func broadcast_snapshot(snapshot: Dictionary) -> void:
	if not active or not multiplayer.is_server(): return
	var compress_started := Time.get_ticks_usec()
	# Fragment compressed snapshots below the UDP MTU; losing one snapshot is
	# harmless because the next contains the full state again.
	var packed := var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
	var count := ceili(packed.size() / 900.0)
	PerformanceDiagnostics.snapshot_bytes = packed.size()
	PerformanceDiagnostics.snapshot_parts = count
	PerformanceDiagnostics.record_section("Snapshot compress", Time.get_ticks_usec() - compress_started)
	for index in count:
		receive_snapshot_part.rpc(snapshot.sequence, index, count, packed.slice(index * 900, mini((index + 1) * 900, packed.size())))

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_snapshot_part(sequence: int, index: int, count: int, data: PackedByteArray) -> void:
	if sequence <= last_snapshot.get("sequence", 0) or count < 1 or count > 64 or index < 0 or index >= count or data.size() > 900: return
	if not snapshot_parts.has(sequence): snapshot_parts[sequence] = {"count": count, "parts": {}}
	var entry: Dictionary = snapshot_parts[sequence]
	if entry.count != count: return
	entry.parts[index] = data
	if entry.parts.size() == count:
		var decode_started := Time.get_ticks_usec()
		var packed := PackedByteArray()
		for part in count: packed.append_array(entry.parts[part])
		PerformanceDiagnostics.snapshot_bytes = packed.size()
		PerformanceDiagnostics.snapshot_parts = count
		var unpacked := packed.decompress_dynamic(262144, FileAccess.COMPRESSION_DEFLATE)
		var decoded: Variant = bytes_to_var(unpacked)
		if decoded is Dictionary and decoded.get("sequence", 0) == sequence: receive_snapshot(decoded)
		PerformanceDiagnostics.record_section("Snapshot receive", Time.get_ticks_usec() - decode_started)
	for key in snapshot_parts.keys():
		if key <= last_snapshot.get("sequence", 0) or key < sequence - 3: snapshot_parts.erase(key)

func receive_snapshot(snapshot: Dictionary) -> void:
	if snapshot.get("phase", "game") != ("game" if started else "lobby"): return
	last_snapshot = snapshot
	if is_instance_valid(level) and level.lobby_world == not started: level.apply_snapshot(snapshot)

func _process(delta: float) -> void:
	if joining:
		join_timeout -= delta
		if join_timeout <= 0.0: fail("Connection timed out. Check the host address and firewall.")

func fail(message: String) -> void:
	last_error = message
	status_changed.emit(message)
	var in_world := active
	close()
	if in_world:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred("res://main_menu.tscn")

func close() -> void:
	if active:
		active = false
		GameOptions.round_balance = previous_balance
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	joining = false
	level = null
	roster.clear()
	pending_ready.clear()
	last_snapshot.clear()
	snapshot_parts.clear()
	started = false
	selected_level = "Plaza"
	chat_history.clear()
	chat_times.clear()
	loaded_players.clear()

func leave() -> void:
	close()
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://main_menu.tscn")
