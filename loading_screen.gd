extends CanvasLayer

var busy := false
var panel: Control
var status: Label
var error_dialog: AcceptDialog
var backdrop: Control
var text_layer: Control
var spinner: Control
var transition: Tween
var cover_started := false

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	backdrop = preload("res://loading_backdrop.gd").new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(backdrop)
	text_layer = Control.new()
	text_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(text_layer)
	var title := Label.new()
	title.text = "ORDER UP!"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("b52c24"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.offset_top = -58
	title.offset_bottom = -58
	text_layer.add_child(title)
	status = Label.new()
	status.text = "Loading…"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.offset_top = 48
	status.offset_bottom = 48
	status.add_theme_color_override("font_color", Color("ffe4a0"))
	status.add_theme_font_size_override("font_size", 20)
	text_layer.add_child(status)
	spinner = preload("res://loading_spinner.gd").new()
	spinner.name = "LoadingSpinner"
	spinner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	spinner.offset_left = -76
	spinner.offset_top = -76
	spinner.offset_right = -28
	spinner.offset_bottom = -28
	panel.add_child(spinner)
	panel.hide()
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Loading failed"
	add_child(error_dialog)

func begin_cover() -> void:
	if cover_started:
		return
	cover_started = true
	backdrop.reset()
	panel.show()
	status.text = "Firing up the kitchen…"
	backdrop.modulate.a = 1.0
	text_layer.modulate.a = 0.0
	spinner.modulate.a = 0.0
	transition = create_tween().set_parallel(true)
	transition.tween_property(backdrop, "pattern_entry", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_property(backdrop, "dark_entry", 1.0, 0.5).set_delay(0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_property(text_layer, "modulate:a", 1.0, 0.35).set_delay(0.8)
	transition.tween_property(spinner, "modulate:a", 1.0, 0.35).set_delay(0.8)

func finish_cover() -> void:
	if not cover_started:
		return
	if transition != null and transition.is_running():
		await transition.finished
	status.text = "Ready to roll!"
	backdrop.frozen = true
	var marker: Vector2 = backdrop.truck_center()
	backdrop.pivot_offset = marker
	var scene := get_tree().current_scene
	var has_intro := scene != null and scene.has_method("begin_loading_intro")
	if has_intro:
		scene.begin_loading_intro()
	transition = create_tween().set_parallel(true)
	transition.tween_property(backdrop, "scale", Vector2(42, 42), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	transition.tween_property(backdrop, "position", get_viewport().get_visible_rect().size * 0.5 - marker, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	transition.tween_property(text_layer, "modulate:a", 0.0, 0.3)
	transition.tween_property(spinner, "modulate:a", 0.0, 0.3)
	await transition.finished
	if has_intro:
		scene.play_loading_intro()
	transition = create_tween()
	transition.tween_property(backdrop, "modulate:a", 0.0, 0.65)
	await transition.finished
	panel.hide()
	if has_intro:
		await scene.loading_intro_finished
	cover_started = false

func stage(message: String) -> void:
	PerformanceDiagnostics.stage = message
	status.text = message
	await get_tree().process_frame
	await get_tree().process_frame

func load_scene(path: String, camera_view: Variant = null) -> bool:
	if busy:
		return false
	busy = true
	begin_cover()
	if transition != null and transition.is_running():
		await transition.finished
	var previous := get_tree().current_scene
	var previous_mode := previous.process_mode if is_instance_valid(previous) else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(previous):
		previous.process_mode = Node.PROCESS_MODE_DISABLED
	await stage("Loading assets…")
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error != OK:
		return fail(previous, previous_mode, error_string(error))
	while true:
		var progress: Array = []
		var state := ResourceLoader.load_threaded_get_status(path, progress)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if state in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			return fail(previous, previous_mode, "Could not load " + path.get_file())
		await get_tree().process_frame
	var resource := ResourceLoader.load_threaded_get(path) as PackedScene
	if resource == null:
		return fail(previous, previous_mode, "Scene asset was invalid")
	await stage("Preparing scene…")
	var scene := resource.instantiate()
	var mode := scene.process_mode
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(scene)
	if scene.has_method("is_loading_ready"):
		while not scene.is_loading_ready():
			await get_tree().process_frame
	await stage("Finishing…")
	if camera_view is Transform3D and scene.has_node("FollowCamera"):
		scene.get_node("FollowCamera").global_transform = camera_view
		scene.set("camera_started", true)
		scene.get_node("FollowCamera").make_current()
	get_tree().current_scene = scene
	scene.process_mode = mode
	if is_instance_valid(previous):
		previous.queue_free()
	await get_tree().process_frame
	await finish_cover()
	busy = false
	PerformanceDiagnostics.stage = "Gameplay"
	return true

func fail(previous: Node, previous_mode: int, message: String) -> bool:
	if is_instance_valid(previous):
		previous.process_mode = previous_mode
	busy = false
	panel.hide()
	if transition != null:
		transition.kill()
	cover_started = false
	error_dialog.dialog_text = message
	error_dialog.popup_centered()
	return false
