extends Node3D

## Set this to a ParkingPad in the Inspector to override the nearest available
## serving pad. Leave it empty for automatic destination selection.
@export var destination_path: NodePath
@export_range(2.0, 16.0, 0.5) var cruise_speed: float = 8.0
@export_range(1.0, 8.0, 0.5) var turn_speed: float = 3.5
@export_range(2.0, 8.0, 0.5) var arrival_radius: float = 3.0
@export_range(2.0, 10.0, 0.5) var corner_lookahead: float = 6.0

var destination: Area3D
var waypoints: Array[Vector3] = []
var waypoint_index: int = 0

func begin() -> bool:
	destination = choose_destination()
	if not is_instance_valid(destination):
		return false
	build_route()
	return true

func stop() -> void:
	destination = null
	waypoints.clear()
	waypoint_index = 0

func destination_label() -> String:
	return str(destination.name) if is_instance_valid(destination) else "No destination"

func choose_destination() -> Area3D:
	var level := get_parent().get_parent()
	if not destination_path.is_empty():
		var selected := get_node_or_null(destination_path) as Area3D
		if not selected:
			selected = level.get_node_or_null(destination_path) as Area3D
		if selected:
			return selected
	var truck := get_parent() as Node3D
	var closest: Area3D
	var distance := INF
	for pad in level.get_node("ParkingPads").get_children():
		if not pad is Area3D or not pad.serving_enabled or pad.expired or pad == truck.parking_pad:
			continue
		var gap := truck.global_position.distance_squared_to(pad.global_position)
		if gap < distance:
			closest = pad
			distance = gap
	return closest

func build_route() -> void:
	waypoints.clear()
	waypoint_index = 0
	var truck := get_parent() as Node3D
	var level := truck.get_parent()
	if not level.has_node("ProceduralCity"):
		waypoints.append(destination.global_position)
		return
	var from := truck.global_position
	var to := destination.global_position
	var start_x := clampi(roundi((from.x + 128.0) / 64.0), 0, 4)
	var start_z := clampi(roundi((from.z + 144.0) / 64.0), 0, 5)
	var end_x := clampi(roundi((to.x + 128.0) / 64.0), 0, 4)
	var end_z := clampi(roundi((to.z + 144.0) / 64.0), 0, 5)
	var road_x := -128.0 + 64.0 * start_x
	var road_z := -144.0 + 64.0 * start_z
	var vertical_start := absf(from.x - road_x) <= absf(from.z - road_z)
	var heading := -truck.global_transform.basis.z
	if vertical_start:
		start_z = clampi(floori((from.z + 144.0) / 64.0) if heading.z < 0.0 else ceili((from.z + 144.0) / 64.0), 0, 5)
	else:
		start_x = clampi(floori((from.x + 128.0) / 64.0) if heading.x < 0.0 else ceili((from.x + 128.0) / 64.0), 0, 4)
	var x := start_x
	var z := start_z
	append_grid_point(x, z)
	if vertical_start:
		while z != end_z:
			z += signi(end_z - z)
			append_grid_point(x, z)
		while x != end_x:
			x += signi(end_x - x)
			append_grid_point(x, z)
	else:
		while x != end_x:
			x += signi(end_x - x)
			append_grid_point(x, z)
		while z != end_z:
			z += signi(end_z - z)
			append_grid_point(x, z)
	waypoints.append(to)

func append_grid_point(x: int, z: int) -> void:
	waypoints.append(Vector3(-128.0 + 64.0 * x, 0.0, -144.0 + 64.0 * z))

func driving_command(speed: float) -> Dictionary:
	if not is_instance_valid(destination):
		return {"arrived": true, "throttle": 0.0, "brake": 1.0, "steer": 0.0}
	var truck := get_parent() as Node3D
	var position_2d := Vector2(truck.global_position.x, truck.global_position.z)
	var goal_2d := Vector2(destination.global_position.x, destination.global_position.z)
	if position_2d.distance_to(goal_2d) <= arrival_radius:
		return {"arrived": true, "throttle": 0.0, "brake": 1.0, "steer": 0.0}
	while waypoint_index < waypoints.size() - 1:
		var waypoint := waypoints[waypoint_index]
		if position_2d.distance_to(Vector2(waypoint.x, waypoint.z)) > 3.5:
			break
		waypoint_index += 1
	var target := waypoints[waypoint_index]
	var target_2d := Vector2(target.x, target.z)
	var corner_distance := position_2d.distance_to(target_2d)
	if waypoint_index < waypoints.size() - 1 and corner_distance < corner_lookahead:
		var next := waypoints[waypoint_index + 1]
		var next_direction := Vector2(next.x - target.x, next.z - target.z).normalized()
		target_2d += next_direction * (corner_lookahead - corner_distance)
	var direction := (target_2d - position_2d).normalized()
	var desired_heading := atan2(-direction.x, -direction.y)
	var error := angle_difference(truck.rotation.y, desired_heading)
	var desired_speed := cruise_speed
	if absf(error) > 0.45 or corner_distance < 12.0 and waypoint_index < waypoints.size() - 1:
		desired_speed = turn_speed
	if waypoint_index == waypoints.size() - 1:
		desired_speed = minf(desired_speed, maxf(1.5, goal_2d.distance_to(position_2d) * 0.8))
	return {"arrived": false, "throttle": 1.0 if speed < desired_speed - 0.3 else 0.0, "brake": 1.0 if speed > desired_speed + 0.5 else 0.0, "steer": clampf(error * 1.8, -1.0, 1.0)}
