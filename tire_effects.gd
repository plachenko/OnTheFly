extends Node3D

const LIMIT := 1024
var truck: CharacterBody3D
var tracks: MultiMeshInstance3D
var smoke: Array[GPUParticles3D] = []
var previous: Array = [null, null, null, null]
var slot := 0
var marks_written := 0
var wheel_marks := [0,0,0,0]
var friction_energy := 0.0
var previous_heading := 0.0

func _ready() -> void:
	truck = get_parent()
	previous_heading = truck.rotation.y
	tracks = MultiMeshInstance3D.new()
	tracks.top_level = true
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	instances.mesh = plane
	instances.instance_count = LIMIT
	instances.visible_instance_count = 0
	tracks.multimesh = instances
	var material := ShaderMaterial.new()
	material.shader = preload("res://tire_marks.gdshader")
	tracks.material_override = material
	tracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracks)
	tracks.global_transform = Transform3D.IDENTITY
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,0.5), Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	for i in 4:
		var particles := GPUParticles3D.new()
		particles.amount = 48
		particles.lifetime = 1.2
		particles.local_coords = false
		particles.emitting = false
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.UP
		process.spread = 35
		process.gravity = Vector3(0,0.5,0)
		process.initial_velocity_min = 0.5
		process.initial_velocity_max = 1.5
		process.scale_min = 0.35
		process.scale_max = 0.8
		process.color = Color(.65,.67,.68,.45)
		particles.process_material = process
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var smoke_material := StandardMaterial3D.new()
		smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		smoke_material.albedo_texture = texture
		quad.material = smoke_material
		particles.draw_pass_1 = quad
		add_child(particles)
		smoke.append(particles)

func _physics_process(delta: float) -> void:
	tracks.material_override.set_shader_parameter("clock", Time.get_ticks_msec() / 1000.0)
	var yaw_speed := absf(angle_difference(previous_heading, truck.rotation.y)) / maxf(delta,.001)
	previous_heading = truck.rotation.y
	var bypass: bool = truck.highway_transit != null and truck.highway_transit.active
	if truck.police_parking != null and truck.police_parking.active: bypass = true
	var side_slip: float = absf(sin(truck.rotation.y - truck.travel_heading) * truck.speed)
	friction_energy = 0.0
	for i in 4:
		var wheel: Vector3 = truck.skeleton.to_global(truck.skeleton.get_bone_global_pose(truck.suspension_bones[i]).origin)
		var query := PhysicsRayQueryParameters3D.create(wheel + Vector3.UP * .8, wheel + Vector3.DOWN * 1.0, 1, [truck.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query) if not bypass else {}
		var energy := 0.0
		if not hit.is_empty():
			var pivot: Vector3 = truck.global_transform * truck.front_axle_pivot
			var radius := Vector2(wheel.x - pivot.x, wheel.z - pivot.z).length()
			var rotational_slip := yaw_speed * radius if truck.stationary_drifting else yaw_speed * (3.0 if i >= 2 else .5)
			var slip: float = side_slip + rotational_slip
			if i >= 2: slip += absf(truck.tire_throttle) * truck.tire_brake * 9.0
			var friction := 1.0
			if hit.collider is PhysicsBody3D and hit.collider.physics_material_override: friction = hit.collider.physics_material_override.friction
			var load_ratio: float = clampf(truck.corner_load[i] / maxf(1.0,truck.vehicle_mass * 9.81 / 4.0), .25, 1.5)
			energy = clampf((slip - 1.0) / 8.0 * friction * sqrt(load_ratio), 0.0, 1.0)
			var point: Vector3 = hit.position + hit.normal * .045
			point.y += truck.visual_contact_height(hit.position,hit.collider)-hit.position.y
			smoke[i].global_position = point + Vector3.UP * .1
			if energy > .08 and previous[i] != null:
				var movement: Vector3 = point - previous[i]
				if movement.length() >= 2.0: previous[i] = point
				if movement.length() > .07 and movement.length() < 2.0:
					var normal: Vector3 = hit.normal
					var along := movement.normalized()
					var right := normal.cross(along).normalized()
					tracks.multimesh.set_instance_transform(slot, Transform3D(Basis(right * .26, normal, along * movement.length()), (point + previous[i]) * .5))
					tracks.multimesh.set_instance_custom_data(slot, Color(Time.get_ticks_msec()/1000.0,energy,0,0))
					slot = (slot + 1) % LIMIT
					marks_written += 1
					wheel_marks[i] += 1
					tracks.multimesh.visible_instance_count = mini(marks_written, LIMIT)
					previous[i] = point
			else: previous[i] = point
		else: previous[i] = null
		smoke[i].emitting = energy > .15
		smoke[i].amount_ratio = maxf(.05, energy)
		friction_energy = maxf(friction_energy, energy)
