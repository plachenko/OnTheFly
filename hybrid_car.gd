extends CharacterBody3D
## Engine movement and reusable procedural visual reactions. Forward is local -Z.
signal exploded
enum State { DRIVING, REACTION, FLIGHT, EXPLODED, DISABLED }
var state := State.DRIVING
var speed := 0.0
var throttle := 0.0
var steering := 0.0
var pose := Vector3.ZERO
var pose_velocity := Vector3.ZERO
var flight_age := 0.0
var tumble_axis := Vector3.RIGHT
var tumble_rate := 0.0
var explosion_count := 0
var visual: Node3D
var crash_box := BoxShape3D.new()
var crash_basis := Basis.IDENTITY
var last_visual_center := Vector3.ZERO
var physics_usec := 0
const MODELS := ["sedan", "hatchback-sports", "suv", "van", "taxi", "police"]
var model_index := 0
var model_bounds := AABB()
var model_root: Node3D
var driving_shape: CollisionShape3D
var spin_rng := RandomNumberGenerator.new()
var local_impact := Vector3.ZERO
var spin_vector := Vector3.ZERO
var driving_pose := Vector3.ZERO
var driving_pose_velocity := Vector3.ZERO
var driving_roll := 0.0
var driving_roll_velocity := 0.0
var maneuver_intensity := 0.0
var chassis_pivot := Vector3.ZERO
const MEDIUM_TIP_DURATION := 0.55
const MAX_MEDIUM_ROLL := TAU / 3.0 # 120 degrees
var medium_tip_elapsed := MEDIUM_TIP_DURATION
var medium_tip_start := 0.0
var medium_tip_target := 0.0
@export var tire_friction := 0.85
@export var recovery_damping := 8.0
@export var light_tip_cap := deg_to_rad(14.0)
var tip_duration := MEDIUM_TIP_DURATION
var light_reaction := false
var contact_locked := false
var contact_ground: Dictionary = {}
var contact_pivot := Vector3.ZERO
var contact_pivot_world := Vector3.ZERO
var wheel_rig: Skeleton3D
var wheels: Array[Dictionary] = []
var body_points: Array[Vector3] = []
var driving_body_support: Array[Vector3] = []
var rollover_energy := 0.0
var disabled_roll := 0.0
var tip_axis := Vector3.ZERO
var tip_start := Vector3.ZERO
var tip_target := Vector3.ZERO
var disabled_tip := Vector3.ZERO
var disabled_angle := 0.0
var disabled_angular_speed := 0.0
var balance_margin := -1.0
var stability_bias := 0.0
## Optional production adapter: traffic owns movement, this owns shared reactions.
var external_owner: RigidBody3D
var external_visual: Node3D
var external_model: Node3D
var external_acceleration := 0.0
@export var disabled_hold_seconds := 3.0
@export var disabled_fade_seconds := 2.0
var disabled_cue: Node3D
var rollover_velocity := Vector3.ZERO
var rollover_inherited_velocity := Vector3.ZERO
var rollover_distance := 0.0
var rollover_released := false
var rollover_settled := false
var support_collision_mask := 1

func ensure_disabled_cue() -> void:
	if disabled_cue:
		return
	collision_layer = 0
	collision_mask = 0
	if external_owner:
		external_owner.collision_layer = 0
		external_owner.collision_mask = 0
		external_owner.get_node("VehicleLights").hide()
	driving_shape.set_deferred("disabled", true)
	disabled_cue = preload("res://hybrid_disabled_cue.gd").new()
	disabled_cue.name = "DisabledCue"
	add_child(disabled_cue)
	disabled_cue.hold_seconds = disabled_hold_seconds
	disabled_cue.fade_seconds = disabled_fade_seconds
	var engine := model_bounds.get_center()
	engine.z += model_bounds.size.z * (0.3 if external_owner else -0.3)
	engine.y = model_bounds.end.y * 0.65
	var existing: GPUParticles3D = external_owner.get_node("ImpactSmoke") if external_owner else null
	disabled_cue.start(visual, engine, existing)

func sync_disabled_cue(age: float, hold: float, fade: float) -> void:
	disabled_hold_seconds = hold
	disabled_fade_seconds = fade
	ensure_disabled_cue()
	disabled_cue.hold_seconds = hold
	disabled_cue.fade_seconds = fade
	disabled_cue.set_age(age)

func stop_disabled_cue() -> void:
	if disabled_cue:
		disabled_cue.stop()
		disabled_cue.queue_free()
		disabled_cue = null

func _ready() -> void:
	if external_owner:
		driving_shape = external_owner.get_node("CarCollision")
		visual = external_visual
		collision_layer = 0
		set_physics_process(false)
		spin_rng.randomize()
		set_model(0)
		return
	driving_shape = CollisionShape3D.new()
	add_child(driving_shape)
	visual = Node3D.new()
	add_child(visual)
	spin_rng.randomize()
	set_model(model_index)

func collect_bounds(node: Node3D, relative: Transform3D, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh:
		boxes.append(relative * node.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			collect_bounds(child, relative * child.transform, boxes)

func set_model(index: int) -> void:
	model_index = posmod(index, MODELS.size())
	if is_instance_valid(model_root) and not external_owner:
		visual.remove_child(model_root)
		model_root.queue_free()
	if external_owner:
		model_root = external_model
	else:
		model_root = load("res://assets/kenney_city/cars_rigged/%s.glb" % MODELS[model_index]).instantiate()
		model_root.scale = Vector3.ONE * 1.8
	# Kenney fronts face +Z; controller forward and impact aiming use -Z.
	# Apply before measuring bounds so origin normalization includes this mapping.
	if not external_owner:
		model_root.rotation.y = PI
		visual.add_child(model_root)
	var boxes: Array[AABB] = []
	collect_bounds(model_root, model_root.transform, boxes)
	assert(not boxes.is_empty())
	model_bounds = boxes[0]
	for box in boxes:
		model_bounds = model_bounds.merge(box)
	# Normalize disparate GLB origins: horizontal center and lowest tire at +4 cm.
	var shift := Vector3(-model_bounds.get_center().x, 0.04 - model_bounds.position.y, -model_bounds.get_center().z)
	model_root.position += shift
	model_bounds.position += shift
	map_wheels_and_body()
	# A low body-center pivot, scaled for each model rather than tire-level origin.
	chassis_pivot = Vector3(0, model_bounds.position.y + model_bounds.size.y * 0.4, 0)
	var box := BoxShape3D.new()
	box.size = model_bounds.size
	driving_shape.shape = box
	driving_shape.transform = Transform3D(Basis.IDENTITY, model_bounds.get_center())
	crash_box.size = model_bounds.size * Vector3(0.85, 0.75, 0.85)
	apply_ground_pose(ground_sample(), Vector3.ZERO)

func map_wheels_and_body() -> void:
	wheels.clear()
	body_points.clear()
	wheel_rig = model_root.find_children("*", "Skeleton3D", true, false)[0]
	var model_inverse := visual.global_transform.affine_inverse()
	for mesh in model_root.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = model_inverse * mesh.global_transform
		if str(mesh.name) == "wheel-back":
			# SUV spare is weighted to Spring_RR by the existing rig generator.
			# Keep this non-contact spare attached to the body in this instance.
			mesh.skin = null
			mesh.skeleton = NodePath("")
		if str(mesh.name).begins_with("wheel-") and ("left" in str(mesh.name) or "right" in str(mesh.name)):
			var bounds: AABB = relative * mesh.get_aabb()
			var label: String = str(mesh.name)
			var bone_name := "Spring_" + ("F" if "front" in label else "R") + ("L" if "left" in label else "R")
			var bone := wheel_rig.find_bone(bone_name)
			var offsets: Array[Vector3] = []
			for surface in mesh.mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					offsets.append(relative * vertex - bounds.get_center())
			wheels.append({"bone": bone, "rest": wheel_rig.get_bone_global_rest(bone), "center": bounds.get_center(), "radius": bounds.size.y * 0.5, "points": offsets, "anchor": Vector3.ZERO, "loaded": false, "world_center": Vector3.ZERO, "planted": false})
		else:
			for surface in mesh.mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					body_points.append(relative * vertex)
	assert(wheels.size() == 4 and not body_points.is_empty())
	# Eight body-only bounds corners suffice for ordinary driving; deep reactions
	# retain vertex support. Tire support stays independent of body lifting.
	var body_bounds := AABB(body_points[0], Vector3.ZERO)
	for vertex in body_points:
		body_bounds = body_bounds.expand(vertex)
	driving_body_support.clear()
	for i in 8:
		driving_body_support.append(body_bounds.position + body_bounds.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))

func begin_tire_contact(axis: Vector3) -> void:
	if collision_mask != 0:
		support_collision_mask = collision_mask
	contact_ground = ground_sample()
	contact_locked = not contact_ground.is_empty()
	if not contact_locked:
		return
	var normal: Vector3 = contact_ground.normal
	var push := Vector3(-axis.z, 0, axis.x).normalized()
	var max_score := -INF
	for wheel in wheels:
		max_score = maxf(max_score, wheel.center.dot(push))
	contact_pivot = Vector3.ZERO
	contact_pivot_world = Vector3.ZERO
	var count := 0
	for wheel in wheels:
		wheel.loaded = wheel.center.dot(push) >= max_score - 0.1
		var at: Vector3 = global_transform * wheel.center
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2, at - Vector3.UP * 3, collision_mask, excluded_bodies())
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var plane: Vector3 = hit.get("position", contact_ground.position)
		wheel.anchor = at + normal * (wheel.radius + 0.02 - normal.dot(at - plane))
		if wheel.loaded:
			contact_pivot += wheel.center - Vector3.UP * wheel.radius
			contact_pivot_world += wheel.anchor - normal * wheel.radius
			count += 1
	contact_pivot /= maxf(1, count)
	contact_pivot_world /= maxf(1, count)
	speed = 0.0
	velocity = Vector3.ZERO

func set_wheel_transform(wheel: Dictionary, desired: Transform3D) -> void:
	var rig_to_world := wheel_rig.global_transform
	var in_rig := rig_to_world.affine_inverse() * desired
	var parent := wheel_rig.get_bone_parent(wheel.bone)
	var parent_pose := wheel_rig.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := parent_pose.affine_inverse() * in_rig
	wheel_rig.set_bone_pose_position(wheel.bone, local.origin)
	wheel_rig.set_bone_pose_rotation(wheel.bone, local.basis.get_rotation_quaternion())
	wheel_rig.set_bone_pose_scale(wheel.bone, local.basis.get_scale())

func update_tires(normal: Vector3, plane: Vector3, roll: float) -> void:
	wheel_rig.reset_bone_poses()
	wheel_rig.force_update_all_bone_transforms()
	for wheel in wheels:
		var rest_world: Transform3D = wheel_rig.global_transform * wheel.rest
		var center: Vector3 = visual.global_transform * wheel.center
		var desired := rest_world
		var wheel_basis := visual.global_basis
		wheel.planted = false
		if state == State.DRIVING or (contact_locked and wheel.loaded and absf(roll) < deg_to_rad(55)):
			# Counter the wrapper via actual wheel bones, leaving only loaded tires planted.
			var forward := (-global_basis.z).slide(normal).normalized()
			var terrain_wheel_basis := Basis(normal.cross(-forward).normalized(), normal, -forward)
			var release := 0.0 if state == State.DRIVING else clampf((absf(roll) - deg_to_rad(40)) / deg_to_rad(15), 0, 1)
			release = release * release * (3.0 - 2.0 * release)
			wheel_basis = terrain_wheel_basis.orthonormalized().slerp(visual.global_basis.orthonormalized(), release)
			var anchor: Vector3 = wheel.anchor
			if state == State.DRIVING:
				anchor = center + normal * (wheel.radius + 0.02 - normal.dot(center - plane))
			var released_center: Vector3 = anchor.lerp(center, release)
			var correction := wheel_basis * visual.global_basis.inverse()
			desired.basis = correction * rest_world.basis
			desired.origin = released_center - correction * (center - rest_world.origin)
			center = released_center
			wheel.planted = state != State.DRIVING and release <= 0.0
		var clearance := INF
		if state == State.DRIVING:
			clearance = normal.dot(center - plane) - wheel.radius
		else:
			for offset in wheel.points:
				clearance = minf(clearance, normal.dot(center + wheel_basis * offset - plane))
		if clearance < 0.02 or (state == State.DRIVING and clearance < 0.4):
			var lift := normal * (0.02 - clearance)
			desired.origin += lift
			center += lift
		wheel.world_center = center
		wheel.world_basis = wheel_basis
		set_wheel_transform(wheel, desired)
	wheel_rig.force_update_all_bone_transforms()

func apply_ground_pose(ground: Dictionary, angles: Vector3) -> void:
	var normal: Vector3 = ground.get("normal", Vector3.UP)
	var local_normal := global_basis.inverse() * normal
	# Exact orthogonal terrain frame, including banked slopes.
	var forward := Vector3.FORWARD.slide(local_normal).normalized()
	var terrain_basis := Basis(local_normal.cross(-forward).normalized(), local_normal, -forward)
	var axis := Vector3(angles.x, 0, angles.z)
	visual.basis = terrain_basis * (Basis(axis.normalized(), axis.length()) if axis.length_squared() > 0.000001 else Basis.IDENTITY)
	# Keep the chassis pivot fixed relative to the terrain frame while rotating.
	var pivot := contact_pivot if contact_locked else chassis_pivot
	visual.position = terrain_basis * pivot - visual.basis * pivot + Vector3(0, 0.0 if contact_locked else pose.y + driving_pose.y, 0)
	if contact_locked:
		visual.global_position = contact_pivot_world - visual.global_basis * contact_pivot
		if tip_axis.length_squared() < 0.01:
			visual.global_position += normal * pose.y # Vertical bounce, tires still anchored.
	if ground.is_empty():
		return
	# Body support uses mesh vertices, not a whole-car box that lifts all tires.
	var min_distance := INF
	var support := driving_body_support if state == State.DRIVING else body_points
	for vertex in support:
		min_distance = minf(min_distance, normal.dot(visual.global_transform * vertex - ground.position))
	if min_distance < 0.02:
		visual.global_position += normal * (0.02 - min_distance)
	update_tires(normal, ground.position, axis.length())

func excluded_bodies() -> Array[RID]:
	var result: Array[RID] = [get_rid()]
	if external_owner:
		result.append(external_owner.get_rid())
	return result

func ground_sample() -> Dictionary:
	if external_owner and is_instance_valid(external_owner.city) and state in [State.DRIVING,State.REACTION]:
		return preload("res://traffic_ground.gd").sample(external_owner.city,external_owner.global_position)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position - Vector3.UP * 3.0, support_collision_mask, excluded_bodies())
	return get_world_3d().direct_space_state.intersect_ray(query)

func receive_impact(other_velocity: Vector3, contact_normal: Vector3) -> void:
	if state in [State.EXPLODED, State.FLIGHT, State.DISABLED]:
		return
	var normal := contact_normal.normalized()
	var relative := other_velocity - velocity
	var inherited := velocity + rollover_inherited_velocity
	rollover_inherited_velocity = Vector3.ZERO
	var strength := maxf(0.0, relative.dot(normal))
	if strength < 0.5:
		return
	var local := (global_basis.inverse() * relative).normalized()
	local_impact = local
	# Mirrored local components choose signed pitch/roll without directional clips.
	var light_jolt := strength < 5.0
	var angular_gain := 0.15 if light_jolt else 0.45
	pose_velocity += Vector3(local.z, 0, -local.x) * minf(strength, 12.0) * angular_gain
	if light_jolt:
		# Cap accumulated light hits too: ~3 degree peak tilt with this spring.
		pose_velocity.x = clampf(pose_velocity.x, -0.55, 0.55)
		pose_velocity.z = clampf(pose_velocity.z, -0.55, 0.55)
	pose_velocity.y += minf(strength, 12.0) * (0.01 if light_jolt else 0.035)
	state = State.REACTION
	if strength < 12.0:
		# Torque of a push above the contact line: up.cross(local push).
		# Front/rear => pitch; left/right => roll; diagonals blend both.
		var torque := Vector3(local.z, 0, -local.x)
		var horizontal_ratio := torque.length()
		tip_axis = torque.normalized() if horizontal_ratio > 0.05 else Vector3.ZERO
		light_reaction = strength < 5.0
		begin_tire_contact(tip_axis)
		rollover_velocity = Vector3.ZERO if light_reaction else (relative * 0.32 + inherited * 0.35).slide(Vector3.UP).limit_length(7.0)
		if not light_reaction and horizontal_ratio > 0.05:
			var push := Vector3(relative.x, 0, relative.z).normalized()
			rollover_velocity += push * maxf(0, strength * 0.15 - rollover_velocity.dot(push))
			rollover_velocity = rollover_velocity.limit_length(7.0)
		rollover_distance = 0.0
		rollover_released = false
		rollover_settled = false
		var normal_local: Vector3 = global_basis.inverse() * contact_ground.get("normal", Vector3.UP)
		stability_bias = clampf(normal_local.dot(Vector3(local.x, 0, local.z)), -0.25, 0.25)
		medium_tip_start = pose.z
		tip_start = Vector3(pose.x, 0, pose.z)
		var grip := clampf(tire_friction, 0.2, 1.2)
		if light_reaction:
			# Repeated light hits replace a capped target; they cannot accumulate rollover energy.
			tip_target = tip_axis * tip_angle_for_strength(strength, stability_bias) * horizontal_ratio
			rollover_energy = 0.0
			tip_duration = 0.3
		else:
			tip_target = tip_axis * tip_angle_for_strength(strength, stability_bias) * horizontal_ratio
			rollover_energy = strength * (0.4 + 0.6 * absf(local.x)) * grip
			tip_duration = MEDIUM_TIP_DURATION
		medium_tip_target = tip_target.z
		medium_tip_elapsed = 0.0
	if strength >= 12.0:
		state = State.FLIGHT
		contact_locked = false
		wheel_rig.reset_bone_poses()
		flight_age = 0.0
		velocity += normal * strength * 0.65 + Vector3.UP * strength * 0.45
		# Direction owns dominant signs; variation blends both pitch and roll.
		# Missing horizontal channels get a small randomized secondary component.
		var pitch := local.z * spin_rng.randf_range(0.8, 1.2)
		var roll := -local.x * spin_rng.randf_range(0.8, 1.2)
		if absf(pitch) < 0.08:
			pitch = spin_rng.randf_range(0.18, 0.35) * (-1.0 if spin_rng.randf() < 0.5 else 1.0)
		if absf(roll) < 0.08:
			roll = spin_rng.randf_range(0.18, 0.35) * (-1.0 if spin_rng.randf() < 0.5 else 1.0)
		tumble_axis = Vector3(pitch, spin_rng.randf_range(-0.12, 0.12), roll).normalized()
		tumble_rate = clampf(strength * 0.25, 3.0, 9.0)
		spin_vector = tumble_axis * tumble_rate
		last_visual_center = visual_center()

func tip_angle_for_strength(strength: float, bias: float = 0.0) -> float:
	var grip := clampf(tire_friction, 0.2, 1.2)
	if strength < 5:
		return light_tip_cap * clampf(strength / 5.0, 0, 1) * clampf(grip + bias, 0.4, 1.0)
	var angle := lerpf(light_tip_cap, MAX_MEDIUM_ROLL, clampf((strength - 5.0) / 6.0, 0, 1))
	return minf(MAX_MEDIUM_ROLL, angle * clampf(grip + bias, 0.5, 1.15))

func visual_center() -> Vector3:
	return visual.global_transform * model_bounds.get_center()

func crash_intersects(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = crash_box
	# Fixed world axes: no body or visual rotation enters the query transform.
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = collision_mask
	query.exclude = excluded_bodies()
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	if fractions[0] < 1.0:
		if external_owner:
			query.transform.origin = from + query.motion * minf(1.0, fractions[1] + 0.005)
			query.motion = Vector3.ZERO
			var hit := space.get_rest_info(query)
			if not hit.is_empty():
				external_owner.hybrid_chain_contact(hit, velocity)
		return true
	query.transform.origin = to
	query.motion = Vector3.ZERO
	var overlaps := space.intersect_shape(query, 1)
	if not overlaps.is_empty() and external_owner:
		var hit := space.get_rest_info(query)
		if not hit.is_empty():
			external_owner.hybrid_chain_contact(hit, velocity)
	return not overlaps.is_empty()

func explode_once() -> void:
	if state == State.EXPLODED:
		return
	state = State.EXPLODED
	stop_disabled_cue()
	explosion_count += 1
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visual.hide()
	if not external_owner:
		preload("res://explosion_card.gd").spawn(get_parent(), global_position + Vector3.UP, 4.0)
	exploded.emit()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	if state == State.DISABLED:
		ensure_disabled_cue()
		var old_transform := visual.global_transform
		var support := Vector3.ZERO if rollover_settled else rolling_support_point()
		var remaining := maxf(0, disabled_tip.length() - disabled_angle)
		disabled_angular_speed = move_toward(disabled_angular_speed, minf(4.0, remaining * 4.0), delta * 6.0)
		disabled_angle += minf(remaining, disabled_angular_speed * delta)
		pose.x = tip_axis.x * disabled_angle
		pose.z = tip_axis.z * disabled_angle
		speed = 0.0
		if disabled_angle >= deg_to_rad(55) and not rollover_released:
			# Rebase the owner without changing the visible position when the last
			# loaded tire releases. Subsequent support comes from body/wheel geometry.
			contact_locked = false
			apply_ground_pose(contact_ground, Vector3(pose.x, 0, pose.z))
			move_rollover_root((old_transform.origin - visual.global_position).slide(contact_ground.get("normal", Vector3.UP)))
			rollover_released = true
		if rollover_released and not rollover_settled:
			advance_rollover(delta, old_transform, support)
		else:
			velocity = Vector3.ZERO
			apply_ground_pose(contact_ground, Vector3(pose.x, 0, pose.z))
		driving_shape.transform = visual.transform * Transform3D(Basis.IDENTITY, model_bounds.get_center())
		rollover_settled = disabled_tip.length() - disabled_angle < 0.01 and rollover_velocity.length() < 0.05
		if rollover_settled:
			disabled_cue.tick(delta)
		else:
			disabled_cue.set_age(0) # Give the settled wreck its full hold/fade interval.
		if not external_owner and disabled_cue.complete():
			queue_free()
	elif state == State.FLIGHT:
		flight_age += delta
		velocity.y -= 9.8 * delta
		# Engine owns trajectory; visuals may freely clip while tumbling.
		if external_owner:
			external_owner.global_position += velocity * delta
		else:
			global_position += velocity * delta
		visual.rotate_object_local(tumble_axis, tumble_rate * delta)
		var center := visual_center()
		if crash_intersects(last_visual_center, center):
			explode_once()
		last_visual_center = center
	elif external_owner:
		step_shared_pose(delta, external_acceleration)
	else:
		var previous_speed := speed
		if not contact_locked:
			speed = move_toward(speed, throttle * 16.0, (10.0 if throttle == 0.0 else 5.0) * delta)
			rotate_y(-steering * speed / 3.0 * delta * 0.35)
		var ground := ground_sample()
		var normal: Vector3 = ground.get("normal", Vector3.UP)
		var forward := (-global_basis.z).slide(normal).normalized()
		var falling_speed := velocity.y
		velocity = forward * speed
		velocity.y = velocity.y - 2.0 if is_on_floor() else falling_speed - 9.8 * delta
		var approach_velocity := velocity
		if not contact_locked:
			move_and_slide()
		else:
			velocity = Vector3.ZERO
		for index in get_slide_collision_count():
			var hit := get_slide_collision(index)
			if hit.get_normal().dot(Vector3.UP) < 0.65:
				var resolved_velocity := velocity
				velocity = approach_velocity
				receive_impact(hit.get_collider_velocity(), hit.get_normal())
				if state != State.FLIGHT:
					velocity = resolved_velocity
		var acceleration := (speed - previous_speed) / maxf(delta, 0.001)
		step_shared_pose(delta, acceleration)
	physics_usec = Time.get_ticks_usec() - start

func rolling_support_point() -> Vector3:
	var normal: Vector3 = contact_ground.get("normal", Vector3.UP)
	var lowest := INF
	var candidates: Array[Vector3] = body_points.duplicate()
	for wheel in wheels:
		for offset in wheel.points:
			candidates.append(wheel.center + offset)
	for point in candidates:
		lowest = minf(lowest, normal.dot(visual.global_basis * point))
	var support := Vector3.ZERO
	var count := 0
	for point in candidates:
		if normal.dot(visual.global_basis * point) <= lowest + 0.015:
			support += point
			count += 1
	return support / maxf(count, 1)

func move_rollover_root(offset: Vector3) -> void:
	if external_owner:
		external_owner.global_position += offset
	else:
		global_position += offset

func advance_rollover(delta: float, old_transform: Transform3D, support: Vector3) -> void:
	var normal: Vector3 = contact_ground.get("normal", Vector3.UP)
	rollover_velocity = rollover_velocity.slide(normal).move_toward(Vector3.ZERO, (2.0 + tire_friction * 2.0) * delta)
	var ground := ground_sample()
	if not ground.is_empty():
		contact_ground = ground
	apply_ground_pose(contact_ground, Vector3(pose.x, 0, pose.z))
	# Rotate about the previous lowest support, then transfer to the new lowest
	# body/tire point next tick. Impact momentum adds a bounded frictional slip.
	var geometric := (old_transform * support - visual.global_transform * support).slide(normal)
	var push := (global_basis * Vector3(-tip_axis.z, 0, tip_axis.x)).slide(normal).normalized()
	geometric = push * maxf(0, geometric.dot(push))
	var displacement := geometric + rollover_velocity * delta
	displacement = displacement.limit_length(minf(0.3, maxf(0, 12.0 - rollover_distance)))
	var ray := PhysicsRayQueryParameters3D.create(visual_center(), visual_center() + displacement, support_collision_mask, excluded_bodies())
	var obstacle := get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstacle.is_empty() and absf(obstacle.normal.y) < 0.65:
		displacement = Vector3.ZERO
		rollover_velocity = Vector3.ZERO
	rollover_distance += displacement.length()
	if rollover_distance >= 11.99:
		rollover_velocity = Vector3.ZERO
	move_rollover_root(displacement)
	var previous_plane: Vector3 = contact_ground.get("position", global_position)
	ground = ground_sample()
	if not ground.is_empty():
		move_rollover_root(Vector3.UP * (ground.position.y - previous_plane.y))
		contact_ground = ground
	apply_ground_pose(contact_ground, Vector3(pose.x, 0, pose.z))
	velocity = displacement / maxf(delta, 0.001)

func step_shared_pose(delta: float, acceleration: float) -> void:
	update_driving_pose(delta, acceleration)
	# Spring integration runs only while a reaction is unsettled.
	if state == State.REACTION:
		pose_velocity += (-pose * 32.0 - pose_velocity * recovery_damping) * delta
		pose += pose_velocity * delta
		pose.x = clampf(pose.x, -1.1, 1.1)
		if medium_tip_elapsed < tip_duration:
			medium_tip_elapsed = minf(tip_duration, medium_tip_elapsed + delta)
			var t := medium_tip_elapsed / tip_duration
			var eased := t * t * (3.0 - 2.0 * t)
			var controlled := tip_start.lerp(tip_target, eased)
			pose.x = controlled.x
			pose.z = controlled.z
			var outward := (tip_target - tip_start) * 6.0 * t * (1.0 - t) / tip_duration
			pose_velocity.x = outward.x
			pose_velocity.z = outward.z
		pose.z = clampf(pose.z, -MAX_MEDIUM_ROLL, MAX_MEDIUM_ROLL)
		if light_reaction:
			var bounded := Vector3(pose.x, 0, pose.z).limit_length(light_tip_cap)
			pose.x = bounded.x
			pose.z = bounded.z
		if medium_tip_elapsed >= tip_duration and pose.length() < 0.0005 and pose_velocity.length() < 0.002:
			pose = Vector3.ZERO
			pose_velocity = Vector3.ZERO
			state = State.DRIVING
			contact_locked = false
	if state != State.FLIGHT:
		apply_ground_pose(contact_ground if contact_locked else ground_sample(), Vector3(driving_pose.x + pose.x, 0, driving_roll + pose.z))
		if state == State.REACTION and not light_reaction and contact_locked and tip_axis.length_squared() > 0.01:
			var normal: Vector3 = contact_ground.normal
			var com := visual.global_transform * chassis_pivot
			var projected := com + Vector3.DOWN * (normal.dot(com - contact_pivot_world) / maxf(normal.y, 0.15))
			var push := (global_basis * Vector3(-tip_axis.z, 0, tip_axis.x)).slide(normal).normalized()
			balance_margin = push.dot(projected - contact_pivot_world)
			# Once mass passes support with outward motion, never spring it upright.
			if balance_margin >= 0.01 and pose_velocity.dot(tip_axis) > 0.15:
				state = State.DISABLED
				var final_angle := PI if tip_target.length() > deg_to_rad(95) else PI * 0.5
				disabled_tip = tip_axis * final_angle
				disabled_angle = maxf(0, Vector3(pose.x, 0, pose.z).dot(tip_axis))
				disabled_angular_speed = maxf(0.15, pose_velocity.dot(tip_axis))
				disabled_roll = disabled_tip.z
				pose_velocity = Vector3.ZERO
				throttle = 0
				steering = 0
				ensure_disabled_cue()

func update_driving_pose(delta: float, acceleration: float) -> void:
	# Eased intensity carries damping through the stop, rather than switching it
	# abruptly when acceleration reaches zero. Hard maneuvers ring down more.
	var intensity := clampf(absf(acceleration) / 12.0, 0.0, 1.0)
	maneuver_intensity = lerpf(maneuver_intensity, intensity, 1.0 - exp(-delta * (5.0 if intensity > maneuver_intensity else 2.0)))
	var damping := lerpf(12.0, 5.0, maneuver_intensity)
	var target := Vector3(clampf(acceleration * 0.012, -0.16, 0.16), absf(acceleration) * 0.002, 0)
	# Shared underdamped easing channels preserve velocity at target changes,
	# yielding a small context-dependent bounce instead of a stop impulse.
	driving_pose_velocity += ((target - driving_pose) * 42.0 - driving_pose_velocity * damping) * delta
	driving_pose += driving_pose_velocity * delta
	var roll_target := steering * speed * 0.009
	driving_roll_velocity += ((roll_target - driving_roll) * 42.0 - driving_roll_velocity * 10.0) * delta
	driving_roll += driving_roll_velocity * delta
