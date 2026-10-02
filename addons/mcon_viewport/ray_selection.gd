@tool
extends RefCounted

static func update_selection(selection: EditorSelection, target: Node, additive: bool) -> bool:
	if additive and selection.get_selected_nodes().has(target):
		selection.remove_node(target)
		return false
	if not additive:
		selection.clear()
	selection.add_node(target)
	return true

static func closest_mesh(candidates: Array, origin: Vector3, direction: Vector3, max_distance: float) -> MeshInstance3D:
	var selected: MeshInstance3D
	var nearest := max_distance
	for node in candidates:
		if not node is MeshInstance3D or node.mesh == null:
			continue
		var transform: Transform3D = node.global_transform
		if is_zero_approx(transform.basis.determinant()):
			continue
		var inverse := transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction := inverse.basis * direction
		if not node.mesh.get_aabb().intersects_ray(local_origin, local_direction):
			continue
		var faces: PackedVector3Array = node.mesh.get_faces()
		for index in range(0, faces.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(local_origin, local_direction, faces[index], faces[index + 1], faces[index + 2])
			if hit != null:
				var distance := origin.distance_to(transform * hit)
				if distance < nearest:
					nearest = distance
					selected = node
	return selected
