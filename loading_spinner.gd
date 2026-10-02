extends Control

var angle := 0.0

func _process(delta: float) -> void:
	angle += delta * 4.5
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 30.0, Color("292b32"))
	draw_arc(center, 23.0, 0.0, TAU, 48, Color("603725"), 4.0, true)
	for index in 12:
		var direction := Vector2.from_angle(angle + index * TAU / 12.0)
		draw_line(center + direction * 15, center + direction * 24, Color(1, 0.88, 0.60, 0.25 + float(index + 1) / 16.0), 4.5, true)
