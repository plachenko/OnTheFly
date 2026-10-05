extends Node

# Local gear latches; multiplayer sends resolved throttle/brake strengths.
var gear := 1
var reverse_forward_override := false
var camera_gear := 1
var previous_camera_stick := 0.0
const SHIFT_THRESHOLD := 0.65
const BRAKE_DOUBLE_TAP_MSEC := 350
var brake_held := false
var brake_reverse_active := false
var shortcut_reverse_selected := false
var brake_reverse_drive_override := false
var last_brake_press_msec := -100000

func update_brake_shortcut(strength: float, now_msec: int) -> void:
	if strength < 0.2:
		brake_held = false
		brake_reverse_active = false
		brake_reverse_drive_override = false
	elif strength >= 0.65 and not brake_held:
		brake_held = true
		if now_msec - last_brake_press_msec <= BRAKE_DOUBLE_TAP_MSEC:
			gear = -1
			brake_reverse_active = true
			shortcut_reverse_selected = true
			last_brake_press_msec = -100000
		else:
			last_brake_press_msec = now_msec

func _process(_delta: float) -> void:
	refresh_brake_shortcut()
	refresh_reverse_camera(Input.get_axis("camera_up","camera_down"))

func refresh_brake_shortcut() -> void:
	update_brake_shortcut(Input.get_action_strength("brake"), Time.get_ticks_msec())
	var acceleration := maxf(Input.get_action_strength("gear_accelerate"), Input.get_action_strength("accelerate"))
	if shortcut_reverse_selected and acceleration > 0.15:
		gear = 1
		shortcut_reverse_selected = false
		brake_reverse_active = false
		# The held reverse pedal must not turn into a brake against forward gas.
		# Restore its normal braking function once it is released.
		brake_reverse_drive_override = brake_held
		last_brake_press_msec = -100000

func select_gear(stick_y: float) -> void:
	if absf(stick_y) < SHIFT_THRESHOLD: return
	shortcut_reverse_selected = false
	gear = 1 if stick_y <= -SHIFT_THRESHOLD else -1

func refresh_gear() -> void:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty(): select_gear(Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_Y))

func action_strength(action: String) -> float:
	refresh_gear()
	refresh_brake_shortcut()
	var base := Input.get_action_strength(action)
	if brake_reverse_drive_override and action == "brake": return 0.0
	if brake_reverse_active:
		if action == "brake": return 0.0
		if action == "reverse": return maxf(base, Input.get_action_strength("brake"))
	var pedal := Input.get_action_strength("gear_accelerate")
	if action == "accelerate" and gear == 1: return maxf(base, pedal)
	if action == "reverse" and gear == -1: return maxf(base, pedal)
	return base

func reverse_view_requested() -> bool:
	refresh_gear()
	refresh_brake_shortcut()
	refresh_reverse_camera(Input.get_axis("camera_up","camera_down"))
	return gear == -1 and not reverse_forward_override

func refresh_reverse_camera(stick_y: float) -> void:
	if gear != camera_gear:
		reverse_forward_override = false
		camera_gear = gear
	if gear == -1:
		if stick_y < -SHIFT_THRESHOLD and previous_camera_stick >= -SHIFT_THRESHOLD: reverse_forward_override = true
		elif stick_y > SHIFT_THRESHOLD and previous_camera_stick <= SHIFT_THRESHOLD: reverse_forward_override = false
	else: reverse_forward_override = false
	previous_camera_stick = stick_y

func _input(event: InputEvent) -> void:
	var now := Time.get_ticks_msec()
	if event is InputEventKey and not event.echo:
		for direction in ["left", "right"]:
			if event.is_action(direction): update_signal_key(direction, event.pressed, now)
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
		update_signal_stick(event.device, event.axis_value, now)
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		select_gear(event.axis_value)

	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		refresh_reverse_camera(event.axis_value)

const SIGNAL_DOUBLE_TAP_MSEC := 350
const SIGNAL_FLICK_MSEC := 220
var signal_key_down := {"left": false, "right": false}
var signal_key_press := {"left": -100000, "right": -100000}
var signal_sticks: Dictionary = {}
var pending_direction_signal := 0
var pending_direction_msec := -100000

func queue_direction_signal(direction: int, now: int) -> void:
	pending_direction_signal = direction
	pending_direction_msec = now

func direction_signal_just_pressed(action: String) -> bool:
	if action not in ["direction_signal_left", "direction_signal_right"]:
		return Input.is_action_just_pressed(action)
	var direction := -1 if action == "direction_signal_left" else 1
	if pending_direction_signal != direction or Time.get_ticks_msec() - pending_direction_msec > 250: return false
	pending_direction_signal = 0
	return true

func update_signal_key(direction: String, pressed: bool, now: int) -> void:
	if not pressed:
		signal_key_down[direction] = false
		return
	if signal_key_down[direction]: return
	signal_key_down[direction] = true
	var opposite := "right" if direction == "left" else "left"
	signal_key_press[opposite] = -100000
	if now - int(signal_key_press[direction]) <= SIGNAL_DOUBLE_TAP_MSEC:
		queue_direction_signal(-1 if direction == "left" else 1, now)
		signal_key_press[direction] = -100000
	else:
		signal_key_press[direction] = now

func update_signal_stick(device: int, value: float, now: int) -> void:
	var state: Dictionary = signal_sticks.get(device, {"armed": true, "start": -100000, "direction": 0})
	if absf(value) <= 0.2:
		state = {"armed": true, "start": -100000, "direction": 0}
	elif state.armed:
		var direction := -1 if value < 0.0 else 1
		if state.start == -100000 or state.direction != direction:
			state.start = now
			state.direction = direction
		if absf(value) >= 0.8:
			if now - int(state.start) <= SIGNAL_FLICK_MSEC: queue_direction_signal(direction, now)
			state.armed = false
	signal_sticks[device] = state
