extends Control

const BAND_COUNT := 16
var speech: Node
var levels := PackedFloat32Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	levels.resize(BAND_COUNT)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		levels.fill(0.0)
		return
	var targets := PackedFloat32Array()
	targets.resize(BAND_COUNT)
	if speech != null and speech.has_method("frequency_bands"):
		targets = speech.frequency_bands(BAND_COUNT)
	for index in BAND_COUNT:
		var rate := 25.0 if targets[index] > levels[index] else 8.0
		levels[index] = lerpf(levels[index], targets[index], 1.0 - exp(-rate * delta))
	queue_redraw()

func _draw() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.09, 0.13, 0.95)
	background.set_corner_radius_all(6)
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	var step := (size.x - 12.0) / BAND_COUNT
	for index in levels.size():
		var height := maxf(2.0, levels[index] * (size.y - 10.0))
		draw_rect(Rect2(6.0 + index * step, size.y - 5.0 - height, maxf(1.0, step - 3.0), height), Color(0.40, 0.88, 1.0))
