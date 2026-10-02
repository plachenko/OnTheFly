extends Control

var elapsed := 0.0
var truck_x := 0.15
var frozen := false
var pattern_entry := 0.0
var dark_entry := 0.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not frozen:
		elapsed += delta
		truck_x = 0.12 + fmod(elapsed * 0.11, 0.76)
	queue_redraw()

func reset() -> void:
	elapsed = 0.0
	frozen = false
	pattern_entry = 0.0
	dark_entry = 0.0
	scale = Vector2.ONE
	position = Vector2.ZERO

func truck_center() -> Vector2:
	return Vector2(size.x * truck_x, size.y * 0.88)

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff2d7"))
	# Diagonal stripes enter from the right, then keep drifting left.
	var stripe_height := h * 0.22
	var stripe_y := -stripe_height * (1.0 - pattern_entry)
	var pitch := 96.0
	for index in range(-3, ceili(w / pitch) + 4):
		var x := index * pitch - fmod(elapsed * 90.0, pitch) + w * (1.0 - pattern_entry)
		draw_colored_polygon(PackedVector2Array([Vector2(x, stripe_y), Vector2(x + pitch * 0.5, stripe_y), Vector2(x + pitch * 0.5 - stripe_height, stripe_y + stripe_height), Vector2(x - stripe_height, stripe_y + stripe_height)]), Color("dd4435"))
	# The entire lower half flies up only after the patterns have arrived.
	var dark_y := h * 0.5 + h * 0.5 * (1.0 - dark_entry)
	draw_rect(Rect2(0, dark_y, w, h * 0.5), Color("14161d"))
	# The checker band enters from the left and keeps drifting right.
	var tile := maxf(24.0, h * 0.045)
	var checker_y := h * 0.91 + h * 0.09 * (1.0 - pattern_entry)
	for row in 2:
		for column in range(-2, ceili(w / tile) + 2):
			var x := column * tile + fmod(elapsed * 90.0, tile * 2.0) - w * (1.0 - pattern_entry)
			var color := Color("292b32") if (column + row) % 2 == 0 else Color("fff2d7")
			draw_rect(Rect2(x, checker_y + row * tile, tile, tile), color)
	# Keep the skyline and driving marker attached to the arriving panel.
	var lower_offset := h * 0.5 * (1.0 - dark_entry)
	var hills := PackedVector2Array([Vector2(0, h * 0.84)])
	for index in 81:
		var x := float(index) / 80.0
		hills.append(Vector2(w * x, h * (0.76 - 0.045 * sin(x * TAU * 1.6) - 0.025 * sin(x * TAU * 3.5))))
	hills.append(Vector2(w, h * 0.84))
	for index in hills.size():
		hills[index].y += lower_offset
	draw_colored_polygon(hills, Color("292b32"))
	for index in 17:
		var x := w * float(index) / 16.0
		var roof := h * (0.66 + 0.04 * sin(index * 2.7))
		draw_rect(Rect2(x, roof + lower_offset, w * 0.032, h * 0.84 - roof), Color("292b32"))
	var center := truck_center() + Vector2(0, lower_offset)
	draw_rect(Rect2(center - Vector2(w * 0.023, h * 0.014), Vector2(w * 0.046, h * 0.028)), Color("ffe4a0"))
	draw_line(Vector2(0, h * 0.905 + lower_offset), Vector2(w, h * 0.905 + lower_offset), Color("603725"), 2.0)
