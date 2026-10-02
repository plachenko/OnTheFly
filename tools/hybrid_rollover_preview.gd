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
	scene.aim_arrow.hide()
	var car = scene.car
	car.set_physics_process(false)
	var start: Vector3 = car.global_position
	scene.camera.global_position = start + Vector3(10, 9, 12)
	scene.camera.look_at(start + Vector3(3, 1, 0))
	var marker := MeshInstance3D.new()
	marker.mesh = SphereMesh.new()
	marker.scale = Vector3.ONE * 0.25
	scene.add_child(marker)
	marker.global_position = start + Vector3.UP * 0.25
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.6, 1)
	marker.material_override = material
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../hybrid_rollover_start.png")
	car.receive_impact(Vector3.RIGHT * 11.8, Vector3.RIGHT)
	for tick in 180:
		car._physics_process(1.0 / 60.0)
		await process_frame
		if tick in [45, 179]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../hybrid_rollover_%s.png" % ("mid" if tick == 45 else "settled"))
	print("ROLLOVER RENDER displacement=", car.global_position - start, " settled=", car.rollover_settled, " cue_age=", car.disabled_cue.age)
	quit()
