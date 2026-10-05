extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var folder := "res://.godot/drive-export-test/" + str(Time.get_ticks_usec())
	assert(DirAccess.make_dir_recursive_absolute(folder.path_join("source")) == OK)
	assert(DirAccess.make_dir_recursive_absolute(folder.path_join("destination")) == OK)
	var image_path := folder.path_join("source/reference.png")
	var camera_path := image_path.get_basename() + ".camera.json"
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	assert(image.save_png(image_path) == OK)
	var file := FileAccess.open(camera_path, FileAccess.WRITE)
	file.store_string('{"version":2,"fov":60}')
	file.close()
	var exporter := preload("res://screenshot_drive_export.gd")
	var destination := folder.path_join("destination")
	var result := exporter.copy_capture(image_path, destination)
	assert(result.error.is_empty())
	assert(FileAccess.get_file_as_bytes(result.image) == FileAccess.get_file_as_bytes(image_path))
	assert(FileAccess.get_file_as_bytes(result.camera) == FileAccess.get_file_as_bytes(camera_path))
	assert(exporter.copy_capture(image_path, destination).error.is_empty(), "Repeat save should be harmless")
	file = FileAccess.open(result.camera, FileAccess.WRITE)
	file.store_string("existing unrelated file")
	file.close()
	assert(not exporter.copy_capture(image_path, destination).error.is_empty())
	assert(FileAccess.get_file_as_string(result.camera) == "existing unrelated file")
	assert(not exporter.copy_capture(image_path, folder.path_join("missing")).error.is_empty())
	var capture = root.get_node("ScreenshotCapture")
	assert(capture.drive_button != null and capture.drive_button.disabled)
	capture.last_screenshot_path = image_path
	capture.drive_folder = destination
	capture.save_to_drive_folder()
	assert(capture.drive_status.text.contains("different file"))
	print("DRIVE EXPORT PASS: PNG and camera JSON copied unchanged, repeat safe, conflicts preserved, missing folder handled, screenshot UI reports errors")
	quit()
