@tool
extends RefCounted

const PATH := "res://.godot/mcon_controller.cfg"
const BUTTON_NAMES := ["A: ray select / UI accept", "B: UI back", "X: orbit / UI context menu", "Y: focus / Inspector / View+Y scenes", "View: run / scene / panel modifier", "Guide", "Menu: flight / run chord", "L3: toggle UI mode", "R3: hold for multi-select", "LB: descend / previous control / View+LB scene", "RB: ascend / next control / View+RB scene", "D-pad up", "D-pad down", "D-pad left", "D-pad right", "Misc", "Paddle 1", "Paddle 2", "Paddle 3", "Paddle 4", "Touchpad"]
const AXIS_NAMES := ["Move horizontal / UI horizontal", "Move vertical / UI vertical", "Look horizontal", "Look vertical", "Slow trigger", "Fast trigger / dock modifier"]
const PHYSICAL_BUTTON_NAMES := ["A", "B", "X", "Y", "View", "Guide", "Menu", "L3", "R3", "LB", "RB", "D-pad up", "D-pad down", "D-pad left", "D-pad right", "Misc", "Paddle 1", "Paddle 2", "Paddle 3", "Paddle 4", "Touchpad"]
const PHYSICAL_AXIS_NAMES := ["Left stick X", "Left stick Y", "Right stick X", "Right stick Y", "LT", "RT"]
var buttons: Dictionary = {}
var axes: Dictionary = {}
var inverted: Dictionary = {}

func reset() -> void:
	buttons.clear()
	axes.clear()
	inverted.clear()

func load_profile(path: String = PATH) -> void:
	reset()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for index in BUTTON_NAMES.size():
		var value := int(config.get_value("buttons", str(index), index))
		if value >= -1 and value < PHYSICAL_BUTTON_NAMES.size():
			buttons[index] = value
	for index in AXIS_NAMES.size():
		var value := int(config.get_value("axes", str(index), index))
		if value >= -1 and value < PHYSICAL_AXIS_NAMES.size():
			axes[index] = value
		inverted[index] = bool(config.get_value("inverted", str(index), false))

func save_profile(path: String = PATH) -> Error:
	var config := ConfigFile.new()
	for index in BUTTON_NAMES.size():
		config.set_value("buttons", str(index), buttons.get(index, index))
	for index in AXIS_NAMES.size():
		config.set_value("axes", str(index), axes.get(index, index))
		config.set_value("inverted", str(index), inverted.get(index, false))
	return config.save(path)

func button(device: int, logical: int) -> bool:
	var physical := int(buttons.get(logical, logical))
	return physical >= 0 and Input.is_joy_button_pressed(device, physical)

func axis(device: int, logical: int) -> float:
	var physical := int(axes.get(logical, logical))
	if physical < 0:
		return 0.0
	return transform_axis(logical, Input.get_joy_axis(device, physical))

func transform_axis(logical: int, value: float) -> float:
	if not inverted.get(logical, false):
		return value
	return 1.0 - value if logical >= JOY_AXIS_TRIGGER_LEFT else -value

func build_dialog(parent: Control, saved: Callable, device_provider: Callable = func(): return 0) -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "Controller mapping"
	dialog.ok_button_text = "Save mapping"
	dialog.add_cancel_button("Cancel")
	dialog.min_size = Vector2i(650, 540)
	parent.add_child(dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(630, 470)
	dialog.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	var hint := Label.new()
	hint.text = "Choose physical inputs for each role. Bindings apply to this project's editor.\nDuplicate bindings trigger both roles in the same mode. Defaults use Xbox labels."
	layout.add_child(hint)
	var listener := preload("res://addons/mcon_viewport/binding_listener.gd").new()
	listener.hint = hint
	listener.original_hint = hint.text
	listener.device_provider = device_provider
	dialog.add_child(listener)
	var grid := GridContainer.new()
	grid.columns = 4
	layout.add_child(grid)
	var button_controls: Array[OptionButton] = []
	var axis_controls: Array[OptionButton] = []
	var invert_controls: Array[CheckBox] = []
	for index in BUTTON_NAMES.size():
		var label := Label.new()
		label.text = BUTTON_NAMES[index]
		grid.add_child(label)
		var choice := input_choice(PHYSICAL_BUTTON_NAMES, int(buttons.get(index, index)))
		grid.add_child(choice)
		button_controls.append(choice)
		grid.add_child(Control.new())
		var listen := Button.new()
		listen.text = "Listen…"
		listen.pressed.connect(func(): listener.begin(choice, false))
		grid.add_child(listen)
	for index in AXIS_NAMES.size():
		var label := Label.new()
		label.text = AXIS_NAMES[index]
		grid.add_child(label)
		var choice := input_choice(PHYSICAL_AXIS_NAMES, int(axes.get(index, index)))
		grid.add_child(choice)
		axis_controls.append(choice)
		var invert := CheckBox.new()
		invert.text = "Invert"
		invert.button_pressed = inverted.get(index, false)
		grid.add_child(invert)
		invert_controls.append(invert)
		var listen := Button.new()
		listen.text = "Listen…"
		listen.pressed.connect(func(): listener.begin(choice, true, invert))
		grid.add_child(listen)
	var defaults := dialog.add_button("Restore defaults", false, "defaults")
	defaults.pressed.connect(func():
		listener.cancel()
		for index in button_controls.size():
			button_controls[index].select(index + 1)
		for index in axis_controls.size():
			axis_controls[index].select(index + 1)
			invert_controls[index].button_pressed = false
	)
	dialog.confirmed.connect(func():
		listener.cancel()
		for index in button_controls.size():
			buttons[index] = button_controls[index].selected - 1
		for index in axis_controls.size():
			axes[index] = axis_controls[index].selected - 1
			inverted[index] = invert_controls[index].button_pressed
		saved.call(save_profile())
	)
	dialog.close_requested.connect(dialog.hide)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			listener.cancel()
	)
	return dialog

func input_choice(names: Array, value: int) -> OptionButton:
	var choice := OptionButton.new()
	choice.add_item("Disabled")
	for name in names:
		choice.add_item(name)
	choice.select(value + 1)
	return choice
