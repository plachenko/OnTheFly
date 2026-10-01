extends Node

## Captures the live game viewport from any scene, including paused menus.
const SCREENSHOT_DIRECTORY := "user://screenshots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot") and not event.is_echo():
		get_viewport().set_input_as_handled()
		capture_screenshot.call_deferred()

func capture_screenshot() -> void:
	var directory := ProjectSettings.globalize_path(SCREENSHOT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		push_error("Could not create screenshot folder: %s" % error_string(directory_error))
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/OnTheFly_%s_%d.png" % [SCREENSHOT_DIRECTORY, stamp, Time.get_ticks_msec()]
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(path)
	if save_error == OK:
		print("Screenshot saved: ", ProjectSettings.globalize_path(path))
	else:
		push_error("Could not save screenshot: %s" % error_string(save_error))
