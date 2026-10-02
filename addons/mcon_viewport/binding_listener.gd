@tool
extends Node

var choice: OptionButton
var invert: CheckBox
var hint: Label
var original_hint: String
var device_provider: Callable
var axis_binding: bool = false
var remaining: float = 0.0
var held: Dictionary = {}
var neutral: Dictionary = {}

func begin(target: OptionButton, axis: bool, inversion: CheckBox = null) -> void:
	cancel()
	choice = target
	invert = inversion
	axis_binding = axis
	remaining = 15.0
	held.clear()
	neutral.clear()
	var device: int = device_provider.call()
	for index in 21:
		held[index] = Input.is_joy_button_pressed(device, index)
	for index in 6:
		neutral[index] = absf(Input.get_joy_axis(device, index)) < 0.25
	hint.text = "Listening: %s. Esc cancels; held controls must be released first." % ("move a stick or squeeze a trigger" if axis else "press a controller button")

func cancel() -> void:
	choice = null
	invert = null
	if is_instance_valid(hint):
		hint.text = original_hint

func capture_event(event: InputEvent) -> bool:
	if not is_instance_valid(choice):
		return false
	if not axis_binding and event is InputEventJoypadButton and event.pressed and event.button_index < 21:
		choice.select(event.button_index + 1)
		cancel()
		return true
	if axis_binding and event is InputEventJoypadMotion and event.axis < 6 and absf(event.axis_value) >= 0.65:
		choice.select(event.axis + 1)
		invert.button_pressed = event.axis < JOY_AXIS_TRIGGER_LEFT and event.axis_value < 0.0
		cancel()
		return true
	return false

func _input(event: InputEvent) -> void:
	if choice != null and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if choice == null:
		return
	if not get_parent().visible:
		cancel()
		return
	remaining -= delta
	if remaining <= 0.0:
		cancel()
		return
	var device: int = device_provider.call()
	if device < 0 or not Input.get_connected_joypads().has(device):
		return
	if axis_binding:
		for index in 6:
			var value := Input.get_joy_axis(device, index)
			if absf(value) < 0.25:
				neutral[index] = true
			if neutral.get(index, false) and absf(value) >= 0.65:
				var event := InputEventJoypadMotion.new()
				event.axis = index
				event.axis_value = value
				capture_event(event)
				return
	else:
		for index in 21:
			var pressed := Input.is_joy_button_pressed(device, index)
			var was_held: bool = held.get(index, false)
			held[index] = pressed
			if pressed and not was_held:
				var event := InputEventJoypadButton.new()
				event.button_index = index
				event.pressed = true
				capture_event(event)
				return
