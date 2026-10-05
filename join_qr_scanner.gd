extends AcceptDialog

signal connection_scanned(connection: Dictionary)
var camera: NativeCamera
var decoder: QR
var preview: TextureRect
var status: Label
var busy := false

func _ready() -> void:
	title = "Scan lobby QR"
	ok_button_text = "Cancel"
	var column := VBoxContainer.new()
	add_child(column)
	status = Label.new()
	status.text = "Point the camera at the host's lobby QR code."
	column.add_child(status)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(420, 280)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(preview)
	camera = NativeCamera.new()
	camera.frames_to_skip = 8
	camera.auto_upright = true
	add_child(camera)
	decoder = QR.new()
	add_child(decoder)
	camera.camera_permission_granted.connect(start_camera)
	camera.camera_permission_denied.connect(func(): status.text = "Camera permission is needed to scan. Enable it in Android settings.")
	camera.frame_available.connect(scan_frame)
	decoder.qr_detected.connect(receive_code)
	decoder.qr_scan_failed.connect(func(_error): busy = false)
	visibility_changed.connect(func():
		if not visible: camera.stop(); queue_free())
	if camera.has_camera_permission(): start_camera()
	else: camera.request_camera_permission()

func start_camera() -> void:
	var cameras := camera.get_all_cameras()
	if cameras.is_empty():
		status.text = "No camera is available."
		return
	var selected: CameraInfo = cameras[0]
	for candidate in cameras:
		if not candidate.is_front_facing(): selected = candidate; break
	camera.start(camera.create_feed_request().set_camera_id(selected.get_camera_id()))

func scan_frame(frame: FrameInfo) -> void:
	if not visible: return
	var image := frame.get_image()
	preview.texture = ImageTexture.create_from_image(image)
	if busy: return
	busy = true
	decoder.scan_qr_image(image)

func receive_code(value: String) -> void:
	busy = false
	var connection: Dictionary = preload("res://join_code.gd").decode(value)
	if connection.is_empty():
		status.text = "This is not an OnTheFly lobby QR. Scan the host's lobby code."
		return
	connection_scanned.emit(connection)
	hide()

func _exit_tree() -> void:
	if is_instance_valid(camera): camera.stop()
