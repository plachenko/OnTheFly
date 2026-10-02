@tool
extends RefCounted

static func source_scene(node: Node, edited_root: Node) -> String:
	var current := node
	while is_instance_valid(current):
		if current == edited_root and current != node:
			return ""
		if not current.scene_file_path.is_empty():
			return current.scene_file_path
		if current == edited_root:
			break
		current = current.get_parent()
	return ""

static func children_of(node: Node, root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		# Match editable scene-tree nodes, excluding plugin/runtime helpers and
		# internal nodes of imported scenes which are not editable here.
		if child.owner == root or (child.owner != null and child.owner != root and root.is_ancestor_of(child.owner) and root.is_editable_instance(child.owner)):
			result.append(child)
	return result

static func next_node(root: Node, current: Node, direction: Vector2i) -> Node:
	if root == null:
		return null
	if not is_instance_valid(current) or (current != root and not root.is_ancestor_of(current)):
		return root
	if direction.y < 0:
		return current.get_parent() if current != root else root
	if direction.y > 0:
		var children := children_of(current, root)
		return children[0] if not children.is_empty() else current
	if current == root:
		return root
	var siblings := children_of(current.get_parent(), root)
	if siblings.is_empty():
		return current
	var index := siblings.find(current)
	return siblings[posmod(index + direction.x, siblings.size())]
