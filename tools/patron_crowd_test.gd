extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/patron_crowd_test.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	assert(scene.get_node("Patrons").get_child_count() == 36)
	for frame in 60: await physics_frame
	var initial = scene.get_node("Patrons").get_child(0).home_position
	scene.reset_crowd()
	assert(scene.get_node("Patrons").get_child(0).home_position == initial)
	var patron = scene.get_node("Patrons").get_child(0)
	patron.global_position = scene.truck.global_position + Vector3(.5,0,-7)
	scene.truck.velocity = Vector3(0,0,-10)
	patron.check_dodge()
	assert(patron.dodge_count > 0)
	scene.truck.velocity = Vector3.ZERO
	patron.set_physics_process(false)
	patron.global_position = scene.truck.global_position + Vector3(0,0,-8)
	await physics_frame
	var contact := KinematicCollision3D.new()
	assert(scene.truck.test_move(scene.truck.global_transform,Vector3(0,0,-10),contact))
	assert(contact.get_collider().is_in_group("patrons"))
	patron.set_physics_process(true)
	scene.park_and_open()
	for frame in 180: await physics_frame
	assert(scene.serving_pad.patrons.size() > 0)
	assert(scene.serving_pad.patrons.size() <= 12)
	scene.set_attraction(false)
	assert(scene.serving_pad.patrons.is_empty())
	scene.crowd_size = 120; scene.reset_crowd()
	assert(scene.get_node("Patrons").get_child_count() == 120)
	for frame in 30: await physics_frame
	assert(scene.get_node("Patrons").get_child_count() == 120)
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/patron_crowd_test.png")
	print("PATRON CROWD PASS: repeatable reset, attraction and queue capacity, cancellation, 120 real patrons")
	quit()
