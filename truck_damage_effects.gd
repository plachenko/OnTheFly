extends Node3D

var truck: CharacterBody3D
var smoke: GPUParticles3D
var flash_material: StandardMaterial3D
var wreck_material: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var damage_flash_remaining: float = 0.0
var blink_phase: float = 0.0
var blink_period: float = 1.2
var exploded: bool = false

func _ready() -> void:
	truck = get_parent()
	for mesh in truck.model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mesh)
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.02, 0.01, 0.55)
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.emission_enabled = true
	flash_material.emission = Color.RED
	flash_material.emission_energy_multiplier = 1.5
	wreck_material = StandardMaterial3D.new()
	wreck_material.albedo_color = Color(0.08, 0.065, 0.055, 0.7)
	wreck_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke = GPUParticles3D.new()
	smoke.name = "CriticalSmoke"
	smoke.position = Vector3(0, 2.4, -2.0)
	smoke.amount = 40
	smoke.lifetime = 2.0
	smoke.emitting = false
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 25.0
	motion.initial_velocity_min = 0.8
	motion.initial_velocity_max = 2.0
	motion.gravity = Vector3(0, 0.4, 0)
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.4
	motion.color_ramp = fade_ramp(Color(0.2, 0.21, 0.22, 0.7))
	smoke.process_material = motion
	smoke.draw_pass_1 = particle_mesh(0.35)
	add_child(smoke)

func fade_ramp(color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.15, color)
	gradient.set_color(2, Color(color.r, color.g, color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp

func particle_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	return mesh

func damage_taken() -> void:
	damage_flash_remaining = 0.6
	update_effects(0.0)

func _physics_process(delta: float) -> void:
	update_effects(delta)

func update_effects(delta: float) -> void:
	if exploded and truck.health > 0.0:
		exploded = false
		blink_phase = 0.0
	damage_flash_remaining = maxf(0.0, damage_flash_remaining - delta)
	var critical: bool = truck.health > 0.0 and truck.health / truck.max_health < truck.critical_health_ratio
	smoke.emitting = critical and not truck.round_over
	if truck.health <= 0.0 and not exploded:
		explode()
	var danger := 1.0 - clampf(truck.health / maxf(0.001, truck.max_health * truck.critical_health_ratio), 0.0, 1.0)
	blink_period = lerpf(1.2, 0.16, danger)
	blink_phase = fmod(blink_phase + delta / blink_period, 1.0)
	var red_flash := (critical and blink_phase < 0.45) or (damage_flash_remaining > 0.0 and fmod(0.6 - damage_flash_remaining, 0.2) < 0.1)
	for mesh in meshes:
		mesh.material_overlay = wreck_material if exploded else (flash_material if red_flash else null)

func explode() -> void:
	exploded = true
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	truck.deployed = false
	truck.boost_active = false
	if truck.fsd_enabled:
		truck.stop_fsd("Truck exploded — tow to the service station")
	truck.message = "Truck exploded — R / Y to tow and repair."
	truck.message_timer = 3.0
	preload("res://explosion_card.gd").spawn(get_tree().current_scene, truck.global_position + Vector3.UP * 2.5, 13.0, "TruckExplosion")
