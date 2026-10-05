extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	scene.truck.deployed = true
	scene.truck.opening = 1.0
	scene.truck.skeleton.set_bone_pose_rotation(scene.truck.awning, Quaternion(Vector3.RIGHT, PI/2))
	scene.truck.skeleton.set_bone_pose_rotation(scene.truck.counter, Quaternion(Vector3.RIGHT, -PI/2))
	var pad = load("res://parking_pad.gd").new()
	scene.camera.global_position = scene.truck.global_transform * pad.kitchen_camera_offset
	scene.camera.look_at(scene.truck.global_transform * pad.kitchen_focus_offset)
	scene.camera.fov = 60
	var cutaway = scene.truck.get_node("KitchenCutaway")
	cutaway.update_view(1.0, scene.camera)
	assert(cutaway.materials.size() > 8)
	for m in cutaway.materials: assert(m.get_shader_parameter("strength") == 1.0)
	for frame in 8: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/kitchen_cutaway_preview.png")
	cutaway.update_view(0.0, scene.camera)
	for m in cutaway.materials: assert(m.get_shader_parameter("strength") == 0.0)
	pad.free()
	scene.queue_free()
	await process_frame
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.truck.set_physics_process(false)
	game.truck.parking_pad = game.get_node("ParkingPads/ParkingPad_01")
	game.truck.deployed = true
	game.truck.speed = 0.0
	for frame in 120: game.update_follow_camera(1.0/60.0)
	assert(game.kitchen_blend == 1.0)
	assert(is_equal_approx(game.camera.fov, 60.0))
	assert(game.truck.get_node("KitchenCutaway").strength == 1.0)
	game.truck.deployed = false
	for frame in 120: game.update_follow_camera(1.0/60.0)
	assert(game.kitchen_blend == 0.0 and game.truck.get_node("KitchenCutaway").strength == 0.0)
	game.truck.deployed = true
	for frame in 120: game.update_follow_camera(1.0/60.0)
	game.set_free_camera_look(true)
	assert(game.truck.get_node("KitchenCutaway").strength == 0.0)
	print("KITCHEN_CUTAWAY_PASS: elevated side view, shell materials, opening and restoration")
	quit()
