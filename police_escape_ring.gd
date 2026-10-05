extends Node3D

@export var radius := 10.0
@export var grace_seconds := 4.0
@export var health_per_second := 2.0
@export var escape_distance := 12.0
@export var clear_seconds := 1.0
var active := false
var elapsed := 0.0
var fade_remaining := 0.0
var spin := 0.0
var merge := 0.0
var heading := Vector2.ZERO
var street_center := Vector2.ZERO
var street_axis := Vector2.ZERO
var progress := 0.0
var clear_time := 0.0
var last_position := Vector2.ZERO
var contact_cooldown := 0.0
var ring: MeshInstance3D
var arcs: MeshInstance3D
var ring_material: StandardMaterial3D
var blue_material: StandardMaterial3D
var scene: Node3D

func _ready() -> void:
	scene = get_parent()
	ring_material = material(Color("ff3838"))
	blue_material = material(Color("299cff"))
	ring = MeshInstance3D.new()
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	arcs = MeshInstance3D.new()
	arcs.material_override = blue_material
	arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arcs)
	hide()

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.albedo_color = color
	return result

func player_point() -> Vector2:
	return Vector2(scene.truck.global_position.x, scene.truck.global_position.z)

func begin_chase() -> void:
	active = true
	elapsed = 0.0
	fade_remaining = 0.0
	merge = 0.0
	progress = 0.0
	clear_time = 0.0
	contact_cooldown = 0.0
	heading = Vector2.ZERO
	last_position = player_point()
	show()

# Choose an actual street heading using separation from every pursuing cop.
func choose_route(point: Vector2) -> float:
	var best := -INF
	var nearest := INF
	for street in scene.get_node("ProceduralCity").escape_streets():
		var center: Vector2 = street[0]
		var axis: Vector2 = street[1]
		var right := Vector2(-axis.y, axis.x)
		var distance := absf((point - center).dot(right))
		for sign_value in [-1.0, 1.0]:
			var direction: Vector2 = axis * sign_value
			var destination := point + direction * 30.0
			var separation := 100.0
			for officer in scene.cops:
				if not officer.disabled:
					var cop_point := Vector2(officer.global_position.x, officer.global_position.z)
					separation = minf(separation, destination.distance_to(cop_point))
			var score := separation - distance * 4.0
			if score > best:
				best = score
				heading = direction
				street_center = center
				street_axis = axis
				nearest = distance
	return nearest

func in_red_zone(point: Vector2) -> bool:
	for officer in scene.cops:
		var circle = officer.get_node("PoliceCircle")
		if officer.disabled or not circle.pursuing:
			continue
		var center := Vector2(officer.global_position.x, officer.global_position.z)
		if point.distance_to(center) < circle.radius * 1.15 * circle.chase_radius_multiplier:
			return true
	return false

func touching_cop() -> bool:
	# Use production footprint collision queries, including the truck's full box.
	for officer in scene.cops:
		if not officer.disabled and officer.truck_blocks_motion(officer.global_position, officer.global_position, 0.0):
			return true
	return false

func _physics_process(delta: float) -> void:
	if PoliceDispatch.pursuing and not active:
		begin_chase()
	if not PoliceDispatch.pursuing:
		active = false
		return
	tick_chase(delta)

func tick_chase(delta: float) -> void:
	if scene.truck.police_parking != null and scene.truck.police_parking.active: return
	elapsed += delta
	var point := player_point()
	var movement := point - last_position
	last_position = point
	var previous_heading := heading
	var street_distance: float
	if progress < 1.0 or merge < 0.8:
		street_distance = choose_route(point)
		if previous_heading != heading:
			progress = 0.0
	else:
		street_distance = absf((point - street_center).dot(Vector2(-street_axis.y, street_axis.x)))
	merge = move_toward(merge, clampf(1.0 - maxf(0.0, street_distance - 8.0) / 18.0, 0.0, 1.0), delta * 0.8)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	if touching_cop() or PoliceDispatch.hit_cooldown > 0.0 or scene.truck.impact_cooldown > 0.0:
		contact_cooldown = 1.5
		progress = 0.0
		clear_time = 0.0
	# Displacement, rather than vehicle facing or signed speed, permits reverse escapes.
	if merge >= 0.8 and street_distance <= 8.0 and contact_cooldown <= 0.0:
		progress = maxf(0.0, progress + movement.dot(heading))
	else:
		progress = 0.0
	var trapped := in_red_zone(point)
	if trapped and elapsed > grace_seconds:
		scene.truck.health = maxf(0.0, scene.truck.health - health_per_second * delta)
	if not trapped and progress >= escape_distance and contact_cooldown <= 0.0 and movement.dot(heading) >= -0.01:
		clear_time += delta
	else:
		clear_time = 0.0
	if clear_time >= clear_seconds:
		PoliceDispatch.evade(scene.truck)
		active = false
		fade_remaining = 1.8

func _process(delta: float) -> void:
	spin += delta * 1.8
	if not active and fade_remaining <= 0.0:
		hide()
		return
	show()
	if not active:
		fade_remaining = maxf(0.0, fade_remaining - delta)
		arcs.hide()
		ring_material.albedo_color = Color(0.26, 0.96, 0.47, fade_remaining / 1.8)
	else:
		arcs.show()
		ring_material.albedo_color = Color("ff3838")
	global_position = scene.truck.global_position
	ring.mesh = build_ring(false)
	if active:
		arcs.mesh = build_ring(true)

func build_ring(blue: bool) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var target_angle := atan2(heading.y, heading.x)
	var street_arc := 2.0 * asin(clampf(8.0 / radius, 0.0, 0.85))
	for part in (6 if blue else 1):
		# Six neighboring pieces form one continuous arc at full convergence.
		var final_angle := target_angle + (part - 2.5) * street_arc / 6.0
		var angle := lerp_angle(spin + part * TAU / 6.0, final_angle, smoothstep(0.0, 1.0, merge)) if blue else 0.0
		var width := lerpf(0.18, street_arc / 6.0, merge) if blue else TAU
		var segments := 20 if blue else 96
		for segment in segments:
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var theta: float = angle - width * 0.5 + (segment + corner.x) * width / segments
				var distance: float = radius + (corner.y - 0.5) * (0.36 if blue else 0.18)
				var vertex := Vector3(cos(theta) * distance, 0, sin(theta) * distance)
				var world := global_position + vertex
				vertex.y = scene.get_node("ProceduralCity").height_at(world.x, world.z) - global_position.y + (0.20 if blue else 0.17)
				builder.add_vertex(vertex)
	builder.generate_normals()
	return builder.commit()
