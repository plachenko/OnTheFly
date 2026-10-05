extends ColorRect

var animation_started_msec := 0
var shader_clock_epoch_msec := 0
var steering_offset := 0.0
var steering_heading := 0.0
var controlled := false
var trails: Control
var elapsed: float:
	get: return float(Time.get_ticks_msec()-animation_started_msec)/1000.0
var smoothing_at := -1.0
var finish_travel_seconds := 1.5
var pattern_entry := 0.0:
	set(value):
		pattern_entry = value
		if material: material.set_shader_parameter("pattern_entry",value)
var dark_entry := 0.0:
	set(value):
		dark_entry = value
		if material: material.set_shader_parameter("dark_entry",value)

func _ready() -> void:
	shader_clock_epoch_msec = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://loading_backdrop.gdshader")
	material = shader_material
	trails = preload("res://loading_tire_trail.gd").new()
	trails.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trails.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trails)
	var hint := Label.new()
	hint.text = "Left stick / A, D: steer"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.add_theme_font_size_override("font_size",16)
	hint.add_theme_color_override("font_color",Color("ffe4a0"))
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 24
	hint.offset_top = -112
	hint.offset_right = 330
	hint.offset_bottom = -86
	resized.connect(update_size)
	update_size()
	reset()

func update_size() -> void:
	material.set_shader_parameter("panel_size",size)
	if is_instance_valid(trails): trails.reset()

func reset() -> void:
	animation_started_msec = Time.get_ticks_msec()
	smoothing_at = -1.0
	steering_offset = 0.0
	steering_heading = 0.0
	controlled = false
	material.set_shader_parameter("run_started",(animation_started_msec-shader_clock_epoch_msec)/1000.0)
	material.set_shader_parameter("smoothing_at",-1.0)
	material.set_shader_parameter("steering_offset",0.0)
	material.set_shader_parameter("steering_heading",0.0)
	material.set_shader_parameter("controlled_tracks",false)
	if is_instance_valid(trails):
		trails.reset()
		trails.hide()
	pattern_entry = 0.0
	dark_entry = 0.0
	scale = Vector2.ONE
	position = Vector2.ZERO

func route_y(x: float) -> float:
	return .74+smoothstep(.12,.8,x)*(.035*sin(x*23.0)+.018*sin(x*47.0))

func steer_loading_truck(delta: float, input: float) -> void:
	if absf(input) > .08: controlled = true
	var previous := steering_offset
	var x := .12+.70*(1.0-exp(-elapsed/6.0))
	var road := route_y(x)
	# Keep the controllable truck below the map and above the checker band.
	steering_offset = clampf(steering_offset+input*delta*.085,maxf(-.065,.69-road),minf(.065,.86-road))
	var y_velocity := (steering_offset-previous)/maxf(delta,.001)
	var speed := maxf(.025,.70/6.0*exp(-elapsed/6.0))
	steering_heading = lerpf(steering_heading,atan2(y_velocity*size.y,speed*size.x),1.0-exp(-delta*9.0))
	material.set_shader_parameter("steering_offset",steering_offset)
	material.set_shader_parameter("steering_heading",steering_heading)
	material.set_shader_parameter("controlled_tracks",controlled)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	steer_loading_truck(delta,Input.get_axis("left","right"))
	trails.visible = controlled
	var x := .12+.70*(1.0-exp(-elapsed/6.0))
	var spin := -1.0
	if smoothing_at >= 0.0:
		var travel := maxf(0.0,elapsed-smoothing_at)
		x = lerpf(float(material.get_shader_parameter("smoothing_x")),.88,clampf(travel/finish_travel_seconds,0.0,1.0))
		spin = travel-finish_travel_seconds
	var y := route_y(x)+steering_offset
	var heading := atan2((route_y(x+.001)-route_y(x-.001))*size.y,.002*size.x)+steering_heading
	if spin >= 0.0:
		var theta := spin*4.5
		x = (.88*size.x+sin(theta)*30.0)/size.x
		y = (route_y(.88)*size.y-30.0+cos(theta)*30.0)/size.y+steering_offset
		heading = -theta+steering_heading
	trails.add_tracks(Vector2(x*size.x,y*size.y),heading)

func begin_smoothing() -> void:
	if smoothing_at >= 0.0: return
	smoothing_at = elapsed
	var x := .12+.70*(1.0-exp(-elapsed/6.0))
	finish_travel_seconds = clampf((.88-x)/.12,.7,2.0)
	material.set_shader_parameter("smoothing_at",smoothing_at)
	material.set_shader_parameter("smoothing_x",x)
	material.set_shader_parameter("finish_travel_seconds",finish_travel_seconds)
