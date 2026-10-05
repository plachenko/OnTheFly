extends RefCounted
const LIFT := 0.12

static func bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: rect = rect.expand(point)
	return rect

static func sample(city: Node3D, point: Vector2) -> float:
	var cache: Dictionary = city.get_meta("surface_height_cache", {})
	if not cache.has(point):
		cache[point] = city.terrain_surface_height_at(point.x, point.y)
		city.set_meta("surface_height_cache", cache)
	return cache[point]

static func emit_piece(city: Node3D, tool: SurfaceTool, polygon: PackedVector2Array, lift: float, origin: Vector3, lift_at: Callable = Callable()) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for triangle in range(0, indices.size(), 3):
		var a := polygon[indices[triangle]]
		var b := polygon[indices[triangle + 1]]
		var c := polygon[indices[triangle + 2]]
		# Polygon clipping can leave microscopic slivers along shared cell edges.
		# These contribute no visible area and destabilize trimesh collision.
		if absf((b - a).cross(c - a)) < 0.0001: continue
		for index in range(triangle, triangle + 3):
			var point := polygon[indices[index]]
			var local_lift: float = lift_at.call(point) if lift_at.is_valid() else lift
			tool.add_vertex(Vector3(point.x, sample(city, point) + local_lift, point.y) - origin)

static func cell_triangles(city: Node3D, rect: Rect2) -> Array[PackedVector2Array]:
	var segments: int = maxi(8, roundi(city.terrain_size / city.terrain_step))
	var step: float = city.terrain_size / segments
	var origin: float = -city.terrain_size * 0.5
	var result: Array[PackedVector2Array] = []
	var left := floori((rect.position.x - origin) / step)
	var right := ceili((rect.end.x - origin) / step)
	var low := floori((rect.position.y - origin) / step)
	var high := ceili((rect.end.y - origin) / step)
	for z in range(low, high):
		for x in range(left, right):
			var a := Vector2(origin + x * step, origin + z * step)
			var b := a + Vector2(step, 0)
			var c := a + Vector2(0, step)
			var d := a + Vector2.ONE * step
			result.append(PackedVector2Array([a, b, c]))
			result.append(PackedVector2Array([b, d, c]))
	return result

static func emit_polygon(city: Node3D, tool: SurfaceTool, polygon: PackedVector2Array, lift: float, origin: Vector3, lift_at: Callable = Callable()) -> void:
	if polygon.size() < 3: return
	for triangle in cell_triangles(city, bounds(polygon)):
		for piece in Geometry2D.intersect_polygons(polygon, triangle):
			emit_piece(city, tool, piece, lift, origin, lift_at)

static func generate(city: Node3D, material: Material) -> void:
	var layout := preload("res://city_surface_layout.gd")
	var masks := layout.road_masks(city, 0.45)
	var mask_bounds: Array[Rect2] = []
	var whole := bounds(masks[0])
	for mask in masks:
		await city.loading_checkpoint()
		mask_bounds.append(bounds(mask))
		whole = whole.merge(bounds(mask))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in cell_triangles(city, whole):
		await city.loading_checkpoint()
		var rect := bounds(triangle)
		var covered: Array[PackedVector2Array] = []
		for i in masks.size():
			await city.loading_checkpoint()
			if not rect.intersects(mask_bounds[i], true): continue
			for overlap in Geometry2D.intersect_polygons(triangle, masks[i]):
				await city.loading_checkpoint()
				for piece in layout.remaining(overlap, covered): emit_piece(city, tool, piece, LIFT, Vector3.ZERO)
				covered.append(overlap)
	var finished: Array = await city.loading_job(city.finish_loading_mesh.bind(tool, true))
	var mesh: ArrayMesh = finished[0]
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = "Asphalt"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.get_node("Roads").add_child(visual)
	var body := StaticBody3D.new()
	body.set_meta("drivable_surface", true)
	visual.add_child(body)
	var collider := CollisionShape3D.new()
	collider.shape = finished[1]
	body.add_child(collider)

static func emit_polygon_loading(city: Node3D, tool: SurfaceTool, polygon: PackedVector2Array, lift: float, origin: Vector3) -> void:
	if polygon.size() < 3: return
	for triangle in cell_triangles(city, bounds(polygon)):
		await city.loading_checkpoint()
		for piece in Geometry2D.intersect_polygons(polygon, triangle):
			emit_piece(city, tool, piece, lift, origin)
