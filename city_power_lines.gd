extends RefCounted

const HEIGHT := 9.0
const ATTACHMENT := 8.6
const CLEARANCE := 6.5

static func box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = position
	parent.add_child(visual)
	return visual

static func pole(city: Node3D, parent: Node3D, point: Vector2, yaw: float, wood: Material, metal: Material, ceramic: Material) -> Node3D:
	var node := Node3D.new()
	node.name = "UtilityLightPole"
	node.position = Vector3(point.x, city.height_at(point.x, point.y) + 0.1, point.y)
	node.rotation.y = yaw
	parent.add_child(node)
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = 0.17
	mesh.top_radius = 0.11
	mesh.height = HEIGHT
	mesh.radial_segments = 10
	shaft.mesh = mesh
	shaft.material_override = wood
	shaft.position.y = HEIGHT * 0.5
	node.add_child(shaft)
	box(node, Vector3(2.0, 0.14, 0.16), Vector3(0, ATTACHMENT - 0.2, 0), wood)
	for offset in [-0.7, 0.0, 0.7]:
		box(node, Vector3(0.16, 0.25, 0.16), Vector3(offset, ATTACHMENT - 0.06, 0), ceramic)
	box(node, Vector3(0.12, 0.12, 1.6), Vector3(0, 7.5, -0.7), metal)
	box(node, Vector3(0.5, 0.16, 0.7), Vector3(0, 7.45, -1.5), metal)
	var light := SpotLight3D.new()
	light.position = Vector3(0, 7.3, -1.5)
	light.rotation.x = -PI * 0.5
	light.light_color = Color(1, 0.83, 0.55)
	light.light_energy = 1.8 if city.is_night else 0.0
	light.spot_range = 18
	light.spot_angle = 60
	light.shadow_enabled = false
	node.add_child(light)
	city.add_knockable_pole(node, HEIGHT)
	return node

static func wire_mesh(points: PackedVector3Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in points.size() - 1:
		var direction := (points[index + 1] - points[index]).normalized()
		var right := direction.cross(Vector3.UP).normalized()
		var up := right.cross(direction).normalized()
		for side in 6:
			var angle_a := float(side) * TAU / 6.0
			var angle_b := float(side + 1) * TAU / 6.0
			var a := (right * cos(angle_a) + up * sin(angle_a)) * 0.035
			var b := (right * cos(angle_b) + up * sin(angle_b)) * 0.035
			for vertex in [points[index] + a, points[index + 1] + a, points[index] + b, points[index] + b, points[index + 1] + a, points[index + 1] + b]:
				tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()

static func connect_poles(city: Node3D, parent: Node3D, from: Node3D, to: Node3D, material: Material) -> void:
	for offset in [-0.7, 0.0, 0.7]:
		var start := from.to_global(Vector3(offset, ATTACHMENT, 0))
		var end := to.to_global(Vector3(offset, ATTACHMENT, 0))
		var points := PackedVector3Array()
		for step in 17:
			var t := float(step) / 16.0
			var point := start.lerp(end, t)
			point.y -= 4.0 * 1.15 * t * (1.0 - t)
			point.y = maxf(point.y, city.terrain_surface_height_at(point.x, point.z) + CLEARANCE)
			points.append(point)
		var wire := MeshInstance3D.new()
		wire.name = "OverheadWire"
		wire.mesh = wire_mesh(points)
		wire.material_override = material
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wire.set_meta("wire_points", points)
		wire.set_meta("crosses_road", from.get_meta("road_side") != to.get_meta("road_side"))
		parent.add_child(wire)
		# Loose wires disappear when either support is knocked down.
		var supports: Array[Node3D] = [from, to]
		wire.set_script(preload("res://utility_wire.gd"))
		wire.supports = supports
		for support in supports: wire.support_paths.append(wire.get_path_to(support))

static func generate(city: Node3D) -> void:
	var parent := Node3D.new()
	parent.name = "UtilityPolesAndWires"
	city.get_node("StreetSigns").add_child(parent)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.28, 0.20, 0.12)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.24, 0.26)
	var ceramic := StandardMaterial3D.new()
	ceramic.albedo_color = Color(0.7, 0.75, 0.67)
	var cable := StandardMaterial3D.new()
	cable.albedo_color = Color(0.055, 0.055, 0.065)
	var curb: float = city.road_width * 0.5 + city.sidewalk_width * 0.75
	for route in 5:
		await city.loading_checkpoint()
		var vertical := route < 3
		var road: float = [-128.0, 0.0, 128.0, -80.0, 48.0][route]
		var previous: Node3D
		for index in (10 if vertical else 8):
			await city.loading_checkpoint()
			var along := (-128.0 if vertical else -112.0) + index * 32.0
			if not city.road_segment_exists(vertical,road,along):
				previous = null
				continue
			var side := (-1.0 if index % 2 == 0 else 1.0) if route % 2 == 0 else 1.0
			var shoulder := curb + preload("res://city_road_rules.gd").extra_width(vertical, road, side, city)
			var point := Vector2(road + side * shoulder, along) if vertical else Vector2(along, road + side * shoulder)
			if not city.furniture_on_sidewalk(point):
				previous = null
				continue
			if city.distance_to_diagonal_road(point) < city.diagonal_road_width * 0.5 + 1.0:
				previous = null
				continue
			var blocked := false
			for pad in city.get_parent().get_node("ParkingPads").get_children():
				await city.loading_checkpoint()
				if Vector2(pad.position.x, pad.position.z).distance_to(point) < 6.0:
					blocked = true
			if blocked:
				previous = null
				continue
			var node := pole(city, parent, point, -side * PI * 0.5 if vertical else (0.0 if side > 0 else PI), wood, metal, ceramic)
			node.set_meta("road_side", side)
			if previous != null:
				connect_poles(city, parent, previous, node, cable)
			previous = node

