extends Node

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	if Engine.physics_ticks_per_second != 60:
		push_error("Expected 60 Hz physics")
		get_tree().quit(1)
		return
	if OS.is_debug_build():
		print("RUNTIME POLICY PASS: debug run max_fps=", Engine.max_fps)
	else:
		if Engine.max_fps != 30 or get_node("/root/ReplayRecorder").capture_requested() or ResourceLoader.exists("res://debug_replay_recorder.gd") or get_node("/root/ReplayRecorder").is_processing():
			push_error("Release frame cap or recorder exclusion failed")
			get_tree().quit(1)
			return
		print("RUNTIME POLICY PASS: release 30 FPS / 60 Hz; recorder excluded and disabled even with opt-in flag")
	get_tree().quit()
