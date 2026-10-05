extends Node

## Opt-in debug JPEG replay buffer; omitted from release exports.
## AVI layout: https://learn.microsoft.com/en-us/windows/win32/directshow/avi-riff-file-reference
const FPS := 15
const BUFFER_FRAMES := FPS * 5
const FRAME_SIZE := Vector2i(640, 360)
const DIRECTORY := "user://videos"
signal screenshot_requested
const HOLD_MS := 500
var frames: Array[PackedByteArray] = []
var frame_times: Array[int] = []
var clip_frame_times: Array[int] = []
var elapsed := 0.0
var capture_pending := false
var held_device := -999
var held_started := 0
var held_video := false
var recording: FileAccess
var clip_path := ""
var frame_count := 0
var index := PackedByteArray()
var movie_start := 0
var notice: Label
var notice_time := 0.0

func initialize_capture() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screenshot_requested.connect(get_node("/root/ScreenshotCapture").capture_screenshot.call_deferred)
	# Dummy rendering cannot supply viewport images (headless tests/server).
	set_process(DisplayServer.get_name() != "headless")
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	notice = Label.new()
	notice.size = Vector2(435, 70)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 15)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	notice.add_theme_constant_override("shadow_offset_x", 1)
	notice.add_theme_constant_override("shadow_offset_y", 1)
	overlay.add_child(notice)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and get_node("/root/PerformanceDiagnostics").profile_shortcut.enabled: return
	var shoulder: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER
	var keyboard: bool = event is InputEventKey and event.physical_keycode == KEY_F9 and not event.echo
	if not shoulder and not keyboard:
		return
	get_viewport().set_input_as_handled()
	var device: int = event.device if shoulder else -2
	var now := Time.get_ticks_msec()
	if event.pressed:
		if held_device == -999:
			held_device = device
			held_started = now
			held_video = false
	elif device == held_device:
		update_hold(now)
		if held_video:
			finish_clip()
		else:
			screenshot_requested.emit()
		held_device = -999
		held_video = false

func update_hold(now_ms: int) -> void:
	if held_device != -999 and not held_video and now_ms - held_started >= HOLD_MS:
		held_video = true
		start_clip()

func _process(delta: float) -> void:
	if get_node("/root/PerformanceDiagnostics").profile_shortcut.enabled:
		if recording != null: finish_clip()
		held_device = -999
		held_video = false
		elapsed = 0.0
		frames.clear()
		frame_times.clear()
		return
	update_hold(Time.get_ticks_msec())
	var viewport_size := get_viewport().get_visible_rect().size
	var unit := minf(viewport_size.x / 1280.0, viewport_size.y / 800.0)
	notice.scale = Vector2.ONE * unit
	notice.position = Vector2((viewport_size.x - 435 * unit) * 0.5, 190 * unit)
	notice_time = maxf(0, notice_time - delta)
	if recording != null:
		notice.text = "REC  %.1fs  •  Release F9 to save" % (float(frame_count) / FPS)
	elif notice_time <= 0:
		notice.text = ""
	elapsed += delta
	if elapsed >= 1.0 / FPS and not capture_pending:
		capture_pending = true
		capture_frame()

func capture_frame() -> void:
	if not OS.is_debug_build(): return
	await RenderingServer.frame_post_draw
	var copies := mini(BUFFER_FRAMES, int(elapsed * FPS))
	elapsed = fmod(elapsed, 1.0 / FPS)
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		# Fixed letterboxed dimensions keep clips valid across window resizing.
		var ratio := minf(float(FRAME_SIZE.x) / image.get_width(), float(FRAME_SIZE.y) / image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)))
		image.convert(Image.FORMAT_RGB8)
		var canvas := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGB8)
		canvas.fill(Color.BLACK)
		canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(Vector2(FRAME_SIZE - image.get_size()) / 2.0))
		var jpeg := canvas.save_jpg_to_buffer(0.7)
		var captured_at := Time.get_ticks_usec()
		for i in copies:
			frames.append(jpeg)
			frame_times.append(captured_at)
			if frames.size() > BUFFER_FRAMES:
				frames.pop_front()
				frame_times.pop_front()
			if recording != null:
				clip_frame_times.append(captured_at)
				append_frame(jpeg)
	capture_pending = false

func show_notice(message: String) -> void:
	if is_instance_valid(notice):
		notice.text = message
	notice_time = 8.0
	print(message)

func start_clip() -> void:
	if not OS.is_debug_build(): return
	if frames.is_empty():
		show_notice("Video buffer warming up — try again shortly")
		return
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	if error != OK:
		show_notice("Cannot create video folder: " + error_string(error))
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	clip_path = "%s/OnTheFly_%s_%d.avi" % [DIRECTORY, stamp, Time.get_ticks_msec()]
	recording = FileAccess.open(clip_path, FileAccess.WRITE)
	if recording == null:
		show_notice("Cannot record video: " + error_string(FileAccess.get_open_error()))
		return
	frame_count = 0
	clip_frame_times = frame_times.duplicate()
	get_node("/root/PerformanceDiagnostics").begin_video_tracking()
	index.clear()
	recording.store_buffer(header(0, 4, 0))
	movie_start = recording.get_position() - 4 # Offsets are relative to 'movi'.
	for frame in frames:
		if recording != null:
			append_frame(frame)
	if recording != null:
		print("Video recording started: ", ProjectSettings.globalize_path(clip_path), " (includes %.1fs replay buffer)" % (float(frame_count) / FPS))

func append_frame(jpeg: PackedByteArray) -> void:
	if not OS.is_debug_build() or recording == null: return
	var offset := recording.get_position() - movie_start
	recording.store_buffer(chunk("00dc", jpeg))
	index.append_array("00dc".to_ascii_buffer())
	index.append_array(words([0x10, offset, jpeg.size()]))
	frame_count += 1
	if recording.get_error() != OK:
		var failed_path := clip_path
		recording.close()
		recording = null
		get_node("/root/PerformanceDiagnostics").save_video_report(failed_path.get_basename() + ".performance.json", clip_frame_times, FPS)
		show_notice("Video write failed: " + ProjectSettings.globalize_path(failed_path))
	elif recording.get_position() > 1024 * 1024 * 1024:
		finish_clip() # Stay safely below classic AVI's size limit.

func finish_clip() -> void:
	if recording == null:
		return
	var movie_size := recording.get_position() - movie_start
	recording.store_buffer(chunk("idx1", index))
	var total_size := recording.get_position()
	recording.seek(0)
	recording.store_buffer(header(total_size - 8, movie_size, frame_count))
	recording.flush()
	var error := recording.get_error()
	recording.close()
	recording = null
	index.clear()
	print("Video path: ", ProjectSettings.globalize_path(clip_path))
	var report_path := clip_path.get_basename() + ".performance.json"
	var report_error: Error = get_node("/root/PerformanceDiagnostics").save_video_report(report_path, clip_frame_times, FPS)
	if report_error != OK:
		show_notice("Performance report failed: " + error_string(report_error))
		return
	print("Performance report: ", ProjectSettings.globalize_path(report_path))
	show_notice(("Video saved: " if error == OK else "Video save failed: ") + clip_path.get_file())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finish_clip()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if held_video:
			finish_clip()
		held_device = -999
		held_video = false

func _exit_tree() -> void:
	finish_clip()

static func words(values: Array) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(values.size() * 4)
	for i in values.size():
		result.encode_u32(i * 4, int(values[i]))
	return result

static func chunk(tag: String, data: PackedByteArray) -> PackedByteArray:
	var result := tag.to_ascii_buffer()
	result.append_array(words([data.size()]))
	result.append_array(data)
	if data.size() % 2:
		result.append(0)
	return result

static func header(riff_size: int, movie_size: int, count: int) -> PackedByteArray:
	var avih := words([roundi(1000000.0 / FPS), 0, 0, 0x10, maxi(0, count), 0, 1, 0, FRAME_SIZE.x, FRAME_SIZE.y, 0, 0, 0, 0])
	var strh := "vidsMJPG".to_ascii_buffer()
	strh.append_array(words([0, 0, 0, 1, FPS, 0, maxi(0, count), 0, 0xffffffff, 0]))
	var rect := PackedByteArray()
	rect.resize(8)
	rect.encode_u16(4, FRAME_SIZE.x)
	rect.encode_u16(6, FRAME_SIZE.y)
	strh.append_array(rect)
	var strf := words([40, FRAME_SIZE.x, FRAME_SIZE.y, 0x00180001])
	strf.append_array("MJPG".to_ascii_buffer())
	strf.append_array(words([FRAME_SIZE.x * FRAME_SIZE.y * 3, 0, 0, 0, 0]))
	var stream := "strl".to_ascii_buffer()
	stream.append_array(chunk("strh", strh))
	stream.append_array(chunk("strf", strf))
	var headers := "hdrl".to_ascii_buffer()
	headers.append_array(chunk("avih", avih))
	headers.append_array(chunk("LIST", stream))
	var result := "RIFF".to_ascii_buffer()
	result.append_array(words([riff_size]))
	result.append_array("AVI ".to_ascii_buffer())
	result.append_array(chunk("LIST", headers))
	result.append_array("LIST".to_ascii_buffer())
	result.append_array(words([movie_size]))
	result.append_array("movi".to_ascii_buffer())
	return result
