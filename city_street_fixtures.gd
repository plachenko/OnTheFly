extends RefCounted

# Shared terrain-clipped meshes keep fixtures flush even across terrain cells.
static func generate(city: Node3D, verticals: Array[int], horizontals: Array[int], metal: Material, detail: Material) -> void:
	var rules := preload("res://city_road_rules.gd")
	var centers: Array[Vector2] = []
	for x in verticals:
		for z in horizontals:
			centers.append(Vector2(x + 3.6, z + 3.6))
		for i in range(horizontals.size() - 1):
			centers.append(Vector2(x + 3.6, (horizontals[i] + horizontals[i + 1]) * 0.5))
	for z in horizontals:
		for i in range(verticals.size() - 1):
			centers.append(Vector2((verticals[i] + verticals[i + 1]) * 0.5, z - 3.6))
	# Match the actual crosswalk orientation/selection, placing drains on the
	# approach side beyond its 1.8 m half-depth and before the stop bar.
	for x in verticals:
		for z in [-80, -16, 48, 112]:
			var junction := Vector3(x, 0, z)
			if rules.has_approach_crosswalk(city, Vector3.RIGHT, junction):
				var distance: float = (city.crosswalk_setback + 1.8 + rules.stop_boundary(city, Vector3.RIGHT, junction) - 0.21) * 0.5
				city.add_sewer_grate(Vector2(x - distance, z + city.road_width * 0.5 + rules.extra_width(false, z, 1) - 0.8), false, metal, detail)
			if rules.has_approach_crosswalk(city, Vector3.BACK, junction):
				var distance: float = (city.crosswalk_setback + 1.8 + rules.stop_boundary(city, Vector3.BACK, junction) - 0.21) * 0.5
				city.add_sewer_grate(Vector2(x - city.road_width * 0.5 - rules.extra_width(true, x, -1) + 0.8, z - distance), true, metal, detail)
	var base := SurfaceTool.new()
	var pattern := SurfaceTool.new()
	base.begin(Mesh.PRIMITIVE_TRIANGLES)
	pattern.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed: Array[Vector2] = []
	for center in centers:
		# Keep covers clear of diagonal center paint and island crossings.
		if city.distance_to_diagonal_road(center) < city.diagonal_road_width * 0.5 + 1.0: continue
		placed.append(center)
		var disc := PackedVector2Array()
		for i in 24: disc.append(center + Vector2.from_angle(TAU * i / 24.0) * 0.72)
		emit(city, base, disc, 0.165)
		# Inset disk leaves a dark circular rim; parallel ribs read at game scale.
		var inset := PackedVector2Array()
		for i in 24: inset.append(center + Vector2.from_angle(TAU * i / 24.0) * 0.59)
		emit(city, pattern, inset, 0.17)
		for offset in [-0.36, -0.12, 0.12, 0.36]:
			var half := sqrt(0.54 * 0.54 - offset * offset)
			var rect := Rect2(center + Vector2(-half, offset - 0.035), Vector2(half * 2, 0.07))
			emit(city, base, preload("res://city_surface_layout.gd").rect_polygon(rect), 0.175)
	commit(city, base, "ManholeCovers", metal, placed)
	commit(city, pattern, "ManholeInsets", detail, placed)

static func emit(city: Node3D, tool: SurfaceTool, polygon: PackedVector2Array, lift: float) -> void:
	preload("res://city_road_surface.gd").emit_polygon(city, tool, polygon, lift, Vector3.ZERO)

static func commit(city: Node3D, tool: SurfaceTool, label: String, material: Material, centers: Array[Vector2]) -> void:
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("fixture_centers", centers)
	city.get_node("Roads").add_child(visual)
