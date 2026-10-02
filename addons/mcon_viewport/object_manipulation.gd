@tool
extends RefCounted

var originals: Dictionary = {}
var mode := 0 # Move, rotate, scale.

func begin(nodes: Array) -> bool:
	originals.clear()
	for node in nodes:
		if not node is Node3D:
			continue
		var ancestor: Node = node.get_parent()
		var nested := false
		while ancestor:
			if nodes.has(ancestor) and ancestor is Node3D:
				nested = true
				break
			ancestor = ancestor.get_parent()
		if not nested:
			originals[node] = node.transform
	return not originals.is_empty()

func step(movement: Vector2, look: Vector2, vertical: float, camera_basis: Basis, speed: float, delta: float) -> void:
	var right := Vector3(camera_basis.x.x, 0, camera_basis.x.z).normalized()
	var back := Vector3(camera_basis.z.x, 0, camera_basis.z.z).normalized()
	for node in originals:
		if not is_instance_valid(node):
			continue
		if mode == 0:
			node.global_position += (right * movement.x + back * movement.y + Vector3.UP * vertical).limit_length() * speed * delta
		elif mode == 1:
			node.rotate_y(-movement.x * delta)
			node.rotate_object_local(Vector3.RIGHT, -movement.y * delta)
			node.rotate_object_local(Vector3.BACK, look.x * delta)
		else:
			node.scale *= exp(-movement.y * delta)

func finish(history: Object, cancel: bool = false) -> void:
	var changed: Array = []
	for node in originals:
		if is_instance_valid(node):
			if cancel:
				node.transform = originals[node]
			elif not node.transform.is_equal_approx(originals[node]):
				changed.append(node)
	if not changed.is_empty():
		history.create_action("Controller transform selection")
		for node in changed:
			history.add_do_property(node, "transform", node.transform)
			history.add_undo_property(node, "transform", originals[node])
		history.commit_action(false)
	originals.clear()
