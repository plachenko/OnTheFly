extends Node3D
const CITY_SCENE: PackedScene = preload("res://procedural_city.tscn")
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
@onready var level=$Level
@onready var options_panel = $Menu/OptionsPanel
func _ready() -> void:
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
    start_pan=sin(elapsed*pan_speed)*pan_distance
    $Menu.hide()
    get_viewport().gui_release_focus()

func finish_start() -> void:
    if start_city:
        var city_level = CITY_SCENE.instantiate()
        get_tree().root.add_child(city_level)
        var city_camera: Camera3D = city_level.get_node("FollowCamera")
        city_camera.global_transform=$MenuCamera.global_transform
        city_level.set("camera_started",true)
        city_camera.make_current()
        get_tree().current_scene=city_level
        city_level.get_node("HUD").refresh_options()
        queue_free()
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
    queue_free()
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and options_panel.visible:
        show_options(false)
