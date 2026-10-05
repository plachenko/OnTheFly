extends SceneTree
func _initialize() -> void:
	var model = load("res://assets/truck_with_doors.glb").instantiate()
	root.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		print(node.name, " ", node.mesh.get_aabb(), " materials ", node.mesh.get_surface_count())
		for i in node.mesh.get_surface_count():
			var m = node.get_active_material(i)
			print("  ",m.resource_name, " ", m.albedo_color, " tex ",m.albedo_texture)
	quit()
