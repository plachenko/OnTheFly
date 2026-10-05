extends Control
var lab: Node
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if lab == null or lab.camera == null: return
	var center: Vector2 = lab.chassis_screen_point()
	draw_arc(center,25,0,TAU,32,Color("ffd280"),2,true)
	draw_line(center-Vector2(40,0),center+Vector2(40,0),Color("ffd280"),2)
	draw_line(center-Vector2(0,40),center+Vector2(0,40),Color("ffd280"),2)
	draw_circle(center,4,Color("fff2d7"))
	draw_string(ThemeDB.fallback_font,center+Vector2(32,-30),"Drag chassis",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff2d7"))
