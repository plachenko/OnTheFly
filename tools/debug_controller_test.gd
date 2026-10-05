extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func button(index: int, pressed: bool, device: int = 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index as JoyButton
	event.pressed = pressed
	return event

func run() -> void:
	var debug := root.get_node("DebugMenu")
	debug.controller_quit_requested.disconnect(debug.quit_game)
	var quits := [0]
	debug.controller_quit_requested.connect(func(): quits[0] += 1)
	debug.panel.hide()
	debug.handle_controller_button(button(JOY_BUTTON_BACK, true))
	assert(not debug.panel.visible)
	debug.handle_controller_button(button(JOY_BUTTON_BACK, false))
	assert(debug.panel.visible)
	paused = true
	debug.handle_controller_button(button(JOY_BUTTON_BACK, true))
	debug.handle_controller_button(button(JOY_BUTTON_BACK, false))
	assert(not debug.panel.visible)
	debug.handle_controller_button(button(JOY_BUTTON_BACK, true))
	debug.handle_controller_button(button(JOY_BUTTON_A, true))
	assert(quits[0] == 1 and not debug.panel.visible)
	debug.handle_controller_button(button(JOY_BUTTON_A, true))
	assert(quits[0] == 1)
	debug.handle_controller_button(button(JOY_BUTTON_A, false))
	debug.handle_controller_button(button(JOY_BUTTON_BACK, false))
	assert(not debug.panel.visible)
	debug.handle_controller_button(button(JOY_BUTTON_A, true))
	debug.handle_controller_button(button(JOY_BUTTON_BACK, true))
	assert(quits[0] == 2)
	debug.controller_connection_changed(0, false)
	debug.handle_controller_button(button(JOY_BUTTON_BACK, true, 0))
	debug.handle_controller_button(button(JOY_BUTTON_A, true, 1))
	assert(quits[0] == 2)
	debug.controller_connection_changed(0, false)
	debug.controller_connection_changed(1, false)
	assert(not debug.is_view_held(0))
	paused = false
	print("DEBUG CONTROLLER PASS: View toggle, paused input, View+A both orders, no menu flash, repeat suppression, separate devices and disconnect cleanup")
	quit()
