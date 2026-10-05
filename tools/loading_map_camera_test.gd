extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var loader := root.get_node("LoadingScreen")
	var plan := preload("res://city_topology.gd").new()
	var parks: Array[Vector2i] = []
	plan.generate(12054, parks)
	loader.busy = true
	loader.begin_cover()
	await loader.transition.finished
	for step in 7:
		await loader.city_stage(plan, step, "Preview stage %d" % step)
		assert(loader.map_preview.phase == maxi(1,step))
		assert(loader.map_preview.plan == plan)
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://.godot/loading_map_%d.png" % step)
	await loader.finish_cover()
	loader.busy = false
	loader.load_scene("res://procedural_city.tscn")
	while current_scene == null or not current_scene.has_method("begin_loading_intro") or not current_scene.loading_intro_active:
		await process_frame
	var scene := current_scene
	assert(not scene.truck.is_physics_processing())
	var expected_spawn := Vector2(scene.truck.global_position.x,scene.truck.global_position.z)
	scene.loading_intro_finished.connect(func():
		assert(scene.camera.global_transform.is_equal_approx(scene.loading_intro_end))
		assert(is_equal_approx(scene.camera.fov, scene.loading_intro_end_fov)))
	var previous: Vector3 = scene.camera.global_position
	var maximum_step := 0.0
	while scene.loading_intro_active:
		await process_frame
		maximum_step = maxf(maximum_step, previous.distance_to(scene.camera.global_position))
		previous = scene.camera.global_position
	assert(maximum_step < 1.0, "Intro must avoid a final chase-camera snap")
	assert(scene.truck.is_physics_processing())
	assert(loader.map_preview.spawn.is_equal_approx(expected_spawn))
	while loader.busy: await process_frame
	assert(not loader.panel.visible)
	print("LOADING MAP CAMERA PASS: actual stage geometry, spawn zoom, smooth overhead-to-chase; max frame step=", maximum_step)
	quit()
