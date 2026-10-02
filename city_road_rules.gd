extends RefCounted

# Stable street rules are shared by geometry, traffic and multiplayer maps.
static func one_way(vertical: bool, coordinate: float) -> int:
	if vertical and is_equal_approx(coordinate, -64.0): return 1
	if not vertical and is_equal_approx(coordinate, 112.0): return -1
	return 0

static func extra_width(vertical: bool, coordinate: float, side: float) -> float:
	if vertical and is_equal_approx(coordinate, 64.0) and side < 0: return 3.2
	if not vertical and is_equal_approx(coordinate, -80.0) and side > 0: return 3.2
	return 0.0

static func allows(axis: Vector3, intersection: Vector3) -> bool:
	var vertical := absf(axis.z) > 0.5
	var direction := one_way(vertical, intersection.x if vertical else intersection.z)
	return direction == 0 or (axis.z if vertical else axis.x) * direction > 0

static func passing_allowed(axis: Vector3, point: Vector3) -> bool:
	var vertical := absf(axis.z) > 0.5
	var across: float = point.x if vertical else point.z
	var coordinate := roundf((across + (128.0 if vertical else 144.0)) / 64.0) * 64.0 - (128.0 if vertical else 144.0)
	if absf(across - coordinate) > 12.0: return true # Legacy off-grid routes.
	return one_way(vertical, coordinate) != 0 or extra_width(vertical, coordinate, -axis.z if vertical else axis.x) > 0

static func paint(city: Node3D, road: Node3D, vertical: bool, coordinate: float, crosses: Array, yellow: Material) -> void:
	var direction := one_way(vertical, coordinate)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f4f3dc")
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	yellow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var passing_side := -1.0 if vertical else 1.0
	var passing := extra_width(vertical, coordinate, passing_side) > 0
	road.set_meta("road_type", "one_way" if direction != 0 else ("passing" if passing else "double_yellow"))
	road.set_meta("one_way_direction", direction)
	for along in range(-floori(city.road_visual_extent), floori(city.road_visual_extent)):
		if city.near_street(along + 0.5, crosses, maxf(city.road_width * 0.5 + 3.0, city.stop_line_setback + 2.0)): continue
		for side in ([0.0] if direction != 0 else [-1.0, 1.0]):
			var dashed: bool = direction != 0 or (passing and side == passing_side)
			if dashed and posmod(along, 8) >= 3: continue
			var across: float = side * 0.23
			var a := Vector2(across, along) if vertical else Vector2(along, across)
			var b := Vector2(across, along + 1) if vertical else Vector2(along + 1, across)
			quad(city, road, surface, a, b, 0.17)
	var mesh := surface.commit()
	mesh.surface_set_material(0, white if direction != 0 else yellow)
	var visual := MeshInstance3D.new()
	visual.name = "RoadPaint"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road.add_child(visual)
	paint_approaches(city, road, vertical, coordinate, crosses, white)
	if direction != 0:
		for cross in crosses:
			var point := Vector2(coordinate + city.road_width * 0.5 + 1.0, cross + 11.0) if vertical else Vector2(cross + 11.0, coordinate + city.road_width * 0.5 + 1.0)
			add_sign(city, point, Vector3(0, 0, direction) if vertical else Vector3(direction, 0, 0))

static func vertex(city: Node3D, road: Node3D, surface: SurfaceTool, point: Vector2) -> void:
	var world := point + Vector2(road.position.x, road.position.z)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(Vector3(point.x, city.terrain_surface_height_at(world.x, world.y) + 0.16, point.y))

static func quad(city: Node3D, road: Node3D, surface: SurfaceTool, a: Vector2, b: Vector2, width: float) -> void:
	var right := Vector2(-(b - a).y, (b - a).x).normalized() * width * 0.5
	var points := [a - right, a + right, b - right, b + right]
	for index in [0, 1, 2, 1, 3, 2]: vertex(city, road, surface, points[index])

static func add_sign(city: Node3D, point: Vector2, axis: Vector3) -> void:
	var post := Node3D.new()
	post.name = "OneWaySign"
	post.position = Vector3(point.x, city.height_at(point.x, point.y), point.y)
	post.set_meta("one_way_axis", axis)
	city.get_node("StreetSigns").add_child(post, true)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("343940")
	var pole := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 3.4
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.07
	cylinder.radial_segments = 8
	pole.mesh = cylinder
	pole.material_override = material
	pole.position.y = 1.7
	post.add_child(pole)
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 0.65, 0.08)
	board.mesh = box
	board.material_override = material
	board.position.y = 3.0
	board.rotation.y = atan2(-axis.z, axis.x)
	post.add_child(board)
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "ONE WAY  →" if side > 0 else "←  ONE WAY"
		label.font_size = 56
		label.pixel_size = 0.005
		label.outline_size = 0
		label.position.z = side * 0.05
		label.rotation.y = 0.0 if side > 0 else PI
		label.modulate = Color("fff9e6")
		board.add_child(label)

static func approach_kind(axis: Vector3, intersection: Vector3, lane_side: float = 4.0) -> String:
	var vertical := absf(axis.z) > 0.5
	var coordinate: float = intersection.x if vertical else intersection.z
	var side: float = -axis.z if vertical else axis.x
	var left := Vector3(axis.z, 0, -axis.x)
	if not allows(left, intersection): return "straight"
	var left_vertical := absf(left.z) > 0.5
	var left_coordinate: float = intersection.x if left_vertical else intersection.z
	var left_side: float = -left.z if left_vertical else left.x
	if one_way(vertical, coordinate) != 0:
		if lane_side > 0: return "straight"
		return "straight_left" if extra_width(left_vertical, left_coordinate, left_side) > 0 else "left"
	if extra_width(vertical, coordinate, side) > 0:
		return "straight_left" if extra_width(left_vertical, left_coordinate, left_side) > 0 else "left"
	if extra_width(left_vertical, left_coordinate, left_side) > 0: return "straight_left"
	return "unmarked"

static func arrow(city: Node3D, road: Node3D, surface: SurfaceTool, center: Vector2, axis: Vector2, left: bool, straight: bool) -> void:
	var right := Vector2(-axis.y, axis.x)
	quad(city, road, surface, center - axis * 2.0, center + axis * 0.4, 0.32)
	if straight:
		quad(city, road, surface, center, center + axis * 1.5, 0.32)
		for point in [center + axis * 2.7, center + axis * 1.1 - right * 0.8, center + axis * 1.1 + right * 0.8]: vertex(city, road, surface, point)
	if left:
		quad(city, road, surface, center + axis * 0.4, center + axis * 0.4 - right * 1.3, 0.32)
		for point in [center + axis * 0.4 - right * 2.4, center - right * 1.0 - axis * 0.4, center - right * 1.0 + axis * 1.2]: vertex(city, road, surface, point)

static func paint_approaches(city: Node3D, road: Node3D, vertical: bool, coordinate: float, crosses: Array, white: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var marked := false
	for cross in crosses:
		var intersection := Vector3(coordinate, 0, cross) if vertical else Vector3(cross, 0, coordinate)
		for direction in [-1.0, 1.0]:
			var axis := Vector3(0, 0, direction) if vertical else Vector3(direction, 0, 0)
			if not allows(axis, intersection): continue
			var kind := approach_kind(axis, intersection)
			if kind == "unmarked": continue
			marked = true
			var axis2 := Vector2(axis.x, axis.z)
			var right := Vector2(-axis.z, axis.x)
			var junction := Vector2(0, cross) if vertical else Vector2(cross, 0)
			var split := extra_width(vertical, coordinate, -axis.z if vertical else axis.x) > 0
			arrow(city, road, surface, junction - axis2 * 24.0 + right * 4.0, axis2, kind in ["left", "straight_left"], kind != "left")
			if one_way(vertical, coordinate) != 0:
				var left_kind := approach_kind(axis, intersection, -4)
				arrow(city, road, surface, junction - axis2 * 24.0 - right * 4.0, axis2, left_kind in ["left", "straight_left"], left_kind != "left")
			if split:
				arrow(city, road, surface, junction - axis2 * 24.0 + right * 8.5, axis2, false, true)
				for along in range(13, 33):
					if along < 21 or along % 6 < 3:
						quad(city, road, surface, junction - axis2 * along + right * 6.2, junction - axis2 * (along + 1) + right * 6.2, 0.15)
	if not marked: return
	var mesh := surface.commit()
	mesh.surface_set_material(0, white)
	var visual := MeshInstance3D.new()
	visual.name = "ApproachLaneSplits"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road.add_child(visual)
