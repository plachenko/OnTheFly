extends Node3D
@export var pan_distance: float = .35
@export var pan_speed: float = .22
@export var camera_origin: Vector3 = Vector3(-15,3.2,2.2)
@export var camera_focus: Vector3 = Vector3(0,2.2,2.2)
@export var transition_duration: float = 0.85
var elapsed: float = 0.0
var starting: bool = false
var transition_elapsed: float = 0.0
var start_pan: float = 0.0
var start_city: bool = false
var multiplayer_dialog: ConfirmationDialog
@onready var level=$Level
@onready var options_panel = $Menu/OptionsPanel
func _ready() -> void:
    var updates=Button.new()
    updates.text="Updates"
    updates.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    updates.offset_left=-180
    updates.offset_right=-25
    updates.offset_top=-82
    updates.offset_bottom=-38
    $Menu.add_child(updates)
    updates.pressed.connect(open_updater)
    multiplayer_dialog=preload("res://multiplayer_menu.gd").new()
    add_child(multiplayer_dialog)
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
    lab.pressed.connect(func(): LoadingScreen.load_scene("res://performance_lab.tscn"))
    $Menu/Actions.add_child(lab)
    var action_names=["NewGame","ProceduralCity","HostGame","JoinGame","PerformanceLab","Options","Quit"]
    for index in action_names.size():
        var button=$Menu/Actions.get_node(action_names[index])
        button.position=Vector2(25,87+index*62)
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
func open_updater() -> void:
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
    var pan=sin(elapsed*pan_speed)*pan_distance
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
        $MenuCamera.global_position=truck_position+camera_origin+Vector3(0,0,pan)
        $MenuCamera.look_at(truck_position+camera_focus+Vector3(0,0,pan))
    var devices=Input.get_connected_joypads()
    options_panel.get_node("ControllerName").text="Connected: "+Input.get_joy_name(devices[0]) if not devices.is_empty() else "Keyboard or MCON / XInput controller"

func start_game(procedural: bool = false) -> void:
    if starting:return
    start_city=procedural
    var bank=get_node("/root/GameOptions")
    level.starting_luck=randi_range(-level.starting_luck_range,level.starting_luck_range)
    level.money=maxi(0,level.starting_money+level.starting_luck)
    level.carried_balance=false
    bank.round_balance=level.money
    starting=true
    get_node("/root/LoadingScreen").begin_cover()
    start_pan=sin(elapsed*pan_speed)*pan_distance
    $Menu.hide()
    get_viewport().gui_release_focus()
    set_process(false)
    finish_start.call_deferred()

func finish_start() -> void:
    if start_city:
        set_process(false)
        var loaded: bool = await get_node("/root/LoadingScreen").load_scene("res://procedural_city.tscn", $MenuCamera.global_transform)
        if not loaded:
            starting = false
            transition_elapsed = 0.0
            $Menu.show()
            set_process(true)
        return
    set_process(false)
    level.camera.global_transform=$MenuCamera.global_transform
    level.camera_started=true
    level.camera.make_current()
    level.reparent(get_tree().root)
    get_tree().current_scene=level
    level.set_process(true)
    level.set_process_unhandled_input(true)
    level.truck.set_physics_process(true)
    level.get_node("HUD").show()
    level.get_node("HUD").refresh_options()
    level.get_node("HUD").set_process(true)
    level.get_node("HUD").set_process_input(true)
    await get_node("/root/LoadingScreen").finish_cover()
    queue_free()
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and options_panel.visible:
        show_options(false)
