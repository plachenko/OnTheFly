extends "res://game.gd"

const ECONOMY := ["money", "money_earned", "ingredients", "remaining_time", "round_finished", "round_won", "total_pad_fees", "starting_luck", "carried_balance"]
const ANALOG := ["accelerate", "reverse", "left", "right", "brake", "boost"]
const EDGES := ["serve", "reset", "truck_headlights", "truck_hazard", "truck_signal_left", "truck_signal_right"]
const VEHICLE := ["speed", "velocity", "steer", "rolling", "health", "opening", "deployed", "round_over", "headlights_on", "turn_signal", "hazards_on", "boost_fuel", "booster_owned", "drift_owned", "lift_owned", "armor_owned", "fsd_owned", "fsd_enabled", "message", "message_timer", "corner_load"]
var trucks: Dictionary = {}
var accounts: Dictionary = {}
var incoming: Dictionary = {}
var received_at: Dictionary = {}
var targets: Dictionary = {}
var active_player := 0
var local_player := 0
var local_truck: CharacterBody3D
var input_timer := 0.0
var snapshot_timer := 0.0
var sequence_number := 0
var online_label: Label
var patron_serial := 0
@export var lobby_world := false
var snapshot_props: Array = []
var snapshot_breakables: Array = []

func _ready() -> void:
	await super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	local_player = multiplayer.get_unique_id()
	active_player = local_player
	local_truck = truck
	local_truck.network_controlled = true
	local_truck.set_physics_process(false)
	local_truck.visible = false
	if not multiplayer.is_server():
		for body in find_children("*", "RigidBody3D", true, false):
			body.freeze = true
			body.set_physics_process(false)
	snapshot_props = find_children("*", "RigidBody3D", true, false)
	snapshot_breakables = find_children("BoostBreakable", "Node3D", true, false)
	# Multiplayer keeps sessions separate from the offline save balance.
	money = starting_money
	carried_balance = false
	var online_panel := PanelContainer.new()
	online_panel.position = Vector2(22, 410)
	online_panel.custom_minimum_size = Vector2(310, 110)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.065, 0.075, 0.94)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	online_panel.add_theme_stylebox_override("panel", style)
	$HUD.add_child(online_panel)
	var online_rows := VBoxContainer.new()
	online_panel.add_child(online_rows)
	online_label = Label.new()
	online_label.add_theme_font_size_override("font_size", 16)
	online_label.add_theme_color_override("font_color", Color("ffe4a0"))
	online_rows.add_child(online_label)
	var leave := Button.new()
	leave.text = "Leave session"
	leave.custom_minimum_size.y = 32
	leave.pressed.connect(NetworkSession.leave)
	online_rows.add_child(leave)
	NetworkSession.attach_world(self)

func save_account() -> void:
	if not accounts.has(active_player): return
	for field in ECONOMY: accounts[active_player][field] = get(field)
	accounts[active_player]["last_sale"] = $PatronManager.last_sale
	accounts[active_player]["served_orders"] = $PatronManager.served_orders

func apply_truck_color(body: Node3D, index: int) -> void:
	var tint: Color = NetworkSession.COLORS[clampi(index, 0, NetworkSession.COLORS.size() - 1)]
	for mesh in body.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(surface)
			if original is StandardMaterial3D and "teal" in original.resource_name.to_lower():
				var paint := original.duplicate() as StandardMaterial3D
				paint.albedo_color = tint
				mesh.set_surface_override_material(surface, paint)

func select_player(id: int) -> int:
	var previous := active_player
	save_account()
	if not accounts.has(id): return previous
	active_player = id
	truck = trucks[id]
	for field in ECONOMY: set(field, accounts[id][field])
	$PatronManager.last_sale = accounts[id].get("last_sale", "No orders yet.")
	$PatronManager.served_orders = accounts[id].get("served_orders", 0)
	return previous

func apply_roster(roster: Dictionary) -> void:
	var roster_changed := false
	for id in trucks.keys():
		if not roster.has(id):
			roster_changed = true
			for patron in $Patrons.get_children():
				if patron.get_meta("player_id", 0) == id: patron.cancel_order()
			trucks[id].queue_free()
			trucks.erase(id)
			accounts.erase(id)
			incoming.erase(id)
			targets.erase(id)
	for id in roster:
		if trucks.has(id):
			apply_truck_color(trucks[id], roster[id].get("color", 0))
			continue
		roster_changed = true
		var body: CharacterBody3D = local_truck if id == local_player else preload("res://scenes/truck.tscn").instantiate()
		if id != local_player:
			body.name = "Truck_%d" % id
			add_child(body)
		body.network_controlled = true
		body.set_meta("player_id", id)
		body.set_physics_process(false)
		body.vibration_enabled = id == local_player
		var pad: Node3D = $ParkingPads.get_child(roster[id].slot)
		body.global_position = Vector3(pad.global_position.x, local_truck.spawn_transform.origin.y, pad.global_position.z)
		if has_node("ProceduralCity"):
			body.position.y = $ProceduralCity.height_at(body.position.x, body.position.z) + 0.2
		body.rotation.y = pad.global_rotation.y
		body.spawn_transform = body.global_transform
		body.travel_heading = body.rotation.y
		body.parking_pad = pad
		body.visible = true
		apply_truck_color(body, roster[id].get("color", roster[id].slot % NetworkSession.COLORS.size()))
		var caption := Label3D.new()
		caption.name = "PlayerName"
		caption.text = roster[id].name
		caption.position = Vector3(0, 4.8, 0)
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.font_size = 40
		caption.modulate = Color("ffe4a0") if id == local_player else Color("71e4e4")
		body.add_child(caption)
		trucks[id] = body
		accounts[id] = {"money": starting_money, "money_earned": 0, "ingredients": starting_ingredients, "remaining_time": level_duration_seconds, "round_finished": false, "round_won": false, "total_pad_fees": 0, "starting_luck": 0, "carried_balance": false, "last_sale": "No orders yet.", "served_orders": 0}
		incoming[id] = {}
	if accounts.has(local_player): select_player(local_player)
	if roster_changed: camera_started = false

func receive_controls(id: int, controls: Dictionary) -> void:
	if not trucks.has(id): return
	if lobby_world and not NetworkSession.roster.get(id, {}).get("ready", false):
		incoming[id] = {}
		return
	var sanitized: Dictionary = {}
	for action in ANALOG:
		var value: Variant = controls.get(action, 0.0)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)): return
		sanitized[action] = clampf(float(value), 0.0, 1.0)
	incoming[id] = sanitized
	received_at[id] = Time.get_ticks_msec()

func receive_action(id: int, action: String, argument: int) -> void:
	if not trucks.has(id): return
	if lobby_world and (not NetworkSession.roster.get(id, {}).get("ready", false) or action not in ["reset", "truck_headlights", "truck_hazard", "truck_signal_left", "truck_signal_right"]): return
	var previous := select_player(id)
	if action in EDGES:
		if not round_finished: truck.network_edges[action] = true
	elif action == "restart":
		remaining_time = level_duration_seconds
		round_finished = false
		round_won = false
		money_earned = 0
		ingredients = starting_ingredients
		truck.round_over = false
		truck.health = truck.max_health
		truck.reset_truck()
	elif action == "repair": super.buy_repair(argument)
	elif action == "ingredients": super.buy_ingredients()
	elif action == "upgrade": super.buy_upgrade(argument)
	select_player(previous)

func collect_input() -> void:
	var enabled := not get_tree().paused and not loading_intro_active and not free_camera_look and not round_finished
	if lobby_world: enabled = enabled and lobby_driving_enabled()
	var controls: Dictionary = {}
	for action in ANALOG: controls[action] = Input.get_action_strength(action) if enabled else 0.0
	NetworkSession.send_controls(controls)
	if enabled:
		for action in EDGES:
			if Input.is_action_just_pressed(action): NetworkSession.request_action(action)

func _physics_process(delta: float) -> void:
	if not NetworkSession.active or not is_instance_valid(service_waves) or trucks.is_empty(): return
	# Send neutral input while a local menu is open; other players keep playing.
	input_timer -= delta
	if input_timer <= 0.0:
		collect_input()
		input_timer = 1.0 / 60.0
	if not multiplayer.is_server():
		interpolate_trucks(delta)
		return
	if not NetworkSession.world_ready(): return
	if not lobby_world: service_waves.tick(delta)
	update_service_protection()
	for id in trucks:
		var previous := select_player(id)
		var body: CharacterBody3D = trucks[id]
		body.set_physics_process(false)
		body.network_controls = incoming[id] if Time.get_ticks_msec() - received_at.get(id, 0) < 500 else {}
		if lobby_world and not NetworkSession.roster.get(id, {}).get("ready", false):
			body.network_controls = {}
			body.speed = 0.0
			body.velocity.x = 0.0
			body.velocity.z = 0.0
		if not round_finished:
			body._physics_process(delta)
			if not lobby_world: super.advance_round(delta)
		body.network_edges.clear()
		select_player(previous)
	# Existing patrons use the owner of their order for queue position and payment.
	for patron in $Patrons.get_children():
		patron.set_physics_process(false)
		var owner: int = patron.get_meta("player_id", local_player)
		if patron.pad == null or (accounts.has(owner) and accounts[owner].round_finished):
			owner = $PatronManager.closest_truck(patron).get_meta("player_id", local_player)
			if accounts.has(owner) and accounts[owner].round_finished:
				for id in accounts:
					if not accounts[id].round_finished:
						owner = id
						break
		if not trucks.has(owner): owner = local_player
		var previous := select_player(owner)
		patron._physics_process(delta)
		select_player(previous)
	snapshot_timer -= delta
	if snapshot_timer <= 0.0:
		NetworkSession.broadcast_snapshot(make_snapshot())
		snapshot_timer = 0.05

func advance_round(_delta: float) -> void:
	pass # The host advances each player's round once in the physics loop.

func lobby_driving_enabled() -> bool:
	return false

func service_player_count() -> int:
	return maxi(1, trucks.size())

func can_open_shop(body: CharacterBody3D) -> bool:
	if not super.can_open_shop(body): return false
	for other in trucks.values():
		if other != body and other.parking_pad == body.parking_pad and other.deployed:
			return false
	return true

func active_serving_pad() -> Node3D:
	var pad: Node3D = super.active_serving_pad()
	if pad != null:
		var owner: int = $PatronManager.pad_owners.get(pad, 0)
		if owner != 0 and owner != active_player: return null
	return pad

func update_service_protection() -> void:
	for id in trucks:
		var body: CharacterBody3D = trucks[id]
		var pad: Node3D = body.parking_pad
		var protected: bool = is_instance_valid(pad) and pad.serving_enabled and pad.contains_truck(body) and body.deployed and body.opening > 0.99 and absf(body.speed) < 0.5
		body.set_meta("service_protected", protected)
	for id in trucks:
		for other in trucks:
			if id >= other: continue
			if trucks[id].get_meta("service_protected", false) or trucks[other].get_meta("service_protected", false):
				trucks[id].add_collision_exception_with(trucks[other])
				trucks[other].add_collision_exception_with(trucks[id])
			else:
				trucks[id].remove_collision_exception_with(trucks[other])
				trucks[other].remove_collision_exception_with(trucks[id])

func buy_repair(kind: int) -> bool:
	NetworkSession.request_action("repair", kind)
	return false

func buy_ingredients() -> bool:
	NetworkSession.request_action("ingredients")
	return false

func buy_upgrade(kind: int) -> bool:
	NetworkSession.request_action("upgrade", kind)
	return false

func request_restart() -> void:
	NetworkSession.request_action("restart")

func trigger_impact_shake(strength: float) -> void:
	if active_player == local_player: super.trigger_impact_shake(strength)

func begin_loading_intro() -> void:
	super.begin_loading_intro()
	loading_intro_truck_physics = false

func _process(delta: float) -> void:
	if not is_instance_valid(local_truck): return
	select_player(local_player)
	var balance := GameOptions.round_balance
	super._process(delta)
	GameOptions.round_balance = balance
	var entries := PackedStringArray()
	for id in NetworkSession.roster:
		if accounts.has(id): entries.append("%s  $%d" % [NetworkSession.roster[id].name.left(18), accounts[id].money])
	online_label.text = "ONLINE %d/4 • Separate earnings\n%s" % [trucks.size(), "\n".join(entries)]

func make_snapshot() -> Dictionary:
	var build_started := Time.get_ticks_usec()
	save_account()
	var players: Dictionary = {}
	for id in trucks:
		var body: CharacterBody3D = trucks[id]
		var state := {"transform": body.global_transform, "account": accounts[id].duplicate(true), "model": body.model.quaternion, "pad": str(body.parking_pad.name) if is_instance_valid(body.parking_pad) else ""}
		for field in VEHICLE: state[field] = body.get(field)
		var bones: Array = []
		for bone in [body.awning, body.counter, body.chassis] + body.suspension_bones + body.steer_bones + body.spin_bones:
			bones.append([bone, body.skeleton.get_bone_pose_position(bone), body.skeleton.get_bone_pose_rotation(bone)])
		state["bones"] = bones
		players[id] = state
	var customers: Dictionary = {}
	for patron in $Patrons.get_children():
		if not patron.has_meta("network_id"):
			patron_serial += 1
			patron.set_meta("network_id", patron_serial)
		customers[patron.get_meta("network_id")] = {"transform": patron.global_transform, "text": patron.get_node("Status").text, "animation": patron.visual_anim.current_animation, "variant": patron.active_visual.get_index()}
	var pads: Dictionary = {}
	for pad in $ParkingPads.get_children():
		pads[str(pad.name)] = {"remaining": pad.service_remaining, "started": pad.service_started, "expired": pad.expired, "duration": pad.serving_duration}
	var props: Dictionary = {}
	var bodies: Array = snapshot_props if PerformanceDiagnostics.optimized_snapshots else find_children("*", "RigidBody3D", true, false)
	for body in bodies:
		if not is_instance_valid(body): continue
		if PerformanceDiagnostics.optimized_snapshots and body.freeze and not body.is_in_group("traffic_motion") and not (body.has_method("knock_down") and body.fallen): continue
		props[str(get_path_to(body))] = {"transform": body.global_transform, "fallen": body.get("fallen") if body.has_method("knock_down") else false}
		if body.has_method("get_hybrid_snapshot"):
			props[str(get_path_to(body))]["hybrid"] = body.get_hybrid_snapshot()
	var broken: Array[String] = []
	var breakables: Array = snapshot_breakables if PerformanceDiagnostics.optimized_snapshots else find_children("BoostBreakable", "Node3D", true, false)
	for node in breakables:
		if not is_instance_valid(node): continue
		if node.broken: broken.append(str(get_path_to(node)))
	sequence_number += 1
	var rotation_names: Array = []
	for pad in service_waves.rotation: rotation_names.append(str(pad.name))
	PerformanceDiagnostics.record_section("Snapshot build", Time.get_ticks_usec() - build_started)
	return {"phase": "lobby" if lobby_world else "game", "sequence": sequence_number, "players": players, "customers": customers, "pads": pads, "props": props, "broken": broken, "waves": {"wave": service_waves.wave, "remaining": service_waves.remaining, "in_service": service_waves.in_service, "rotation": rotation_names}}

func apply_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server() or snapshot.get("sequence", 0) <= sequence_number: return
	sequence_number = snapshot.sequence
	var waves: Dictionary = snapshot.get("waves", {})
	if not waves.is_empty():
		service_waves.initialized = true
		service_waves.wave = waves.wave
		service_waves.remaining = waves.remaining
		service_waves.in_service = waves.in_service
		service_waves.rotation.clear()
		for name in waves.rotation:
			var pad := $ParkingPads.get_node_or_null(NodePath(name))
			if pad != null: service_waves.rotation.append(pad)
	for path in snapshot.get("props", {}):
		var body := get_node_or_null(NodePath(path)) as RigidBody3D
		if body == null: continue
		body.global_transform = snapshot.props[path].transform
		if body.has_method("apply_hybrid_snapshot"):
			body.apply_hybrid_snapshot(snapshot.props[path].get("hybrid", {}))
		if body.has_method("knock_down"): body.fallen = snapshot.props[path].fallen
	# Traffic is always included in prop snapshots, even with optimized snapshots.
	# Mirror authoritative cleanup rather than retaining invisible client colliders.
	for car in get_tree().get_nodes_in_group("traffic_motion"):
		if is_ancestor_of(car) and car.has_method("get_hybrid_snapshot") and car.hybrid_reactions_enabled and not snapshot.get("props", {}).has(str(get_path_to(car))):
			car.queue_free()
	for path in snapshot.get("broken", []):
		var node := get_node_or_null(NodePath(path))
		if node == null or node.broken: continue
		node.broken = true
		var visual: Node = node.get_node(node.visual_root)
		for mesh in visual.find_children("*", "MeshInstance3D", true, false): mesh.layers = 0
		if visual is MeshInstance3D: visual.layers = 0
		node.get_node("Debris").emitting = true
	for id in snapshot.players:
		if not trucks.has(id): continue
		var body: CharacterBody3D = trucks[id]
		var state: Dictionary = snapshot.players[id]
		if not targets.has(id): body.global_transform = state.transform
		targets[id] = state.transform
		accounts[id] = state.account.duplicate(true)
		for field in VEHICLE: body.set(field, state[field])
		body.model.quaternion = state.model
		body.parking_pad = $ParkingPads.get_node_or_null(NodePath(state.pad)) if not state.pad.is_empty() else null
		for bone in state.bones:
			body.skeleton.set_bone_pose_position(bone[0], bone[1])
			body.skeleton.set_bone_pose_rotation(bone[0], bone[2])
		body.get_node("VehicleLights").headlights_enabled = body.headlights_on
		body.get_node("VehicleLights").set_driving_lights(body.deployed, body.speed < -0.25, body.turn_signal < 0, body.turn_signal > 0, body.hazards_on)
		body.get_node("VehicleLights").sync_with_chassis()
	# Do not overwrite the authoritative account with stale local HUD fields.
	if accounts.has(local_player):
		active_player = 0
		select_player(local_player)
	for name in snapshot.pads:
		var pad := $ParkingPads.get_node_or_null(NodePath(name))
		if pad == null: continue
		pad.service_remaining = snapshot.pads[name].remaining
		pad.service_started = snapshot.pads[name].started
		pad.expired = snapshot.pads[name].expired
		pad.serving_duration = snapshot.pads[name].get("duration", service_window_seconds)
		pad.refresh_service_sign()
	for patron in $Patrons.get_children():
		if not snapshot.customers.has(patron.get_meta("network_id", -1)): patron.queue_free()
	for id in snapshot.customers:
		var patron: Node3D = $Patrons.get_node_or_null("Customer_%d" % id)
		var state: Dictionary = snapshot.customers[id]
		if patron == null:
			patron = $PatronManager.patron_scene.instantiate()
			patron.name = "Customer_%d" % id
			patron.character_variant = state.variant
			patron.set_meta("network_id", id)
			$Patrons.add_child(patron)
			patron.set_physics_process(false)
		patron.global_transform = state.transform
		patron.get_node("Status").text = state.text
		if not state.animation.is_empty(): patron.play_visual(state.animation)

func interpolate_trucks(delta: float) -> void:
	for id in targets:
		if not trucks.has(id): continue
		var body: CharacterBody3D = trucks[id]
		var target: Transform3D = targets[id]
		if body.global_position.distance_to(target.origin) > 12.0: body.global_transform = target
		else: body.global_transform = body.global_transform.interpolate_with(target, 1.0 - exp(-18.0 * delta))

func _exit_tree() -> void:
	if NetworkSession.level == self: NetworkSession.close()
