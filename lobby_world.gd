extends "res://multiplayer_game.gd"

var lobby_menu: Control
var driving_bar: Control

func _ready() -> void:
	await super._ready()
	$HUD/Layout.hide()
	$ParkingPads.hide()
	$PatronSpawns.hide()
	$Patrons.hide()
	$PatronManager.set_process(false)
	for pad in $ParkingPads.get_children(): pad.serving_enabled = false
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	lobby_menu = preload("res://multiplayer_lobby.tscn").instantiate()
	lobby_menu.world = self
	menu_layer.add_child(lobby_menu)
	var menu_button := Button.new()
	menu_button.text = "Lobby Menu"
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -190
	menu_button.offset_right = -24
	menu_button.offset_top = 24
	menu_button.offset_bottom = 68
	menu_button.pressed.connect(func(): lobby_menu.show())
	$HUD.add_child(menu_button)
	driving_bar = PanelContainer.new()
	driving_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	driving_bar.offset_left = -405
	driving_bar.offset_right = -24
	driving_bar.offset_top = -160
	driving_bar.offset_bottom = -24
	$HUD.add_child(driving_bar)
	var rows := VBoxContainer.new()
	driving_bar.add_child(rows)
	var caption := Label.new()
	caption.text = "LOBBY • Quick messages"
	rows.add_child(caption)
	var buttons := GridContainer.new()
	buttons.columns = 3
	rows.add_child(buttons)
	for phrase in NetworkSession.MESSAGES:
		var button := Button.new()
		button.text = phrase
		button.custom_minimum_size = Vector2(120, 36)
		button.pressed.connect(func(): NetworkSession.send_chat(phrase))
		buttons.add_child(button)
	var unready := Button.new()
	unready.text = "Unready / Lobby Menu"
	unready.visible = not multiplayer.is_server()
	unready.pressed.connect(func():
		lobby_menu.show()
		NetworkSession.set_lobby_options(false, NetworkSession.roster[local_player].color))
	rows.add_child(unready)
	NetworkSession.world_message_received.connect(show_world_message)

func lobby_driving_enabled() -> bool:
	return is_instance_valid(lobby_menu) and not lobby_menu.visible and NetworkSession.roster.get(local_player, {}).get("ready", false)

func can_open_shop(_body: CharacterBody3D) -> bool:
	return false

func apply_roster(roster: Dictionary) -> void:
	var existing: Array = trucks.keys()
	super.apply_roster(roster)
	for id in trucks:
		if id in existing: continue
		var body: CharacterBody3D = trucks[id]
		body.global_position = Vector3(-12 + roster[id].slot * 8, body.spawn_transform.origin.y, 15)
		body.rotation.y = 0
		body.travel_heading = 0
		body.parking_pad = null
		body.spawn_transform = body.global_transform

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(driving_bar): driving_bar.visible = is_instance_valid(lobby_menu) and not lobby_menu.visible
	if is_instance_valid(online_label): online_label.text = "LOBBY • %d/4 drivers\nGet ready and drive while you wait." % trucks.size()

func show_world_message(id: int, text: String) -> void:
	if not trucks.has(id): return
	var bubble := preload("res://world_speech_bubble.gd").new()
	bubble.text = text
	trucks[id].add_child(bubble)
