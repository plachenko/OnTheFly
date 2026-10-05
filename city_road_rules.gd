extends RefCounted

static func lane_scale(city: Node3D) -> float:
	return float(city.get("road_width"))/16.0 if city != null and city.get("road_width") != null else 1.0

static func perpendicular_crosswalk(city: Node3D, intersection: Vector3) -> bool:
	if city.get("topology") != null and city.topology.artery_kind(true,intersection.x) == "street_level": return true
	var column := roundi((intersection.x + 128.0) / 64.0)
	var row := roundi((intersection.z + 80.0) / 64.0)
	if column < 0 or column > 4 or row < 0 or row > 3: return false
	return ((column * 4 + row + 1) * 7) % 20 < roundi(20.0 * city.multi_crosswalk_fraction)

static func has_approach_crosswalk(city: Node3D, axis: Vector3, intersection: Vector3) -> bool:
	if city.has_method("bridge_intersection") and city.bridge_intersection(intersection): return false
	if city.crosswalk_scene == null: return false
	if intersection.z < -80.0 or intersection.z > 112.0: return false
	# The generated stripes cross the west and (when selected) south arms.
	if absf(axis.z) > 0.5: return axis.z > 0 and perpendicular_crosswalk(city, intersection)
	return axis.x > 0

static func approach_edge(city: Node3D, axis: Vector3, intersection: Vector3) -> float:
	var vertical := absf(axis.z) > 0.5
	return city.road_width * 0.5 + extra_width(not vertical, intersection.z if vertical else intersection.x, -axis.z if vertical else -axis.x, city)

static func stop_boundary(city: Node3D, axis: Vector3 = Vector3.ZERO, intersection: Vector3 = Vector3.ZERO) -> float:
	if axis == Vector3.ZERO or has_approach_crosswalk(city, axis, intersection):
		return maxf(city.stop_line_setback, city.crosswalk_setback + 4.5)
	# One metre between the junction asphalt edge and the near edge of the bar.
	return approach_edge(city, axis, intersection) + 1.0 + 0.21

# Stable street rules are shared by geometry, traffic and multiplayer maps.
static func one_way(vertical: bool, coordinate: float, city: Node3D = null) -> int:
	if city != null and city.get("topology") != null and city.topology.planned: return city.topology.one_way(vertical,coordinate)
	if vertical and is_equal_approx(coordinate, -64.0): return 1
	if not vertical and is_equal_approx(coordinate, 112.0): return -1
	return 0

static func extra_width(vertical: bool, coordinate: float, side: float, city: Node3D = null) -> float:
	if city != null and city.get("earlier_style") == true:
		if vertical and is_equal_approx(coordinate, 64.0) and side < 0: return 3.2
		if not vertical and is_equal_approx(coordinate, -80.0) and side > 0: return 3.2
		return 0.0
	if city != null and city.get("topology") != null and city.topology.planned:
		return city.parking_bay_width + .4 if city.topology.arteries.has(city.topology.key(vertical,coordinate)) else 0.0
	if vertical and is_equal_approx(coordinate, 64.0) and side < 0: return 3.2
	if not vertical and is_equal_approx(coordinate, -80.0) and side > 0: return 3.2
	return 0.0

static func allows(axis: Vector3, intersection: Vector3, city: Node3D = null) -> bool:
	var vertical := absf(axis.z) > 0.5
	var direction := one_way(vertical, intersection.x if vertical else intersection.z, city)
	return direction == 0 or (axis.z if vertical else axis.x) * direction > 0

static func passing_allowed(axis: Vector3, point: Vector3, city: Node3D = null) -> bool:
	var vertical := absf(axis.z) > 0.5
	var across: float = point.x if vertical else point.z
	var coordinate := roundf((across + (128.0 if vertical else 144.0)) / 64.0) * 64.0 - (128.0 if vertical else 144.0)
	if absf(across - coordinate) > 12.0*lane_scale(city): return true # Legacy off-grid routes.
	return one_way(vertical, coordinate, city) != 0 or extra_width(vertical, coordinate, -axis.z if vertical else axis.x, city) > 0

static func paint(city: Node3D, road: Node3D, vertical: bool, coordinate: float, crosses: Array, yellow: Material, signs: bool = true) -> void:
	var direction := one_way(vertical, coordinate, city)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("fffbea")
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	yellow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var passing_side := -1.0 if vertical else 1.0
	var passing := extra_width(vertical, coordinate, passing_side, city) > 0
	road.set_meta("road_type", "one_way" if direction != 0 else ("passing" if passing else "double_yellow"))
	road.set_meta("one_way_direction", direction)
	for along in range(-floori(city.road_visual_extent), floori(city.road_visual_extent)):
		if not city.road_segment_exists(vertical,coordinate,along+.5): continue
		var blocked := false
		for cross in crosses:
			var junction := Vector3(coordinate, 0, cross) if vertical else Vector3(cross, 0, coordinate)
			var approach_direction := 1.0 if along + 0.5 < cross else -1.0
			var axis := Vector3(0, 0, approach_direction) if vertical else Vector3(approach_direction, 0, 0)
			if absf(along + 0.5 - cross) < stop_boundary(city, axis, junction) + 0.85: blocked = true
		if blocked: continue
		for side in ([0.0] if direction != 0 else [-1.0, 1.0]):
			var dashed: bool = direction != 0 or (passing and side == passing_side)
			if dashed and posmod(along, 8) >= 3: continue
			var across: float = side * 0.28
			var a := Vector2(across, along) if vertical else Vector2(along, across)
			var b := Vector2(across, along + 1) if vertical else Vector2(along + 1, across)
			quad(city, road, surface, a, b, 0.28)
	var mesh := surface.commit()
	if mesh.get_surface_count() > 0: mesh.surface_set_material(0, white if direction != 0 else yellow)
	var visual := MeshInstance3D.new()
	visual.name = "RoadPaint"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road.add_child(visual)
	paint_approaches(city, road, vertical, coordinate, crosses, white)
	if city.topology.artery_kind(vertical,coordinate) != "inner": paint_artery_lanes(city,road,vertical,coordinate,crosses,white)
	road.set_meta("markings_version",2)
	if direction != 0 and signs:
		for cross in crosses:
			var point := Vector2(coordinate + city.road_width * 0.5 + 1.0, cross + 11.0) if vertical else Vector2(cross + 11.0, coordinate + city.road_width * 0.5 + 1.0)
			add_sign(city, point, Vector3(0, 0, direction) if vertical else Vector3(direction, 0, 0))

static func vertex(city: Node3D, road: Node3D, surface: SurfaceTool, point: Vector2) -> void:
	var world := point + Vector2(road.position.x, road.position.z)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(Vector3(point.x, city.terrain_surface_height_at(world.x, world.y) + 0.16, point.y))

static func quad(city: Node3D, road: Node3D, surface: SurfaceTool, a: Vector2, b: Vector2, width: float) -> void:
	var center := (a+b)*.5 + Vector2(road.position.x,road.position.z)
	if not city.on_grid_road(center): return
	var right := Vector2(-(b - a).y, (b - a).x).normalized() * width * 0.5
	var points := [a - right, a + right, b - right, b + right]
	for index in [0, 1, 2, 1, 3, 2]: vertex(city, road, surface, points[index])

static func add_sign(city: Node3D, point: Vector2, axis: Vector3) -> void:
	if not city.sidewalks_ready:
		city.pending_one_way_signs.append([point,axis])
		return
	if not city.furniture_on_sidewalk(point): return
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

static func approach_kind(axis: Vector3, intersection: Vector3, lane_side: float = 4.0, city: Node3D = null) -> String:
	var vertical := absf(axis.z) > 0.5
	var coordinate: float = intersection.x if vertical else intersection.z
	var side: float = -axis.z if vertical else axis.x
	var left := Vector3(axis.z, 0, -axis.x)
	if not allows(left, intersection, city): return "straight"
	var left_vertical := absf(left.z) > 0.5
	var left_coordinate: float = intersection.x if left_vertical else intersection.z
	var left_side: float = -left.z if left_vertical else left.x
	if one_way(vertical, coordinate, city) != 0:
		if lane_side > 0: return "straight"
		return "straight_left" if extra_width(left_vertical, left_coordinate, left_side, city) > 0 else "left"
	if extra_width(vertical, coordinate, side, city) > 0:
		return "straight_left" if extra_width(left_vertical, left_coordinate, left_side, city) > 0 else "left"
	if extra_width(left_vertical, left_coordinate, left_side, city) > 0: return "straight_left"
	return "unmarked"

static func arrow(city: Node3D, road: Node3D, surface: SurfaceTool, center: Vector2, axis: Vector2, left: bool, straight: bool) -> void:
	if not city.on_grid_road(center+Vector2(road.position.x,road.position.z)): return
	var right := Vector2(-axis.y, axis.x)
	quad(city, road, surface, center - axis * 2.0, center + axis * 0.4, 0.48)
	if straight:
		quad(city, road, surface, center, center + axis * 1.5, 0.48)
		for point in [center + axis * 2.7, center + axis * 1.1 - right * 0.8, center + axis * 1.1 + right * 0.8]: vertex(city, road, surface, point)
	if left:
		quad(city, road, surface, center + axis * 0.4, center + axis * 0.4 - right * 1.3, 0.48)
		for point in [center + axis * 0.4 - right * 2.4, center - right * 1.0 - axis * 0.4, center - right * 1.0 + axis * 1.2]: vertex(city, road, surface, point)

static func paint_approaches(city: Node3D, road: Node3D, vertical: bool, coordinate: float, crosses: Array, white: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var marked := false
	for cross in crosses:
		var intersection := Vector3(coordinate, 0, cross) if vertical else Vector3(cross, 0, coordinate)
		for direction in [-1.0, 1.0]:
			var axis := Vector3(0, 0, direction) if vertical else Vector3(direction, 0, 0)
			if not allows(axis, intersection, city): continue
			var axis2 := Vector2(axis.x, axis.z)
			var right := Vector2(-axis.z, axis.x)
			var junction := Vector2(0, cross) if vertical else Vector2(cross, 0)
			if city.topology.artery_kind(vertical,coordinate) != "inner":
				if city.has_method("bridge_intersection") and city.bridge_intersection(intersection): continue
				arrow(city,road,surface,junction-axis2*25+right*(2*lane_scale(city)),axis2,true,true)
				arrow(city,road,surface,junction-axis2*25+right*(6*lane_scale(city)),axis2,false,true)
				marked = true
				continue
			var kind := approach_kind(axis, intersection, 4, city)
			if kind == "unmarked": continue
			marked = true
			var split := extra_width(vertical, coordinate, -axis.z if vertical else axis.x, city) > 0
			var boundary := stop_boundary(city, axis, intersection)
			var arrow_distance := maxf(24.0, boundary + 3.5)
			arrow(city, road, surface, junction - axis2 * arrow_distance + right * (4.0*lane_scale(city)), axis2, kind in ["left", "straight_left"], kind != "left")
			if one_way(vertical, coordinate, city) != 0:
				var left_kind := approach_kind(axis, intersection, -4, city)
				arrow(city, road, surface, junction - axis2 * arrow_distance - right * (4.0*lane_scale(city)), axis2, left_kind in ["left", "straight_left"], left_kind != "left")
			if split:
				arrow(city, road, surface, junction - axis2 * arrow_distance + right * (city.road_width*.5+.5), axis2, false, true)
				for along in range(ceili(boundary + 0.21 + 0.35), 33):
					if along < 21 or along % 6 < 3:
						quad(city, road, surface, junction - axis2 * along + right * (6.2*lane_scale(city)), junction - axis2 * (along + 1) + right * (6.2*lane_scale(city)), 0.24)
	if not marked: return
	var mesh := surface.commit()
	if mesh.get_surface_count() == 0: return
	mesh.surface_set_material(0, white)
	var visual := MeshInstance3D.new()
	visual.name = "ApproachLaneSplits"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road.add_child(visual)

static func paint_artery_lanes(city: Node3D, road: Node3D, vertical: bool, coordinate: float, crosses: Array, white: Material) -> void:
	road.set_meta("artery_kind",city.topology.artery_kind(vertical,coordinate))
	road.set_meta("driving_lanes_per_direction",2)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for along in range(-floori(city.road_visual_extent),floori(city.road_visual_extent)):
		if not city.road_segment_exists(vertical,coordinate,along+.5): continue
		var junction := false
		for cross in crosses:
			if absf(along+.5-cross)<16: junction=true
		if junction: continue
		for side in [-1.0,1.0]:
			for lane_edge in [city.road_width*.25,city.road_width*.5]:
				if is_equal_approx(lane_edge,city.road_width*.25) and posmod(along,8)>=3: continue
				var a := Vector2(lane_edge*side,along) if vertical else Vector2(along,lane_edge*side)
				var b := Vector2(lane_edge*side,along+1) if vertical else Vector2(along+1,lane_edge*side)
				quad(city,road,surface,a,b,.24)
			if city.topology.artery_kind(vertical,coordinate)=="bridge" and posmod(along,12)==0:
				var a := Vector2((city.road_width*.5+.5)*side,along) if vertical else Vector2(along,(city.road_width*.5+.5)*side)
				var b := Vector2((city.road_width*.5+3)*side,along+2) if vertical else Vector2(along+2,(city.road_width*.5+3)*side)
				quad(city,road,surface,a,b,.3)
	var mesh := surface.commit()
	if mesh.get_surface_count()==0: return
	mesh.surface_set_material(0,white)
	var visual := MeshInstance3D.new()
	visual.name="ArteryLaneMarkings"
	visual.mesh=mesh
	road.add_child(visual)


static func refresh_saved_markings(city: Node3D) -> void:
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color("ffda4d")
	yellow.roughness = 1.0
	for road in city.get_node("Roads").get_children():
		var label := str(road.name)
		if not (label.begins_with("Road_V_") or label.begins_with("Road_H_")): continue
		if road.get_meta("markings_version",0) >= 2: continue
		for name in ["RoadPaint","ApproachLaneSplits","ArteryLaneMarkings"]:
			var old: Node = road.get_node_or_null(name)
			if old != null: old.free()
		var vertical := label.begins_with("Road_V_")
		var coordinate: float = road.position.x if vertical else road.position.z
		paint(city,road,vertical,coordinate,city.topology.horizontals if vertical else city.topology.verticals,yellow,false)
		for name in ["RoadPaint","ApproachLaneSplits","ArteryLaneMarkings"]:
			var marking: MeshInstance3D = road.get_node_or_null(name)
			if marking != null:
				marking.mesh = preload("res://city_visual_surface.gd").smooth_mesh(city,marking.mesh,marking.global_transform)
