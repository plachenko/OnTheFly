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
@export var acceleration_rate: float = 2.8
@export var braking_rate: float = 4.0
@export var acceleration_jerk: float = 6.0
var current_driving_speed: float = 0.0
var driving_acceleration: float = 0.0
var suspension_acceleration: float = 0.0
@export var loop_extent: float = 55.0
@export var obey_crosswalks: bool = true
@export_range(0.0, 1.0, 0.05) var intersection_turn_chance: float = 0.28
@export var parked: bool = false
@export_category("Truck Interaction")
@export_range(0.0, 12.0, 0.5) var disabling_impact_speed: float = 0.5
@export_range(300.0, 4000.0, 50.0) var disabled_mass: float = 950.0
@export_range(0.1, 1.0, 0.05) var truck_push_speed_ratio: float = 0.6
@export_range(0.5, 12.0, 0.5) var chain_impact_min_speed: float = 2.5
var motion_vector: Vector3 = Vector3.ZERO
var incoming_velocity: Vector3 = Vector3.ZERO
var pending_chain_hits: Dictionary = {}
@export_category("Horns")
@export var horns_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var prolonged_impact_horn_chance: float = 0.45
var horn_player: AudioStreamPlayer3D
var short_horn: AudioStream
var held_horn: AudioStream
var horn_cooldown: float = 0.0
var next_ambient_honk: float = 15.0
var horn_rng := RandomNumberGenerator.new()
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
var impatient_driver: bool = false
@export_category("Driver Patience")
@export var maximum_patience: float = 100.0
@export var patience_depletion_rate: float = 8.0
@export var patience_recovery_rate: float = 5.0
var patience_remaining: float = 100.0
var patience_ratio: float:
	get:
		return clampf(patience_remaining / maxf(maximum_patience, 0.001), 0.0, 1.0)
var steering_angle: float = 0.0
var wheelbase: float = 2.8
var desired_passing_offset: float = 0.0
var passing_offset: float = 0.0
var passing_truck: bool = false
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
@export_category("Traffic Performance")
@export var near_simulation_radius := 90.0
@export var sleep_simulation_radius := 115.0
@export var distant_tick_seconds := 0.2
var distant_mode := false
var proximity_timer := 0.0
var distant_elapsed := 0.0
@export var hybrid_reactions_enabled := true
@export var hybrid_disabled_hold_seconds := 3.0
@export var hybrid_disabled_fade_seconds := 2.0
var hybrid: CharacterBody3D
var hybrid_pending_relative := Vector3.ZERO
var hybrid_pending_normal := Vector3.ZERO
var hybrid_pending_strength := 0.0
var hybrid_pending_motion := Vector3.ZERO
var hybrid_hit_cooldown := 0.0
var active_collision_layer := 1
var active_collision_mask := 1

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
	add_to_group("traffic_motion")
	active_collision_layer = collision_layer
	active_collision_mask = collision_mask
	proximity_timer = float(get_instance_id() % 25) * 0.01
	for mesh in $Visual.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 240.0
		mesh.visibility_range_end_margin = 20.0
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
	impatient_driver = traffic_rng.randf() < 0.4
	patience_depletion_rate = maximum_patience / (traffic_rng.randf_range(1.5, 3.5) if impatient_driver else traffic_rng.randf_range(10.0, 18.0))
	patience_recovery_rate = traffic_rng.randf_range(3.0, 7.0)
	patience_remaining = maximum_patience
	configure_horn()
	$VehicleLights.configure_kenney_car(model_scene != null and model_scene.resource_path.get_file() == "police.glb")
	if model_scene != null and model_scene.resource_path.get_file() == "police.glb":
		var circle := MeshInstance3D.new()
		circle.name = "PoliceCircle"
		circle.set_script(preload("res://police_circle.gd"))
		# Diameter is three actual car lengths, excluding collision padding.
		circle.radius = maxf(1.0, $CarCollision.shape.size.z - collision_padding * 2.0) * 1.5
		add_child(circle)

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
	if not Engine.is_editor_hint() and hybrid_reactions_enabled and supports_hybrid_model():
		hybrid = preload("res://hybrid_car.gd").new()
		hybrid.name = "SharedHybridReaction"
		hybrid.external_owner = self
		hybrid.external_visual = $Visual
		hybrid.external_model = $Visual.get_child(0)
		hybrid.disabled_hold_seconds = hybrid_disabled_hold_seconds
		hybrid.disabled_fade_seconds = hybrid_disabled_fade_seconds
		add_child(hybrid)
		collision_center = $CarCollision.position
		hybrid.exploded.connect(explode)

func supports_hybrid_model() -> bool:
	if not spring_skeleton or $Visual.get_child_count() == 0:
		return false
	for bone_name in ["Chassis", "Spring_FL", "Spring_FR", "Spring_RL", "Spring_RR"]:
		if spring_skeleton.find_bone(bone_name) < 0:
			return false
	var wheels := 0
	for mesh in $Visual.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).begins_with("wheel-") and ("left" in str(mesh.name) or "right" in str(mesh.name)):
			wheels += 1
	return wheels == 4

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and not multiplayer.is_server():
		return
	if Engine.is_editor_hint():
		_tick_traffic(delta)
		return
	var tick_started := Time.get_ticks_usec()
	proximity_timer -= delta
	if proximity_timer <= 0.0:
		proximity_timer = 0.25
		update_proximity_mode()
	if distant_mode and not disabled:
		distant_elapsed += delta
		if distant_elapsed >= maxf(0.05, distant_tick_seconds):
			step_distant_route(distant_elapsed)
			distant_elapsed = 0.0
	else:
		_tick_traffic(delta)
	if hybrid_reactions_enabled and hybrid and not distant_mode:
		step_hybrid(delta)
	PerformanceDiagnostics.record_section("Traffic", Time.get_ticks_usec() - tick_started)

func step_hybrid(delta: float) -> void:
	hybrid_hit_cooldown = maxf(0.0, hybrid_hit_cooldown - delta)
	if hybrid_pending_strength > 0.0 and current_driving_speed < 0.3:
		hybrid.velocity = motion_vector
		hybrid.rollover_inherited_velocity = hybrid_pending_motion
		hybrid.receive_impact(hybrid.velocity + hybrid_pending_relative, hybrid_pending_normal)
		hybrid_pending_strength = 0.0
		hybrid_pending_relative = Vector3.ZERO
	if hybrid.state == hybrid.State.DRIVING:
		hybrid.velocity = motion_vector
	hybrid.external_acceleration = -driving_acceleration # Production front is +Z.
	hybrid.steering = -steering_angle / 0.55
	hybrid.speed = current_driving_speed
	hybrid._physics_process(delta)
	if hybrid.state in [hybrid.State.DRIVING, hybrid.State.REACTION]:
		$CarCollision.transform = $Visual.transform * Transform3D(Basis.IDENTITY, collision_center)
	if hybrid.state in [hybrid.State.FLIGHT, hybrid.State.DISABLED, hybrid.State.EXPLODED]:
		if not disabled:
			disabled = true
			disabled_elapsed = 0.0
			turning = false
			turn_intent = 0
		freeze = true
		motion_vector = hybrid.velocity
		linear_velocity = hybrid.velocity
		incoming_velocity = hybrid.velocity
	elif hybrid.contact_locked:
		current_driving_speed = 0.0
		driving_acceleration = 0.0
		motion_vector = Vector3.ZERO
	$VehicleLights.sync_with_chassis()

func is_roof_landing(normal: Vector3, point: Vector3, other_velocity: Vector3, minimum_speed: float) -> bool:
	if exploded or (disabled and (not hybrid or hybrid.state != hybrid.State.FLIGHT)):
		return false
	var relative := other_velocity - motion_vector
	var shape := $CarCollision.shape as BoxShape3D
	if not shape or normal.dot(Vector3.UP) < 0.7 or relative.y > -maxf(0.5, minimum_speed):
		return false
	if -relative.dot(normal) < maxf(0.5, minimum_speed):
		return false
	var local_point: Vector3 = $CarCollision.to_local(point)
	var half := shape.size * 0.5
	return local_point.y >= half.y * 0.65 and absf(local_point.x) <= half.x + 0.15 and absf(local_point.z) <= half.z + 0.15

func consume_truck_landing() -> bool:
	if not multiplayer.is_server() or exploded:
		return false
	disabled = true
	disabled_elapsed = 0.0
	hybrid_pending_strength = 0.0
	freeze = true
	if hybrid_reactions_enabled and hybrid:
		hybrid.explode_once()
	else:
		explode()
	return true

func receive_vehicle_contact(other_velocity: Vector3, normal: Vector3, point: Vector3) -> bool:
	if not hybrid_reactions_enabled or not hybrid:
		return disable_from_impact(maxf(0.0, (other_velocity - motion_vector).dot(normal)), normal, point)
	var relative := other_velocity - motion_vector
	return queue_hybrid_impact(relative, normal)

func queue_hybrid_impact(relative: Vector3, normal: Vector3) -> bool:
	if not multiplayer.is_server() or disabled or exploded or hybrid_hit_cooldown > 0.0:
		return false
	var strength := maxf(0.0, relative.dot(normal.normalized()))
	if strength < maxf(0.5, disabling_impact_speed):
		return false
	hybrid_hit_cooldown = 0.15
	if distant_mode:
		distant_mode = false
		collision_layer = active_collision_layer
		collision_mask = active_collision_mask
		$VehicleLights.process_mode = Node.PROCESS_MODE_INHERIT
		$VehicleLights.show()
	if strength >= 12.0 or parked or current_driving_speed < 0.3:
		hybrid.velocity = motion_vector
		hybrid.receive_impact(hybrid.velocity + relative, normal)
		if hybrid.state == hybrid.State.FLIGHT:
			disabled = true
			disabled_elapsed = 0.0
			freeze = true
			linear_velocity = hybrid.velocity
			incoming_velocity = hybrid.velocity
			motion_vector = hybrid.velocity
			apply_crumple(strength, normal)
	else:
		# Brake through the existing route controller before capturing tire anchors.
		if strength >= hybrid_pending_strength:
			hybrid_pending_strength = strength
			hybrid_pending_relative = relative
			hybrid_pending_motion = motion_vector
			hybrid_pending_normal = normal
	return true

func hybrid_chain_contact(hit: Dictionary, impact_velocity: Vector3) -> void:
	var other := instance_from_id(hit.get("collider_id", 0))
	if not is_instance_valid(other) or other == self or not other.has_method("receive_car_impact") or other.disabled:
		return
	var normal: Vector3 = hit.normal
	var other_velocity: Vector3 = other.motion_vector
	var approach := maxf(0.0, -(impact_velocity - other_velocity).dot(normal))
	if approach >= chain_impact_min_speed and not pending_chain_hits.has(other.get_instance_id()):
		pending_chain_hits[other.get_instance_id()] = true
		apply_chain_hit.call_deferred(other, approach, -normal, hit.point)

func tick_hybrid_cleanup(delta: float) -> void:
	disabled_elapsed += delta
	bounce_cooldown = maxf(0.0, bounce_cooldown - delta)
	if hybrid.state != hybrid.State.DISABLED:
		$ImpactSmoke.emitting = hybrid.state == hybrid.State.FLIGHT and disabled_elapsed < smoke_duration
	$VehicleLights.set_driving_lights(false, false, false, false, true)
	if hybrid.state == hybrid.State.DISABLED:
		$VehicleLights.hide()
		if hybrid.disabled_cue and hybrid.disabled_cue.complete():
			queue_free()
		return
	if exploded and disabled_elapsed > fade_delay:
		var amount := clampf((disabled_elapsed - fade_delay) / maxf(fade_duration, 0.01), 0, 1)
		fade_visuals($Visual, amount)
		if amount >= 1.0:
			queue_free()

func get_hybrid_snapshot() -> Dictionary:
	if not hybrid_reactions_enabled or not hybrid:
		return {}
	var cue: Dictionary = {}
	if hybrid.state == hybrid.State.DISABLED:
		hybrid.ensure_disabled_cue()
		cue = {"age": hybrid.disabled_cue.age, "hold": hybrid.disabled_cue.hold_seconds, "fade": hybrid.disabled_cue.fade_seconds}
	var wheel_poses: Array = []
	for wheel in hybrid.wheels:
		var bone: int = wheel.bone
		wheel_poses.append([bone, hybrid.wheel_rig.get_bone_pose_position(bone), hybrid.wheel_rig.get_bone_pose_rotation(bone), hybrid.wheel_rig.get_bone_pose_scale(bone)])
	var lights := $VehicleLights
	return {"root": global_transform, "rolling": {"momentum": hybrid.rollover_velocity, "distance": hybrid.rollover_distance, "settled": hybrid.rollover_settled}, "state": hybrid.state, "velocity": motion_vector, "disabled": disabled, "exploded": exploded, "elapsed": disabled_elapsed, "visual": $Visual.transform, "visible": $Visual.visible, "collision": $CarCollision.transform, "layer": collision_layer, "mask": collision_mask, "wheels": wheel_poses, "cue": cue, "lights": [lights.brake_enabled, lights.reverse_enabled, lights.left_enabled, lights.right_enabled, lights.hazard_enabled, lights.headlights_enabled, lights.police_enabled, lights.visible]}

func apply_hybrid_snapshot(data: Dictionary) -> void:
	if multiplayer.is_server() or not hybrid or data.is_empty():
		return
	if data.exploded and not exploded:
		explode()
	if data.has("root"):
		global_transform = data.root
	hybrid.state = data.state
	hybrid.velocity = data.velocity
	var rolling: Dictionary = data.get("rolling", {})
	hybrid.rollover_velocity = rolling.get("momentum", Vector3.ZERO)
	hybrid.rollover_distance = rolling.get("distance", 0.0)
	hybrid.rollover_settled = rolling.get("settled", false)
	disabled = data.disabled
	exploded = data.exploded
	disabled_elapsed = data.elapsed
	motion_vector = data.velocity
	$Visual.transform = data.visual
	$Visual.visible = data.visible
	$CarCollision.transform = data.collision
	collision_layer = data.layer
	collision_mask = data.mask
	for wheel in data.wheels:
		hybrid.wheel_rig.set_bone_pose_position(wheel[0], wheel[1])
		hybrid.wheel_rig.set_bone_pose_rotation(wheel[0], wheel[2])
		hybrid.wheel_rig.set_bone_pose_scale(wheel[0], wheel[3])
	hybrid.wheel_rig.force_update_all_bone_transforms()
	var lights: Array = data.get("lights", [])
	if lights.size() == 8:
		$VehicleLights.set_driving_lights(lights[0], lights[1], lights[2], lights[3], lights[4])
		$VehicleLights.headlights_enabled = lights[5]
		$VehicleLights.set_police_enabled(lights[6])
		$VehicleLights.visible = lights[7]
	if disabled:
		$VehicleLights.set_driving_lights(false, false, false, false, true)
		if hybrid.state == hybrid.State.DISABLED:
			var cue: Dictionary = data.get("cue", {"age": disabled_elapsed, "hold": 3.0, "fade": 2.0})
			hybrid.sync_disabled_cue(cue.age, cue.hold, cue.fade)
			$VehicleLights.hide()
		else:
			hybrid.stop_disabled_cue()
			fade_visuals($Visual, clampf((disabled_elapsed - fade_delay) / maxf(fade_duration, 0.01), 0, 1))
	$VehicleLights.sync_with_chassis()

func update_proximity_mode() -> void:
	var nearest := INF
	var level := city.get_parent() if is_instance_valid(city) else null
	var players: Variant = level.get("trucks") if level != null else null
	if players is Dictionary:
		for body in players.values():
			var gap: float = global_position.distance_squared_to(body.global_position)
			if gap < nearest:
				nearest = gap
				truck = body
	elif is_instance_valid(truck): nearest = global_position.distance_squared_to(truck.global_position)
	var circle := get_node_or_null("PoliceCircle")
	var must_stay_active: bool = disabled or hybrid_pending_strength > 0 or (hybrid != null and hybrid.state != hybrid.State.DRIVING) or (circle != null and circle.pursuing)
	var radius := near_simulation_radius if distant_mode else maxf(near_simulation_radius + 5.0, sleep_simulation_radius)
	var should_sleep := PerformanceDiagnostics.traffic_lod_enabled and not must_stay_active and nearest > radius * radius
	if should_sleep == distant_mode: return
	distant_mode = should_sleep
	# Normal traffic is already kinematic; dynamic wreck physics is kept intact.
	collision_layer = 0 if distant_mode else active_collision_layer
	collision_mask = 0 if distant_mode else active_collision_mask
	$VehicleLights.process_mode = Node.PROCESS_MODE_DISABLED if distant_mode else Node.PROCESS_MODE_INHERIT
	$VehicleLights.visible = not distant_mode
	if circle != null: circle.process_mode = Node.PROCESS_MODE_DISABLED if distant_mode else Node.PROCESS_MODE_INHERIT
	if not distant_mode:
		distant_elapsed = 0.0
		update_car_pose(0.0)

func step_distant_route(delta: float) -> void:
	if parked or not is_instance_valid(city): return
	update_drive_speed(0.0 if should_wait_for_walk_light() or should_follow_car() else driving_speed, delta)
	if turning: advance_turn(delta)
	else:
		plan_intersection_turn()
		progress += current_driving_speed * delta
		if turn_intent != 0 and (turn_center - route_position()).dot(travel_axis) <= 8.0: begin_turn()
		elif progress > loop_extent:
			progress = -loop_extent
			considered_intersections.clear()
	var point := driving_position()
	position = Vector3(point.x, city.height_at(point.x, point.z) + 0.09, point.z)
	var facing := (turn_curve(minf(1.0, turn_progress + 0.02)) - turn_curve(maxf(0.0, turn_progress - 0.02))).normalized() if turning else travel_axis
	rotation.y = atan2(facing.x, facing.z)
	motion_vector = facing * current_driving_speed

func _tick_traffic(delta: float) -> void:
	if not Engine.is_editor_hint():
		update_horn(delta)
	if hybrid_reactions_enabled and hybrid:
		if disabled:
			tick_hybrid_cleanup(delta)
			return
		if hybrid.contact_locked:
			$VehicleLights.set_driving_lights(true, false, false, false, false)
			return
	if disabled:
		motion_vector = linear_velocity
	if disabled and not exploded:
		incoming_velocity = linear_velocity
	if not hybrid_reactions_enabled or not hybrid:
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
	var police_circle := get_node_or_null("PoliceCircle")
	if police_circle != null and police_circle.pursuing:
		update_police_chase(delta)
		return
	var following_car := should_follow_car()
	var truck_stopped := update_truck_avoidance(delta, following_car)
	var stopped := hybrid_pending_strength > 0 or should_wait_for_walk_light() or following_car or truck_stopped
	var previous_driving_speed := current_driving_speed
	update_drive_speed(0.0 if stopped else driving_speed, delta)
	if current_driving_speed > 0.001:
		if turning:
			advance_turn(delta)
		else:
			if absf(passing_offset) < 0.05:
				plan_intersection_turn()
			progress += current_driving_speed * delta
			if turn_intent != 0 and (turn_center - route_position()).dot(travel_axis) <= 8.0:
				begin_turn()
			elif progress > loop_extent:
				progress = -loop_extent
				considered_intersections.clear()
	update_driving_suspension(clampf((current_driving_speed - previous_driving_speed) / maxf(delta, 0.001), -8.0, 4.0), delta)
	$VehicleLights.set_driving_lights(stopped or driving_acceleration < -0.2, false, turn_intent < 0 or passing_truck, turn_intent > 0, false)
	update_car_pose(delta)

func braking_lookahead() -> float:
	# Include time to ease into braking before reaching full deceleration.
	return current_driving_speed * current_driving_speed / (2.0 * maxf(braking_rate, 0.1)) + current_driving_speed * braking_rate / maxf(acceleration_jerk, 0.1) + 2.0

func update_drive_speed(target_speed: float, delta: float) -> void:
	var difference := target_speed - current_driving_speed
	if absf(difference) < 0.03 and absf(driving_acceleration) < 0.1:
		current_driving_speed = target_speed
		driving_acceleration = 0.0
		return
	var desired_acceleration := clampf(difference * 2.0, -braking_rate, acceleration_rate)
	driving_acceleration = move_toward(driving_acceleration, desired_acceleration, acceleration_jerk * delta)
	var next_speed := maxf(0.0, current_driving_speed + driving_acceleration * delta)
	if (target_speed - next_speed) * difference <= 0.0:
		next_speed = target_speed
		driving_acceleration = 0.0
	current_driving_speed = next_speed

func update_driving_suspension(acceleration: float, delta: float) -> void:
	if hybrid_reactions_enabled and hybrid:
		return
	if spring_velocities.size() != 5:
		return
	# Load the rear under acceleration and the front under braking.
	for index in range(1, 5):
		var target_offset := acceleration * (0.065 if index <= 2 else -0.065)
		spring_velocities[index] += target_offset * spring_stiffness * delta
	var acceleration_change := acceleration - suspension_acceleration
	spring_velocities[0] += acceleration_change * 0.035
	suspension_acceleration = acceleration

func driving_position() -> Vector3:
	var point := turn_curve(turn_progress) if turning else route_position()
	return point + Vector3(-travel_axis.z, 0, travel_axis.x) * desired_passing_offset

func truck_blocks_motion(start: Vector3, finish: Vector3, clearance: float = 0.8) -> bool:
	if not is_instance_valid(truck):
		return false
	var truck_shape := truck.get_node("TruckCollision") as CollisionShape3D
	var car_half: Vector3 = $CarCollision.shape.size * 0.5
	var shape_transform: Transform3D = truck_shape.global_transform
	var local_start := shape_transform.affine_inverse() * start
	var local_finish := shape_transform.affine_inverse() * finish
	if absf(local_start.y) > truck_shape.shape.size.y * 0.5 + car_half.y + 2.0:
		return false
	var forward := travel_axis.normalized()
	var right := Vector3(-forward.z, 0, forward.x)
	var half: Vector3 = truck_shape.shape.size * 0.5
	half.x += absf(shape_transform.basis.x.dot(right)) * car_half.x + absf(shape_transform.basis.x.dot(forward)) * car_half.z + clearance
	half.z += absf(shape_transform.basis.z.dot(right)) * car_half.x + absf(shape_transform.basis.z.dot(forward)) * car_half.z + clearance
	var enter := 0.0
	var leave := 1.0
	for axis in [0, 2]:
		var movement: float = local_finish[axis] - local_start[axis]
		if absf(movement) < 0.0001:
			if absf(local_start[axis]) > half[axis]:
				return false
		else:
			var a: float = (-half[axis] - local_start[axis]) / movement
			var b: float = (half[axis] - local_start[axis]) / movement
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
			if enter > leave:
				return false
	return true

func truck_is_in_parking_bay() -> bool:
	if absf(truck.speed) > 0.5:
		return false
	if is_instance_valid(truck.parking_pad):
		return truck.parking_pad.contains_truck(truck)
	for bay in city.get_node("ParkingSpaces").get_children():
		var axis: Vector3 = bay.get_meta("parking_axis", Vector3.FORWARD)
		var delta: Vector3 = truck.global_position - bay.global_position
		var right := Vector3(-axis.z, 0, axis.x)
		if absf(delta.dot(axis)) < 2.0 and absf(delta.dot(right)) < 0.8 and absf((-truck.global_basis.z).dot(axis)) > 0.95:
			return true
	return false

func passing_lane_clear(offset: float) -> bool:
	var right := Vector3(-travel_axis.z, 0, travel_axis.x)
	var origin := route_position() + right * offset
	for distance in [0.0, 4.0, 8.0, 12.0, 18.0]:
		var point: Vector3 = origin + travel_axis * distance
		point.y = city.height_at(point.x, point.z) + 0.15
		if truck_blocks_motion(point, point):
			return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = $CarCollision.shape
		query.transform = Transform3D(Basis(Vector3.UP, rotation.y), point + collision_center + Vector3.UP * 0.25)
		var exclusions: Array[RID] = [get_rid()]
		var ground := city.get_node_or_null("Terrain/HillyGround") as PhysicsBody3D
		if ground:
			exclusions.append(ground.get_rid())
		query.exclude = exclusions
		query.collision_mask = collision_mask
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true

func update_patience(blocked: bool, delta: float) -> void:
	var change := -patience_depletion_rate if blocked else patience_recovery_rate
	patience_remaining = clampf(patience_remaining + change * delta, 0.0, maximum_patience)

func update_truck_avoidance(delta: float, queued: bool = false) -> bool:
	if not is_instance_valid(truck):
		return false
	var point := global_position
	var blocked := truck_blocks_motion(point, point + travel_axis * maxf(12.0, braking_lookahead() + 6.0))
	var parked_truck := truck_is_in_parking_bay() if blocked else false
	var legal_passing := preload("res://city_road_rules.gd").passing_allowed(travel_axis, route_position())
	if not legal_passing: passing_truck = false
	update_patience((blocked and not parked_truck) or queued, delta)
	if passing_truck and (truck.global_position - point).dot(travel_axis) < -10.0:
		passing_truck = false
	if blocked:
		if not parked_truck and patience_ratio <= 0.25:
			honk()
		if legal_passing and not turning and (parked_truck or patience_ratio <= 0.1) and passing_lane_clear(-4.8):
			passing_truck = true
	elif queued and patience_ratio <= 0.1:
		honk()
	var desired := -4.8 if passing_truck else 0.0
	desired_passing_offset = desired
	# A clear passing corridor lets the car roll forward into a steered curve.
	return (blocked and not passing_truck) or (passing_truck and not passing_lane_clear(-4.8))

func configure_horn() -> void:
	horn_rng.randomize()
	var voice: String = ["compact", "sedan", "van"][horn_rng.randi_range(0, 2)]
	if model_scene and model_scene.resource_path.get_file() in ["van.glb", "delivery.glb"]:
		voice = "van"
	short_horn = load("res://assets/audio/horns/%s_short.wav" % voice)
	held_horn = load("res://assets/audio/horns/%s_held.wav" % voice)
	horn_player = AudioStreamPlayer3D.new()
	horn_player.name = "Horn"
	horn_player.position = Vector3(0, 1.0, 0)
	horn_player.volume_db = -8.0
	horn_player.unit_size = 8.0
	horn_player.max_distance = 60.0
	horn_player.pitch_scale = horn_rng.randf_range(0.96, 1.04)
	add_child(horn_player)
	next_ambient_honk = horn_rng.randf_range(8.0, 25.0)

func honk(prolonged: bool = false) -> bool:
	if not horns_enabled or exploded or not is_instance_valid(horn_player):
		return false
	if not prolonged and (horn_cooldown > 0.0 or horn_player.playing):
		return false
	horn_player.stream = held_horn if prolonged else short_horn
	horn_player.play()
	var duration := horn_player.stream.get_length() / horn_player.pitch_scale
	var comic := preload("res://comic_burst.gd")
	var at := global_position + Vector3.UP * 2.8
	if prolonged:
		var word := "H" + "O".repeat(clampi(ceili(duration * 1.5), 3, 8)) + "NK"
		comic.spawn(self, at, word, duration, 5.5)
	else:
		comic.spawn(self, at + Vector3(-0.65, 0.0, 0.0), "HONK", duration * 0.5, 2.8)
		comic.spawn(self, at + Vector3(0.65, 0.55, 0.0), "HONK", duration * 0.5, 2.8, duration * 0.5)
	horn_cooldown = 6.0 if prolonged else horn_rng.randf_range(8.0, 14.0)
	return true

func update_horn(delta: float) -> void:
	horn_cooldown = maxf(0.0, horn_cooldown - delta)
	if disabled or parked or exploded or not horns_enabled:
		return
	next_ambient_honk -= delta
	if next_ambient_honk <= 0.0:
		next_ambient_honk = horn_rng.randf_range(12.0, 30.0)
		if is_instance_valid(truck) and global_position.distance_to(truck.global_position) < 50.0 and horn_rng.randf() < 0.3:
			honk()

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
			var one_way := preload("res://city_road_rules.gd").one_way(absf(travel_axis.z) > 0.5, intersection.x if absf(travel_axis.z) > 0.5 else intersection.z)
			if absf(lane_offset.dot(right)) > 1.5 and not (one_way != 0 and absf(lane_offset.dot(right) + 8.0) < 1.5):
				continue
			var ahead := (intersection - current).dot(travel_axis)
			if ahead < 13.0 or ahead > 20.0:
				continue
			var key := Vector2i(ix, iz)
			if considered_intersections.has(key):
				continue
			considered_intersections[key] = true
			var rules := preload("res://city_road_rules.gd")
			var kind := rules.approach_kind(travel_axis, intersection, (current - intersection).dot(right))
			var options: Array[int] = []
			var left := Vector3(travel_axis.z, 0, -travel_axis.x)
			if kind != "straight" and rules.allows(left, intersection): options.append(-1)
			if kind == "unmarked" and rules.allows(-left, intersection): options.append(1)
			if not options.is_empty() and (kind == "left" or traffic_rng.randf() < intersection_turn_chance):
				turn_intent = options[traffic_rng.randi_range(0, options.size() - 1)]
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
	turn_progress = minf(1.0, turn_progress + current_driving_speed * delta / turn_length)
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
		var spacing: float = ($CarCollision.shape.size.z + other.get_node("CarCollision").shape.size.z) * 0.5 + braking_lookahead()
		if ahead > 0.0 and ahead < spacing:
			return true
	return false

func disable_from_impact(approach_speed: float, push_direction: Vector3, _impact_point: Vector3) -> bool:
	if not multiplayer.is_server():
		return false
	if hybrid_reactions_enabled and hybrid:
		return queue_hybrid_impact(push_direction.normalized() * approach_speed, push_direction.normalized())
	if disabled or approach_speed < disabling_impact_speed:
		return false
	disabled = true
	if distant_mode:
		distant_mode = false
		collision_layer = active_collision_layer
		collision_mask = active_collision_mask
		$VehicleLights.process_mode = Node.PROCESS_MODE_INHERIT
		$VehicleLights.show()
	disabled_elapsed = 0.0
	if horn_rng.randf() < prolonged_impact_horn_chance:
		honk(true)
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
	if hybrid_reactions_enabled and hybrid:
		return # Grounded rollovers remain anchored; flight has its own launch velocity.
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
	if hybrid_reactions_enabled and hybrid:
		if hybrid.state != hybrid.State.FLIGHT:
			return false
		bounce_cooldown = 0.3
		hybrid.velocity = direction.normalized() * clampf(truck_speed * 1.25, 18, 42) + Vector3.UP * 9
		linear_velocity = hybrid.velocity
		incoming_velocity = hybrid.velocity
		return true
	bounce_cooldown = 0.3
	sleeping = false
	linear_velocity = direction.normalized() * clampf(truck_speed * 1.25, 18.0, 42.0) + Vector3.UP * 9.0
	incoming_velocity = linear_velocity
	randomize_tumble()
	return true

func explode() -> void:
	if exploded:
		return
	exploded = true
	if is_instance_valid(horn_player):
		horn_player.stop()
	collision_layer = 0
	collision_mask = 0
	$VehicleLights.visible = false
	if hybrid_reactions_enabled and hybrid:
		$Visual.hide()
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
	preload("res://hybrid_disabled_cue.gd").configure_smoke($ImpactSmoke)

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
	apply_chassis_suspension_pose()
	for index in range(crumple_bones.size()):
		var bone := crumple_bones[index]
		if bone >= 0:
			var inward := -1.0 if index == 0 else 1.0
			spring_skeleton.set_bone_pose_position(bone,crumple_rest_positions[index] + Vector3(0.0,0.0,inward * crumple_depths[index]))

func apply_chassis_suspension_pose() -> void:
	if hybrid_reactions_enabled and hybrid:
		return
	if spring_bones.size() != 5 or spring_bones[0] < 0:
		return
	var chassis := spring_bones[0]
	var wheel_positions: Array[Vector3] = []
	for index in range(1, 5):
		if spring_bones[index] < 0:
			return
		wheel_positions.append(spring_skeleton.get_bone_global_rest(spring_bones[index]).origin)
	var front := (wheel_positions[0] + wheel_positions[1]) * 0.5
	var rear := (wheel_positions[2] + wheel_positions[3]) * 0.5
	var left := (wheel_positions[0] + wheel_positions[2]) * 0.5
	var right := (wheel_positions[1] + wheel_positions[3]) * 0.5
	var front_load := (spring_offsets[1] + spring_offsets[2]) * 0.5
	var rear_load := (spring_offsets[3] + spring_offsets[4]) * 0.5
	var left_load := (spring_offsets[1] + spring_offsets[3]) * 0.5
	var right_load := (spring_offsets[2] + spring_offsets[4]) * 0.5
	var heave := spring_offsets[0] + (front_load + rear_load) * 0.5
	var pitch_angle := clampf(atan2(rear_load - front_load, maxf(front.distance_to(rear), 0.1)), -0.2, 0.2)
	var roll_angle := clampf(atan2(right_load - left_load, maxf(left.distance_to(right), 0.1)), -0.15, 0.15)
	var body_motion := Transform3D(Basis.from_euler(Vector3(pitch_angle, 0, roll_angle)), Vector3.UP * heave)
	var desired := body_motion * spring_skeleton.get_bone_global_rest(chassis)
	var parent := spring_skeleton.get_bone_parent(chassis)
	var parent_pose := spring_skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	set_suspension_bone_pose(chassis, parent_pose.affine_inverse() * desired)
	spring_skeleton.force_update_all_bone_transforms()
	# Wheel bones are children of Chassis: counter its movement to keep tires planted.
	for index in range(1, 5):
		var bone := spring_bones[index]
		var wheel_parent := spring_skeleton.get_bone_parent(bone)
		var wheel_parent_pose := spring_skeleton.get_bone_global_pose(wheel_parent) if wheel_parent >= 0 else Transform3D.IDENTITY
		var wheel_rest := spring_skeleton.get_bone_global_rest(bone)
		if index <= 2:
			wheel_rest.basis = Basis(Vector3.UP, steering_angle) * wheel_rest.basis
		set_suspension_bone_pose(bone, wheel_parent_pose.affine_inverse() * wheel_rest)

func set_suspension_bone_pose(bone: int, pose: Transform3D) -> void:
	spring_skeleton.set_bone_pose_position(bone, pose.origin)
	spring_skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
	spring_skeleton.set_bone_pose_scale(bone, pose.basis.get_scale())

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
		if ahead > 1.5 and ahead < maxf(7.0, braking_lookahead() + $CarCollision.shape.size.z * 0.5):
			return true
	return false

func update_car_pose(delta: float) -> void:
	if not is_instance_valid(city) or not city.has_method("height_at"):
		return
	var point := driving_position()
	var facing := (turn_curve(minf(1.0, turn_progress + 0.02)) - turn_curve(maxf(0.0, turn_progress - 0.02))).normalized() if turning else travel_axis
	if delta <= 0.0 or position.distance_to(point) > 50.0:
		position = Vector3(point.x, city.height_at(point.x, point.z) + 0.09, point.z)
		rotation.y = atan2(facing.x, facing.z)
		steering_angle = 0.0
		motion_vector = Vector3.ZERO
	else:
		var lookahead := maxf(3.0, current_driving_speed * 0.55)
		var target := point + facing * lookahead
		var offset := target - position
		var heading_error := wrapf(atan2(offset.x, offset.z) - rotation.y, -PI, PI)
		# Pure pursuit chooses steering; a bicycle model turns and moves the car.
		var desired_steering := clampf(atan2(2.0 * wheelbase * sin(heading_error), maxf(Vector2(offset.x, offset.z).length(), 1.0)), -0.55, 0.55)
		steering_angle = move_toward(steering_angle, desired_steering, delta * 0.9)
		var yaw_step := current_driving_speed / wheelbase * tan(steering_angle) * delta
		var midpoint := rotation.y + yaw_step * 0.5
		var vector := Vector3(sin(midpoint), 0, cos(midpoint)) * current_driving_speed
		var next := position + vector * delta
		next.y = city.height_at(next.x, next.z) + 0.09
		if truck_blocks_motion(global_position, get_parent().to_global(next)):
			current_driving_speed = 0.0
			driving_acceleration = 0.0
			motion_vector = Vector3.ZERO
		else:
			motion_vector = (next - position) / delta
			position = next
			rotation.y += yaw_step
		if not turning:
			progress = (position - lane_center).dot(travel_axis)
			passing_offset = (position - route_position()).dot(Vector3(-travel_axis.z, 0, travel_axis.x))
		facing = Vector3(sin(rotation.y), 0, cos(rotation.y))
	var x := position.x
	var z := position.z
	apply_chassis_suspension_pose()
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

func update_police_chase(delta: float) -> void:
	if not is_instance_valid(truck):
		return
	var to_truck := truck.global_position - global_position
	if PoliceDispatch.willing_stop(self) and to_truck.length() < 16.0:
		current_driving_speed = 0.0
		motion_vector = Vector3.ZERO
		return
	var error := wrapf(atan2(to_truck.x, to_truck.z) - rotation.y, -PI, PI)
	var desired := clampf(atan2(2.0 * wheelbase * sin(error), maxf(3.0, to_truck.length())), -0.55, 0.55)
	if absf(error) > PI * 0.6:
		desired = 0.55 * signf(error)
	steering_angle = move_toward(steering_angle, desired, 1.2 * delta)
	update_drive_speed(0.0 if hybrid_pending_strength > 0 else minf(28.0, maxf(12.0, absf(truck.speed) + 4.0)), delta)
	var yaw := current_driving_speed / wheelbase * tan(steering_angle) * delta
	var heading := rotation.y + yaw * 0.5
	var movement := Vector3(sin(heading), 0, cos(heading)) * current_driving_speed * delta
	var next := global_position + movement
	if truck_blocks_motion(global_position, next, 0.0):
		PoliceDispatch.police_hit(truck)
		current_driving_speed = 0.0
		motion_vector = Vector3.ZERO
	else:
		global_position = next
		global_position.y = city.height_at(next.x, next.z) + 0.09
		rotation.y += yaw
		motion_vector = movement / maxf(delta, 0.001)
	apply_chassis_suspension_pose()
	$VehicleLights.sync_with_chassis()
