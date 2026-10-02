extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/hybrid_car_demo.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_process(false)
	scene.label.hide()
	var car = scene.car
	car.set_physics_process(false)
	car.receive_impact(Vector3.RIGHT * 11.8, Vector3.RIGHT)
	for tick in 180:
		car._physics_process(1.0 / 60.0)
	scene.camera.global_position = car.global_position + Vector3(6, 4, 7)
	scene.camera.look_at(car.global_position + Vector3.UP)
	scene.aim_arrow.hide()
	car.disabled_cue.set_age(1)
	for frame in 45:
		await process_frame
	await create_timer(1.6).timeout # Give the low-rate plume real time to emerge.
	print("SMOKE PREVIEW ", car.disabled_cue.smoke.global_position, " emitting=", car.disabled_cue.smoke.emitting, " visible=", car.disabled_cue.smoke.is_visible_in_tree(), " paused=", paused)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../hybrid_disabled_hold.png")
	car.disabled_cue.set_age(4)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../hybrid_disabled_fade.png")
	print("DISABLED PREVIEW SAVED: hold and half-fade")
	quit()
