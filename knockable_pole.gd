extends RigidBody3D

@export var minimum_impact_speed: float = 10.0
var fallen: bool = false
var visual: Node3D
@export var height: float = 5.0
@export var visual_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	if visual == null: visual = get_parent() as Node3D

func impact_knock_down(direction: Vector3, impact_speed: float) -> bool:
	if fallen or impact_speed < minimum_impact_speed:
		return false
	fallen = true
	# Collision callbacks run during physics; release the pole afterwards.
	call_deferred("release_pole", direction, impact_speed)
	return true

func release_pole(direction: Vector3, impact_speed: float) -> void:
	freeze = false
	sleeping = false
	var horizontal := Vector3(direction.x, 0, direction.z).normalized()
	apply_impulse(horizontal * mass * minf(impact_speed, 22.0) * 0.65, Vector3.UP * height * 0.3)
	apply_torque_impulse(Vector3.UP.cross(horizontal) * mass * height * 0.5)
	for light in visual.find_children("*", "Light3D", true, false):
		light.light_energy = 0.0
	for label in visual.find_children("*", "Label3D", true, false):
		label.hide()

func _physics_process(_delta: float) -> void:
	if fallen and is_instance_valid(visual):
		var base := global_transform.translated_local(Vector3(0, -height * 0.5, 0))
		base.basis = base.basis.scaled(visual_scale)
		visual.global_transform = base
