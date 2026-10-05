extends CanvasLayer

var vectors_enabled: bool = false
var panel: PanelContainer
var hide_ui: CheckBox
var arrows: MeshInstance3D
var refresh: float = 0.0
signal controller_quit_requested
var controller_buttons: Dictionary = {}
var view_chords: Dictionary = {}
var performance_label: Label
var performance_refresh := 0.0
var baseline_options: Dictionary = {}
var comparison_options: Dictionary = {}
var all_baseline: CheckBox
const BASELINE_PROPERTIES := {"Traffic": "traffic_enabled", "Traffic logic": "traffic_logic_enabled", "Pedestrian logic and spawning": "pedestrian_logic_enabled", "Detailed buildings": "buildings_as_blocks"}
const COMPARISON_PROPERTIES := {"Full-distance traffic simulation": "traffic_lod_enabled", "Full-detail distant rendering": "rendering_lod_enabled", "Unoptimized multiplayer snapshots": "optimized_snapshots"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	controller_quit_requested.connect(quit_game)
	Input.joy_connection_changed.connect(controller_connection_changed)
	layer = 1100
	panel = PanelContainer.new()
	panel.position = Vector2(20, 80)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	scroll.add_child(rows)
	var title := Label.new()
	title.text = "Debug menu — F3 / View"
	rows.add_child(title)
	var vectors := CheckBox.new()
	vectors.text = "Car motion vectors"
	vectors.toggled.connect(func(enabled: bool): vectors_enabled = enabled)
	rows.add_child(vectors)
	hide_ui = CheckBox.new()
	hide_ui.text = "Game UI"
	hide_ui.toggled.connect(func(enabled: bool): ScreenshotCapture.set_screenshot_mode(not enabled))
	rows.add_child(hide_ui)
	var hint := Label.new()
	hint.text = "Arrows show direction and one second of movement.\nView: toggle debug menu · View + A: quit game"
	rows.add_child(hint)
	performance_label = Label.new()
	performance_label.add_theme_font_size_override("font_size", 15)
	rows.add_child(performance_label)
	rows.add_child(preload("res://performance_graph.gd").new())
	var baseline_title := Label.new()
	baseline_title.text = "Baseline features  -  checked means enabled"
	rows.add_child(baseline_title)
	all_baseline = CheckBox.new()
	all_baseline.name = "AllBaseline"
	all_baseline.text = "All baseline features"
	all_baseline.toggled.connect(set_all_baseline)
	rows.add_child(all_baseline)
	for label in BASELINE_PROPERTIES:
		add_baseline_option(rows, label, BASELINE_PROPERTIES[label], false)
	for key in preload("res://debug_render_filters.gd").OPTIONS:
		add_baseline_option(rows, preload("res://debug_render_filters.gd").OPTIONS[key], key, true)
	var comparison_title := Label.new()
	comparison_title.text = "Optional performance comparisons  -  may reduce FPS"
	rows.add_child(comparison_title)
	for label in COMPARISON_PROPERTIES:
		var option := CheckBox.new()
		option.text = label
		option.toggled.connect(set_comparison.bind(COMPARISON_PROPERTIES[label]))
		comparison_options[COMPARISON_PROPERTIES[label]] = option
		rows.add_child(option)
	var capture_button := Button.new()
	capture_button.text = "Capture frame timings for 20 seconds"
	capture_button.pressed.connect(func():
		var result := PerformanceDiagnostics.start_capture()
		capture_button.text = "Recording 20 seconds…" if PerformanceDiagnostics.capture != null else result)
	rows.add_child(capture_button)
	var folder := Button.new()
	folder.text = "Open performance captures"
	folder.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path("user://performance")))
	rows.add_child(folder)
	var close := Button.new()
	close.text = "Close debug menu"
	close.pressed.connect(panel.hide)
	rows.add_child(close)
	panel.hide()
	arrows = MeshInstance3D.new()
	arrows.name = "TrafficMotionVectors"
	arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("38e6ff")
	arrows.material_override = material
	add_child(arrows)
	sync_options.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and handle_controller_button(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode == KEY_F3 and event.pressed and not event.echo:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	panel.show()
	sync_options()
	all_baseline.grab_focus()

func add_baseline_option(rows: VBoxContainer, label: String, key: String, render_feature: bool) -> void:
	var option := CheckBox.new()
	option.text = label
	option.toggled.connect(set_baseline.bind(key, render_feature))
	baseline_options[key] = {"checkbox": option, "render": render_feature}
	rows.add_child(option)

func set_baseline(enabled: bool, key: String, render_feature: bool) -> void:
	if render_feature:
		PerformanceDiagnostics.render_filters.set_disabled(key, not enabled)
	else:
		PerformanceDiagnostics.set(key, not enabled if key == "buildings_as_blocks" else enabled)
	sync_options()

func set_all_baseline(enabled: bool) -> void:
	for key in baseline_options:
		set_baseline(enabled, key, baseline_options[key].render)
	sync_options()

func set_comparison(enabled: bool, property: String) -> void:
	PerformanceDiagnostics.set(property, not enabled)
	sync_options()

func sync_options() -> void:
	if PerformanceDiagnostics.render_filters == null: return
	var enabled_count := 0
	for key in baseline_options:
		var entry: Dictionary = baseline_options[key]
		var enabled: bool
		if entry.render:
			enabled = not PerformanceDiagnostics.render_filters.disabled.get(key, false)
		else:
			enabled = bool(PerformanceDiagnostics.get(key))
			if key == "buildings_as_blocks": enabled = not enabled
		entry.checkbox.set_pressed_no_signal(enabled)
		if enabled: enabled_count += 1
	all_baseline.set_pressed_no_signal(enabled_count == baseline_options.size())
	all_baseline.text = "All baseline features (%d/%d enabled)" % [enabled_count, baseline_options.size()]
	for key in comparison_options:
		comparison_options[key].set_pressed_no_signal(not bool(PerformanceDiagnostics.get(key)))

func is_view_held(device: int) -> bool:
	return controller_buttons.get(device, {}).get(JOY_BUTTON_BACK, false) or Input.is_joy_button_pressed(device, JOY_BUTTON_BACK)

func handle_controller_button(event: InputEventJoypadButton) -> bool:
	if event.button_index not in [JOY_BUTTON_BACK, JOY_BUTTON_A]:
		return false
	var buttons: Dictionary = controller_buttons.get(event.device, {})
	var was_pressed: bool = buttons.get(event.button_index, false)
	buttons[event.button_index] = event.pressed
	controller_buttons[event.device] = buttons
	var view: bool = buttons.get(JOY_BUTTON_BACK, false)
	var accept: bool = buttons.get(JOY_BUTTON_A, false)
	if view and accept:
		if not view_chords.get(event.device, false):
			view_chords[event.device] = true
			controller_quit_requested.emit()
		return true
	if event.button_index == JOY_BUTTON_BACK:
		# Toggle on release so adding A never briefly opens the menu.
		if not event.pressed and was_pressed:
			if not view_chords.get(event.device, false):
				panel.visible = not panel.visible
			view_chords.erase(event.device)
		return true
	return view or view_chords.get(event.device, false)

func quit_game() -> void:
	get_tree().quit()

func controller_connection_changed(device: int, _connected: bool) -> void:
	controller_buttons.erase(device)
	view_chords.erase(device)

func _process(delta: float) -> void:
	if panel.visible: sync_options()
	performance_refresh -= delta
	if panel.visible and performance_refresh <= 0.0:
		performance_refresh = 0.5
		PerformanceDiagnostics.refresh_traffic_counts()
		performance_label.text = PerformanceDiagnostics.summary()
	hide_ui.set_pressed_no_signal(not ScreenshotCapture.screenshot_mode)
	arrows.visible = vectors_enabled
	refresh -= delta
	if vectors_enabled and refresh <= 0.0:
		refresh = 0.05
		update_vectors()

func update_vectors() -> void:
	var mesh := ImmediateMesh.new()
	var started := false
	for car in get_tree().get_nodes_in_group("traffic_motion"):
		if car.exploded or car.motion_vector.length() < 0.05:
			continue
		if not started:
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			started = true
		var start: Vector3 = car.global_position + Vector3.UP * 1.8
		var vector: Vector3 = car.motion_vector
		var end := start + vector
		var direction := vector.normalized()
		var side := direction.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var head := minf(0.8, vector.length() * 0.25)
		for point in [start, end, end, end - direction * head + side * head * 0.5, end, end - direction * head - side * head * 0.5]:
			mesh.surface_add_vertex(point)
	if started:
		mesh.surface_end()
	arrows.mesh = mesh
