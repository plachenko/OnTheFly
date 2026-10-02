extends RefCounted

const WIDTH := 0.13
const ACROSS_ARM := 0.95
const ALONG_ARM := 0.9

static func neighbors(city: Node3D, bay: Node3D, vertical: bool, length: float) -> Array[Node3D]:
	var found: Array[Node3D] = [null, null]
	var center := Vector2(bay.position.x, bay.position.z)
	var along: float = center.y if vertical else center.x
	var grid_start := -144.0 if vertical else -128.0
	var block := floori((along - grid_start) / 64.0)
	for other in bay.get_parent().get_children():
		if other == bay or not other is Node3D or other.get_meta("serving", false): continue
		var axis: Vector3 = other.get_meta("parking_axis", Vector3.ZERO)
		if (absf(axis.z) > 0.5) != vertical: continue
		if other.get_meta("parking_side", 0) != bay.get_meta("parking_side", 0): continue
		var at := Vector2(other.position.x, other.position.z)
		var across: float = absf(at.x - center.x) if vertical else absf(at.y - center.y)
		var next_along: float = at.y if vertical else at.x
		if across > 0.05 or floori((next_along - grid_start) / 64.0) != block: continue
		var other_length: float = other.get_meta("parking_paint_length", city.parking_bay_length)
		var gap := absf(next_along - along) - (length + other_length) * 0.5
		if gap < -0.05 or gap > city.parking_marker_gap + 0.1: continue
		var end := 0 if next_along < along else 1
		if found[end] == null: found[end] = other
	return found

static func segments(city: Node3D, bay: Node3D, vertical: bool, width: float, length: float) -> Array:
	var result: Array = []
	var adjacent := neighbors(city, bay, vertical, length)
	var across_arm := minf(ACROSS_ARM, width * 0.3)
	var along_arm := minf(ALONG_ARM, length * 0.15)
	for end in 2:
		var sign := -1.0 if end == 0 else 1.0
		var along := sign * length * 0.5
		var shared := adjacent[end] != null
		# The bay with the lower along-coordinate owns the shared marks.
		if shared and end == 0: continue
		if shared:
			var neighbor := adjacent[end]
			var separation: float = neighbor.position.z - bay.position.z if vertical else neighbor.position.x - bay.position.x
			var other_length: float = neighbor.get_meta("parking_paint_length", city.parking_bay_length)
			along = (length * 0.5 + separation - other_length * 0.5) * 0.5
		for side in [-1.0, 1.0]:
			var corner := Vector2(side * width * 0.5, along)
			result.append([corner, corner - Vector2(side * across_arm, 0)])
			if shared:
				result.append([corner - Vector2(0, along_arm), corner + Vector2(0, along_arm)])
			else:
				result.append([corner, corner - Vector2(0, sign * along_arm)])
	return result

static func emit(city: Node3D, bay: Node3D, vertical: bool, surface: SurfaceTool, width: float, length: float) -> void:
	var layout := preload("res://city_surface_layout.gd")
	var projection := preload("res://city_road_surface.gd")
	var offset := Vector2(bay.position.x, bay.position.z)
	var covered: Array[PackedVector2Array] = []
	var strokes := segments(city, bay, vertical, width, length)
	bay.set_meta("parking_mark_segments", strokes)
	for stroke in strokes:
		var a: Vector2 = stroke[0] if vertical else Vector2(stroke[0].y, stroke[0].x)
		var b: Vector2 = stroke[1] if vertical else Vector2(stroke[1].y, stroke[1].x)
		var right := Vector2(-(b - a).y, (b - a).x).normalized() * WIDTH * 0.5
		var polygon := PackedVector2Array([a - right + offset, a + right + offset, b + right + offset, b - right + offset])
		# Union the overlapping elbows/caps, avoiding coplanar double paint.
		for piece in layout.remaining(polygon, covered):
			projection.emit_polygon(city, surface, piece, 0.135, bay.position)
		covered.append(polygon)
