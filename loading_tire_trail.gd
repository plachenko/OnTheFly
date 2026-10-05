extends Control
var left_track := PackedVector2Array()
var right_track := PackedVector2Array()
func reset() -> void:
	left_track.clear()
	right_track.clear()
	queue_redraw()
func add_tracks(center: Vector2, heading: float) -> void:
	var forward := Vector2(cos(heading),sin(heading))
	var across := Vector2(-forward.y,forward.x)
	var rear := center-forward*16.0
	var left := rear-across*11.0
	var right := rear+across*11.0
	if not left_track.is_empty() and left_track[-1].distance_to(left) < 2.0: return
	left_track.append(left)
	right_track.append(right)
	if left_track.size() > 2400:
		left_track.remove_at(0)
		right_track.remove_at(0)
	queue_redraw()
func _draw() -> void:
	if left_track.size() < 2: return
	draw_polyline(left_track,Color("3d3029"),3.0,true)
	draw_polyline(right_track,Color("3d3029"),3.0,true)
