extends SceneTree

func _initialize() -> void:
	var mapping = load("res://addons/mcon_viewport/controller_mapping.gd").new()
	assert(mapping.buttons.get(JOY_BUTTON_A, JOY_BUTTON_A) == JOY_BUTTON_A)
	mapping.buttons[JOY_BUTTON_A] = JOY_BUTTON_RIGHT_STICK
	mapping.buttons[JOY_BUTTON_X] = -1
	mapping.axes[JOY_AXIS_RIGHT_Y] = JOY_AXIS_LEFT_Y
	mapping.inverted[JOY_AXIS_RIGHT_Y] = true
	mapping.inverted[JOY_AXIS_TRIGGER_LEFT] = true
	assert(is_equal_approx(mapping.transform_axis(JOY_AXIS_RIGHT_Y, 0.75), -0.75))
	assert(is_equal_approx(mapping.transform_axis(JOY_AXIS_TRIGGER_LEFT, 0.25), 0.75))
	assert(not mapping.button(0, JOY_BUTTON_X))
	var path := "res://.godot/controller_mapping_test.cfg"
	assert(mapping.save_profile(path) == OK)
	var restored = load("res://addons/mcon_viewport/controller_mapping.gd").new()
	restored.load_profile(path)
	assert(restored.buttons[JOY_BUTTON_A] == JOY_BUTTON_RIGHT_STICK)
	assert(restored.buttons[JOY_BUTTON_X] == -1)
	assert(restored.axes[JOY_AXIS_RIGHT_Y] == JOY_AXIS_LEFT_Y)
	assert(restored.inverted[JOY_AXIS_RIGHT_Y])
	restored.reset()
	assert(restored.buttons.is_empty() and restored.axes.is_empty() and restored.inverted.is_empty())
	DirAccess.remove_absolute(path)
	print("CONTROLLER MAPPING PASS: defaults, button/axis remap persistence, disabled input, inversions and reset")
	quit()
