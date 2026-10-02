extends Control

var players: VBoxContainer
var level_picker: OptionButton
var color_picker: OptionButton
var ready_button: CheckButton
var start_button: Button
var bubbles: Control
var hint: Label
var world: Node
var previous_ready := false
var readiness_initialized := false
var resume_button: Button

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.12, 0.88)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 570)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)
	var title := Label.new()
	title.text = "OnTheFly • MULTIPLAYER LOBBY"
	title.add_theme_font_size_override("font_size", 26)
	rows.add_child(title)
	players = VBoxContainer.new()
	players.custom_minimum_size.y = 130
	rows.add_child(players)
	var options := HBoxContainer.new()
	rows.add_child(options)
	level_picker = OptionButton.new()
	for name in NetworkSession.LEVELS: level_picker.add_item(name)
	level_picker.custom_minimum_size.x = 220
	level_picker.item_selected.connect(func(index: int): NetworkSession.choose_level(level_picker.get_item_text(index)))
	options.add_child(level_picker)
	color_picker = OptionButton.new()
	for name in ["Red truck", "Blue truck", "Green truck", "Yellow truck", "Purple truck", "White truck"]: color_picker.add_item(name)
	color_picker.custom_minimum_size.x = 180
	color_picker.item_selected.connect(func(_index: int): send_options())
	options.add_child(color_picker)
	ready_button = CheckButton.new()
	ready_button.text = "Ready"
	ready_button.toggled.connect(func(_pressed: bool): send_options())
	options.add_child(ready_button)
	hint = Label.new()
	rows.add_child(hint)
	bubbles = Control.new()
	bubbles.custom_minimum_size.y = 140
	bubbles.clip_contents = true
	rows.add_child(bubbles)
	NetworkSession.chat_received.connect(append_chat)
	var chat_row := GridContainer.new()
	chat_row.columns = 3
	rows.add_child(chat_row)
	for phrase in NetworkSession.MESSAGES:
		var send := Button.new()
		send.text = phrase
		send.custom_minimum_size = Vector2(220, 36)
		send.pressed.connect(func(): NetworkSession.send_chat(phrase))
		chat_row.add_child(send)
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	start_button = Button.new()
	start_button.text = "Start Session"
	start_button.pressed.connect(func(): NetworkSession.start_session())
	actions.add_child(start_button)
	resume_button = Button.new()
	resume_button.text = "Drive lobby"
	resume_button.pressed.connect(func(): hide())
	actions.add_child(resume_button)
	var leave := Button.new()
	leave.text = "Leave Lobby"
	leave.pressed.connect(NetworkSession.leave)
	actions.add_child(leave)
	NetworkSession.lobby_changed.connect(refresh)
	refresh()

func send_options() -> void:
	NetworkSession.set_lobby_options(ready_button.button_pressed, color_picker.selected)

func append_chat(sender: String, text: String) -> void:
	if not visible: return
	var bubble := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff2d7")
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", style)
	var caption := Label.new()
	caption.text = "%s: %s" % [sender, text]
	caption.add_theme_color_override("font_color", Color("292b32"))
	caption.add_theme_font_size_override("font_size", 20)
	bubble.add_child(caption)
	bubbles.add_child(bubble)
	var width: float = bubble.get_combined_minimum_size().x
	bubble.position = Vector2(maxf(0, (bubbles.size.x - width) * 0.5), 88)
	var tail := Polygon2D.new()
	tail.color = style.bg_color
	tail.position = Vector2(30, bubble.get_combined_minimum_size().y)
	tail.polygon = PackedVector2Array([Vector2(0, -1), Vector2(18, -1), Vector2(3, 11)])
	bubble.add_child(tail)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(bubble, "position:y", 18.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.35).set_delay(1.0)
	tween.chain().tween_callback(bubble.queue_free)

func refresh() -> void:
	for child in players.get_children():
		players.remove_child(child)
		child.queue_free()
	var host := multiplayer.is_server()
	start_button.visible = host
	start_button.disabled = not NetworkSession.can_start()
	ready_button.visible = not host
	level_picker.disabled = not host
	for index in level_picker.item_count:
		if level_picker.get_item_text(index) == NetworkSession.selected_level: level_picker.select(index)
	var local_id := multiplayer.get_unique_id()
	if NetworkSession.roster.has(local_id):
		var entry: Dictionary = NetworkSession.roster[local_id]
		color_picker.select(entry.color)
		ready_button.set_pressed_no_signal(entry.ready)
		resume_button.disabled = not entry.ready
		if readiness_initialized and entry.ready != previous_ready:
			visible = not entry.ready
		if not entry.ready: show()
		previous_ready = entry.ready
		readiness_initialized = true
	for id in NetworkSession.roster:
		var entry: Dictionary = NetworkSession.roster[id]
		var row := HBoxContainer.new()
		players.add_child(row)
		var light := Label.new()
		light.text = "●"
		light.add_theme_color_override("font_color", Color("55df88") if entry.ready else Color("ff625d"))
		row.add_child(light)
		var name_label := Label.new()
		name_label.text = "%s%s • %s" % [entry.name, " (Host)" if id == 1 else "", "Ready" if entry.ready else "Not ready"]
		row.add_child(name_label)
		var swatch := ColorRect.new()
		swatch.color = NetworkSession.COLORS[entry.color]
		swatch.custom_minimum_size = Vector2(34, 22)
		row.add_child(swatch)
	hint.text = "Drive the lobby while guests get ready. Only you can start the session." if host else "Ready lets you drive the lobby. Unready brings this menu back."
