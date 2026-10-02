extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var model = load("res://assets/kenney_city/cars_rigged/sedan.glb").instantiate()
	root.add_child(model)
	await process_frame
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		print(mesh.name, " ", mesh.get_aabb(), " ", mesh.transform)
	for rig in model.find_children("*", "Skeleton3D", true, false):
		print("RIG ", rig.get_path())
		for i in rig.get_bone_count():
			print(rig.get_bone_name(i), " ", rig.get_bone_global_rest(i))
	quit()
