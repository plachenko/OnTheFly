extends Node

var active := false
var truck: CharacterBody3D
var city: Node3D
var direction := Vector3.ZERO
var axis := 0
var side := 1.0
var arrival_plane := 0.0
var wrapped := false
var last_coordinate := 0.0
var saved_layer := 0
var saved_mask := 0
var road_center := 0.0
var lane_coordinate := 0.0
var entry_lateral := 0.0
var entry_elapsed := 0.0
var departure_index := 0
var arrival_pose_pending := false
const LANE_BLEND_SECONDS := 0.9

func surface_height(point: Vector3) -> float:
	return city.road_visual_height_at(point.x,point.z) + preload("res://city_road_surface.gd").LIFT

func prepare_arrival(point: Vector3) -> Vector3:
	var lateral := 2 if axis == 0 else 0
	point[lateral] = lane_coordinate
	point.y = surface_height(point) + .05
	return point

func warp_to_exit(exit: Dictionary) -> Vector3:
	axis = 2 if exit.vertical else 0
	side = -exit.side
	direction = Vector3.ZERO
	direction[axis] = side
	var lateral := 2 if axis == 0 else 0
	arrival_plane = exit.center.y if axis == 2 else exit.center.x
	road_center = exit.center.x if axis == 2 else exit.center.y
	lane_coordinate = road_center + Vector3(-direction.z,0,direction.x)[lateral]*(6*preload("res://city_road_rules.gd").lane_scale(city))
	var point := Vector3(exit.center.x,0,exit.center.y) - direction*34
	point = prepare_arrival(point)
	wrapped = true
	arrival_pose_pending = true
	entry_elapsed = LANE_BLEND_SECONDS
	entry_lateral = lane_coordinate
	last_coordinate = point[axis]
	truck.rotation.y = atan2(-direction.x,-direction.z)
	truck.travel_heading = truck.rotation.y
	return point

func update_road_pose(delta: float, snap: bool = false) -> void:
	truck.longitudinal_accel = 0.0
	truck.lateral_accel = 0.0
	truck.update_slope_tilt(1.0 if snap else delta)
	if snap:
		for i in 4:
			truck.spring_height[i] = 0.0
			truck.spring_velocity[i] = 0.0
			var rest = truck.skeleton.get_bone_global_rest(truck.suspension_bones[i])
			var wheel: Vector3 = truck.skeleton.global_transform * rest.origin
			truck.road_height[i] = surface_height(wheel) + .59 - wheel.y
	truck.update_suspension(delta)
	truck.get_node("VehicleLights").sync_with_chassis()

func _ready() -> void:
	truck = get_parent()
	city = truck.get_parent().get_node("ProceduralCity")

func drive(delta: float) -> bool:
	var signs := city.get_node_or_null("HighwayApproaches")
	if not active and signs and not truck.round_over and truck.health > 0.0:
		for road_sign in signs.get_children():
			if not road_sign.has_meta("highway_axis"): continue
			var a: int = road_sign.get_meta("highway_axis")
			var s: float = road_sign.get_meta("highway_side")
			var departure_lateral := 2 if a == 0 else 0
			var distance: float = (truck.global_position[a] - road_sign.global_position[a]) * s
			if distance < 0.0 or absf(truck.global_position[departure_lateral] - road_sign.global_position[departure_lateral]) >= 14.0: continue
			axis = a
			departure_index = int(road_sign.get_meta("exit_index",0))
			side = s
			direction = Vector3.ZERO
			direction[axis] = side
			arrival_plane = -road_sign.global_position[axis]
			road_center = road_sign.global_position[departure_lateral]
			var right := Vector3(-direction.z,0,direction.x)
			var lane := (6.0 if city.topology.planned else 4.0)*preload("res://city_road_rules.gd").lane_scale(city)
			lane_coordinate = road_center + right[departure_lateral]*lane
			entry_lateral = truck.global_position[departure_lateral]
			entry_elapsed = 0.0
			for other in signs.get_children():
				if other.has_meta("highway_axis") and int(other.get_meta("highway_axis")) == axis and float(other.get_meta("highway_side")) == -side and absf(other.global_position[departure_lateral] - road_sign.global_position[departure_lateral]) < 1.0:
					arrival_plane = other.global_position[axis]
			saved_layer = truck.collision_layer
			saved_mask = truck.collision_mask
			truck.collision_layer = 0
			truck.collision_mask = 0
			truck.fsd_enabled = false
			truck.deployed = false
			last_coordinate = truck.global_position[axis]
			wrapped = false
			active = true
			break
	if not active: return false
	if arrival_pose_pending:
		update_road_pose(delta,true)
		arrival_pose_pending = false
	if (truck.global_position[axis] - last_coordinate) * side < -100.0:
		wrapped = true
		entry_elapsed = LANE_BLEND_SECONDS
		truck.global_position = prepare_arrival(truck.global_position)
		truck.rotation.y = atan2(-direction.x,-direction.z)
		truck.travel_heading = truck.rotation.y
		update_road_pose(delta,true)
	if wrapped and (truck.global_position[axis] - arrival_plane) * side >= 0.0:
		finish()
		return false
	truck.speed = truck.forward_speed
	var previous_position: Vector3 = truck.global_position
	truck.global_position += direction * truck.speed * delta
	entry_elapsed = minf(LANE_BLEND_SECONDS,entry_elapsed+delta)
	var blend := entry_elapsed/LANE_BLEND_SECONDS
	blend = blend*blend*(3.0-2.0*blend)
	var lateral := 2 if axis == 0 else 0
	truck.global_position[lateral] = lerpf(entry_lateral,lane_coordinate,blend)
	truck.global_position.y = surface_height(truck.global_position) + .05
	truck.velocity = (truck.global_position-previous_position)/maxf(delta,.001)
	var heading := atan2(-truck.velocity.x,-truck.velocity.z)
	var heading_error := angle_difference(truck.rotation.y,heading)
	truck.steer = clampf(heading_error,-.4,.4)
	truck.rotation.y = lerp_angle(truck.rotation.y,heading,1.0-exp(-10.0*delta))
	truck.travel_heading = heading
	last_coordinate = truck.global_position[axis]
	truck.rolling += truck.speed * delta / 0.59
	update_road_pose(delta)
	truck.get_node("VehicleLights").set_driving_lights(false, false, false, false, truck.hazards_on)
	truck.get_node("VehicleLights").sync_with_chassis()
	return true

func finish() -> void:
	truck.collision_layer = saved_layer
	truck.collision_mask = saved_mask
	truck.impact_cooldown = 0.2
	active = false

func _exit_tree() -> void:
	if active and is_instance_valid(truck): finish()
