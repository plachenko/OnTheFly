extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var manipulation = load("res://addons/mcon_viewport/object_manipulation.gd").new()
	var node := Node3D.new()
	var child := Node3D.new()
	root.add_child(node)
	node.add_child(child)
	assert(manipulation.begin([node, child]))
	assert(manipulation.originals.size() == 1)
	manipulation.step(Vector2(1, 0), Vector2.ZERO, 0, Basis.IDENTITY, 2.0, 1.0)
	assert(node.position.is_equal_approx(Vector3(2, 0, 0)))
	manipulation.finish(null, true)
	assert(node.transform.is_equal_approx(Transform3D.IDENTITY))
	manipulation.begin([node])
	manipulation.mode = 1
	manipulation.step(Vector2(1, 0), Vector2.ZERO, 0, Basis.IDENTITY, 2, 1)
	assert(not node.basis.is_equal_approx(Basis.IDENTITY))
	manipulation.finish(null, true)
	manipulation.begin([node])
	manipulation.mode = 2
	manipulation.step(Vector2(0, -1), Vector2.ZERO, 0, Basis.IDENTITY, 2, 1)
	assert(node.scale.x > 1)
	var history := UndoRedo.new()
	manipulation.finish(history)
	assert(history.has_undo())
	history.undo()
	assert(node.transform.is_equal_approx(Transform3D.IDENTITY))
	history.redo()
	assert(node.scale.x > 1)
	history.clear_history()
	history.free()
	node.free()
	print("OBJECT MANIPULATION PASS: move, rotate, scale, cancel, undo/redo, nested selection")
	quit()
