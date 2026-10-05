extends Control
signal scrubbed(time: float)
signal key_selected(index: int)
signal key_retimed(index: int, time: float)
var clip: Dictionary = {}
var selected := 0
var playhead := 0.0
var dragging_key := false
var dragging_head := false
var pose_sampler: Callable
const LEFT := 28.0
func _ready() -> void:
	custom_minimum_size.y = 130
	mouse_filter = Control.MOUSE_FILTER_STOP
func x_at(time: float) -> float: return LEFT+time/maxf(.1,float(clip.get("duration",1.0)))*(size.x-LEFT*2)
func time_at(x: float) -> float: return clampf((x-LEFT)/maxf(1,size.x-LEFT*2),0,1)*float(clip.get("duration",1.0))
func _gui_input(event: InputEvent) -> void:
	if clip.is_empty(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var nearest := -1
			var distance := 15.0
			for i in clip.keys.size():
				var d: float = event.position.distance_to(Vector2(x_at(clip.keys[i].time),42))
				if d < distance: nearest=i; distance=d
			if nearest >= 0:
				selected=nearest; dragging_key=true; key_selected.emit(nearest)
			else: dragging_head=true; scrubbed.emit(time_at(event.position.x))
		else: dragging_key=false; dragging_head=false
		accept_event()
	if event is InputEventMouseMotion:
		if dragging_key: key_retimed.emit(selected,time_at(event.position.x)); accept_event()
		elif dragging_head: scrubbed.emit(time_at(event.position.x)); accept_event()
func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel","Panel"),Rect2(Vector2.ZERO,size))
	if clip.is_empty(): return
	var font := ThemeDB.fallback_font
	for i in 6:
		var t: float = float(clip.duration)*i/5.0
		var x := x_at(t)
		draw_line(Vector2(x,22),Vector2(x,104),Color("405965"),1)
		draw_string(font,Vector2(x-10,122),"%.2fs" % t,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c9dbdf"))
	for channel in ["pitch","roll"]:
		var points := PackedVector2Array()
		for i in 121:
			var t: float = clip.duration*i/120.0
			var pose: Dictionary = pose_sampler.call(t) if pose_sampler.is_valid() else preload("res://truck_exaggeration.gd").sample({"clips":{"curve":clip},"strength":1.0},"curve",t)
			points.append(Vector2(x_at(t),84.0-float(pose[channel])*.8))
		draw_polyline(points,Color("ed956a") if channel == "pitch" else Color("56d7c2"),2,true)
	for i in clip.keys.size():
		var key: Dictionary = clip.keys[i]
		var x := x_at(key.time)
		var color := Color("ffd280") if i == selected else Color("c3d9df")
		draw_colored_polygon(PackedVector2Array([Vector2(x,34),Vector2(x+7,42),Vector2(x,50),Vector2(x-7,42)]),color)
		draw_string(font,Vector2(clampf(x-25,5,size.x-90),20),key.get("label","Pose"),HORIZONTAL_ALIGNMENT_LEFT,90,12,color)
	draw_line(Vector2(x_at(playhead),24),Vector2(x_at(playhead),105),Color("ffffff"),2)
