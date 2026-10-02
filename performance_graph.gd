extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(620, 90)

func _process(_delta: float) -> void:
	if is_visible_in_tree(): queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10151c"))
	var values: Array[float] = PerformanceDiagnostics.frame_ms
	var ceiling := 66.7
	for budget in [16.7, 33.3]:
		var y: float = size.y * (1.0 - budget / ceiling)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("466154"), 1.0)
	if values.size() < 2: return
	for index in range(1, values.size()):
		var a := Vector2(float(index - 1) / (values.size() - 1) * size.x, size.y * (1.0 - minf(values[index - 1], ceiling) / ceiling))
		var b := Vector2(float(index) / (values.size() - 1) * size.x, size.y * (1.0 - minf(values[index], ceiling) / ceiling))
		draw_line(a, b, Color("ff625d") if values[index] > 33.3 else Color("55df88"), 1.5)
