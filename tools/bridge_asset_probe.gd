extends SceneTree
func _initialize() -> void:
	for path in ["res://assets/kenney_city/roads/road-bridge.glb","res://assets/kenney_city/roads/bridge-pillar.glb"]:
		var node: Node = load(path).instantiate()
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			print(path," ",mesh.name," ",mesh.mesh.get_aabb())
			var values := {}
			for index in mesh.mesh.get_surface_count():
				for vertex in mesh.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]: values[snappedf(vertex.y,.001)]=true
			print("heights ",values.keys())
		node.free()
	quit()
