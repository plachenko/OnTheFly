extends RefCounted
const Layout = preload("res://city_surface_layout.gd")

static func area(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size(): total += points[i].cross(points[(i + 1) % points.size()])
	return absf(total) * 0.5

static func pieces(city: Node3D, center: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for raw in Layout.remaining(city.rounded_block_contour(center), Layout.road_masks(city, 0.45)):
		if area(raw) < 30: continue
		# Round the new diagonal corners as well as the original block corners.
		for inset in Geometry2D.offset_polygon(raw, -1.2, Geometry2D.JOIN_ROUND):
			for rounded in Geometry2D.offset_polygon(inset, 1.2, Geometry2D.JOIN_ROUND):
				result.append(rounded)
	return result

static func inner_pieces(city: Node3D, center: Vector2) -> Array[PackedVector2Array]:
	var inner: Array[PackedVector2Array] = []
	for outer in pieces(city, center):
		for polygon in Geometry2D.offset_polygon(outer, -city.sidewalk_width, Geometry2D.JOIN_ROUND):
			if area(polygon) > 1: inner.append(polygon)
	return inner

static func make_block(city: Node3D, center: Vector2, material: Material) -> void:
	var shapes := pieces(city, center)
	if shapes.is_empty(): return
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in shapes:
		Layout.emit_polygon(city, top, polygon, city.sidewalk_height, Vector3.ZERO)
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			var direction := (b - a).normalized()
			var inward := Vector2(-direction.y, direction.x) * 0.18
			Layout.emit_polygon(city, edge, PackedVector2Array([a, b, b + inward, a + inward]), city.sidewalk_height + 0.015, Vector3.ZERO, false)
			var ah: float = city.terrain_surface_height_at(a.x, a.y)
			var bh: float = city.terrain_surface_height_at(b.x, b.y)
			var high_a := Vector3(a.x, ah + city.sidewalk_height, a.y)
			var high_b := Vector3(b.x, bh + city.sidewalk_height, b.y)
			var low_a := Vector3(a.x, ah + 0.06, a.y)
			var low_b := Vector3(b.x, bh + 0.06, b.y)
			for vertex in [high_a, high_b, low_a, high_b, low_b, low_a]: sides.add_vertex(vertex)
	var slab := add_mesh(city.get_node("Roads"), "RoundedSidewalk", top, material, true)
	slab.set_meta("island_shapes", shapes)
	var curb_material := StandardMaterial3D.new()
	curb_material.albedo_color = Color("ede5cb")
	curb_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_mesh(city.get_node("Roads"), "IslandCurbFaces", sides, curb_material, false)
	add_mesh(city.get_node("Roads"), "IslandCurbOutline", edge, curb_material, false)

static func add_mesh(parent: Node3D, title: String, tool: SurfaceTool, material: Material, collision: bool) -> MeshInstance3D:
	tool.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.mesh = tool.commit()
	visual.mesh.surface_set_material(0, material)
	parent.add_child(visual, true)
	if collision:
		visual.create_trimesh_collision()
		for body in visual.get_children(): body.set_meta("sidewalk", true)
	return visual

static func crosswalks(city: Node3D) -> void:
	if not city.diagonal_roads_enabled: return
	var all_shapes: Array[PackedVector2Array] = []
	for x in range(-96, 97, 64):
		for z in range(-112, 145, 64):
			all_shapes.append_array(pieces(city, Vector2(x, z)))
	var centers: Array[Vector2] = []
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("fff6de")
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	for polygon in all_shapes:
		for segment in city.diagonal_road_segments:
			var start := Vector2(segment.x, segment.y)
			var finish := Vector2(segment.z, segment.w)
			var direction := (finish - start).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var best := Vector2.ZERO
			var best_length := 0.0
			for i in polygon.size():
				var a := polygon[i]
				var b := polygon[(i + 1) % polygon.size()]
				var midpoint := (a + b) * 0.5
				var foot := Geometry2D.get_closest_point_to_segment(midpoint, start, finish)
				if absf(midpoint.distance_to(foot) - (city.diagonal_road_width * 0.5 + 0.45)) > 0.5: continue
				if city.on_grid_road(foot, 4.5): continue
				if a.distance_to(b) > best_length:
					best_length = a.distance_to(b)
					best = foot
			if best_length < 3: continue
			var duplicate := false
			for existing in centers:
				if existing.distance_to(best) < 9: duplicate = true
			if duplicate: continue
			var reach: float = city.diagonal_road_width * 0.5 + 1.8
			var a := best - normal * reach
			var b := best + normal * reach
			var a_valid := false
			var b_valid := false
			for shape in all_shapes:
				a_valid = a_valid or Geometry2D.is_point_in_polygon(a, shape)
				b_valid = b_valid or Geometry2D.is_point_in_polygon(b, shape)
			if not a_valid or not b_valid: continue
			centers.append(best)
			var crossing := preload("res://island_crosswalk.gd").new()
			crossing.name = "IslandCrosswalk"
			crossing.position = Vector3(best.x, 0, best.y)
			crossing.endpoint_a = Vector3(a.x, city.height_at(a.x, a.y) + city.sidewalk_height, a.y)
			crossing.endpoint_b = Vector3(b.x, city.height_at(b.x, b.y) + city.sidewalk_height, b.y)
			crossing.crossing_offset = reach
			crossing.intersection_center_x = best.x
			crossing.crosses_vertical_road = absf(normal.x) > absf(normal.y)
			crossing.set_meta("island", true)
			crossing.set_meta("endpoints", [a, b])
			city.get_node("Crosswalks").add_child(crossing, true)
			var stripes := SurfaceTool.new()
			stripes.begin(Mesh.PRIMITIVE_TRIANGLES)
			for step in range(-ceili(city.diagonal_road_width * 0.5), ceili(city.diagonal_road_width * 0.5) + 1):
				var midpoint := best + normal * float(step)
				var polygon_strip := PackedVector2Array([midpoint - direction * 1.7 - normal * 0.22, midpoint + direction * 1.7 - normal * 0.22, midpoint + direction * 1.7 + normal * 0.22, midpoint - direction * 1.7 + normal * 0.22])
				Layout.emit_polygon(city, stripes, polygon_strip, 0.27, crossing.position)
			add_mesh(crossing, "ZebraStripes", stripes, paint, false)
			var ramp_material := StandardMaterial3D.new()
			ramp_material.albedo_color = Color(0.65, 0.66, 0.62)
			for side in [-1.0, 1.0]:
				var ramp := SurfaceTool.new()
				ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
				var distances: Array[float] = [city.diagonal_road_width * 0.5 - 1.2, city.diagonal_road_width * 0.5 + 0.45, reach + 0.8]
				for part in range(2):
					var polygon_ramp := PackedVector2Array()
					for corner in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
						var index := part + int(corner.y)
						var point: Vector2 = best + normal * side * distances[index] + direction * corner.x * 1.7
						polygon_ramp.append(point)
					var ramp_lift := func(point: Vector2) -> float:
						var distance: float = (point - best).dot(normal) * side
						var blend := clampf((distance - distances[0]) / (distances[1] - distances[0]), 0, 1)
						return lerpf(0.123, city.sidewalk_height + 0.005, blend)
					preload("res://city_road_surface.gd").emit_polygon(city, ramp, polygon_ramp, 0, crossing.position, ramp_lift)
				add_mesh(crossing, "CurbRamp", ramp, ramp_material, true)
