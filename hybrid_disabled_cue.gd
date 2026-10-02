extends Node3D
## Per-car visual cue. No imported material resources are modified.
var visual: Node3D
var smoke: CPUParticles3D
var borrowed_smoke: GPUParticles3D
var engine_point := Vector3.ZERO
var age := 0.0
var hold_seconds := 3.0
var fade_seconds := 2.0
var opacity := 1.0
var start_count := 0
var outline: StandardMaterial3D
var soot: StandardMaterial3D
var overlays: Array[Dictionary] = []
var fading_materials: Array[Dictionary] = []
var material_cache: Dictionary = {}

func fading_copy(source: Material) -> Material:
	if not source:
		source = StandardMaterial3D.new()
	var id := source.get_instance_id()
	if material_cache.has(id):
		return material_cache[id]
	var copy := source.duplicate() as Material
	if copy is BaseMaterial3D:
		var alpha: float = copy.albedo_color.a
		fading_materials.append({"material": copy, "alpha": alpha, "transparency": copy.transparency})
	material_cache[id] = copy
	return copy

static func configure_smoke(particles: GPUParticles3D, count: int = 28, duration: float = 1.8) -> void:
	particles.amount = count
	particles.lifetime = duration
	particles.local_coords = false
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 25
	motion.initial_velocity_min = 0.6
	motion.initial_velocity_max = 1.6
	motion.gravity = Vector3(0, 0.25, 0)
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.22
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.2, Color(1, 1, 1, 0.6))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	motion.color_ramp = ramp
	particles.process_material = motion
	particles.draw_pass_1 = make_puff()

static func make_puff() -> SphereMesh:
	var puff := SphereMesh.new()
	puff.radius = 0.3
	puff.height = 0.6
	puff.radial_segments = 8
	puff.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.31, 0.33, 0.34, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	puff.material = material
	return puff

func start(body: Node3D, engine: Vector3, existing_smoke: GPUParticles3D = null) -> void:
	if start_count > 0:
		return
	start_count = 1
	visual = body
	engine_point = engine
	outline = StandardMaterial3D.new()
	outline.albedo_color = Color(1, 0.85, 0.02, 1)
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.035
	outline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		var surfaces: Array = []
		for surface in mesh.mesh.get_surface_count():
			surfaces.append(mesh.get_surface_override_material(surface))
		var original_override: Material = mesh.material_override
		overlays.append({"mesh": mesh, "original": mesh.material_overlay, "override": original_override, "surfaces": surfaces})
		if original_override:
			mesh.material_override = fading_copy(original_override)
		else:
			for surface in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, fading_copy(mesh.get_active_material(surface)))
		mesh.material_overlay = outline
	borrowed_smoke = existing_smoke
	if borrowed_smoke:
		borrowed_smoke.emitting = false
		borrowed_smoke.hide()
	# Twelve CPU puffs are reliable in Compatibility as well as Forward+.
	smoke = CPUParticles3D.new()
	smoke.name = "DisabledSmoke"
	smoke.amount = 12
	smoke.lifetime = 1.2
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 25
	smoke.initial_velocity_min = 2.5
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(0, 0.35, 0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 0.7))
	smoke.color_ramp = ramp
	smoke.mesh = make_puff()
	soot = smoke.mesh.material
	add_child(smoke)
	set_age(0)

func set_age(seconds: float) -> void:
	age = maxf(0, seconds)
	var fraction := clampf((age - hold_seconds) / maxf(0.05, fade_seconds), 0, 1)
	opacity = 1.0 - fraction * fraction * (3.0 - 2.0 * fraction)
	outline.albedo_color.a = opacity
	soot.albedo_color.a = 0.45 * opacity
	for entry in fading_materials:
		entry.material.transparency = entry.transparency if opacity >= 0.999 else BaseMaterial3D.TRANSPARENCY_ALPHA
		entry.material.albedo_color.a = entry.alpha * opacity
	for entry in overlays:
		if is_instance_valid(entry.mesh):
			entry.mesh.transparency = 0.0 # Material alpha also works in Compatibility.
	smoke.global_position = visual.global_transform * engine_point
	smoke.emitting = opacity > 0.1
	if opacity <= 0:
		smoke.hide()
		visual.hide()

func tick(delta: float) -> void:
	set_age(age + delta)

func complete() -> bool:
	return age >= hold_seconds + maxf(0.05, fade_seconds)

func stop() -> void:
	if is_instance_valid(smoke):
		smoke.emitting = false
		smoke.hide()
	for entry in overlays:
		if is_instance_valid(entry.mesh):
			entry.mesh.material_overlay = entry.original
			entry.mesh.material_override = entry.override
			for surface in entry.surfaces.size():
				entry.mesh.set_surface_override_material(surface, entry.surfaces[surface])
