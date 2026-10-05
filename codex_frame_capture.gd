extends Node

signal changed
signal status_changed(message: String)
const FRAME_INTERVAL := 0.2
const MAX_SECONDS := 30.0
var captures: Array[Dictionary] = []
var active: Dictionary = {}
var recording := false
var capturing := false
var elapsed := 0.0
var next_frame := 0.0

func begin() -> void:
	if capturing or recording: return
	active = {"paths": [], "times_us": [], "thumbnail": null}
	recording = true
	elapsed = 0.0
	next_frame = 0.0
	capture_one()

func finish() -> void:
	recording = false
	if not capturing: commit()

func _process(delta: float) -> void:
	if not recording: return
	elapsed += delta
	next_frame -= delta
	if elapsed >= MAX_SECONDS:
		finish()
	elif next_frame <= 0 and not capturing:
		capture_one()

func read_frame() -> Dictionary:
	var source := get_node_or_null("/root/ScreenshotCapture")
	if source == null or source.capture_in_progress or DisplayServer.get_name() == "headless": return {}
	var previous: String = source.last_screenshot_path
	await source.capture_screenshot(true)
	if source.last_screenshot_path == previous: return {}
	var path := ProjectSettings.globalize_path(source.last_screenshot_path)
	return {"path": path, "time_us": Time.get_ticks_usec()}

func capture_one() -> void:
	capturing = true
	next_frame = FRAME_INTERVAL
	var frame := await read_frame()
	if not frame.is_empty():
		active.paths.append(frame.path)
		active.times_us.append(frame.time_us)
		if active.thumbnail == null:
			var image := Image.load_from_file(frame.path)
			if image != null and not image.is_empty():
				var ratio := minf(160.0 / image.get_width(), 90.0 / image.get_height())
				image.resize(maxi(1, int(image.get_width() * ratio)), maxi(1, int(image.get_height() * ratio)))
				active.thumbnail = ImageTexture.create_from_image(image)
	capturing = false
	if not recording: commit()

func commit() -> void:
	if active.is_empty(): return
	if not active.paths.is_empty():
		captures.append(active)
		status_changed.emit("Added %d captured frame(s)." % active.paths.size())
		changed.emit()
	else: status_changed.emit("No frame captured. Try again when rendering is available.")
	active = {}

func attachments() -> Array:
	var result: Array = []
	for capture in captures:
		for index in capture.paths.size():
			var path: String = capture.paths[index]
			var camera_path := path.get_basename() + ".camera.json"
			result.append({"path": path, "time_us": capture.times_us[index], "camera": JSON.parse_string(FileAccess.get_file_as_string(camera_path)) if FileAccess.file_exists(camera_path) else {}})
	return result

func clear() -> void:
	captures.clear()
	changed.emit()
