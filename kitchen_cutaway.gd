extends Node

var materials: Array[ShaderMaterial] = []
var strength := 0.0
@onready var truck = get_parent()

func _ready() -> void:
	for mesh in truck.model.find_children("*", "MeshInstance3D", true, false):
		var shell: bool = mesh.name == "Cargo roof" or mesh.name == "Far side wall" or str(mesh.name).begins_with("Side ") or str(mesh.name).begins_with("Rear ") or str(mesh.name).begins_with("Window edge trim")
		if not shell: continue
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			if not original is StandardMaterial3D: continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://kitchen_cutaway.gdshader")
			material.set_shader_parameter("tint", original.albedo_color)
			material.set_shader_parameter("metallic_value", original.metallic)
			material.set_shader_parameter("roughness_value", original.roughness)
			mesh.set_surface_override_material(surface, material)
			materials.append(material)

func update_view(blend: float, camera: Camera3D) -> void:
	strength = blend
	var focus: Vector3 = truck.global_transform * Vector3(0,2.4,1.0)
	var center := camera.unproject_position(focus) / camera.get_viewport().get_visible_rect().size
	for material in materials:
		material.set_shader_parameter("strength", blend)
		material.set_shader_parameter("opening_center", center)
		material.set_shader_parameter("world_to_truck", truck.global_transform.affine_inverse())
