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
var map_preview: Control
var logo_background: Polygon2D
var logo_title: Label
const LOGO_POSITION := Vector2(48,170)

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
	map_preview = preload("res://loading_map_preview.gd").new()
	map_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(map_preview)
	map_preview.reset()
	map_preview.hide()
	text_layer = Control.new()
	text_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(text_layer)
	logo_background = Polygon2D.new()
	logo_background.name = "LogoBackground"
	logo_background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(650,0),Vector2(0,390)])
	logo_background.color = Color("17343b")
	text_layer.add_child(logo_background)
	var title := Label.new()
	logo_title = title
	title.text = "On the Fly!"
	title.name = "LoadingTitle"
	title.add_theme_font_override("font", ThemeDB.fallback_font)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_outline_color", Color("8e2925"))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_color", Color("fff2d7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = LOGO_POSITION
	title.size = Vector2(470,76)
	title.rotation = deg_to_rad(-26)
	text_layer.add_child(title)
	status = Label.new()
	status.text = "Loading..."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.offset_top = 260
	status.offset_bottom = 260
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
	spinner.hide()
	spinner.set_process(false)
	panel.hide()
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Loading failed"
	add_child(error_dialog)

func begin_cover() -> void:
	if cover_started:
		return
	cover_started = true
	backdrop.reset()
	map_preview.reset()
	prepare_initial_map()
	map_preview.position.y = get_viewport().get_visible_rect().size.y
	map_preview.modulate.a = 1.0
	panel.show()
	status.text = "Firing up the kitchen..."
	backdrop.modulate.a = 1.0
	text_layer.modulate.a = 1.0
	status.modulate.a = 0.0
	logo_background.position = Vector2(-460,-280)
	logo_title.position = LOGO_POSITION + Vector2(0,get_viewport().get_visible_rect().size.y)
	logo_title.rotation = deg_to_rad(-44)
	spinner.modulate.a = 0.0
	transition = create_tween().set_parallel(true)
	transition.tween_property(backdrop, "pattern_entry", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_property(backdrop, "dark_entry", 1.0, 0.5).set_delay(0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_property(status, "modulate:a", 1.0, 0.35).set_delay(0.8)
	transition.tween_property(logo_background,"position",Vector2.ZERO,.65).set_delay(.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_method(animate_logo_arc,0.0,1.0,1.0).set_delay(.15)
	transition.tween_property(spinner, "modulate:a", 1.0, 0.35).set_delay(0.8)

func prepare_initial_map() -> void:
	var current := get_tree().current_scene
	var city: Node = current.find_child("ProceduralCity",true,false) if current != null else null
	if not CityStore.generate_next and city != null and city.get("topology") != null and city.map_size == CityStore.preferred_size and city.original_grid == CityStore.original_grid:
		map_preview.reveal(city.topology,1)
		return
	var seed_value := 12054
	if CityStore.generate_next:
		if CityStore.pending_generation_seed < 0: CityStore.pending_generation_seed = randi()
		seed_value = CityStore.pending_generation_seed
	var plan := preload("res://city_topology.gd").new()
	var parks: Array[Vector2i] = []
	plan.generate(seed_value,parks,CityStore.preferred_size,14,22)
	if CityStore.original_grid: plan.use_original_grid()
	map_preview.reveal(plan,1)

func animate_logo_arc(t: float) -> void:
	var phase_offset: float
	var rotation_degrees: float
	if t < .78:
		var rise := 1.0-pow(1.0-t/.78,3.0)
		phase_offset = lerpf(get_viewport().get_visible_rect().size.y,-12.0,rise)
		rotation_degrees = lerpf(-44.0,-23.0,rise)
	else:
		var settle := smoothstep(.78,1.0,t)
		phase_offset = lerpf(-12.0,0.0,settle)
		rotation_degrees = lerpf(-23.0,-26.0,settle)
	map_preview.position.y = phase_offset
	logo_title.position = LOGO_POSITION + Vector2(0,phase_offset)
	logo_title.rotation = deg_to_rad(rotation_degrees)

func finish_cover() -> void:
	if not cover_started:
		return
	if transition != null and transition.is_running():
		await transition.finished
	status.text = "Ready to roll!"
	var scene := get_tree().current_scene
	var has_intro := scene != null and scene.has_method("begin_loading_intro")
	if has_intro:
		scene.begin_loading_intro()
		if map_preview.visible and map_preview.plan != null:
			map_preview.spawn = Vector2(scene.truck.global_position.x, scene.truck.global_position.z)
			map_preview.phase = 7
			transition = create_tween()
			transition.tween_property(map_preview, "zoom", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await transition.finished
	transition = create_tween().set_parallel(true)
	transition.tween_property(text_layer, "modulate:a", 0.0, 0.3)
	transition.tween_property(spinner, "modulate:a", 0.0, 0.3)
	if has_intro:
		scene.play_loading_intro()
	transition.tween_property(backdrop, "modulate:a", 0.0, 1.2)
	transition.tween_property(map_preview, "modulate:a", 0.0, 1.2)
	await transition.finished
	panel.hide()
	if has_intro:
		await scene.loading_intro_finished
	cover_started = false

func city_stage(topology: RefCounted, step: int, message: String) -> void:
	if not busy: return
	map_preview.reveal(topology, step)
	if topology.arteries.is_empty() and step == 2: message = "Laying original grid streets..."
	if topology.arteries.is_empty() and step == 3: message = "Connecting original grid junctions..."
	await stage(message)
	if step < 4: await get_tree().create_timer(0.2).timeout

func stage(message: String) -> void:
	message = message.replace("â€¦", "...").replace("…", "...")
	if "smoothing road" in message.to_lower() or "finishing" in message.to_lower(): backdrop.begin_smoothing()
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
	await stage("Loading assets...")
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
	await stage("Preparing scene...")
	var scene := resource.instantiate()
	var mode := scene.process_mode
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(scene)
	if scene.has_method("is_loading_ready"):
		while not scene.is_loading_ready():
			await get_tree().process_frame
	var city := scene.find_child("ProceduralCity",true,false)
	if city != null and city.get("topology") != null:
		map_preview.reveal(city.topology,6)
	await stage("Finishing...")
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
		previous.process_mode = previous_mode as Node.ProcessMode
	busy = false
	panel.hide()
	if transition != null:
		transition.kill()
	cover_started = false
	error_dialog.dialog_text = message
	error_dialog.popup_centered()
	return false
