extends Node3D
@export var pan_distance: float = .35
@export var pan_speed: float = .22
@export var camera_origin: Vector3 = Vector3(-15,3.2,2.2)
@export var camera_focus: Vector3 = Vector3(0,2.2,2.2)
@export var transition_duration: float = 0.85
@export var use_saved_menu_city := true
@export var menu_ground_fill_offset: float = -0.6
@export var menu_ground_fill_color := Color(0.035, 0.055, 0.10, 1.0)
var menu_ready := false
var stage: RefCounted
var elapsed: float = 0.0
var starting: bool = false
var transition_elapsed: float = 0.0
var start_pan: float = 0.0
var start_city: bool = false
var multiplayer_dialog: ConfirmationDialog
var city_menu: PanelContainer
var lab_menu: PanelContainer
var city_size_picker: OptionButton
var bridges_picker: CheckButton
var earlier_style_picker: CheckButton
@onready var level=$Level
@onready var options_panel = $Menu/OptionsPanel
func _ready() -> void:
	var updates=Button.new()
	updates.text="Updates"
	updates.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	updates.offset_left=65
	updates.offset_right=220
	updates.offset_top=-125
	updates.offset_bottom=-81
	$Menu.add_child(updates)
	updates.pressed.connect(open_updater)
	var share := Button.new()
	share.name = "Share"
	share.text = "Share"
	share.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	share.offset_left = 240
	share.offset_right = 395
	share.offset_top = -125
	share.offset_bottom = -81
	$Menu.add_child(share)
	var share_dialog := preload("res://share_dialog.gd").new()
	add_child(share_dialog)
	share.pressed.connect(share_dialog.show_release)
	var debug := Button.new()
	debug.name = "Debug"
	debug.text = "Debug"
	debug.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	debug.offset_left = 415
	debug.offset_right = 570
	debug.offset_top = -125
	debug.offset_bottom = -81
	$Menu.add_child(debug)
	debug.pressed.connect(DebugMenu.open_menu)
	multiplayer_dialog=preload("res://multiplayer_menu.gd").new()
	add_child(multiplayer_dialog)
	$Menu/Actions/Heading.hide()
	$Menu/Actions.offset_top=190
	$Menu/Actions.offset_bottom=720
	for spec in [["HostGame","Host multiplayer",true],["JoinGame","Join multiplayer",false]]:
		var button=Button.new()
		button.name=spec[0]
		button.text=spec[1]
		button.add_theme_font_size_override("font_size",22)
		button.pressed.connect(multiplayer_dialog.open.bind(spec[2]))
		$Menu/Actions.add_child(button)
	var lab=Button.new()
	lab.name="PerformanceLab"
	lab.text="Performance lab"
	lab.add_theme_font_size_override("font_size",22)
	lab.pressed.connect(func(): show_submenu(lab_menu))
	$Menu/Actions.add_child(lab)
	var generate_button=Button.new()
	generate_button.name="GenerateCity"
	generate_button.text="Generate New City"
	generate_button.add_theme_font_size_override("font_size",22)
	generate_button.pressed.connect(func(): show_submenu(city_menu))
	$Menu/Actions.add_child(generate_button)
	build_submenus()
	$Menu/Actions/ProceduralCity.text="Play Saved City"
	var action_names=["NewGame","ProceduralCity","GenerateCity","HostGame","JoinGame","PerformanceLab","Options","Quit"]
	for index in action_names.size():
		var button=$Menu/Actions.get_node(action_names[index])
		button.position=Vector2(25,25+index*56)
		button.size=Vector2(285,48)
	$Menu/Actions/NewGame.text="Single player"
	if not NetworkSession.last_error.is_empty():
		$Menu/Footer.text=NetworkSession.last_error
		NetworkSession.last_error=""
	level.set_process(false)
	level.set_process_unhandled_input(false)
	level.truck.set_physics_process(false)
	level.get_node("HUD").hide()
	level.get_node("HUD").set_process(false)
	level.get_node("HUD").set_process_input(false)
	$MenuCamera.make_current()
	$Menu/Actions/NewGame.pressed.connect(start_game)
	$Menu/Actions/ProceduralCity.pressed.connect(func(): start_game(true))
	$Menu/Actions/Options.pressed.connect(func(): show_options(true))
	$Menu/Actions/Quit.pressed.connect(func(): get_tree().quit())
	options_panel.get_node("Close").pressed.connect(func(): show_options(false))
	var settings=get_node("/root/GameOptions")
	settings.bind_video_audio(options_panel)
	for field in [["StickDeadzone","stick_deadzone"],["TriggerDeadzone","trigger_deadzone"],["SteeringSensitivity","steering_sensitivity"]]:
		var slider=options_panel.get_node(field[0])
		slider.value=settings.get(field[1])
		slider.value_changed.connect(func(value): settings.set(field[1],value); update_labels())
	options_panel.get_node("Vibration").button_pressed=settings.vibration_enabled
	options_panel.get_node("Vibration").toggled.connect(func(value): settings.vibration_enabled=value)
	options_panel.visible=false
	update_labels()
	$Menu/Actions/NewGame.grab_focus()
	stage = preload("res://menu_stage.gd").new()
	await stage.prepare(self)
	get_tree().node_added.connect(hide_new_world_label)
	menu_ready = true

func hide_new_world_label(node: Node) -> void:
	if node is Label3D:
		hide_world_label.call_deferred(node)

func hide_world_label(node: Node) -> void:
	if not menu_ready or not is_instance_valid(node) or not level.is_ancestor_of(node): return
	if node.visible:
		if not stage.hidden.has(node): stage.hidden.append(node)
		node.hide()

func is_loading_ready() -> bool:
	return menu_ready

func open_updater() -> void:
	if OS.get_name() == "Android":
		UpdateNotifications.check_for_updates(true)
		return
	var script_path=OS.get_executable_path().get_base_dir().path_join("Update_Game.ps1")
	var dialog=ConfirmationDialog.new()
	dialog.title="Game updates"
	dialog.dialog_text="Close the game and open the launcher to check for updates?"
	dialog.ok_button_text="Exit and check"
	add_child(dialog)
	if OS.has_feature("editor") or OS.get_name()!="Windows" or not FileAccess.file_exists(script_path):
		dialog.dialog_text="Launch the exported game using Launch_OnTheFly.cmd to check for updates."
		dialog.ok_button_text="OK"
		dialog.confirmed.connect(dialog.queue_free)
	else:
		dialog.confirmed.connect(func():
			var process_id=OS.create_process("powershell.exe",PackedStringArray(["-NoProfile","-STA","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File",script_path,"-CheckOnOpen"]))
			if process_id>0:get_tree().quit()
			else:dialog.dialog_text="Could not open the launcher. Open Launch_OnTheFly.cmd from the game folder.";dialog.popup_centered())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540,180))
func show_options(showing: bool) -> void:
	if showing:get_node("/root/GameOptions").sync_video_audio(options_panel)
	options_panel.visible=showing
	$Menu/Actions.visible=not showing
	if showing:options_panel.get_node("Close").grab_focus()
	else:$Menu/Actions/Options.grab_focus()
func update_labels() -> void:
	var settings=get_node("/root/GameOptions")
	options_panel.get_node("StickDeadzoneLabel").text="Stick deadzone %d%%"%roundi(settings.stick_deadzone*100)
	options_panel.get_node("TriggerDeadzoneLabel").text="Trigger deadzone %d%%"%roundi(settings.trigger_deadzone*100)
	options_panel.get_node("SteeringSensitivityLabel").text="Steering sensitivity %.2f"%settings.steering_sensitivity
func _process(delta: float) -> void:
	elapsed+=delta
	if not menu_ready: return
	var _pan=sin(elapsed*pan_speed)*pan_distance
	var truck_position: Vector3=level.truck.global_position
	if starting:
		transition_elapsed+=delta
		var fraction=clampf(transition_elapsed/maxf(.1,transition_duration),0.0,1.0)
		var blend=smoothstep(0.0,1.0,fraction)
		var initial_offset=camera_origin-camera_focus
		var yaw=lerpf(atan2(initial_offset.x,initial_offset.z),level.truck.rotation.y+level.orbit,blend)
		var pitch=lerpf(asin(initial_offset.normalized().y),level.pitch,blend)
		var distance=lerpf(initial_offset.length(),level.distance,blend)
		var focus=truck_position+(camera_focus+Vector3(0,0,start_pan)).lerp(Vector3(0,1.8,0),blend)
		$MenuCamera.global_position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
		$MenuCamera.look_at(focus)
		$MenuCamera.fov=lerpf(35.0,level.camera.fov,blend)
		if fraction>=1.0:finish_start.call_deferred()
	else:
		stage.update(self,delta)
	var devices=Input.get_connected_joypads()
	options_panel.get_node("ControllerName").text="Connected: "+Input.get_joy_name(devices[0]) if not devices.is_empty() else "Keyboard or MCON / XInput controller"

func start_game(procedural: bool = false) -> void:
	if starting or not menu_ready:return
	start_city=procedural or stage.saved_city
	var bank=get_node("/root/GameOptions")
	level.starting_luck=randi_range(-level.starting_luck_range,level.starting_luck_range)
	level.money=maxi(0,level.starting_money+level.starting_luck)
	level.carried_balance=false
	bank.round_balance=level.money
	starting=true
	if needs_city_load(): get_node("/root/LoadingScreen").begin_cover()
	start_pan=sin(elapsed*pan_speed)*pan_distance
	$Menu.hide()
	get_viewport().gui_release_focus()
	set_process(false)
	finish_start.call_deferred()

func needs_city_load() -> bool:
	return start_city and not (stage.saved_city and not CityStore.generate_next and level.get_node("ProceduralCity").map_size == CityStore.preferred_size and level.get_node("ProceduralCity").original_grid == CityStore.original_grid and level.get_node("ProceduralCity").earlier_style == CityStore.earlier_style)

func finish_start() -> void:
	if needs_city_load():
		set_process(false)
		var loaded: bool = await get_node("/root/LoadingScreen").load_scene("res://procedural_city.tscn", $MenuCamera.global_transform)
		if not loaded:
			starting = false
			transition_elapsed = 0.0
			$Menu.show()
			set_process(true)
		return
	set_process(false)
	stage.resume()
	var cinematic: Camera3D = $MenuCamera
	var cinematic_pose := cinematic.get_camera_transform()
	var cinematic_fov := cinematic.fov
	cinematic.reparent(level)
	cinematic.make_current()
	level.reparent(get_tree().root)
	get_tree().current_scene=level
	level.set_process(true)
	level.set_process_unhandled_input(true)
	level.truck.set_physics_process(true)
	level.get_node("HUD").show()
	level.get_node("HUD").refresh_options()
	level.get_node("HUD").set_process(true)
	level.get_node("HUD").set_process_input(true)
	level.begin_menu_intro(cinematic_pose, cinematic_fov, cinematic)
	await level.loading_intro_finished
	queue_free()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (city_menu.visible or lab_menu.visible):
		close_submenu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and options_panel.visible:
		show_options(false)

func submenu(title: String, node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -405; panel.offset_right = -70
	panel.offset_top = -185; panel.offset_bottom = 185
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,24)
	panel.add_child(margin)
	var column := VBoxContainer.new(); column.name = "Items"; column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	var heading := Label.new(); heading.text = title; heading.add_theme_font_size_override("font_size",24); column.add_child(heading)
	$Menu.add_child(panel); panel.hide()
	return panel

func submenu_items(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0).get_node("Items")

func submenu_button(column: VBoxContainer, label: String, node_name: String, action: Callable) -> void:
	var button := Button.new(); button.name = node_name; button.text = label
	button.custom_minimum_size.y = 48; button.pressed.connect(action); column.add_child(button)

func build_submenus() -> void:
	city_menu = submenu("Generate New City", "CityGenerationMenu")
	var city_items := submenu_items(city_menu)
	city_size_picker = OptionButton.new(); city_size_picker.name = "CitySize"
	city_size_picker.add_item("New city: Small",0); city_size_picker.add_item("New city: Large",1)
	city_size_picker.select(CityStore.preferred_size); city_size_picker.custom_minimum_size.y = 42
	city_items.add_child(city_size_picker)
	bridges_picker = CheckButton.new(); bridges_picker.name = "Bridges"; bridges_picker.text = "Bridges"
	bridges_picker.button_pressed = not CityStore.original_grid
	city_items.add_child(bridges_picker)
	earlier_style_picker = CheckButton.new()
	earlier_style_picker.name = "EarlierStyle"
	earlier_style_picker.text = "Earlier traffic islands (narrow roads)"
	earlier_style_picker.button_pressed = CityStore.earlier_style
	bridges_picker.disabled = CityStore.earlier_style
	earlier_style_picker.toggled.connect(func(enabled: bool): bridges_picker.disabled = enabled)
	city_items.add_child(earlier_style_picker)
	submenu_button(city_items,"Generate city","Generate",generate_city)
	submenu_button(city_items,"Back","Back",close_submenu)
	lab_menu = submenu("Performance Lab", "PerformanceLabMenu")
	var labs := submenu_items(lab_menu)
	submenu_button(labs,"Rendering / physics lab","RenderingLab",func(): LoadingScreen.load_scene("res://performance_lab.tscn"))
	submenu_button(labs,"Truck handling lab","HandlingLab",func(): LoadingScreen.load_scene("res://scenes/handling_lab.tscn"))
	submenu_button(labs,"Truck exaggeration lab","ExaggerationLab",func(): LoadingScreen.load_scene("res://scenes/truck_exaggeration_lab.tscn"))
	submenu_button(labs,"Patron crowd test","PatronCrowdTest",func(): LoadingScreen.load_scene("res://scenes/patron_crowd_test.tscn"))
	submenu_button(labs,"Back","Back",close_submenu)

func show_submenu(panel: PanelContainer) -> void:
	$Menu/Actions.hide(); city_menu.hide(); lab_menu.hide()
	panel.show()
	submenu_items(panel).get_child(1).grab_focus()

func close_submenu() -> void:
	city_menu.hide(); lab_menu.hide(); $Menu/Actions.show()
	$Menu/Actions/GenerateCity.grab_focus()

func generate_city() -> void:
	CityStore.preferred_size = city_size_picker.selected
	CityStore.original_grid = not bridges_picker.button_pressed
	CityStore.earlier_style = earlier_style_picker.button_pressed
	if CityStore.earlier_style: CityStore.original_grid = true
	CityStore.generate_next = true
	start_game(true)
