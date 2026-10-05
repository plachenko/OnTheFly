extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(20, 20)

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, 10), Vector2(10, 0), Vector2(20, 10), Vector2(14, 10), Vector2(14, 20), Vector2(6, 20), Vector2(6, 10)]), Color(0.55, 0.94, 1.0))
