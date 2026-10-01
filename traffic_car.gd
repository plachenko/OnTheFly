@tool
extends RigidBody3D

@export_category("Kenney Car")
@export var model_scene: PackedScene
@export_range(1.0, 3.0, 0.1) var car_scale: float = 1.8
@export_range(0.05, 0.5, 0.05) var collision_padding: float = 0.2
var collision_center: Vector3 = Vector3(0, 0.75, 0)
@export_category("Traffic Route")
@export var travel_axis: Vector3 = Vector3.FORWARD
@export var lane_center: Vector3 = Vector3.ZERO
@export_range(-55.0, 55.0, 1.0) var progress: float = 0.0
@export_range(2.0, 18.0, 0.5) var driving_speed: float = 8.0
@export var loop_extent: float = 55.0
@export var obey_crosswalks: bool = true
@export_range(0.0, 1.0, 0.05) var intersection_turn_chance: float = 0.28
@export var parked: bool = false
@export_category("Truck Interaction")
@export_range(0.0, 12.0, 0.5) var disabling_impact_speed: float = 0.5
@export_range(300.0, 4000.0, 50.0) var disabled_mass: float = 950.0
@export_range(0.1, 1.0, 0.05) var truck_push_speed_ratio: float = 0.6
@export_range(0.5, 12.0, 0.5) var chain_impact_min_speed: float = 2.5
var incoming_velocity: Vector3 = Vector3.ZERO
var pending_chain_hits: Dictionary = {}
@export_category("Impact Springs")
@export_range(10.0, 100.0, 1.0) var spring_stiffness: float = 42.0
@export_range(1.0, 20.0, 0.5) var spring_damping: float = 3.0
@export_range(0.05, 0.5, 0.01) var spring_travel: float = 0.38
@export_category("Crumple Zones")
@export_range(1.0, 15.0, 0.5) var crumple_start_speed: float = 5.0
@export_range(0.05, 0.5, 0.01) var maximum_crumple: float = 0.32
@export_range(0.01, 0.1, 0.01) var crumple_per_speed: float = 0.04
@export_category("Disabled Car Cleanup")
@export_range(1.0, 60.0, 0.5) var fade_delay: float = 4.0
@export_range(0.5, 10.0, 0.5) var fade_duration: float = 0.8
@export var explosion_delay: float = 4.0
var exploded: bool = false
var bounce_cooldown: float = 0.0
var warning_material: StandardMaterial3D
@export_range(0.5, 15.0, 0.5) var smoke_duration: float = 6.0
var city: Node3D
var truck: CharacterBody3D
var disabled: bool = false
var disabled_elapsed: float = 0.0
var spring_skeleton: Skeleton3D
var spring_bones: Array[int] = []
var spring_rest_positions: Array[Vector3] = []
var spring_offsets: Array[float] = []
var spring_velocities: Array[float] = []
var crumple_bones: Array[int] = []
var crumple_rest_positions: Array[Vector3] = []
var crumple_depths: Array[float] = [0.0, 0.0]
var traffic_rng := RandomNumberGenerator.new()
var considered_intersections: Dictionary = {}
var turn_intent: int = 0
var turning: bool = false
var turn_progress: float = 0.0
var turn_length: float = 14.0
var turn_center: Vector3
var turn_start: Vector3
var turn_end: Vector3
var turn_control_a: Vector3
var turn_control_b: Vector3
var turn_exit_axis: Vector3

func _ready() -> void:
	city = get_parent().get_parent() as Node3D
	truck = city.get_parent().get_node_or_null("FoodTruck") as CharacterBody3D
	mass = disabled_mass
	max_contacts_reported = 16
	if model_scene and $Visual.get_child_count() == 0:
		var model := model_scene.instantiate() as Node3D
		model.name = "KenneyCar"
		model.scale = Vector3.ONE * car_scale
		$Visual.add_child(model)
	spring_skeleton = find_spring_skeleton($Visual)
	fit_collision_to_model()
	if Engine.is_editor_hint():
		return
	$VehicleLights.attach_to_chassis(spring_skeleton)
	if spring_skeleton:
		for bone_name in ["Chassis", "Spring_FL", "Spring_FR", "Spring_RL", "Spring_RR"]:
			var bone := spring_skeleton.find_bone(bone_name)
			spring_bones.append(bone)
			spring_rest_positions.append(spring_skeleton.get_bone_pose_position(bone) if bone >= 0 else Vector3.ZERO)
			spring_offsets.append(0.0)
			spring_velocities.append(0.0)
		for bone_name in ["Crumple_Front", "Crumple_Rear"]:
			var bone := spring_skeleton.find_bone(bone_name)
			crumple_bones.append(bone)
			crumple_rest_positions.append(spring_skeleton.get_bone_pose_position(bone) if bone >= 0 else Vector3.ZERO)
	$Visual.rotation.y = 0.0
	traffic_rng.randomize()
	$VehicleLights.configure_kenney_car(model_scene != null and model_scene.resource_path.get_file() == "police.glb")
	if parked:
		$VehicleLights.headlights_enabled = false
	configure_impact_smoke()
	warning_material = StandardMaterial3D.new()
	warning_material.albedo_color = Color(1.0, 0.02, 0.01, 0.65)
	warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_material.emission_enabled = true
	warning_material.emission = Color.RED
	warning_material.emission_energy_multiplier = 2.0
	update_car_pose(0.0)

func _physics_process(delta: float) -> void:
	if disabled and not exploded:
		incoming_velocity = linear_velocity
	update_impact_springs(delta)
	if disabled:
		$VehicleLights.sync_with_chassis()
	if disabled:
		disabled_elapsed += delta
		bounce_cooldown = maxf(0.0, bounce_cooldown - delta)
		if not exploded:
			var interval := lerpf(0.35, 0.08, clampf(disabled_elapsed / explosion_delay, 0.0, 1.0))
			for mesh in $Visual.find_children("*", "MeshInstance3D", true, false):
				mesh.material_overlay = warning_material if fmod(disabled_elapsed, interval * 2.0) < interval else null
			if disabled_elapsed >= explosion_delay:
				explode()
		$ImpactSmoke.emitting = disabled_elapsed < smoke_duration
		$VehicleLights.set_driving_lights(false, false, false, false, true)
		if exploded and disabled_elapsed > maxf(fade_delay, explosion_delay):
			var fade_amount := clampf((disabled_elapsed - maxf(fade_delay, explosion_delay)) / fade_duration,0.0,1.0)
			fade_visuals($Visual,fade_amount)
			if fade_amount >= 1.0:
				queue_free()
	if Engine.is_editor_hint() or not is_instance_valid(city) or disabled:
		return
	if parked:
		$VehicleLights.set_driving_lights(false, false, false, false, false)
		return
	# Keep advancing around the truck; actual impacts use the existing disabled-car physics.
	var stopped := should_wait_for_walk_light() or should_follow_car()
	if not stopped:
		if turning:
			advance_turn(delta)
		else:
			plan_intersection_turn()
			progress += driving_speed * delta
			if turn_intent != 0 and (turn_center - route_position()).dot(travel_axis) <= 8.0:
				begin_turn()
			elif progress > loop_extent:
				progress = -loop_extent
				considered_intersections.clear()
	$VehicleLights.set_driving_lights(stopped, false, turn_intent < 0, turn_intent > 0, false)
	update_car_pose(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not disabled or exploded:
		return
	for index in state.get_contact_count():
		var other := state.get_contact_collider_object(index)
		if not is_instance_valid(other) or not other.has_method("receive_car_impact") or other.disabled:
			continue
		var normal := (state.transform.basis * state.get_contact_local_normal(index)).normalized()
		var other_velocity := state.get_contact_collider_velocity_at_position(index)
		# Preserve the approach velocity even when the solver has already bounced us.
		var approach := maxf(0.0, -(incoming_velocity - other_velocity).dot(normal))
		approach = maxf(approach, maxf(0.0, -(state.linear_velocity - other_velocity).dot(normal)))
		if approach < chain_impact_min_speed or pending_chain_hits.has(other.get_instance_id()):
			continue
		pending_chain_hits[other.get_instance_id()] = true
		# Release frozen traffic bodies outside the physics contact callback.
		apply_chain_hit.call_deferred(other, approach, -normal, state.get_contact_collider_position(index))

func apply_chain_hit(other: Object, approach: float, direction: Vector3, point: Vector3) -> void:
	if not is_instance_valid(other):
		return
	pending_chain_hits.erase(other.get_instance_id())
	other.receive_car_impact(approach, direction, point)

func receive_car_impact(approach: float, direction: Vector3, point: Vector3) -> bool:
	if disabled or exploded or approach < chain_impact_min_speed:
		return false
	return disable_from_impact(approach, direction, point)

func set_police_lights_enabled(enabled: bool) -> void:
	$VehicleLights.set_police_enabled(enabled)

func route_position() -> Vector3:
	return lane_center + travel_axis * progress

func plan_intersection_turn() -> void:
	if turn_intent != 0 or intersection_turn_chance <= 0.0:
		return
	var current := route_position()
	var right := Vector3(-travel_axis.z, 0.0, travel_axis.x)
	for ix in range(-128, 129, 64):
		for iz in range(-144, 177, 64):
			var intersection := Vector3(ix, 0.0, iz)
			var lane_offset := current - intersection - right * 4.0
			if absf(lane_offset.dot(right)) > 1.5:
				continue
			var ahead := (intersection - current).dot(travel_axis)
			if ahead < 13.0 or ahead > 20.0:
				continue
			var key := Vector2i(ix, iz)
			if considered_intersections.has(key):
				continue
			considered_intersections[key] = true
			if traffic_rng.randf() < intersection_turn_chance:
				turn_intent = -1 if traffic_rng.randf() < 0.5 else 1
				turn_center = intersection
			return

func begin_turn() -> void:
	turning = true
	turn_progress = 0.0
	turn_start = route_position()
	var left := Vector3(travel_axis.z, 0.0, -travel_axis.x)
	turn_exit_axis = left if turn_intent < 0 else -left
	var exit_right := Vector3(-turn_exit_axis.z, 0.0, turn_exit_axis.x)
	turn_end = turn_center + exit_right * 4.0 + turn_exit_axis * 8.0
	turn_control_a = turn_start + travel_axis * 7.0
	turn_control_b = turn_end - turn_exit_axis * 7.0
	turn_length = maxf(10.0, turn_start.distance_to(turn_end) * 1.35)

func advance_turn(delta: float) -> void:
	turn_progress = minf(1.0, turn_progress + driving_speed * delta / turn_length)
	if turn_progress >= 1.0:
		turning = false
		travel_axis = turn_exit_axis
		progress = turn_end.dot(travel_axis)
		lane_center = turn_end - travel_axis * progress
		turn_intent = 0
		considered_intersections.clear()
		considered_intersections[Vector2i(roundi(turn_center.x), roundi(turn_center.z))] = true

func turn_curve(t: float) -> Vector3:
	var inv := 1.0 - t
	return turn_start * (inv * inv * inv) + turn_control_a * (3.0 * inv * inv * t) + turn_control_b * (3.0 * inv * t * t) + turn_end * (t * t * t)

func should_follow_car() -> bool:
	if turning:
		return false
	for other in get_parent().get_children():
		if other == self or not other is RigidBody3D or other.disabled or other.turning:
			continue
		if travel_axis.dot(other.travel_axis) < 0.99 or lane_center.distance_to(other.lane_center) > 0.7:
			continue
		var ahead: float = (other.global_position - global_position).dot(travel_axis)
		if ahead > 0.0 and ahead < 8.0:
			return true
	return false

func disable_from_impact(approach_speed: float, push_direction: Vector3, _impact_point: Vector3) -> bool:
	if disabled or approach_speed < disabling_impact_speed:
		return false
	disabled = true
	disabled_elapsed = 0.0
	turning = false
	turn_intent = 0
	$VehicleLights.set_driving_lights(false, false, false, false, true)
	# Release the wreck into a deliberately exaggerated airborne tumble.
	rotation.x = 0.0
	rotation.z = 0.0
	$Visual.rotation.x = 0.0
	$Visual.rotation.z = 0.0
	$CarCollision.transform = Transform3D(Basis.IDENTITY, collision_center)
	snap_collision_to_ground()
	axis_lock_angular_x = false
	axis_lock_angular_y = false
	axis_lock_angular_z = false
	linear_damp = 0.18
	angular_damp = 0.12
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.55
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	$ImpactSmoke.emitting = true
	var horizontal_push := Vector3(push_direction.x,0.0,push_direction.z).normalized()
	linear_velocity = horizontal_push * clampf(approach_speed * 1.1, 7.0, 28.0) + Vector3.UP * clampf(approach_speed * 0.45, 5.5, 12.0)
	randomize_tumble()
	incoming_velocity = linear_velocity
	excite_impact_springs(approach_speed,horizontal_push)
	apply_crumple(approach_speed,horizontal_push)
	return true

func push_from_truck(push_direction: Vector3, truck_speed: float, _impact_point: Vector3) -> void:
	if not disabled or truck_speed <= 0.0:
		return
	var direction := Vector3(push_direction.x,0.0,push_direction.z).normalized()
	if direction.is_zero_approx():
		return
	var target_speed := minf(truck_speed * truck_push_speed_ratio, 7.0)
	var current_speed := linear_velocity.dot(direction)
	var speed_gain := maxf(0.0, target_speed - current_speed)
	if speed_gain > 0.0:
		sleeping = false
		$ImpactSmoke.emitting = true
		apply_central_impulse(direction * mass * minf(speed_gain * 0.25, 1.5))
		if spring_velocities.size() == 5:
			spring_velocities[0] = clampf(spring_velocities[0] - speed_gain * 0.08,-3.0,3.0)
		apply_crumple(truck_speed,direction)

func randomize_tumble() -> void:
	angular_velocity = Vector3(traffic_rng.randf_range(-6.0, 6.0), traffic_rng.randf_range(-3.0, 3.0), traffic_rng.randf_range(-6.0, 6.0))
	if angular_velocity.length() < 3.0:
		angular_velocity.x = 5.0

func boost_bounce(direction: Vector3, truck_speed: float) -> bool:
	if not disabled or exploded or bounce_cooldown > 0.0:
		return false
	bounce_cooldown = 0.3
	sleeping = false
	linear_velocity = direction.normalized() * clampf(truck_speed * 1.25, 18.0, 42.0) + Vector3.UP * 9.0
	incoming_velocity = linear_velocity
	randomize_tumble()
	return true

func explode() -> void:
	exploded = true
	collision_layer = 0
	collision_mask = 0
	$VehicleLights.visible = false
	for mesh in $Visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = null
	preload("res://explosion_card.gd").spawn(get_tree().current_scene, global_position + Vector3.UP * 1.8, 9.0)

func fit_collision_to_model() -> void:
	var bounds: Array[AABB] = []
	collect_model_bounds($Visual, Transform3D.IDENTITY, bounds)
	if bounds.is_empty():
		return
	var combined := bounds[0]
	for index in range(1, bounds.size()):
		combined = combined.merge(bounds[index])
	var lower := combined.position - Vector3(collision_padding, 0.0, collision_padding)
	var upper := combined.end + Vector3(collision_padding, collision_padding + spring_travel, collision_padding)
	# Tires meet the road; padding must not bury the collider beneath it.
	lower.y = maxf(0.025, lower.y)
	var shape := BoxShape3D.new()
	shape.size = (upper - lower).max(Vector3(0.5, 0.5, 0.5))
	collision_center = (lower + upper) * 0.5
	$CarCollision.shape = shape
	$CarCollision.position = collision_center
	continuous_cd = true

func collect_model_bounds(node: Node3D, relative: Transform3D, bounds: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh:
		bounds.append(relative * node.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			collect_model_bounds(child, relative * child.transform, bounds)

func snap_collision_to_ground() -> void:
	if not is_instance_valid(city):
		return
	var required_y := -INF
	var half_size: Vector3 = $CarCollision.shape.size * 0.5
	for local_x in [-half_size.x, half_size.x]:
		for local_z in [-half_size.z, half_size.z]:
			var offset: Vector3 = global_transform.basis * (collision_center + Vector3(local_x, -half_size.y, local_z))
			var x := global_position.x + offset.x
			var z := global_position.z + offset.z
			var ground: float = city.terrain_surface_height_at(x, z)
			required_y = maxf(required_y, ground - offset.y)
	global_position.y = required_y + 0.025

func configure_impact_smoke() -> void:
	var smoke := $ImpactSmoke as GPUParticles3D
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 25.0
	motion.initial_velocity_min = 0.6
	motion.initial_velocity_max = 1.6
	motion.gravity = Vector3(0.0, 0.25, 0.0)
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.28
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.2, Color(1.0, 1.0, 1.0, 0.6))
	fade.set_color(2, Color(1.0, 1.0, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	motion.color_ramp = ramp
	smoke.process_material = motion
	var puff := SphereMesh.new()
	puff.radius = 0.38
	puff.height = 0.76
	puff.radial_segments = 8
	puff.rings = 4
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.31, 0.33, 0.34, 0.45)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soot.vertex_color_use_as_albedo = true
	puff.material = soot
	smoke.draw_pass_1 = puff

func fade_visuals(node: Node, amount: float) -> void:
	if node is MeshInstance3D:
		node.transparency = amount
	for child in node.get_children():
		fade_visuals(child,amount)

func find_spring_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_spring_skeleton(child)
		if found:
			return found
	return null

func excite_impact_springs(approach_speed: float, direction: Vector3) -> void:
	if spring_velocities.size() != 5:
		return
	var local_hit := global_transform.basis.inverse() * direction
	spring_velocities[0] = clampf(spring_velocities[0] - approach_speed * 0.65,-7.0,7.0)
	for index in range(1,5):
		var side := -1.0 if index == 1 or index == 3 else 1.0
		var end := -1.0 if index <= 2 else 1.0
		var weight := clampf(1.0 + local_hit.x * side * 0.3 + local_hit.z * end * 0.3,0.4,1.6)
		spring_velocities[index] = clampf(spring_velocities[index] - approach_speed * 0.95 * weight,-9.0,9.0)

func apply_crumple(impact_speed: float, direction: Vector3) -> void:
	if crumple_bones.size() != 2 or impact_speed <= crumple_start_speed:
		return
	var local_hit := global_transform.basis.inverse() * direction
	var end_index := 0 if local_hit.z < 0.0 else 1
	var angle_factor := clampf(absf(local_hit.z),0.35,1.0)
	var depth := minf(maximum_crumple,(impact_speed - crumple_start_speed) * crumple_per_speed * angle_factor)
	crumple_depths[end_index] = maxf(crumple_depths[end_index],depth)

func update_impact_springs(delta: float) -> void:
	if not spring_skeleton:
		return
	for index in range(spring_bones.size()):
		var bone := spring_bones[index]
		if bone < 0:
			continue
		var acceleration := -spring_stiffness * spring_offsets[index] - spring_damping * spring_velocities[index]
		spring_velocities[index] += acceleration * delta
		spring_offsets[index] = clampf(spring_offsets[index] + spring_velocities[index] * delta,-spring_travel,spring_travel)
		spring_skeleton.set_bone_pose_position(bone,spring_rest_positions[index] + Vector3.UP * spring_offsets[index])
	for index in range(crumple_bones.size()):
		var bone := crumple_bones[index]
		if bone >= 0:
			var inward := -1.0 if index == 0 else 1.0
			spring_skeleton.set_bone_pose_position(bone,crumple_rest_positions[index] + Vector3(0.0,0.0,inward * crumple_depths[index]))

func should_wait_for_walk_light() -> bool:
	if not obey_crosswalks:
		return false
	for crossing in city.get_node("Crosswalks").get_children():
		if not crossing.walk_allowed and not crossing.vehicle_yellow:
			continue
		var ahead: float
		if crossing.crosses_vertical_road:
			if absf(travel_axis.z) < 0.5 or absf(crossing.position.x-lane_center.x) > 5.0:
				continue
			ahead = (crossing.position.z-(lane_center.z+travel_axis.z*progress)) * travel_axis.z
		else:
			if absf(travel_axis.x) < 0.5:
				continue
			if absf(crossing.position.z-lane_center.z) > 5.0:
				continue
			ahead = (crossing.position.x-(lane_center.x+travel_axis.x*progress)) * travel_axis.x
		if ahead > 1.5 and ahead < 7.0:
			return true
	return false

func update_car_pose(delta: float) -> void:
	if not is_instance_valid(city) or not city.has_method("height_at"):
		return
	var point := turn_curve(turn_progress) if turning else route_position()
	var facing := (turn_curve(minf(1.0, turn_progress + 0.02)) - turn_curve(maxf(0.0, turn_progress - 0.02))).normalized() if turning else travel_axis
	var x := point.x
	var z := point.z
	position = Vector3(x,city.height_at(x,z)+0.09,z)
	rotation.y = atan2(facing.x,facing.z)
	var front := Vector2(x+facing.x*1.4,z+facing.z*1.4)
	var rear := Vector2(x-facing.x*1.4,z-facing.z*1.4)
	var pitch := -atan2(city.height_at(front.x,front.y)-city.height_at(rear.x,rear.y),2.8)
	var right := Vector3(cos(rotation.y),0.0,-sin(rotation.y))
	var right_h: float = city.height_at(x+right.x*1.1,z+right.z*1.1)
	var left_h: float = city.height_at(x-right.x*1.1,z-right.z*1.1)
	var roll := atan2(right_h-left_h,2.2)
	var blend := 1.0 if delta <= 0.0 else 1.0-exp(-8.0*delta)
	$Visual.rotation.x = lerp_angle($Visual.rotation.x,clampf(pitch,-0.3,0.3),blend)
	$Visual.rotation.z = lerp_angle($Visual.rotation.z,clampf(roll,-0.3,0.3),blend)
	$CarCollision.transform = $Visual.transform * Transform3D(Basis.IDENTITY, collision_center)
	if spring_skeleton:
		$VehicleLights.sync_with_chassis()
	else:
		$VehicleLights.transform = $Visual.transform
