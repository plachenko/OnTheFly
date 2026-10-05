extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var controls = root.get_node("DrivingControls")
	controls.update_signal_key("left", true, 1000)
	assert(controls.pending_direction_signal == 0)
	controls.update_signal_key("left", true, 1100)
	assert(controls.pending_direction_signal == 0, "Held key is not a second tap")
	controls.update_signal_key("left", false, 1150)
	controls.update_signal_key("left", true, 1200)
	assert(controls.pending_direction_signal == -1)
	controls.pending_direction_signal = 0
	controls.update_signal_stick(0, 0.0, 2000)
	controls.update_signal_stick(0, 0.3, 2010)
	controls.update_signal_stick(0, 0.9, 2100)
	assert(controls.pending_direction_signal == 1)
	controls.pending_direction_signal = 0
	controls.update_signal_stick(0, 1.0, 2150)
	assert(controls.pending_direction_signal == 0, "Held stick does not repeat")
	controls.update_signal_stick(0, 0.0, 2300)
	controls.update_signal_stick(0, -0.3, 2310)
	controls.update_signal_stick(0, -0.9, 2700)
	assert(controls.pending_direction_signal == 0, "Slow steering is not a flick")
	controls.queue_direction_signal(-1, Time.get_ticks_msec())
	assert(not controls.direction_signal_just_pressed("direction_signal_right"))
	assert(controls.direction_signal_just_pressed("direction_signal_left"))
	assert(not controls.direction_signal_just_pressed("direction_signal_left"))
	print("Direction signal gestures passed")
	quit()
