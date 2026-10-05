extends "res://handling_lab.gd"
const MOTION = preload("res://truck_exaggeration.gd")
var document: Dictionary = {}
var selected_state := "brake"
var selected_key := 2
var cursor := .34
var playing := false
var live_physics := false
var physics_toggle: CheckBox
var timeline: Control
var clip_picker: OptionButton
var pose_fields := {}
var key_label: LineEdit
var duration_field: SpinBox
var key_time: SpinBox
var loop_toggle: CheckBox
var strength_field: SpinBox
var path_field: LineEdit
var drag_mode: OptionButton
var dragging_chassis := false
var drag_start := Vector2.ZERO
var drag_pose: Dictionary = {}
var orbiting := false
var camera_yaw := .7
var camera_pitch := .35
var camera_distance := 11.5

func _ready() -> void:
	truck.set_physics_process(false)
	truck.set_process_unhandled_input(false)
	truck.set_process_input(false)
	truck.test_controls_enabled = true
	document = truck.exaggeration.profile.duplicate(true) if not truck.exaggeration.profile.is_empty() else MOTION.template(truck.handling_id)
	build_world()
	build_ui()
	running = false
	truck.exaggeration.preview = true
	set_document()
	sync_editor()
	update_camera()

func selected_clip() -> Dictionary: return document.clips[selected_state]
func selected_frame() -> Dictionary: return selected_clip().keys[selected_key]
func set_document() -> void:
	truck.exaggeration.profile = document
	truck.exaggeration.preview = not live_physics
	truck.exaggeration.preview_state = selected_state
	truck.exaggeration.preview_time = cursor

func text(rows: Container, value: String, size: int = 16) -> Label:
	var label := Label.new(); label.text=value; label.add_theme_font_size_override("font_size",size); rows.add_child(label); return label
func spin(rows: Container, label: String, low: float, high: float, step_value: float, callback: Callable) -> SpinBox:
	var row := HBoxContainer.new(); rows.add_child(row)
	var name_label := text(row,label); name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var field := SpinBox.new(); field.min_value=low; field.max_value=high; field.step=step_value; field.custom_minimum_size.x=126; field.value_changed.connect(callback); row.add_child(field); return field

func build_ui() -> void:
	var canvas := CanvasLayer.new(); add_child(canvas)
	var overlay := preload("res://exaggeration_gizmo.gd").new(); overlay.lab=self; overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); canvas.add_child(overlay)
	var panel := PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); panel.offset_left=16; panel.offset_right=360; panel.offset_top=16; panel.offset_bottom=-16; canvas.add_child(panel)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",8); scroll.add_child(rows)
	text(rows,"CHASSIS EXAGGERATION",21)
	text(rows,"Visual motion over the base physics.",14)
	clip_picker = OptionButton.new()
	for item_name in MOTION.STATES: clip_picker.add_item(item_name.capitalize())
	rows.add_child(clip_picker); clip_picker.item_selected.connect(select_clip)
	var controls := HBoxContainer.new(); rows.add_child(controls)
	button(controls,"Play / pause clip",toggle_clip_playback)
	button(controls,"Reset pose",reset_pose)
	physics_toggle = CheckBox.new(); physics_toggle.text="Replay actual physics"; rows.add_child(physics_toggle)
	physics_toggle.toggled.connect(func(value): live_physics=value; running=value; playing=false; restart_run(); set_document())
	var maneuver_picker := OptionButton.new()
	for item_name in MANEUVERS: maneuver_picker.add_item(item_name)
	rows.add_child(maneuver_picker); maneuver_picker.select(1)
	maneuver_picker.item_selected.connect(func(index): maneuver=index; restart_run())
	var enabled := CheckBox.new(); enabled.text="Apply exaggeration layer"; enabled.button_pressed=true; rows.add_child(enabled)
	enabled.toggled.connect(func(value): truck.exaggeration.enabled=value)
	strength_field=spin(rows,"Layer strength",0,2,.05,func(value): if not syncing: document.strength=value)
	duration_field=spin(rows,"Clip seconds",.1,5,.05,change_duration)
	loop_toggle=CheckBox.new(); loop_toggle.text="Loop clip"; rows.add_child(loop_toggle)
	loop_toggle.toggled.connect(func(value): if not syncing: selected_clip().loop=value)
	text(rows,"Selected keyframe",18)
	key_label=LineEdit.new(); rows.add_child(key_label)
	key_label.text_changed.connect(func(value): if not syncing: selected_frame().label=value; timeline.queue_redraw())
	key_time=spin(rows,"Time (seconds)",0,5,.01,func(value): if not syncing: retime_key(selected_key,value))
	for channel in MOTION.CHANNELS:
		var limit: float = .75 if channel == "heave" else 30.0
		pose_fields[channel]=spin(rows,channel.capitalize()+ (" (m)" if channel == "heave" else " (deg)"),-limit,limit,.01 if channel == "heave" else .25,func(value): edit_pose(channel,value))
	var keys_row := HBoxContainer.new(); rows.add_child(keys_row)
	button(keys_row,"Add key here",add_key); button(keys_row,"Delete key",delete_key)
	text(rows,"Drag the gold chassis handle",16)
	drag_mode=OptionButton.new(); drag_mode.add_item("Pitch + roll"); drag_mode.add_item("Lift / bounce"); drag_mode.add_item("Yaw / twist"); rows.add_child(drag_mode)
	text(rows,"Right drag: orbit. Wheel: zoom.",14)
	path_field=LineEdit.new(); path_field.text=MOTION.default_path(truck.handling_id); rows.add_child(path_field)
	var files := HBoxContainer.new(); rows.add_child(files)
	button(files,"Save JSON",func(): save_to(path_field.text))
	button(files,"Load JSON",func(): load_from(path_field.text))
	button(rows,"Save as...",show_save_dialog)
	status=text(rows,"Save at the default path to use it in-game.",14); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(rows,"Main menu",func(): LoadingScreen.load_scene("res://main_menu.tscn"))
	var bottom := VBoxContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bottom.offset_left=376; bottom.offset_right=-16; bottom.offset_top=-190; bottom.offset_bottom=-16; canvas.add_child(bottom)
	telemetry=text(bottom,"",16)
	timeline=preload("res://exaggeration_timeline.gd").new(); timeline.size_flags_horizontal=Control.SIZE_EXPAND_FILL; bottom.add_child(timeline)
	timeline.scrubbed.connect(scrub)
	timeline.key_selected.connect(select_key)
	timeline.key_retimed.connect(retime_key)

func toggle_clip_playback() -> void:
	if physics_toggle.button_pressed: physics_toggle.button_pressed = false
	playing = not playing
	live_physics = false
	running = false
	set_document()

func select_clip(index: int) -> void:
	selected_state=MOTION.STATES[index]
	if not document.clips.has(selected_state): document.clips[selected_state]=MOTION.template().clips[selected_state]
	selected_key=mini(2,selected_clip().keys.size()-1); cursor=selected_frame().time; playing=false
	set_document(); sync_editor()
func select_key(index: int) -> void:
	selected_key=index; cursor=selected_frame().time; playing=false; set_document(); sync_editor()
func scrub(time: float) -> void:
	cursor=time; playing=false; set_document(); timeline.playhead=cursor; timeline.queue_redraw()
func sync_editor() -> void:
	syncing=true
	clip_picker.select(MOTION.STATES.find(selected_state))
	strength_field.value=document.strength
	duration_field.value=selected_clip().duration
	loop_toggle.button_pressed=selected_clip().loop
	key_label.text=selected_frame().get("label","Pose")
	key_time.max_value=selected_clip().duration; key_time.value=selected_frame().time
	for channel in MOTION.CHANNELS: pose_fields[channel].value=selected_frame()[channel]
	timeline.clip=selected_clip(); timeline.selected=selected_key; timeline.playhead=cursor; timeline.queue_redraw()
	syncing=false
func edit_pose(channel: String, value: float) -> void:
	if syncing: return
	selected_frame()[channel]=value; cursor=selected_frame().time; playing=false; set_document(); timeline.queue_redraw()
func reset_pose() -> void:
	for channel in MOTION.CHANNELS: selected_frame()[channel]=0.0
	set_document(); sync_editor()
func change_duration(value: float) -> void:
	if syncing: return
	var ratio: float = value/selected_clip().duration
	for key in selected_clip().keys: key.time *= ratio
	selected_clip().duration=value; cursor*=ratio; sync_editor()
func retime_key(index: int, value: float) -> void:
	var keys: Array = selected_clip().keys
	var key: Dictionary = keys[index]
	var low: float = keys[index-1].time+.01 if index > 0 else 0.0
	var high: float = keys[index+1].time-.01 if index < keys.size()-1 else selected_clip().duration
	key.time=clampf(value,low,high); selected_key=index; cursor=key.time; playing=false; set_document(); sync_editor()
func add_key() -> void:
	var keys: Array = selected_clip().keys
	for i in keys.size():
		if absf(keys[i].time-cursor) < .01: select_key(i); return
	var pose := MOTION.sample(document,selected_state,cursor)
	for channel in MOTION.CHANNELS: pose[channel] /= maxf(.001,float(document.strength))
	pose.time=cursor; pose.label="Pose"; keys.append(pose); keys.sort_custom(func(a,b): return a.time < b.time)
	selected_key=keys.find(pose); sync_editor()
func delete_key() -> void:
	if selected_clip().keys.size() <= 2: return
	selected_clip().keys.remove_at(selected_key); selected_key=mini(selected_key,selected_clip().keys.size()-1); select_key(selected_key)
func save_to(path: String) -> Error:
	var error: Error = MOTION.save_profile(path,document)
	status.text="Saved "+path+". New trucks read the default path automatically." if error == OK else "Save failed: "+error_string(error)
	return error
func load_from(path: String) -> Error:
	var reader := MOTION.new(); var error: Error = reader.load_profile(path)
	if error == OK:
		document=reader.profile; selected_state=selected_state if document.clips.has(selected_state) else str(document.clips.keys()[0]); selected_key=0; cursor=0; set_document(); sync_editor()
	status.text="Loaded "+path if error == OK else "Load failed: "+error_string(error)
	return error
func show_save_dialog() -> void:
	var dialog := FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE; dialog.filters=PackedStringArray(["*.json ; Exaggeration profile"]); dialog.current_file="truck_exaggeration.json"; add_child(dialog)
	dialog.file_selected.connect(func(path): path_field.text=path; save_to(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered_ratio(.7)

func _physics_process(delta: float) -> void:
	if live_physics: super.step(delta)
	else: truck.update_suspension(delta)
func _process(delta: float) -> void:
	if playing:
		cursor+=delta
		if cursor > selected_clip().duration:
			cursor=fposmod(cursor,selected_clip().duration) if selected_clip().loop else selected_clip().duration
			if not selected_clip().loop: playing=false
	set_document(); update_camera()
	timeline.clip=document.clips.get(truck.exaggeration.state,selected_clip()) if live_physics else selected_clip()
	timeline.selected=-1 if live_physics else selected_key
	timeline.playhead=truck.exaggeration.age if live_physics else cursor
	timeline.queue_redraw()
	telemetry.text="%s | %.2fs | %s | %.1f km/h\nPitch orange / roll teal. Drag diamonds to retime peaks and rebounds." % ["PHYSICS: "+truck.exaggeration.state if live_physics else selected_state.to_upper(),timeline.playhead,selected_frame().get("label","Pose"),truck.speed*3.6]
func update_camera() -> void:
	if camera == null: return
	camera.position=truck.position+Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*camera_distance
	camera.look_at(truck.position+Vector3(-2.3,2.0,0))
func chassis_screen_point() -> Vector2: return camera.unproject_position(truck.global_position+Vector3(0,2.4,0))
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting=event.pressed
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_distance=maxf(8,camera_distance-.7)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_distance=minf(28,camera_distance+.7)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.position.distance_to(chassis_screen_point()) < 65 and not live_physics:
				dragging_chassis=true; drag_start=event.position; drag_pose=selected_frame().duplicate(); playing=false
			elif not event.pressed: dragging_chassis=false
	if event is InputEventMouseMotion:
		if orbiting: camera_yaw-=event.relative.x*.008; camera_pitch=clampf(camera_pitch+event.relative.y*.006,.10,1.1)
		if dragging_chassis: drag_chassis(event.position-drag_start)
func drag_chassis(offset: Vector2) -> void:
	var frame := selected_frame()
	match drag_mode.selected:
		0: frame.pitch=clampf(drag_pose.pitch-offset.y*.15,-30,30); frame.roll=clampf(drag_pose.roll+offset.x*.15,-30,30)
		1: frame.heave=clampf(drag_pose.heave-offset.y*.005,-.75,.75)
		2: frame.yaw=clampf(drag_pose.yaw+offset.x*.15,-30,30)
	cursor=frame.time; set_document(); sync_editor()
