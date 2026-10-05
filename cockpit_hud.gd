extends Control

# Resolution-independent cockpit shared by keyboard, gamepad, mouse and touch.
const IVORY := Color("d8c2ab")
const DARK := Color("161619")
const RED := Color("c63226")
var level: Node
var body: Node3D
var unit := 1.0
var canvas := Vector2(1280, 720)
var wheel_angle := 0.0
var elapsed := 0.0
var fingers: Dictionary = {}
var mirror_view: SubViewport
var mirror_camera: Camera3D
var mirror_image: TextureRect
var active := false
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mirror_view = SubViewport.new()
	mirror_view.size = Vector2i(384, 112)
	mirror_view.world_3d = level.get_world_3d()
	mirror_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mirror_view)
	mirror_camera = Camera3D.new()
	mirror_camera.fov = 75
	mirror_camera.far = 180
	mirror_view.add_child(mirror_camera)
	mirror_camera.current = true
	mirror_image = TextureRect.new()
	mirror_image.texture = mirror_view.get_texture()
	mirror_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror_image.flip_h = true
	mirror_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(mirror_image)
	get_viewport().size_changed.connect(arrange)
	arrange()

func arrange() -> void:
	var viewport_size := get_viewport_rect().size
	unit = minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	canvas = viewport_size / unit
	mirror_image.position = Vector2(canvas.x * 0.5 - 145, 30) * unit
	mirror_image.size = Vector2(290, 76) * unit
	release_controls()

func wheel_center() -> Vector2:
	return Vector2(220, canvas.y - 105)

func pedal_rect(brake: bool) -> Rect2:
	return Rect2(Vector2(canvas.x - (270 if brake else 140), canvas.y - 200), Vector2(105, 178))

func signal_rect() -> Rect2:
	return Rect2(Vector2(35, canvas.y - 270), Vector2(85, 130))

func gear_rect() -> Rect2:
	return Rect2(Vector2(canvas.x * 0.5 - 64, canvas.y - 224), Vector2(128, 66))

func _process(delta: float) -> void:
	body = level.get("local_truck")
	if not is_instance_valid(body): body = level.get("truck")
	var allowed: bool = is_instance_valid(body) and not get_tree().paused and not level.round_finished and not level.loading_intro_active and not level.free_camera_look and level.kitchen_blend < 0.1
	if active and not allowed: release_controls()
	active = allowed
	visible = allowed
	mirror_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if allowed else SubViewport.UPDATE_DISABLED
	if not allowed: return
	elapsed += delta
	var steering := Input.get_axis("left", "right")
	wheel_angle = move_toward(wheel_angle, steering * 1.45, delta * (1.6 if absf(steering) > 0.99 else 4.0))
	var focus: Vector3 = body.global_position + Vector3.UP * 2.7
	mirror_camera.global_position = focus + body.global_basis.z * 3.8
	mirror_camera.look_at(focus + body.global_basis.z * 35, Vector3.UP)
	queue_redraw()

func plate(rect: Rect2, fill: Color, border: Color = IVORY, radius: int = 14) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(5)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func caption(point: Vector2, value: String, size_px: int = 24, color: Color = IVORY) -> void:
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func gauge(center: Vector2, radius: float, value: float, title: String, health: bool) -> void:
	draw_circle(center, radius + 7, IVORY)
	draw_circle(center, radius, DARK)
	draw_arc(center, radius - 15, -PI * 0.9, -PI * 0.1, 48, IVORY, 7, true)
	draw_arc(center, radius - 15, -PI * 0.9 if health else -PI * 0.3, -PI * 0.7 if health else -PI * 0.1, 16, RED, 9, true)
	for index in 9:
		var angle := lerpf(-PI * 0.9, -PI * 0.1, index / 8.0)
		draw_line(center + Vector2.from_angle(angle) * (radius - 27), center + Vector2.from_angle(angle) * (radius - 7), IVORY, 3, true)
	var angle := lerpf(-PI * 0.9, -PI * 0.1, clampf(value, 0, 1))
	draw_line(center, center + Vector2.from_angle(angle) * (radius - 30), RED, 8, true)
	draw_circle(center, 13, Color.BLACK)
	caption(center + Vector2(-radius + 22, 43), title, 17)
	if health:
		caption(center + Vector2(-radius + 13, -8), "E", 22)
		caption(center + Vector2(radius - 26, -8), "F", 22)

func _draw() -> void:
	if not is_instance_valid(body): return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * unit)
	# Windshield header, pillars and molded dash retain an open driving view.
	draw_rect(Rect2(0, 0, canvas.x, 14), DARK)
	for side in [0.0, canvas.x]:
		var inward := 1.0 if side == 0 else -1.0
		draw_line(Vector2(side, 0), Vector2(side + inward * 35, canvas.y), Color("08090c"), 32, true)
		draw_line(Vector2(side + inward * 12, 0), Vector2(side + inward * 48, canvas.y), Color("414048"), 5, true)
	plate(Rect2(390, canvas.y - 174, canvas.x - 710, 215), DARK)
	plate(Rect2(canvas.x - 320, canvas.y - 238, 325, 280), Color("0e0e11"), Color("474342"), 40)
	plate(Rect2(16, 20, 192, 100), IVORY, Color("665d55"))
	caption(Vector2(34, 66), "$%s" % level.money, 36, Color("131315"))
	draw_line(Vector2(32, 79), Vector2(190, 79), Color("665d55"), 1)
	caption(Vector2(34, 105), "LICENSE %d" % level.license_points, 20, DARK)
	plate(Rect2(canvas.x / 2 - 157, 18, 314, 100), DARK, Color("49443f"), 25)
	# Dangling dice moves with steering and acceleration.
	var hang := Vector2(canvas.x / 2 + sin(elapsed * 2.5) * 3 + wheel_angle * 14, 170)
	draw_line(Vector2(canvas.x / 2, 115), hang, IVORY.darkened(0.4), 3, true)
	draw_set_transform(hang * unit, sin(elapsed * 2.5) * 0.07 + wheel_angle * 0.12, Vector2.ONE * unit)
	plate(Rect2(-24, 0, 48, 48), IVORY, Color("918071"), 9)
	for dot in [Vector2(-12, 12), Vector2(12, 12), Vector2(0, 24), Vector2(-12, 36), Vector2(12, 36)]: draw_circle(dot, 4, DARK)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * unit)
	var cluster := Vector2(canvas.x / 2, canvas.y - 40)
	var health: float = body.health / maxf(1, body.max_health)
	gauge(cluster + Vector2(-125, 0), 92, health, "HEALTH", true)
	gauge(cluster + Vector2(125, 0), 92, absf(body.speed) * 3.6 / 120.0, "%d km/h" % roundi(absf(body.speed) * 3.6), false)
	plate(gear_rect(), Color("08090b"), Color("4b4640"))
	caption(gear_rect().position + Vector2(26, 46), "R" if DrivingControls.gear == -1 or body.speed < -0.5 else "D", 42)
	plate(Rect2(cluster + Vector2(-35, -65), Vector2(70, 60)), Color("08090b"), Color("403b35"), 9)
	if health <= body.critical_health_ratio and fmod(elapsed, 0.8) < 0.4:
		var engine := cluster + Vector2(-22, -49)
		draw_rect(Rect2(engine, Vector2(44, 27)), Color("ffac29"), false, 4)
		draw_line(engine + Vector2(11, -7), engine + Vector2(30, -7), Color("ffac29"), 4)
		draw_line(engine + Vector2(20, -7), engine + Vector2(20, 0), Color("ffac29"), 4)
		draw_line(engine + Vector2(-7, 5), engine + Vector2(-7, 22), Color("ffac29"), 4)
	for brake in [true, false]:
		var rect := pedal_rect(brake)
		var pressed: bool = Input.is_action_pressed("brake" if brake else "gear_accelerate") or (not brake and Input.is_action_pressed("accelerate"))
		plate(rect, RED.darkened(0.35) if pressed else Color("212124"), Color("71665a"), 12)
		caption(rect.position + Vector2(8, -14), "BRAKE" if brake else "ACCEL", 22)
		var foot := Rect2(rect.position + Vector2(13, 48 if brake else 16), Vector2(79, 75 if brake else 143))
		plate(foot, Color("101013"), IVORY, 10)
		for y in range(12, int(foot.size.y) - 6, 10): draw_line(foot.position + Vector2(10, y), foot.position + Vector2(foot.size.x - 10, y), Color("55504c"), 3)
	var wc := wheel_center()
	draw_arc(wc, 156, 0, TAU, 80, Color("08080a"), 53, true)
	draw_arc(wc, 155, 0, TAU, 80, IVORY, 38, true)
	draw_arc(wc, 174, 0, TAU, 80, Color("a49384"), 3, true)
	draw_set_transform(wc * unit, wheel_angle, Vector2.ONE * unit)
	for angle in [0.0, PI, PI * 0.5]: draw_line(Vector2.from_angle(angle) * 30, Vector2.from_angle(angle) * 137, IVORY, 32, true)
	draw_circle(Vector2.ZERO, 63, IVORY.darkened(0.15))
	draw_circle(Vector2.ZERO, 46, DARK)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * unit)
	var stalk := signal_rect()
	draw_line(stalk.position + Vector2(75, 125), stalk.position + Vector2(16, 24), DARK, 32, true)
	caption(stalk.position + Vector2(5, 35), "↕", 27, Color("33e759") if body.turn_signal != 0 else IVORY)
	if body.turn_signal != 0 and fmod(elapsed, 0.8) < 0.4:
		caption(Vector2(canvas.x / 2 + (-90 if body.turn_signal < 0 else 68), canvas.y - 188), "◀" if body.turn_signal < 0 else "▶", 26, Color("33e759"))
	caption(Vector2(canvas.x - 260, 55), level.compass_heading(-body.global_basis.z), 28)
	caption(Vector2(canvas.x - 260, 82), "TIME %d:%02d" % [int(level.remaining_time) / 60, int(level.remaining_time) % 60], 18)
	caption(Vector2(420, canvas.y - 247), "KITCHEN   BOOST   LIGHTS   TOW", 16)
	var boost_label := level.get_node_or_null("HUD/Layout/BoostPanel/BoostLabel")
	if boost_label != null:
		caption(Vector2(420, canvas.y - 277), str(boost_label.text), 16)
	if health <= body.critical_health_ratio:
		caption(Vector2(420, canvas.y - 307), "ENGINE CRITICAL — REACH REPAIRS", 17, Color("ffac29"))
	draw_set_transform(Vector2.ZERO)

func hit(point: Vector2) -> String:
	if signal_rect().has_point(point): return "signal"
	if point.distance_to(wheel_center()) < 180: return "wheel"
	if pedal_rect(true).has_point(point): return "brake"
	if pedal_rect(false).has_point(point): return "gear_accelerate"
	if gear_rect().has_point(point): return "gear"
	if Rect2(410, canvas.y - 272, 320, 36).has_point(point):
		return ["serve", "boost", "truck_headlights", "reset"][clampi(int((point.x - 410) / 80), 0, 3)]
	return ""

func press(index: int, point: Vector2) -> bool:
	var action := hit(point)
	if action.is_empty(): return false
	fingers[index] = {"action": action, "start": point, "point": point}
	if action == "gear":
		DrivingControls.shortcut_reverse_selected = false
		DrivingControls.gear *= -1
	elif action not in ["wheel", "signal"]: Input.action_press(action)
	return true

func drag(index: int, point: Vector2) -> bool:
	if not fingers.has(index): return false
	var state: Dictionary = fingers[index]
	state.point = point
	if state.action == "wheel": update_steering()
	elif state.action == "signal" and absf(point.y - state.start.y) > 24:
		DrivingControls.queue_direction_signal(1 if point.y < state.start.y else -1, Time.get_ticks_msec())
		state.action = "signal_done"
	return true

func update_steering() -> void:
	var amount := 0.0
	for state in fingers.values():
		if state.action == "wheel": amount = clampf((state.point.x - state.start.x) / 110.0, -1, 1)
	Input.action_release("left")
	Input.action_release("right")
	if amount != 0: Input.action_press("right" if amount > 0 else "left", absf(amount))

func release(index: int) -> bool:
	if not fingers.has(index): return false
	var action: String = fingers[index].action
	fingers.erase(index)
	if action == "wheel": update_steering()
	elif action not in ["signal", "signal_done", "gear"]:
		var still_held := false
		for state in fingers.values():
			if state.action == action: still_held = true
		if not still_held: Input.action_release(action)
	return true

func release_controls() -> void:
	for index in fingers.keys(): release(index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE: release_controls()

func _input(event: InputEvent) -> void:
	if not active: return
	var handled := false
	if event is InputEventScreenTouch:
		handled = press(event.index, event.position / unit) if event.pressed else release(event.index)
	elif event is InputEventScreenDrag: handled = drag(event.index, event.position / unit)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		handled = press(-1, event.position / unit) if event.pressed else release(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION: handled = drag(-1, event.position / unit)
	if handled: get_viewport().set_input_as_handled()
