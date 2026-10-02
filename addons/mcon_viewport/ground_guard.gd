@tool
extends RefCounted

const CLEARANCE := 0.8
const RANGE := 10000.0

static func surface_hit(candidates: Array, origin: Vector3, direction: Vector3) -> Dictionary:
	var nearest := RANGE
	var result := {}
	for node in candidates:
		if not is_instance_valid(node) or not node is MeshInstance3D or node.mesh == null:
			continue
		var transform: Transform3D = node.global_transform
		if is_zero_approx(transform.basis.determinant()):
			continue
		var inverse := transform.affine_inverse()
		var triangles: TriangleMesh = node.mesh.generate_triangle_mesh()
		if triangles == null:
			continue
		var hit := triangles.intersect_ray(inverse * origin, inverse.basis * direction)
		if hit.is_empty():
			continue
		var normal: Vector3 = (inverse.basis.transposed() * hit.normal).normalized()
		if absf(normal.y) < 0.25:
			continue
		var position: Vector3 = transform * hit.position
		var distance := origin.distance_to(position)
		if distance < nearest:
			nearest = distance
			result = {"position": position}
	return result

static func protect(pose: Transform3D, reference_height: float, candidates: Array) -> Transform3D:
	var origin := pose.origin
	origin.y = maxf(reference_height, pose.origin.y) + CLEARANCE
	var hit := surface_hit(candidates, origin, Vector3.DOWN)
	if hit.is_empty():
		# Recover an already underground camera as well as preventing descent.
		hit = surface_hit(candidates, origin, Vector3.UP)
	if not hit.is_empty():
		pose.origin.y = maxf(pose.origin.y, float(hit.position.y) + CLEARANCE)
	return pose
