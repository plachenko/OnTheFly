extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var guard = load("res://addons/mcon_viewport/ground_guard.gd")
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	ground.mesh = plane
	root.add_child(ground)
	var pose := Transform3D(Basis.from_euler(Vector3(-0.3, 0.5, 0.0)), Vector3(0, -2, 0))
	var protected: Transform3D = guard.protect(pose, 5.0, [ground])
	assert(is_equal_approx(protected.origin.y, guard.CLEARANCE))
	assert(protected.basis.is_equal_approx(pose.basis))
	protected = guard.protect(pose, -2.0, [ground])
	assert(is_equal_approx(protected.origin.y, guard.CLEARANCE))
	pose.origin.y = 5.0
	assert(guard.protect(pose, 5.0, [ground]).is_equal_approx(pose))
	ground.position.y = 12.0
	ground.rotation.z = 0.2
	pose.origin = Vector3(3, 8, 0)
	protected = guard.protect(pose, 20.0, [ground])
	assert(protected.origin.y > 12.0)
	assert(protected.origin.x == pose.origin.x and protected.origin.z == pose.origin.z)
	assert(guard.protect(pose, 20.0, []).is_equal_approx(pose))
	ground.free()
	print("EDITOR GROUND GUARD PASS: descent clamp, underground recovery, slope, unchanged rotation/height above ground, empty scene")
	quit()
