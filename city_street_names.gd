extends RefCounted

const AVENUES := ["Taco Avenue", "Dumpling Avenue", "Pizza Avenue", "Ramen Avenue", "Falafel Avenue"]
const STREETS := ["Pancake Street", "Noodle Street", "Burrito Street", "Waffle Street", "Sushi Street", "Croissant Street"]
const DIAGONALS := ["Spaghetti Way", "Pretzel Way", "Nacho Way"]

static func plate(parent: Node3D, text: String, angle: float, height: float) -> void:
	var arm := Node3D.new()
	arm.name = text.replace(" ", "")
	arm.rotation.y = angle
	arm.position.y = height
	parent.add_child(arm)
	var border := StandardMaterial3D.new()
	border.albedo_color = Color("e9efd9")
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("175b43")
	for layer in 2:
		var board := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.7 - layer * 0.08, 0.48 - layer * 0.07, 0.07 if layer == 0 else 0.08)
		board.mesh = box
		board.material_override = border if layer == 0 else green
		arm.add_child(board)
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = text
		label.font_size = 48
		label.pixel_size = 0.0043
		label.outline_size = 0
		label.modulate = Color("f4f5df")
		label.position.z = side * 0.045
		label.rotation.y = PI if side < 0 else 0.0
		arm.add_child(label)

static func add_sign(city: Node3D, point: Vector2, first: String, second: String, angle: float = PI * 0.5) -> void:
	var post := Node3D.new()
	post.name = "StreetName_%d_%d" % [roundi(point.x), roundi(point.y)]
	post.position = Vector3(point.x, city.height_at(point.x, point.y), point.y)
	post.set_meta("street_names", [first, second])
	city.get_node("StreetSigns").add_child(post)
	var pole := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 3.5
	cylinder.top_radius = 0.045
	cylinder.bottom_radius = 0.065
	cylinder.radial_segments = 8
	pole.mesh = cylinder
	pole.position.y = 1.75
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("687578")
	pole.material_override = metal
	post.add_child(pole)
	plate(post, first, angle, 3.35)
	plate(post, second, 0.0, 2.85)

static func generate(city: Node3D) -> void:
	var names := {"avenues": {}, "streets": {}, "diagonals": {}}
	var corner: float = city.road_width * 0.5 + city.sidewalk_width * 0.65
	for x in range(-128, 129, 64):
		var avenue: String = AVENUES[(x + 128) / 64]
		names.avenues[x] = avenue
		for z in range(-144, 177, 64):
			var street: String = STREETS[(z + 144) / 64]
			names.streets[z] = street
			var point := Vector2(x + corner + preload("res://city_road_rules.gd").extra_width(true, x, 1), z + corner + preload("res://city_road_rules.gd").extra_width(false, z, 1))
			if city.distance_to_diagonal_road(point) >= city.diagonal_road_width * 0.5 + 0.5:
				add_sign(city, point, avenue, street)
	if city.diagonal_roads_enabled:
		for index in city.diagonal_road_segments.size():
			var segment: Vector4 = city.diagonal_road_segments[index]
			var start := Vector2(segment.x, segment.y)
			var end := Vector2(segment.z, segment.w)
			var direction := (end - start).normalized()
			var diagonal: String = DIAGONALS[index % DIAGONALS.size()]
			names.diagonals[index] = diagonal
			# Place a pair of street names at each diagonal/grid junction.
			for axis in 2:
				var delta: float = end[axis] - start[axis]
				if absf(delta) < 0.001:
					continue
				for coordinate in (names.avenues if axis == 0 else names.streets):
					var t: float = (float(coordinate) - start[axis]) / delta
					if t < 0.0 or t > 1.0:
						continue
					var junction := start.lerp(end, t)
					var point: Vector2 = junction + Vector2(-direction.y, direction.x) * (city.diagonal_road_width * 0.5 + city.sidewalk_width * 0.65)
					point[axis] = float(coordinate) + corner * signf(point[axis] - float(coordinate))
					var best := INF
					var chosen := point
					for sample in 32:
						var candidate := junction + Vector2.from_angle(float(sample) * TAU / 32.0) * corner * 1.6
						if city.on_grid_road(candidate, 0.8) or city.distance_to_diagonal_road(candidate) < city.diagonal_road_width * 0.5 + 0.8:
							continue
						var score := candidate.distance_squared_to(point)
						if score < best:
							best = score
							chosen = candidate
					if best == INF:
						continue
					point = chosen
					var cross_name: String = names.avenues[coordinate] if axis == 0 else names.streets[coordinate]
					add_sign(city, point, diagonal, cross_name, atan2(-direction.y, direction.x))
	city.set_meta("street_names", names)
