extends Node
var stick_deadzone: float = .18
var trigger_deadzone: float = .05
var steering_sensitivity: float = 1.0
var vibration_enabled: bool = true
var fullscreen: bool = false
var vsync_enabled: bool = true
var window_size_index: int = 0
var antialiasing: int = 2
var master_volume: float = .8
var round_balance: int = -1
const WINDOW_SIZES = [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1600,1000)]

func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    apply_video()
    apply_audio()

func apply_video() -> void:
    get_tree().root.msaa_3d=antialiasing as Viewport.MSAA
    if DisplayServer.get_name()=="headless":return
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
    if not fullscreen:DisplayServer.window_set_size(WINDOW_SIZES[window_size_index])
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func apply_audio() -> void:
    AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.001,master_volume)))
    AudioServer.set_bus_mute(0,master_volume<=0)

func bind_video_audio(panel: Control) -> void:
    panel.get_node("Fullscreen").button_pressed=fullscreen
    panel.get_node("VSync").button_pressed=vsync_enabled
    panel.get_node("MasterVolume").value=master_volume*100
    panel.get_node("Fullscreen").toggled.connect(func(value): fullscreen=value; apply_video(); refresh_video_audio(panel))
    panel.get_node("VSync").toggled.connect(func(value): vsync_enabled=value; apply_video())
    panel.get_node("WindowSize").pressed.connect(func(): window_size_index=(window_size_index+1)%WINDOW_SIZES.size(); apply_video(); refresh_video_audio(panel))
    panel.get_node("Antialiasing").pressed.connect(func(): antialiasing=(antialiasing+1)%3; apply_video(); refresh_video_audio(panel))
    panel.get_node("MasterVolume").value_changed.connect(func(value): master_volume=value/100.0; apply_audio(); refresh_video_audio(panel))
    panel.get_node("TestSound").pressed.connect(func(): panel.get_node("TestSoundPlayer").play())
    refresh_video_audio(panel)

func refresh_video_audio(panel: Control) -> void:
    var dimensions: Vector2i=WINDOW_SIZES[window_size_index]
    panel.get_node("WindowSize").text="Window size: %d × %d"%[dimensions.x,dimensions.y]
    panel.get_node("WindowSize").disabled=fullscreen
    panel.get_node("Antialiasing").text="Anti-aliasing: "+["Off","2×","4×"][antialiasing]
    panel.get_node("MasterVolumeLabel").text="Master volume: %d%%"%roundi(master_volume*100)

func sync_video_audio(panel: Control) -> void:
    panel.get_node("Fullscreen").set_pressed_no_signal(fullscreen)
    panel.get_node("VSync").set_pressed_no_signal(vsync_enabled)
    panel.get_node("MasterVolume").set_value_no_signal(master_volume*100)
    refresh_video_audio(panel)

func _input(event: InputEvent) -> void:
    if not event is InputEventJoypadButton or event.button_index!=JOY_BUTTON_A:
        return
    if get_node("/root/DebugMenu").is_view_held(event.device):
        return
    var focused=get_viewport().gui_get_focus_owner()
    if not focused is BaseButton or not focused.is_visible_in_tree() or focused.disabled:
        return
    get_viewport().set_input_as_handled()
    if event.pressed:
        if focused.toggle_mode:
            focused.button_pressed=not focused.button_pressed
        focused.pressed.emit.call_deferred()
