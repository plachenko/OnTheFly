extends Node

## Release-safe autoload. Capture is opt-in even in editor/debug builds.
## Run with -- --debug-replay-capture or enable debug/replay_capture/enabled.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	if not capture_requested(): return
	enable_capture()

func enable_capture() -> bool:
	if not OS.is_debug_build(): return false
	# Dynamic loading lets the release export preset omit this implementation.
	var implementation := load("res://debug_replay_recorder.gd") as Script
	if implementation == null: return false
	set_script(implementation)
	set_process_input(true)
	call("initialize_capture")
	return true

func capture_requested() -> bool:
	return OS.is_debug_build() and (bool(ProjectSettings.get_setting("debug/replay_capture/enabled", false)) or "--debug-replay-capture" in OS.get_cmdline_user_args())
