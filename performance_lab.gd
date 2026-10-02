extends Node3D

const ITEMS := [
	["Cube", "", 1.0],
	["Car model", "res://assets/kenney_city/cars_rigged/sedan.glb", 1.8],
	["Food truck model", "res://assets/truck_with_doors.glb", 1.0],
	["Cone", "res://scenes/cone.tscn", 1.0],
	["Crate", "res://scenes/breakable_crate.tscn", 1.0],
	["Tree", "res://scenes/breakable_tree.tscn", 1.0],
	["Building", "res://assets/kenney_city/commercial/building-a.glb", 4.0],
	["Custom scene/model", "", 1.0],
]
var instances: Node3D
var camera: Camera3D
var menu: PanelContainer
var stats_panel: PanelContainer
var picker: OptionButton
var physics_picker: OptionButton
var count_input: SpinBox
var spacing_input: SpinBox
var scale_input: SpinBox
var chunk_input: SpinBox
var staggered: CheckBox
var scripts: CheckBox
var path_input: LineEdit
var stats: Label
var result_label: Label
var origin_label: Label
var resource_dialog: FileDialog
var spawn_origin := Vector3.ZERO
var busy := false
var generation := 0
var cursor := 0
var last_load_ms := 0.0
var last_spawn_ms := 0.0
var post_spawn_peak := 0.0
var observe_until := 0
var refresh_timer := 0.0
var camera_speed := 30.0
var cube_mesh: BoxMesh

func _ready() -> void:
	instances = Node3D.new()
	instances.name = "Instances"
	add_child(instances)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2000, 2000)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("667774")
	plane.material_override = material
	ground.add_child(plane)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000, 0.4, 2000)
	collision.shape = shape
	collision.position.y = -0.2
	ground.add_child(collision)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.shadow_enabled = false
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("91b3c4")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	camera = Camera3D.new()
	camera.position = Vector3(0, 24, 36)
	camera.far = 2500
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(2, 2, 2)
	build_controls()
	reset_timings()

func build_controls() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	menu = PanelContainer.new()
	menu.position = Vector2(18, 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.075, 0.96)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	menu.add_theme_stylebox_override("panel", style)
	canvas.add_child(menu)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(410, minf(740, get_viewport().get_visible_rect().size.y - 60))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 390
	rows.add_theme_constant_override("separation", 7)
	scroll.add_child(rows)
	add_label(rows, "PERFORMANCE LAB — empty plane", 20)
	add_label(rows, "Hold right mouse + WASD / Q E to fly.\nShift: faster • Wheel: speed • Tab: hide panel\nClick the plane to choose a spawn origin.", 14)
	var row := HBoxContainer.new()
	rows.add_child(row)
	picker = OptionButton.new()
	for item in ITEMS: picker.add_item(item[0])
	row.add_child(picker)
	physics_picker = OptionButton.new()
	for mode in ["Render only", "Scene physics", "Static bounds", "Dynamic bounds"]: physics_picker.add_item(mode)
	row.add_child(physics_picker)
	path_input = LineEdit.new()
	path_input.placeholder_text = "res:// path for a custom .tscn / .glb"
	rows.add_child(path_input)
	resource_dialog = FileDialog.new()
	resource_dialog.access = FileDialog.ACCESS_RESOURCES
	resource_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	resource_dialog.filters = PackedStringArray(["*.tscn ; Scene", "*.glb ; Model"])
	add_child(resource_dialog)
	resource_dialog.file_selected.connect(func(path: String): path_input.text = path; picker.select(ITEMS.size() - 1))
	add_button(rows, "Browse project scenes / models", func(): resource_dialog.popup_centered_ratio(0.7))
	count_input = add_number(rows, "Count", 1, 1000, 25)
	spacing_input = add_number(rows, "Grid spacing (m)", 1, 40, 8)
	scale_input = add_number(rows, "Item scale", 0.1, 20, 1, 0.1)
	picker.item_selected.connect(func(index: int): scale_input.value = ITEMS[index][2])
	staggered = CheckBox.new()
	staggered.text = "Spread spawning across frames"
	rows.add_child(staggered)
	chunk_input = add_number(rows, "Items per frame", 1, 100, 5)
	scripts = CheckBox.new()
	scripts.text = "Run scripts on new items (standalone props)"
	rows.add_child(scripts)
	origin_label = add_label(rows, "Spawn origin: 0, 0", 14)
	add_button(rows, "Spawn batch", func(): spawn_batch())
	add_button(rows, "Clear all / cancel spawning", func(): clear_items())
	add_button(rows, "Reset frame statistics", reset_timings)
	add_button(rows, "Record 20 seconds of frame timings", func():
		var result := PerformanceDiagnostics.start_capture()
		result_label.text = "Recording CSV for 20 seconds." if PerformanceDiagnostics.capture != null else result)
	add_button(rows, "Open captures folder", func(): OS.shell_open(ProjectSettings.globalize_path("user://performance")))
	result_label = add_label(rows, "Start empty, then spawn to compare.\nFirst load can cost more than a cached load.", 14)
	stats_panel = PanelContainer.new()
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -430
	stats_panel.offset_right = -18
	stats_panel.offset_top = 18
	stats_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(stats_panel)
	var readings := VBoxContainer.new()
	stats_panel.add_child(readings)
	add_label(readings, "LIVE FRAME TIMINGS", 18)
	var graph := preload("res://performance_graph.gd").new()
	readings.add_child(graph)
	graph.custom_minimum_size = Vector2(390, 80)
	stats = add_label(readings, "Collecting timings…", 14)
	add_button(rows, "Back to main menu", func(): get_tree().change_scene_to_file("res://main_menu.tscn"))

func add_label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func add_number(parent: Node, title: String, minimum: float, maximum: float, value: float, step: float = 1.0) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := add_label(row, title, 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	row.add_child(spin)
	return spin

func reset_timings() -> void:
	PerformanceDiagnostics.frame_ms.clear()
	PerformanceDiagnostics.sections.clear()
	PerformanceDiagnostics.displayed_peaks.clear()
	PerformanceDiagnostics.stage = "Performance lab: idle"
	post_spawn_peak = 0

func _process(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		camera.position += camera.basis * motion.normalized() * camera_speed * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0) * delta
	if Time.get_ticks_msec() < observe_until and not PerformanceDiagnostics.frame_ms.is_empty():
		post_spawn_peak = maxf(post_spawn_peak, PerformanceDiagnostics.frame_ms.back())
	refresh_timer -= delta
	if refresh_timer <= 0 and menu.visible:
		refresh_timer = 0.25
		var frames: Array[float] = PerformanceDiagnostics.frame_ms
		var average := 0.0
		var worst := 0.0
		for frame in frames:
			average += frame
			worst = maxf(worst, frame)
		average /= maxf(1, frames.size())
		stats.text = "Instances: %d%s\nFrame %.2f ms • %.0f FPS • worst %.2f ms\nCPU physics %.2f ms • process %.2f ms\nDraw calls %d • primitives %d\nLast batch: load %.2f ms • spawn/ready %.2f ms\nPeak after spawning: %.2f ms\n16.7 ms = 60 FPS • red = over 33 ms\n%s" % [instances.get_child_count(), " (spawning…)" if busy else "", average, 1000 / maxf(average, 0.01), worst, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), last_load_ms, last_spawn_ms, post_spawn_peak, "Recording CSV…" if PerformanceDiagnostics.capture != null else "F3 / View opens full diagnostics."]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			menu.visible = not menu.visible
			stats_panel.visible = menu.visible
			get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_speed = minf(200, camera_speed * 1.2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_speed = maxf(2, camera_speed / 1.2)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		if point is Vector3:
			spawn_origin = Vector3(clampf(point.x, -600, 600), 0, clampf(point.z, -600, 600))
			origin_label.text = "Spawn origin: %.0f, %.0f" % [spawn_origin.x, spawn_origin.z]

func spawn_batch() -> void:
	if busy: return
	var index := picker.selected
	var path: String = path_input.text.strip_edges() if index == ITEMS.size() - 1 else ITEMS[index][1]
	var resource: PackedScene
	var cached := ResourceLoader.has_cached(path) if not path.is_empty() else true
	var started := Time.get_ticks_usec()
	if index != 0:
		if not path.begins_with("res://") or not ResourceLoader.exists(path):
			result_label.text = "Choose an existing res:// scene or model."
			return
		resource = load(path) as PackedScene
		if resource == null:
			result_label.text = "This resource is not a scene/model."
			return
	last_load_ms = (Time.get_ticks_usec() - started) / 1000.0
	PerformanceDiagnostics.record_section("Item load", Time.get_ticks_usec() - started)
	busy = true
	var token := generation
	var count := int(count_input.value)
	var chunk := int(chunk_input.value) if staggered.button_pressed else count
	var mode := physics_picker.selected
	var run_scripts := scripts.button_pressed
	var scale_factor := float(scale_input.value)
	var spacing := float(spacing_input.value)
	var columns := ceili(sqrt(count))
	var origin := spawn_origin - Vector3(0, 0, cursor * spacing)
	cursor += ceili(float(count) / columns) + 1
	last_spawn_ms = 0
	post_spawn_peak = 0
	PerformanceDiagnostics.stage = "Performance lab: spawn " + ITEMS[index][0]
	for item_index in count:
		if token != generation: return
		started = Time.get_ticks_usec()
		var item: Node = resource.instantiate() if resource != null else MeshInstance3D.new()
		if not item is Node3D:
			item.free()
			result_label.text = "Choose a scene with a 3D root."
			busy = false
			return
		if resource == null: item.mesh = cube_mesh
		item.position = Vector3.ZERO
		item.scale *= scale_factor
		prepare_item(item, mode, run_scripts)
		var bounds := mesh_bounds(item)
		item.position.y -= bounds.position.y - 0.05
		var container: Node3D = RigidBody3D.new() if mode == 3 else (StaticBody3D.new() if mode == 2 else Node3D.new())
		container.add_child(item)
		if mode >= 2:
			var collider := CollisionShape3D.new()
			collider.name = "BoundsCollision"
			var shape := BoxShape3D.new()
			shape.size = Vector3(maxf(bounds.size.x, 0.1), maxf(bounds.size.y, 0.1), maxf(bounds.size.z, 0.1))
			collider.shape = shape
			collider.position = bounds.get_center() + Vector3.UP * item.position.y
			container.add_child(collider)
		container.position = origin + Vector3((item_index % columns - (columns - 1) * 0.5) * spacing, 1.5 if mode == 3 else 0, (floorf(float(item_index) / columns) - (ceili(float(count) / columns) - 1) * 0.5) * spacing)
		instances.add_child(container)
		var duration := Time.get_ticks_usec() - started
		last_spawn_ms += duration / 1000.0
		PerformanceDiagnostics.record_section("Item spawn", duration)
		if (item_index + 1) % chunk == 0 and item_index + 1 < count: await get_tree().process_frame
	busy = false
	observe_until = Time.get_ticks_msec() + 5000
	result_label.text = "Spawned %d • %s load\nLoad %.2f ms • spawn/ready %.2f ms" % [count, "cached" if cached else "first", last_load_ms, last_spawn_ms]

func prepare_item(node: Node, mode: int, run_scripts: bool) -> void:
	if not run_scripts: node.set_script(null)
	if mode != 1 and node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
		if node is RigidBody3D: node.freeze = true
	for child in node.get_children(): prepare_item(child, mode, run_scripts)

func mesh_bounds(node: Node, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var here: Transform3D = transform * node.transform if node is Node3D else transform
	var bounds := AABB()
	var found := false
	if node is MeshInstance3D and node.mesh != null:
		bounds = here * node.get_aabb()
		found = true
	for child in node.get_children():
		var child_bounds := mesh_bounds(child, here)
		if child_bounds.size.length_squared() <= 0: continue
		bounds = bounds.merge(child_bounds) if found else child_bounds
		found = true
	return bounds

func clear_items() -> void:
	generation += 1
	busy = false
	var started := Time.get_ticks_usec()
	for item in instances.get_children(): item.free()
	cursor = 0
	PerformanceDiagnostics.record_section("Item clear", Time.get_ticks_usec() - started)
	PerformanceDiagnostics.stage = "Performance lab: cleared"
	result_label.text = "Cleared all items. Reset statistics for an empty baseline."

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
