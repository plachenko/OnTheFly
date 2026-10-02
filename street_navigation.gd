extends RefCounted

static func roads(city: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names: Dictionary = city.get_meta("street_names", {})
	var extent: float = city.road_visual_extent
	for coordinate in names.get("avenues", {}):
		result.append({"id": "v:%s" % coordinate, "name": names.avenues[coordinate], "start": Vector2(coordinate, -extent), "end": Vector2(coordinate, extent), "width": city.road_width + 3.2})
	for coordinate in names.get("streets", {}):
		result.append({"id": "h:%s" % coordinate, "name": names.streets[coordinate], "start": Vector2(-extent, coordinate), "end": Vector2(extent, coordinate), "width": city.road_width + 3.2})
	for index in names.get("diagonals", {}):
		var segment: Vector4 = city.diagonal_road_segments[index]
		result.append({"id": "d:%s" % index, "name": names.diagonals[index], "start": Vector2(segment.x, segment.y), "end": Vector2(segment.z, segment.w), "width": city.diagonal_road_width})
	return result

static func locate(routes: Array[Dictionary], point: Vector2, heading: Vector2, previous: String = "") -> Dictionary:
	var best: Dictionary = {}
	var score := INF
	for road in routes:
		var axis: Vector2 = road.end - road.start
		var t := clampf((point - road.start).dot(axis) / axis.length_squared(), 0, 1)
		var gap := point.distance_to(road.start + axis * t)
		var alignment := absf(axis.normalized().dot(heading))
		if gap > road.width * 0.5 + 3.0: continue
		var candidate: float = gap * 0.4 + (1.0 - alignment) * 10.0 - (1.5 if road.id == previous else 0.0)
		if candidate < score:
			score = candidate
			best = road
	return best

static func upcoming(routes: Array[Dictionary], road: Dictionary, point: Vector2, heading: Vector2) -> Dictionary:
	if road.is_empty(): return {}
	var r: Vector2 = road.end - road.start
	var direction := r.normalized() * (1.0 if r.dot(heading) >= 0 else -1.0)
	var nearest := 115.0
	var result: Dictionary = {}
	for other in routes:
		if other.id == road.id: continue
		var s: Vector2 = other.end - other.start
		var denominator := r.cross(s)
		if absf(denominator) < 0.001: continue
		var offset: Vector2 = other.start - road.start
		var t := offset.cross(s) / denominator
		var u := offset.cross(r) / denominator
		if t < 0 or t > 1 or u < 0 or u > 1: continue
		var junction: Vector2 = road.start + r * t
		var ahead := (junction - point).dot(direction)
		if ahead > 8.0 and ahead < nearest:
			nearest = ahead
			result = {"key": road.id + "/" + other.id, "name": other.name, "point": junction, "direction": direction, "distance": ahead}
	return result

static func neighbors(routes: Array[Dictionary], road: Dictionary, point: Vector2, heading: Vector2, crossing_radius: float = 5.0) -> Dictionary:
	var result := {"past": {}, "next": {}, "crossing": {}}
	if road.is_empty(): return result
	var r: Vector2 = road.end - road.start
	var direction := r.normalized() * (1.0 if r.dot(heading) >= 0 else -1.0)
	var near_past := 180.0
	var near_next := 180.0
	var near_crossing := INF
	for other in routes:
		if other.id == road.id: continue
		var s: Vector2 = other.end - other.start
		var denominator := r.cross(s)
		if absf(denominator) < 0.001: continue
		var offset: Vector2 = other.start - road.start
		var t := offset.cross(s) / denominator
		var u := offset.cross(r) / denominator
		if t < 0 or t > 1 or u < 0 or u > 1: continue
		var junction: Vector2 = road.start + r * t
		var signed_distance := (junction - point).dot(direction)
		var distance := absf(signed_distance)
		var street := {"key": road.id + "/" + other.id, "name": other.name, "point": junction, "direction": direction, "distance": distance, "signed_distance": signed_distance}
		if distance <= crossing_radius and distance < near_crossing:
			near_crossing = distance
			result.crossing = street
		elif signed_distance > crossing_radius and distance < near_next:
			near_next = distance
			result.next = street
		elif signed_distance < -crossing_radius and distance < near_past:
			near_past = distance
			result.past = street
	return result
