extends MeshInstance3D

var radius: float = 4.0
var refresh: float = 0.0
var yellow_remaining: float = 0.0
var warning_blend: float = 0.0
var pursuing: bool = false
var red_blend: float = 0.0
const YELLOW_HOLD: float = 2.5
var chase_radius_multiplier := 1.3
var return_from_center := false
var return_blend := 1.0
var return_delay := 0.0

func begin_green_return() -> void:
	pursuing = false
	yellow_remaining = 0.0
	warning_blend = 0.0
	red_blend = 0.0
	return_from_center = true
	return_blend = 0.0
	return_delay = 1.8

func truck_overlaps() -> bool:
	var car := get_parent()
	var truck: Node3D = car.truck
	if not is_instance_valid(truck):
		return false
	var center := Vector2(car.global_position.x, car.global_position.z)
	var detection_radius := radius * (1.15 if yellow_remaining > 0.0 or pursuing else 0.5)
	for child in truck.find_children("*", "CollisionShape3D", true, false):
		if child.disabled or not child.shape is BoxShape3D:
			continue
		var half: Vector3 = child.shape.size * 0.5
		var outline := PackedVector2Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var world: Vector3 = child.to_global(Vector3(corner.x * half.x, 0, corner.y * half.z))
			outline.append(Vector2(world.x, world.z))
		if Geometry2D.is_point_in_polygon(center, outline):
			return true
		for index in 4:
			var closest := Geometry2D.get_closest_point_to_segment(center, outline[index], outline[(index + 1) % 4])
			if center.distance_squared_to(closest) <= detection_radius * detection_radius:
				return true
	return false

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color("42f578")
	green.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = green
	update_ring()

func _process(delta: float) -> void:
	var car := get_parent()
	visible = not car.exploded
	if pursuing and return_from_center:
		return_from_center = false
		return_blend = 1.0
		return_delay = 0.0
	if return_from_center:
		return_delay = maxf(0.0, return_delay - delta)
		if return_delay <= 0.0:
			return_blend = minf(1.0, return_blend + delta / 1.2)
		if return_blend >= 1.0:
			return_from_center = false
	elif truck_overlaps():
		yellow_remaining = YELLOW_HOLD
	else:
		yellow_remaining = maxf(0.0, yellow_remaining - delta)
	warning_blend = move_toward(warning_blend, 1.0 if yellow_remaining > 0.0 or pursuing else 0.0, delta / 0.5)
	red_blend = move_toward(red_blend, 1.0 if pursuing else 0.0, delta / 0.5)
	var eased := smoothstep(0.0, 1.0, warning_blend)
	material_override.albedo_color = Color("42f578").lerp(Color("ffe44a"), eased).lerp(Color("ff3838"), smoothstep(0.0, 1.0, red_blend))
	refresh -= delta
	if visible and refresh <= 0.0:
		refresh = 0.08
		update_ring()

func update_ring() -> void:
	var car := get_parent()
	var center: Vector3 = car.global_position
	var city: Node3D = car.city
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 96:
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var angle: float = (float(segment) + corner.x) * TAU / 96.0
			var distance: float = radius * lerpf(0.5, 1.15, smoothstep(0.0, 1.0, warning_blend)) * lerpf(1.0, chase_radius_multiplier, smoothstep(0.0, 1.0, red_blend)) * smoothstep(0.0, 1.0, return_blend) + (corner.y - 0.5) * 0.16
			distance = maxf(0.0, distance)
			var point: Vector3 = center + Vector3(cos(angle), 0, sin(angle)) * distance
			point.y = maxf(city.terrain_surface_height_at(point.x, point.z), city.height_at(point.x, point.z)) + 0.15
			tool.add_vertex(point)
	tool.generate_normals()
	mesh = tool.commit()
