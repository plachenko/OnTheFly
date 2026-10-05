extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.truck.set_physics_process(false)
	scene.cop.set_physics_process(false)
	scene.truck.global_position = Vector3(14, 0.15, 22)
	scene.start_pursuit()
	root.get_node("PoliceDispatch").set_physics_process(false)
	for frame in 50:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../police_escape_preview.png")
	quit()
