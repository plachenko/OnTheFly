extends PanelContainer

const FORMAT := "onthefly.camera_timeline"
var document := {"format": FORMAT, "version": 1, "space": "truck_relative", "sample_rate": 30, "duration": 1.0, "keys": []}
var recording := false
var playing := false
var cursor := 0.0
var elapsed := 0.0
var next_sample := 0.0
var selected := 0
var paused_for_scrub := false
var previous_pause := false
var controlled_scene: Node
var timeline: Control
var status: Label
var record_button: Button
var relative_button: CheckButton
var duration_control: SpinBox

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := VBoxContainer.new()
	add_child(column)
	status = Label.new()
	status.text = "CAMERA TIMELINE · Double LB, hold to record, release to scrub"
	column.add_child(status)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	record_button = add_button(actions, "Record", toggle_record)
	add_button(actions, "Play", play)
	add_button(actions, "Stop", func():
		if recording: stop_record()
		else: stop_playback())
	add_button(actions, "Add key", add_key)
	add_button(actions, "Resume game", resume_game)
	add_button(actions, "Export JSON", export_dialog)
	add_button(actions, "Import JSON", import_dialog)
	relative_button = CheckButton.new()
	relative_button.text = "Relative to truck"
	relative_button.button_pressed = true
	relative_button.toggled.connect(func(enabled: bool):
		if not recording:
			document.space = "truck_relative" if enabled else "world"
			scrub(cursor))
	column.add_child(relative_button)
	duration_control = SpinBox.new()
	duration_control.min_value = .001
	duration_control.max_value = 3600
	duration_control.step = .001
	duration_control.suffix = "seconds"
	duration_control.value_changed.connect(func(value: float):
		if recording: return
		var minimum: float = float(document.keys[-1].time) if not document.keys.is_empty() else .001
		document.duration = maxf(value, minimum)
		cursor = minf(cursor, document.duration)
		refresh())
	column.add_child(duration_control)
	timeline = preload("res://exaggeration_timeline.gd").new()
	column.add_child(timeline)
	timeline.pose_sampler = graph_pose
	timeline.scrubbed.connect(scrub)
	timeline.key_selected.connect(func(index: int): selected = index; scrub(float(document.keys[index].time)))
	timeline.key_retimed.connect(retime_key)
	refresh()

func add_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func start_record() -> void:
	var scene: Node = get_node("/root/ScreenshotCapture").camera_scene()
	if scene == null: return
	stop_playback()
	resume_game()
	controlled_scene = scene
	previous_pause = get_tree().paused
	get_tree().paused = false
	scene.set_free_camera_look(true)
	document.keys = []
	document.duration = 0.0
	document.scene = scene.scene_file_path
	document.reference = scene.camera_view_state()
	recording = true
	cursor = 0.0
	elapsed = 0.0
	next_sample = 1.0 / 30.0
	record_pose(0.0)
	show()
	refresh()

func stop_record(pause_to_scrub: bool = true) -> void:
	if not recording: return
	recording = false
	record_pose(elapsed)
	document.duration = maxf(elapsed, .001)
	cursor = document.duration
	if pause_to_scrub:
		paused_for_scrub = true
		get_tree().paused = true
	else: get_tree().paused = previous_pause
	show()
	refresh()

func toggle_record() -> void:
	if recording: stop_record()
	else: start_record()

func record_pose(time: float) -> void:
	if not is_instance_valid(controlled_scene): return
	var key := {"time": time, "label": "", "pose": controlled_scene.camera_view_state()}
	if not document.keys.is_empty() and is_equal_approx(float(document.keys[-1].time), time): document.keys[-1] = key
	else: document.keys.append(key)
	document.duration = maxf(.001, time)

func _process(delta: float) -> void:
	if (recording or playing or paused_for_scrub) and (not is_instance_valid(controlled_scene) or get_node("/root/ScreenshotCapture").camera_scene() != controlled_scene):
		if recording: stop_record(false)
		stop_playback()
		resume_game()
		controlled_scene = null
	if recording:
		elapsed += delta
		cursor = elapsed
		if elapsed >= next_sample:
			next_sample = elapsed + 1.0 / 30.0
			record_deferred.call_deferred(elapsed)
		refresh()
	elif playing:
		cursor = minf(float(document.duration), cursor + delta)
		apply_pose(cursor)
		if cursor >= float(document.duration): stop_playback()
		refresh()

func record_deferred(time: float) -> void:
	if recording: record_pose(time)

func play() -> void:
	if recording: stop_record()
	if document.keys.is_empty(): return
	controlled_scene = get_node("/root/ScreenshotCapture").camera_scene()
	if controlled_scene == null: return
	controlled_scene.set_free_camera_look(true)
	controlled_scene.camera_timeline_playing = true
	if cursor >= float(document.duration): cursor = 0.0
	playing = true
	apply_pose(cursor)
	refresh()

func stop_playback() -> void:
	playing = false
	if is_instance_valid(controlled_scene): controlled_scene.camera_timeline_playing = false

func scrub(time: float) -> void:
	if recording: return
	stop_playback()
	cursor = clampf(time, 0, float(document.duration))
	apply_pose(cursor)
	refresh()

func apply_pose(time: float) -> void:
	var scene: Node = get_node("/root/ScreenshotCapture").camera_scene()
	var pose := sample_pose(document, time)
	if scene != null and not pose.is_empty(): scene.restore_camera_view(pose, document.space == "truck_relative")

static func pose_transform(pose: Dictionary, relative: bool) -> Transform3D:
	var prefix := "truck_relative_" if relative else ""
	var p: Array = pose[prefix + "position"]
	var x: Array = pose[prefix + "basis_x"]
	var y: Array = pose[prefix + "basis_y"]
	var z: Array = pose[prefix + "basis_z"]
	return Transform3D(Basis(Vector3(x[0], x[1], x[2]), Vector3(y[0], y[1], y[2]), Vector3(z[0], z[1], z[2])), Vector3(p[0], p[1], p[2]))

static func sample_pose(clip: Dictionary, time: float) -> Dictionary:
	var keys: Array = clip.get("keys", [])
	if keys.is_empty(): return {}
	if time <= float(keys[0].time): return keys[0].pose.duplicate(true)
	if time >= float(keys[-1].time): return keys[-1].pose.duplicate(true)
	var left := 0
	var right := keys.size() - 1
	while right - left > 1:
		var middle := (left + right) >> 1
		if float(keys[middle].time) <= time: left = middle
		else: right = middle
	var a: Dictionary = keys[left].pose
	var b: Dictionary = keys[right].pose
	var fraction := (time - float(keys[left].time)) / (float(keys[right].time) - float(keys[left].time))
	var result := a.duplicate(true)
	for relative in [false, true]:
		var transform := pose_transform(a, relative).interpolate_with(pose_transform(b, relative), fraction)
		var prefix := "truck_relative_" if relative else ""
		result[prefix + "position"] = [transform.origin.x, transform.origin.y, transform.origin.z]
		for axis in ["x", "y", "z"]:
			var value: Vector3 = transform.basis["xyz".find(axis)]
			result[prefix + "basis_" + axis] = [value.x, value.y, value.z]
	for field in ["fov", "near", "far", "horizontal_offset", "vertical_offset", "orbit_yaw_degrees", "orbit_pitch_degrees", "orbit_distance"]:
		result[field] = lerpf(float(a[field]), float(b[field]), fraction)
	return result

func graph_pose(time: float) -> Dictionary:
	var pose := sample_pose(document, time)
	return {"pitch": float(pose.get("orbit_pitch_degrees", 0)), "roll": rad_to_deg(pose_transform(pose, true).basis.get_euler().z) if not pose.is_empty() else 0.0}

func add_key() -> void:
	if recording: return
	var scene: Node = get_node("/root/ScreenshotCapture").camera_scene()
	if scene == null: return
	var key := {"time": cursor, "label": "Key", "pose": scene.camera_view_state()}
	for index in document.keys.size():
		if is_equal_approx(float(document.keys[index].time), cursor):
			document.keys[index] = key
			refresh()
			return
	document.keys.append(key)
	document.keys.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.time) < float(b.time))
	refresh()

func retime_key(index: int, time: float) -> void:
	if recording: return
	var low := float(document.keys[index - 1].time) + .001 if index > 0 else 0.0
	var high := float(document.keys[index + 1].time) - .001 if index + 1 < document.keys.size() else float(document.duration)
	if low > high: return
	document.keys[index].time = clampf(time, low, high)
	selected = index
	scrub(float(document.keys[index].time))

func resume_game() -> void:
	stop_playback()
	if paused_for_scrub:
		get_tree().paused = previous_pause
		paused_for_scrub = false
	refresh()

func refresh() -> void:
	if timeline == null: return
	timeline.clip = document
	timeline.playhead = cursor
	timeline.selected = selected
	timeline.queue_redraw()
	record_button.text = "Stop recording" if recording else "Record"
	duration_control.editable = not recording
	duration_control.set_value_no_signal(document.duration)
	status.text = "CAMERA · %.3f / %.3fs · %d samples · %s" % [cursor, document.duration, document.keys.size(), "Recording" if recording else ("Playing" if playing else ("Paused: scrub or Resume game" if paused_for_scrub else "Ready"))]

func export_dialog() -> void:
	if recording: stop_record()
	if document.keys.is_empty():
		status.text = "Record camera movement or add a key before exporting."
		return
	var dialog := FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.json ; Camera timeline"])
	dialog.current_file = "camera_timeline.json"
	add_child(dialog)
	dialog.file_selected.connect(func(path: String): save_json(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(.75)

func save_json(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Could not save timeline: " + error_string(FileAccess.get_open_error())
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "\t"))
	status.text = "Saved camera timeline: " + path
	return OK

func import_dialog() -> void:
	var dialog := FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Camera timeline"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String): load_json(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(.75)

func load_json(path: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid_document(data):
		status.text = "Invalid camera timeline JSON"
		return false
	if recording: stop_record(false)
	stop_playback()
	document = data
	selected = 0
	relative_button.set_pressed_no_signal(document.space == "truck_relative")
	scrub(0.0)
	return true

static func valid_document(data: Variant) -> bool:
	if not data is Dictionary or data.get("format") != FORMAT or data.get("version") != 1: return false
	if data.get("space") not in ["world", "truck_relative"] or not data.get("keys") is Array: return false
	if data.keys.is_empty() or data.keys.size() > 100000: return false
	if not data.get("duration") is float and not data.get("duration") is int: return false
	if not is_finite(float(data.duration)) or float(data.duration) <= 0: return false
	var previous := -1.0
	for key in data.keys:
		if not key is Dictionary or not key.get("pose") is Dictionary: return false
		if not key.get("time") is float and not key.get("time") is int: return false
		var time := float(key.time)
		if not is_finite(time) or time < 0 or time <= previous or time > float(data.duration): return false
		previous = time
		for prefix in ["", "truck_relative_"]:
			for field in ["position", "basis_x", "basis_y", "basis_z"]:
				var value = key.pose.get(prefix + field)
				if not value is Array or value.size() != 3: return false
				for number in value:
					if not number is float and not number is int: return false
					if not is_finite(float(number)): return false
		for field in ["fov", "near", "far", "horizontal_offset", "vertical_offset", "orbit_yaw_degrees", "orbit_pitch_degrees", "orbit_distance"]:
			var value = key.pose.get(field)
			if not value is float and not value is int: return false
			if not is_finite(float(value)): return false
		if float(key.pose.fov) <= 0 or float(key.pose.fov) >= 180 or float(key.pose.near) <= 0 or float(key.pose.far) <= float(key.pose.near): return false
		for relative in [false, true]:
			var basis := pose_transform(key.pose, relative).basis
			for axis in [basis.x, basis.y, basis.z]:
				if absf(axis.length() - 1.0) > .001: return false
			if absf(basis.x.dot(basis.y)) > .001 or absf(basis.y.dot(basis.z)) > .001 or absf(basis.z.dot(basis.x)) > .001 or basis.determinant() < .999: return false
	return true
