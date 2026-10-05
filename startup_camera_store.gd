extends RefCounted

static func valid_pose(pose: Variant) -> bool:
	return preload("res://camera_timeline.gd").valid_document({
		"format": "onthefly.camera_timeline", "version": 1,
		"space": "truck_relative", "duration": 1.0,
		"keys": [{"time": 0.0, "pose": pose}]})

static func read_pose(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	return parser.data if valid_pose(parser.data) else {}

static func write_pose(path: String, pose: Dictionary) -> Error:
	if not valid_pose(pose): return ERR_INVALID_DATA
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(pose, "\t"))
	file.flush()
	return file.get_error()

static func apply_to_menu(camera: Camera3D, truck: Node3D, pose: Dictionary) -> void:
	camera.global_transform = Transform3D(truck.global_basis.orthonormalized(), truck.global_position) * preload("res://camera_timeline.gd").pose_transform(pose, true)
	camera.fov = pose.fov
	camera.near = pose.near
	camera.far = pose.far
	camera.h_offset = pose.horizontal_offset
	camera.v_offset = pose.vertical_offset
