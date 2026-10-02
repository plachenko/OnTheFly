extends SceneTree

func _initialize() -> void:
	var navigation = load("res://addons/mcon_viewport/node_navigation.gd")
	var scene := Node.new()
	var first := Node3D.new()
	var second := Node.new()
	var leaf := Node.new()
	scene.add_child(first)
	first.owner = scene
	scene.add_child(second)
	second.owner = scene
	first.add_child(leaf)
	leaf.owner = scene
	var helper := Node.new()
	scene.add_child(helper)
	assert(navigation.next_node(scene, null, Vector2i.DOWN) == scene)
	assert(navigation.next_node(scene, scene, Vector2i.DOWN) == first)
	assert(navigation.next_node(scene, first, Vector2i.RIGHT) == second)
	assert(navigation.next_node(scene, second, Vector2i.RIGHT) == first)
	assert(navigation.next_node(scene, first, Vector2i.LEFT) == second)
	assert(navigation.next_node(scene, first, Vector2i.DOWN) == leaf)
	assert(navigation.next_node(scene, leaf, Vector2i.UP) == first)
	assert(navigation.next_node(scene, leaf, Vector2i.DOWN) == leaf)
	assert(navigation.children_of(scene, scene).size() == 2)
	scene.scene_file_path = "res://main.tscn"
	assert(navigation.source_scene(second, scene).is_empty())
	first.scene_file_path = "res://scenes/vehicle_lights.tscn"
	assert(navigation.source_scene(first, scene) == first.scene_file_path)
	assert(navigation.source_scene(leaf, scene) == first.scene_file_path)
	assert(navigation.source_scene(scene, scene) == scene.scene_file_path)
	scene.free()
	print("EDITOR NODE NAVIGATION PASS: root, parent/child, sibling wrap, generic nodes, helper exclusion")
	quit()
