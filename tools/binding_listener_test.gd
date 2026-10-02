extends SceneTree

func _initialize() -> void:
	var mapping = load("res://addons/mcon_viewport/controller_mapping.gd").new()
	var listener = load("res://addons/mcon_viewport/binding_listener.gd").new()
	listener.hint = Label.new()
	listener.original_hint = "Choose a binding"
	listener.device_provider = func(): return -1
	var buttons: OptionButton = mapping.input_choice(mapping.PHYSICAL_BUTTON_NAMES, 0)
	var axes: OptionButton = mapping.input_choice(mapping.PHYSICAL_AXIS_NAMES, 0)
	var invert := CheckBox.new()
	listener.begin(buttons, false)
	var motion := InputEventJoypadMotion.new()
	motion.axis = 3
	motion.axis_value = -1.0
	assert(not listener.capture_event(motion))
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_RIGHT_SHOULDER
	button.pressed = true
	assert(listener.capture_event(button))
	assert(buttons.selected == JOY_BUTTON_RIGHT_SHOULDER + 1)
	assert(listener.choice == null and listener.hint.text == listener.original_hint)
	listener.begin(axes, true, invert)
	motion.axis_value = 0.1
	assert(not listener.capture_event(motion))
	motion.axis_value = -0.8
	assert(listener.capture_event(motion))
	assert(axes.selected == 4 and invert.button_pressed)
	listener.begin(axes, true, invert)
	motion.axis = JOY_AXIS_TRIGGER_RIGHT
	motion.axis_value = 0.9
	assert(listener.capture_event(motion))
	assert(axes.selected == JOY_AXIS_TRIGGER_RIGHT + 1 and not invert.button_pressed)
	listener.begin(buttons, false)
	listener.cancel()
	assert(not listener.capture_event(button))
	assert(mapping.buttons.is_empty(), "Listening changes draft controls until Save mapping")
	var parent := Control.new()
	root.add_child(parent)
	var dialog: AcceptDialog = mapping.build_dialog(parent, func(_error): pass, func(): return -1)
	var choices = dialog.find_children("*", "OptionButton", true, false)
	var listens: Array[Button] = []
	for control in dialog.find_children("*", "Button", true, false):
		if control.text == "Listen…":
			listens.append(control)
	assert(listens.size() == choices.size() and listens.size() == 27)
	var capture = dialog.get_child(dialog.get_child_count() - 1)
	for child in dialog.get_children():
		if child.has_method("capture_event"):
			capture = child
	for index in listens.size():
		listens[index].pressed.emit()
		assert(capture.choice == choices[index], "Listen must target its own row")
	capture.cancel()
	parent.free()
	listener.hint.free()
	listener.free()
	buttons.free()
	axes.free()
	invert.free()
	print("BINDING LISTENER PASS: buttons, axes, threshold, inversion, trigger capture, cancel, draft-only changes")
	quit()
