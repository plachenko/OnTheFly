extends RefCounted

static func road_masks(city: Node3D, shoulder: float = 0.0) -> Array[PackedVector2Array]:
	var masks: Array[PackedVector2Array] = []
	var rules := preload("res://city_road_rules.gd")
	var extent: float = city.road_visual_extent
	for x in range(-128, 129, 64):
		var left: float = x - city.road_width * 0.5 - rules.extra_width(true, x, -1) - shoulder
		var right: float = x + city.road_width * 0.5 + rules.extra_width(true, x, 1) + shoulder
		masks.append(rect_polygon(Rect2(Vector2(left, -extent), Vector2(right - left, extent * 2))))
	for z in range(-144, 177, 64):
		var low: float = z - city.road_width * 0.5 - rules.extra_width(false, z, -1) - shoulder
		var high: float = z + city.road_width * 0.5 + rules.extra_width(false, z, 1) + shoulder
		masks.append(rect_polygon(Rect2(Vector2(-extent, low), Vector2(extent * 2, high - low))))
	if city.diagonal_roads_enabled:
		for segment in city.diagonal_road_segments:
			var start := Vector2(segment.x, segment.y)
			var finish := Vector2(segment.z, segment.w)
			if start.distance_to(finish) < 1: continue
			var direction := (finish - start).normalized()
			var right: Vector2 = Vector2(-direction.y, direction.x) * (city.diagonal_road_width * 0.5 + shoulder)
			masks.append(PackedVector2Array([start - right, finish - right, finish + right, start + right]))
	return masks

static func rect_polygon(bounds: Rect2) -> PackedVector2Array:
	return PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])

static func remaining(polygon: PackedVector2Array, masks: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [polygon]
	for mask in masks:
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			for result in Geometry2D.clip_polygons(piece, mask):
				if not Geometry2D.is_polygon_clockwise(result): next.append(result)
		pieces = next
		if pieces.is_empty(): break
	return pieces

static func emit_polygon(city: Node3D, tool: SurfaceTool, polygon: PackedVector2Array, lift: float, origin: Vector3, subdivide: bool = true) -> void:
	preload("res://city_road_surface.gd").emit_polygon(city, tool, polygon, lift, origin)

static func emit_triangle(city: Node3D, tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, lift: float, origin: Vector3, depth: int = 0) -> void:
	if depth < 7 and maxf(a.distance_squared_to(b), maxf(b.distance_squared_to(c), c.distance_squared_to(a))) > 4.0:
		var ab := (a + b) * 0.5
		var bc := (b + c) * 0.5
		var ca := (c + a) * 0.5
		emit_triangle(city, tool, a, ab, ca, lift, origin, depth + 1)
		emit_triangle(city, tool, ab, b, bc, lift, origin, depth + 1)
		emit_triangle(city, tool, ca, bc, c, lift, origin, depth + 1)
		emit_triangle(city, tool, ab, bc, ca, lift, origin, depth + 1)
		return
	# Geometry2D triangulation already supplies Godot front-face ordering.
	for point in [a, b, c]:
		var ground: float = city.terrain_surface_height_at(point.x, point.y)
		tool.add_vertex(Vector3(point.x, ground + lift, point.y) - origin)

static func add_patch(city: Node3D, parent: Node3D, label: String, polygon: PackedVector2Array, lift: float, material: Material, shoulder: float) -> void:
	add_patches(city, parent, label, [polygon], lift, material, shoulder)

static func add_patches(city: Node3D, parent: Node3D, label: String, polygons: Array[PackedVector2Array], lift: float, material: Material, shoulder: float) -> void:
	var pieces: Array[PackedVector2Array] = []
	var masks := road_masks(city, shoulder)
	for polygon in polygons: pieces.append_array(remaining(polygon, masks))
	if pieces.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces: emit_polygon(city, tool, piece, lift, parent.position)
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	parent.add_child(visual)
	if label in ["Grass", "ParkGrass", "ParkPath_X", "ParkPath_Z", "Sidewalk"]:
		visual.create_trimesh_collision()
		for body in visual.get_children(): body.set_meta("sidewalk", true)
