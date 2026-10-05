extends RefCounted

static func generate(city: Node3D) -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("555b5b")
	grey.roughness = 1
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("4b793b")
	green.roughness = 1
	for cell in city.topology.blocks:
		await city.loading_checkpoint()
		if not city.topology.primary(Vector2(cell)): continue
		var kind: String = city.topology.plot_kind(Vector2(cell))
		var node := Node3D.new()
		node.name = "Plot_%d_%d" % [cell.x,cell.y]
		node.set_meta("plot_kind",kind)
		node.set_meta("plot_bounds",city.topology.blocks[cell])
		city.get_node("Parks").add_child(node)
		preload("res://city_surface_layout.gd").add_patches(city,node,"Grass" if kind != "grey" else "BuildingAsphalt",preload("res://city_islands.gd").inner_pieces(city,Vector2(cell)),city.sidewalk_height+.02,green if kind != "grey" else grey,0)
		lower_to_ground(city,node)

static func lower_to_ground(city: Node3D, parent: Node) -> void:
	for visual in parent.get_children():
		if not visual is MeshInstance3D or not visual.mesh is ArrayMesh: continue
		var source: ArrayMesh = visual.mesh
		var shaped := ArrayMesh.new()
		for index in source.get_surface_count():
			var arrays := source.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices.size():
				var world: Vector3 = visual.to_global(vertices[vertex])
				vertices[vertex].y -= city.artery_lift_at(world.x,world.z)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			shaped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			shaped.surface_set_material(index,source.surface_get_material(index))
		visual.mesh = shaped
		for child in visual.get_children(): child.free()
		visual.create_trimesh_collision()
