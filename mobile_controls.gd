extends CanvasLayer

# Native TouchScreenButtons keep independent fingers and feed the existing InputMap.
var buttons: Array[TouchScreenButton] = []
var enabled: bool = false
var camera_finger: int = -1
var suspended: bool = false
@onready var level = get_parent()
@onready var hud: CanvasLayer = level.get_node("HUD")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 2
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--touch-controls" in OS.get_cmdline_user_args()
	if not enabled:
		return
	for spec in [["left", "LEFT"], ["right", "RIGHT"], ["reverse", "REVERSE"], ["brake", "BRAKE"], ["accelerate", "DRIVE"], ["serve", "KITCHEN"], ["boost", "BOOST"], ["reset", "TOW"], ["truck_signal_left", "SIGNAL L"], ["truck_headlights", "LIGHTS"], ["truck_hazard", "HAZARDS"], ["truck_signal_right", "SIGNAL R"]]:
		add_button(spec[0], spec[1])
	# Keep the status message, replacing the desktop key legend with touch help.
	var controls = hud.get_node("Layout/ControlsPanel")
	for child in controls.get_children():
		if child is Label and child.name != "StatusLabel":
			child.hide()
	var status: Label = controls.get_node("StatusLabel")
	status.position = Vector2(16, 8)
	status.size = Vector2(1248, 50)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(arrange)
	arrange()

func add_button(action_name: String, caption: String) -> void:
	var button := TouchScreenButton.new()
	button.name = action_name
	button.action = action_name
	button.shape = RectangleShape2D.new()
	button.shape.size = Vector2(108, 74)
	button.shape_visible = false
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	var face := Panel.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.position = Vector2(-54, -37)
	face.size = Vector2(108, 74)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.1, 0.82)
	style.border_color = Color(0.54, 0.79, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	face.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.size = face.size
	face.add_child(label)
	button.add_child(face)
	button.pressed.connect(func(): face.modulate = Color(1.0, 0.72, 0.42))
	button.released.connect(func(): face.modulate = Color.WHITE)
	add_child(button)
	buttons.append(button)

func arrange() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var unit := minf(1.0, viewport_size.x / 720.0)
	var bottom := viewport_size.y - 22.0 * unit
	# Pedals and steering at opposite corners; utilities sit above them.
	var positions := [Vector2(76, -48), Vector2(196, -48), Vector2(-316, -48), Vector2(-196, -48), Vector2(-76, -48), Vector2(76, -132), Vector2(-76, -132), Vector2(196, -132), Vector2(76, -216), Vector2(196, -216), Vector2(-196, -216), Vector2(-76, -216)]
	for i in buttons.size():
		buttons[i].scale = Vector2.ONE * unit
		var point: Vector2 = positions[i] * unit
		buttons[i].position = Vector2(point.x if point.x > 0 else viewport_size.x + point.x, bottom + point.y)
	# Existing fixed-layout menus stay centered and fully visible on portrait screens.
	var layout: Control = hud.get_node("Layout")
	var hud_scale := minf(viewport_size.x / 1280.0, maxf(100.0, viewport_size.y - 280.0 * unit) / 800.0)
	layout.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layout.size = Vector2(1280, 800)
	layout.scale = Vector2.ONE * hud_scale
	layout.position = Vector2((viewport_size.x - 1280.0 * hud_scale) * 0.5, 0)

func _process(_delta: float) -> void:
	if not enabled:
		return
	var blocked: bool = get_tree().paused or level.round_finished
	if blocked != suspended:
		suspended = blocked
		camera_finger = -1
		for button in buttons:
			# Hiding native touch buttons releases their held action immediately.
			button.visible = not blocked

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		camera_finger = -1
		for button in buttons:
			button.hide()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and enabled and not suspended:
		for button in buttons:
			button.show()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or suspended:
		return
	if event is InputEventScreenTouch:
		if event.pressed and camera_finger == -1:
			camera_finger = event.index
		elif not event.pressed and camera_finger == event.index:
			camera_finger = -1
	elif event is InputEventScreenDrag and event.index == camera_finger and level.kitchen_blend < 0.1:
		level.orbit -= event.relative.x * 0.006
		level.pitch = clampf(level.pitch + event.relative.y * 0.004, 0.18, 1.05)
		level.camera_return_timer = level.camera_return_delay
		get_viewport().set_input_as_handled()
