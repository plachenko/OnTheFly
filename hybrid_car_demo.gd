extends Node3D
const CAR_MODELS := preload("res://hybrid_car.gd").MODELS
var car: CharacterBody3D
var camera: Camera3D
var label: Label
var selected_model := 0
var impact_direction := 0
var impact_strength := 3.0
const MAX_CHARGE_SECONDS := 2.0
var charging := false
var charge_seconds := 0.0
var charge_source := ""
var committed_impacts := 0
var last_push := Vector3.ZERO
var last_committed_strength := 0.0
var impact_aim := Vector3.FORWARD
var stick_deadzone := 0.18
var trigger_deadzone := 0.05
var steering_sensitivity := 1.0
var aim_arrow: Node3D
var arrow_shaft: MeshInstance3D
var arrow_tip: MeshInstance3D
# Labels describe impulse travel, not the side the striker starts on.
const DIRECTIONS := [Vector3.FORWARD, Vector3(1, 0, -1), Vector3.RIGHT, Vector3(1, 0, 1), Vector3.BACK, Vector3(-1, 0, 1), Vector3.LEFT, Vector3(-1, 0, -1), Vector3.UP, Vector3.DOWN]
const DIRECTION_NAMES := ["forward (hit rear)", "forward-right", "right (hit left)", "back-right", "backward (hit front)", "back-left", "left (hit right)", "forward-left", "up", "down"]

func _ready() -> void:
	var options := get_node_or_null("/root/GameOptions")
	if options:
		stick_deadzone = options.stick_deadzone
		trigger_deadzone = options.trigger_deadzone
		steering_sensitivity = options.steering_sensitivity
	_surface(Vector3(80, 1, 100), Vector3(0, -0.5, 0), 0, Color.DARK_SLATE_GRAY)
	_surface(Vector3(10, 1, 18), Vector3(12, 1.8, -12), -0.25, Color.SLATE_GRAY)
	_surface(Vector3(8, 8, 8), Vector3(-10, 4, -18), 0, Color.SIENNA)
	_surface(Vector3(8, 6, 8), Vector3(20, 3, -30), 0, Color.TAN)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(20, 20)
	canvas.add_child(label)
	reset_car()
	create_aim_arrow()

func create_aim_arrow() -> void:
	aim_arrow = Node3D.new()
	add_child(aim_arrow)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_shaft = MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.055
	shaft.bottom_radius = 0.055
	shaft.height = 1.0
	arrow_shaft.mesh = shaft
	arrow_shaft.material_override = material
	aim_arrow.add_child(arrow_shaft)
	arrow_tip = MeshInstance3D.new()
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.2
	tip.height = 0.4
	arrow_tip.mesh = tip
	arrow_tip.material_override = material
	aim_arrow.add_child(arrow_tip)
	update_aim_arrow()

func arrow_length(strength: float) -> float:
	return 1.0 + clampf(strength, 1.0, 40.0) * 0.1

func update_aim_arrow() -> void:
	if not is_instance_valid(car):
		aim_arrow.hide()
		return
	aim_arrow.show()
	var length := arrow_length(effective_strength())
	aim_arrow.global_position = car.global_position + Vector3.UP * (car.model_bounds.end.y + 1.0)
	var direction: Vector3 = (car.global_basis * impact_aim).normalized()
	aim_arrow.global_basis = Basis(Quaternion(Vector3.UP, direction))
	arrow_shaft.scale.y = length - 0.4
	arrow_shaft.position.y = (length - 0.4) * 0.5
	arrow_tip.position.y = length - 0.2

func _surface(size: Vector3, at: Vector3, pitch: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.x = pitch
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)

func reset_car() -> void:
	cancel_charge()
	if is_instance_valid(car):
		car.queue_free()
	car = preload("res://hybrid_car.gd").new()
	car.model_index = selected_model
	add_child(car)
	car.position = Vector3(0, 0.15, 10)
	car.apply_ground_pose(car.ground_sample(), Vector3.ZERO)

func charged_strength(base: float, seconds: float) -> float:
	var amount := clampf(seconds / MAX_CHARGE_SECONDS, 0, 1)
	return lerpf(base, maxf(base, 11.8), amount) if base < 12.0 else minf(40.0, base * (1.0 + amount * 0.5))

func effective_strength() -> float:
	return charged_strength(impact_strength, charge_seconds) if charging else impact_strength

func begin_charge(source: String) -> void:
	if charging or not is_instance_valid(car):
		return
	charging = true
	charge_source = source
	charge_seconds = 0

func advance_charge(delta: float) -> void:
	if charging:
		charge_seconds = minf(MAX_CHARGE_SECONDS, charge_seconds + delta)

func cancel_charge() -> void:
	charging = false
	charge_seconds = 0
	charge_source = ""

func release_charge(source: String) -> void:
	if not charging or source != charge_source:
		return
	var strength := effective_strength()
	cancel_charge()
	trigger_impact(strength)

func trigger_impact(strength: float = -1.0) -> void:
	cancel_charge() # Preset impacts also cancel any pending held action.
	if not is_instance_valid(car):
		return
	if strength < 0:
		strength = impact_strength
	var direction: Vector3 = (car.global_basis * impact_aim).normalized()
	last_push = direction
	last_committed_strength = strength
	committed_impacts += 1
	car.receive_impact(car.velocity + direction * strength, direction)

func axis_value(value: float, deadzone: float) -> float:
	return signf(value) * clampf((absf(value) - deadzone) / maxf(0.01, 1.0 - deadzone), 0, 1)

func controller_drive(stick: Vector2) -> Vector2:
	return Vector2(clampf(axis_value(stick.x, stick_deadzone) * steering_sensitivity, -1, 1), -axis_value(stick.y, stick_deadzone))

func aim_right_stick(stick: Vector2) -> void:
	if stick.length() <= stick_deadzone:
		return # Keep last aim on release, including a selected vertical direction.
	impact_aim = Vector3(stick.x, 0, stick.y).normalized()
	impact_direction = -1

func select_direction(index: int) -> void:
	impact_direction = posmod(index, DIRECTIONS.size())
	impact_aim = DIRECTIONS[impact_direction].normalized()

func controller_command(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "impact"
		JOY_BUTTON_B: return "reset"
		JOY_BUTTON_X: return "high_medium"
		JOY_BUTTON_LEFT_SHOULDER: return "previous_model"
		JOY_BUTTON_RIGHT_SHOULDER: return "next_model"
		JOY_BUTTON_DPAD_UP: return "up_impact"
		JOY_BUTTON_DPAD_DOWN: return "down_impact"
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton:
		return
	if event.button_index == JOY_BUTTON_A:
		if event.pressed:
			begin_charge("pad")
		else:
			release_charge("pad")
		return
	if not event.pressed:
		return
	match controller_command(event.button_index):
		"impact": trigger_impact()
		"reset": reset_car()
		"high_medium":
			impact_strength = 11.8
			trigger_impact()
		"previous_model", "next_model":
			selected_model = posmod(selected_model + (-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1), CAR_MODELS.size())
			reset_car()
		"up_impact": select_direction(8)
		"down_impact": select_direction(9)

func _process(delta: float) -> void:
	if not is_instance_valid(car):
		cancel_charge()
		aim_arrow.hide()
		label.text = "Disabled car faded out. R/B resets; M/N or LB/RB changes model."
		return
	advance_charge(delta)
	car.throttle = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	car.steering = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var pads := Input.get_connected_joypads()
	if pads.is_empty() and charging and charge_source == "pad":
		cancel_charge()
	if not pads.is_empty():
		var pad := pads[0]
		var drive := controller_drive(Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)))
		car.steering = clampf(car.steering + drive.x, -1, 1)
		car.throttle = clampf(car.throttle + drive.y, -1, 1)
		aim_right_stick(Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)))
		var strength_change := axis_value(Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT), trigger_deadzone) - axis_value(Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT), trigger_deadzone)
		impact_strength = clampf(impact_strength + strength_change * 8.0 * delta, 1, 40)
	update_aim_arrow()
	camera.global_position = camera.global_position.lerp(car.global_position + Vector3(0, 14, 19), minf(1.0, delta * 4.0))
	camera.look_at(car.global_position + Vector3.UP)
	var aim_name: String = DIRECTION_NAMES[impact_direction] if impact_direction >= 0 else "right-stick aim"
	var estimated_angle := rad_to_deg(car.tip_angle_for_strength(effective_strength()))
	label.text = "Hybrid Kenney demo | W/S drive/reverse, A/D steer, release to brake\nQ/E direction | -/+ strength | Space impact | 1/2/3 preset+impact | R reset\nM/N model | PAD: left stick drive/steer, RIGHT stick aim push direction\nRT/LT strength +/- | A/Cross impact | B/Circle reset | LB/RB model\nD-pad up/down vertical impact | Controller: %s\nModel: %s | Local push: %s %s | strength %.1f m/s\nState: %s | speed %.1f | grip %.2f | roll %.1f degrees\n4/X/Square: 11.8 high-medium hit (aim lateral for rollover) | R/B resets\nLast car tick %d us (not a benchmark)" % ["connected" if not pads.is_empty() else "absent (keyboard active)", CAR_MODELS[selected_model], aim_name, impact_aim, impact_strength, car.State.keys()[car.state], car.speed, car.tire_friction, rad_to_deg(car.pose.z), car.physics_usec]
	label.text += "\nHOLD Space/A, release to commit | charge %.2f/2s | base %.1f -> effective %.1f m/s\nTip preview %.1f degrees (12+ = flight) | pitch %.1f | balance margin %.2fm" % [charge_seconds, impact_strength, effective_strength(), estimated_angle, rad_to_deg(car.pose.x), car.balance_margin]
	label.text += "\nLast applied %.1f m/s | world push %s" % [last_committed_strength, last_push]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	if event.physical_keycode == KEY_SPACE:
		if event.pressed:
			begin_charge("keyboard")
		else:
			release_charge("keyboard")
		return
	if not event.pressed:
		return
	if event.physical_keycode == KEY_R:
		reset_car()
	if event.physical_keycode == KEY_Q:
		select_direction(impact_direction - 1)
	if event.physical_keycode == KEY_E:
		select_direction(impact_direction + 1)
	if event.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		impact_strength = maxf(1.0, impact_strength - 1.0)
	if event.physical_keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		impact_strength = minf(40.0, impact_strength + 1.0)
	if event.physical_keycode in [KEY_M, KEY_N]:
		selected_model = posmod(selected_model + (1 if event.physical_keycode == KEY_M else -1), CAR_MODELS.size())
		reset_car()
	for entry in [[KEY_1, 3.0], [KEY_2, 11.0], [KEY_3, 20.0], [KEY_4, 11.8]]:
		if event.physical_keycode == entry[0]:
			impact_strength = entry[1]
			trigger_impact()
