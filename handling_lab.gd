extends Node3D

const INPUT_VERSION := 1
const RUN_TICKS := 480
const HZ := 60
const MANEUVERS := ["Normal turn", "Power slide", "Donut"]
var running := true
var automatic := true
var tick := 0
var session_tick := 0
var run_number := 0
var maneuver := 1
var suite := false
var recording := false
var capture: Dictionary = {}
var camera: Camera3D
var telemetry: Label
var status: Label
var mode_button: Button
var run_button: Button
var record_button: Button
var profile_picker: OptionButton
var profile_name: LineEdit
var truck_id: LineEdit
var sliders := {}
var slider_labels := {}
var trail: MeshInstance3D
var trail_points := PackedVector3Array()
var syncing := false
var previous_yaw := 0.0
var yaw_rate := 0.0
var peak_slip := 0.0
var last_capture_path := ""
@onready var truck = $FoodTruck

func _ready() -> void:
	if Engine.physics_ticks_per_second != HZ:
		push_error("Handling lab requires 60 Hz physics.")
		get_tree().quit(2)
		return
	truck.set_physics_process(false)
	truck.set_process_unhandled_input(false)
	truck.set_process_input(false)
	truck.test_controls_enabled = true
	build_world()
	var effects := preload("res://tire_effects.gd").new()
	effects.name = "TireEffects"
	truck.add_child(effects)
	build_ui()
	restart_run()

func can_open_shop(_truck: Node) -> bool: return false
func has_ingredients() -> bool: return false

func build_world() -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(600,1,600)
	collision.shape = shape
	body.position.y = -.5
	body.add_child(collision)
	add_child(body)
	var ground := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	ground.mesh = mesh
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color("394850")
	ground.material_override = asphalt
	body.add_child(ground)
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	for value in range(-120,121,10):
		lines.add_vertex(Vector3(value,.015,-120))
		lines.add_vertex(Vector3(value,.015,120))
		lines.add_vertex(Vector3(-120,.015,value))
		lines.add_vertex(Vector3(120,.015,value))
	var markings := MeshInstance3D.new()
	markings.mesh = lines.commit()
	markings.material_override = line_material(Color("788a90"))
	add_child(markings)
	trail = MeshInstance3D.new()
	trail.material_override = line_material(Color("53eac5"))
	add_child(trail)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("9dc6dd")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = .65
	add_child(world)
	camera = Camera3D.new()
	camera.far = 500
	camera.current = true
	add_child(camera)
	update_camera()

func line_material(color: Color) -> Material:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func button(rows: Container, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.pressed.connect(callback)
	rows.add_child(result)
	return result

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 16
	panel.offset_right = 412
	panel.offset_top = 16
	panel.offset_bottom = -16
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",7)
	margin.add_child(rows)
	var title := Label.new()
	title.text = "TRUCK HANDLING LAB"
	title.add_theme_font_size_override("font_size",22)
	rows.add_child(title)
	var choice := OptionButton.new()
	for item_name in MANEUVERS: choice.add_item(item_name)
	choice.add_item("Repeat all three")
	choice.select(maneuver)
	choice.item_selected.connect(func(index):
		suite = index == 3
		maneuver = 0 if suite else index
		restart_run())
	rows.add_child(choice)
	var commands := HBoxContainer.new()
	rows.add_child(commands)
	run_button = button(commands,"Pause",func():
		running = not running
		run_button.text = "Pause" if running else "Resume")
	button(commands,"Restart",restart_run)
	mode_button = button(commands,"Manual drive",func():
		automatic = not automatic
		mode_button.text = "Manual drive" if automatic else "Automated"
		running = true
		run_button.text = "Pause"
		restart_run())
	telemetry = Label.new()
	telemetry.add_theme_font_size_override("font_size",15)
	rows.add_child(telemetry)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(fields)
	var field_keys := ["power_slide_turn_multiplier","power_slide_steering","power_slide_traction_response","power_slide_recovery_response","sprite_animation_strength","sprite_animation_time_scale","sprite_lean_delay","sprite_transition_seconds"]
	for key in HandlingProfiles.FIELDS:
		if key not in field_keys: field_keys.append(key)
	for key in field_keys:
		if key.begins_with("sprite_") and not truck.use_driving_billboard: continue
		var spec: Array = HandlingProfiles.FIELDS[key]
		var label := Label.new()
		label.add_theme_font_size_override("font_size",14)
		fields.add_child(label)
		var slider := HSlider.new()
		slider.min_value = spec[1]
		slider.max_value = spec[2]
		slider.step = spec[3]
		slider.value = truck.get(key)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fields.add_child(slider)
		sliders[key] = slider
		slider_labels[key] = label
		slider.value_changed.connect(func(value): change_property(key,value))
	var presets := HBoxContainer.new()
	rows.add_child(presets)
	button(presets,"Original",func(): apply_values(HandlingProfiles.original(),"Original"))
	button(presets,"Gentler slide",func(): apply_values(HandlingProfiles.gentle(),"Gentler slide"))
	profile_picker = OptionButton.new()
	profile_picker.item_selected.connect(func(index):
		var item_name := profile_picker.get_item_text(index)
		if HandlingProfiles.profiles.has(item_name):
			profile_name.text = item_name
			apply_values(HandlingProfiles.profiles[item_name],item_name))
	rows.add_child(profile_picker)
	var names := HBoxContainer.new()
	rows.add_child(names)
	profile_name = LineEdit.new()
	profile_name.text = "My truck"
	profile_name.placeholder_text = "Profile name"
	profile_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(profile_name)
	truck_id = LineEdit.new()
	truck_id.text = truck.handling_id
	truck_id.placeholder_text = "Truck ID"
	truck_id.custom_minimum_size.x = 115
	names.add_child(truck_id)
	var saves := HBoxContainer.new()
	rows.add_child(saves)
	button(saves,"Save profile",save_profile)
	button(saves,"Use as default",save_default)
	button(saves,"Export .tres",export_resource)
	var records := HBoxContainer.new()
	rows.add_child(records)
	record_button = button(records,"Record tuning",toggle_recording)
	button(records,"Open saves",func(): OS.shell_open(ProjectSettings.globalize_path("user://handling")))
	button(records,"Menu",func():
		if recording and finish_recording() != OK: return
		get_tree().change_scene_to_file("res://main_menu.tscn"))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 42
	status.add_theme_font_size_override("font_size",13)
	rows.add_child(status)
	status.text = "Live changes. Restart to compare from the same start."
	refresh_profiles()
	sync_sliders()

func sync_sliders() -> void:
	syncing = true
	for key in sliders:
		sliders[key].value = truck.get(key)
		slider_labels[key].text = "%s: %.2f" % [HandlingProfiles.FIELDS[key][0],truck.get(key)]
	syncing = false

func change_property(key: String, value: float) -> void:
	if syncing: return
	HandlingProfiles.apply(truck,{key:value})
	slider_labels[key].text = "%s: %.2f" % [HandlingProfiles.FIELDS[key][0],truck.get(key)]
	record_event("property",{"key":key,"value":truck.get(key)})

func apply_values(values: Dictionary, item_name: String) -> void:
	HandlingProfiles.apply(truck,values)
	sync_sliders()
	record_event("profile",{"name":item_name,"values":HandlingProfiles.snapshot(truck)})
	status.text = "Loaded %s. Restart for a fresh comparison." % item_name

func refresh_profiles() -> void:
	profile_picker.clear()
	profile_picker.add_item("Load a saved profile…")
	for item_name in HandlingProfiles.profiles: profile_picker.add_item(item_name)

func save_profile() -> void:
	var error: Error = HandlingProfiles.save_profile(profile_name.text,HandlingProfiles.snapshot(truck))
	status.text = "Saved profile: " + profile_name.text if error == OK else "Save failed: " + error_string(error)
	refresh_profiles()

func save_default() -> void:
	var error: Error = HandlingProfiles.save_profile(profile_name.text,HandlingProfiles.snapshot(truck))
	if error == OK: error = HandlingProfiles.set_default(truck_id.text.strip_edges(),profile_name.text.strip_edges())
	status.text = "Default for %s: %s" % [truck_id.text,profile_name.text] if error == OK else "Save failed: "+error_string(error)
	refresh_profiles()

func export_resource() -> void:
	var profile := HandlingProfiles.PROFILE_SCRIPT.new()
	profile.display_name = profile_name.text
	profile.values = HandlingProfiles.snapshot(truck)
	DirAccess.make_dir_recursive_absolute("user://handling/exports")
	var filename: String = profile_name.text.strip_edges().validate_filename()
	if filename.is_empty(): filename = "truck"
	var path := "user://handling/exports/" + filename + ".tres"
	var error := ResourceSaver.save(profile,path)
	status.text = "Exported "+path if error == OK else "Export failed: "+error_string(error)

func inputs(at: int, kind: int) -> Dictionary:
	if at < 60: return {}
	if at < 240: return {} if kind == 2 else {"accelerate":1.0}
	match kind:
		0:
			if at < 420: return {"accelerate":.6,"left":.45}
		1:
			if at < 312: return {"brake":1.0,"left":1.0}
			if at < 372: return {"brake":.3,"right":.35}
			if at < 420: return {"accelerate":.6}
		2:
			if at < 420: return {"accelerate":1.0,"brake":1.0,"left":1.0}
	return {"brake":1.0}

func restart_run() -> void:
	truck.reset_truck()
	truck.health = truck.max_health
	truck.round_over = false
	truck.test_controls = {}
	truck.test_controls_enabled = automatic
	tick = 0
	run_number += 1
	peak_slip = 0
	previous_yaw = truck.rotation.y
	trail_points.clear()
	trail.mesh = null
	record_event("run_start",{"run":run_number,"maneuver":MANEUVERS[maneuver],"automatic":automatic,"values":HandlingProfiles.snapshot(truck)})

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if not running: return
	truck.test_controls_enabled = automatic
	truck.test_controls = inputs(tick,maneuver) if automatic else {}
	truck._physics_process(delta)
	yaw_rate = angle_difference(previous_yaw,truck.rotation.y)/delta
	previous_yaw = truck.rotation.y
	var slip: float = absf(angle_difference(truck.travel_heading,truck.rotation.y))
	peak_slip = maxf(peak_slip,slip)
	if recording:
		capture.samples.append({"tick":session_tick,"run":run_number,"run_tick":tick,"inputs":{"accelerate":truck.control_strength("accelerate"),"reverse":truck.control_strength("reverse"),"brake":truck.control_strength("brake"),"left":truck.control_strength("left"),"right":truck.control_strength("right")},"position":[truck.position.x,truck.position.y,truck.position.z],"yaw":truck.rotation.y,"speed":truck.speed,"yaw_rate":yaw_rate,"slip":slip,"slide_blend":truck.power_slide_blend,"on_floor":truck.is_on_floor()})
		# Bound memory for long tuning sessions; captures can be restarted immediately.
		if capture.samples.size() >= 60*60*10:
			if finish_recording() != OK: running = false
	if tick%6 == 0:
		trail_points.append(Vector3(truck.position.x,.04,truck.position.z))
		if trail_points.size()>2000: trail_points.remove_at(0)
		update_trail()
	tick += 1
	session_tick += 1
	if automatic and tick >= RUN_TICKS:
		record_event("run_end",{"peak_slip":peak_slip,"position":[truck.position.x,truck.position.z]})
		if suite: maneuver = (maneuver+1)%MANEUVERS.size()
		restart_run()

func update_trail() -> void:
	if trail_points.size()<2: return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in trail_points: mesh.surface_add_vertex(point)
	mesh.surface_end()
	trail.mesh = mesh

func _process(_delta: float) -> void:
	update_camera()
	telemetry.text = "%s · %s · run %d · %.1f / 8 s\nSpeed %.1f km/h · yaw %.0f°/s\nSlip %.0f° · peak %.0f° · slide %.0f%%" % ["AUTO" if automatic else "MANUAL",MANEUVERS[maneuver],run_number,tick/60.0,truck.speed*3.6,rad_to_deg(yaw_rate),rad_to_deg(absf(angle_difference(truck.travel_heading,truck.rotation.y))),rad_to_deg(peak_slip),truck.power_slide_blend*100]

func update_camera() -> void:
	camera.position = truck.position + Vector3(12,15,18)
	camera.look_at(truck.position+Vector3(-4,1,0))

func record_event(kind: String, data: Dictionary) -> void:
	if recording: capture.events.append({"tick":session_tick,"run_tick":tick,"type":kind,"data":data})

func begin_recording() -> void:
	capture = {"version":1,"input_version":INPUT_VERSION,"physics_hz":HZ,"truck_id":truck_id.text,"initial_values":HandlingProfiles.snapshot(truck),"events":[],"samples":[]}
	recording = true
	session_tick = 0
	record_button.text = "Stop + save recording"
	running = true
	run_button.text = "Pause"
	restart_run()
	status.text = "Recording inputs, motion and property changes at 60 Hz."

func toggle_recording() -> void:
	if recording: finish_recording()
	else: begin_recording()

func finish_recording(path: String = "") -> Error:
	if not recording: return ERR_UNAVAILABLE
	if path.is_empty(): path = "user://handling/captures/tuning_%s_%d.json" % [Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_msec()]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		status.text = "Recording save failed; data kept in memory."
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(capture))
	var error := file.get_error()
	file.close()
	if error != OK:
		status.text = "Recording save failed; data kept in memory."
		return error
	recording = false
	last_capture_path = path
	record_button.text = "Record tuning"
	status.text = "Saved "+path
	return OK

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and recording: finish_recording()
