@tool
extends Control
signal color_sampled(color: Color)
var sampling := false
var base: Image
var texture: ImageTexture
var strokes: Array[Dictionary] = []
var current: Dictionary = {}
var pen_color := Color(1.0, 0.15, 0.08)
var pen_width := 8.0

func set_image(image: Image) -> void:
	base = image.duplicate()
	base.convert(Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(base)
	strokes.clear()
	current.clear()
	queue_redraw()
func image_rect() -> Rect2:
	if base == null: return Rect2()
	var dimensions := Vector2(base.get_size())
	var factor := minf(size.x / dimensions.x, size.y / dimensions.y)
	var displayed := dimensions * factor
	return Rect2((size - displayed) * 0.5, displayed)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("20242b"))
	if base == null: return
	var rect := image_rect()
	draw_texture_rect(texture, rect, false)
	var scale_factor := rect.size.x / base.get_width()
	for stroke in strokes:
		var points := PackedVector2Array()
		for point in stroke.points: points.append(rect.position + point * scale_factor)
		if points.size() > 1: draw_polyline(points, stroke.color, stroke.width * scale_factor, true)
		for point in points: draw_circle(point, stroke.width * scale_factor * 0.5, stroke.color)
func _gui_input(event: InputEvent) -> void:
	if base == null: return
	var rect := image_rect()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and rect.has_point(event.position):
			if sampling:
				var point := to_image(event.position)
				var image := painted_image()
				sampling = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				color_sampled.emit(image.get_pixel(roundi(point.x), roundi(point.y)))
				accept_event()
				return
			current = {"color": pen_color, "width": pen_width, "points": PackedVector2Array([to_image(event.position)])}
			strokes.append(current)
		elif not event.pressed: current = {}
		accept_event()
	elif event is InputEventMouseMotion and not current.is_empty():
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			current = {}
			return
		var point := to_image(event.position)
		var points: PackedVector2Array = current.points
		if points[-1].distance_to(point) >= 0.5:
			points.append(point)
			current.points = points
		accept_event()
	queue_redraw()
func to_image(point: Vector2) -> Vector2:
	var rect := image_rect()
	var mapped := (point - rect.position) * base.get_width() / rect.size.x
	return mapped.clamp(Vector2.ZERO, Vector2(base.get_size()) - Vector2.ONE)
func undo() -> void:
	current = {}
	if not strokes.is_empty(): strokes.pop_back()
	queue_redraw()
func clear() -> void:
	current = {}
	strokes.clear()
	queue_redraw()
func paint_disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(maxi(0, floori(center.y-radius)), mini(image.get_height(), ceili(center.y+radius)+1)):
		for x in range(maxi(0, floori(center.x-radius)), mini(image.get_width(), ceili(center.x+radius)+1)):
			var coverage := clampf(radius + 0.5 - Vector2(x, y).distance_to(center), 0, 1) * color.a
			if coverage > 0: image.set_pixel(x, y, image.get_pixel(x, y).lerp(Color(color.r,color.g,color.b,1), coverage))
func painted_image() -> Image:
	if base == null: return null
	var image: Image = base.duplicate()
	for stroke in strokes:
		var points: PackedVector2Array = stroke.points
		if points.is_empty(): continue
		var radius: float = stroke.width * 0.5
		paint_disc(image, points[0], radius, stroke.color)
		for i in range(1, points.size()):
			var count := maxi(1, ceili(points[i-1].distance_to(points[i]) / maxf(1, radius * 0.35)))
			for step in range(1, count+1): paint_disc(image, points[i-1].lerp(points[i], float(step)/count), radius, stroke.color)
	return image
