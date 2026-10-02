extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var loader := root.get_node("LoadingScreen")
	assert(not loader.busy and not loader.panel.visible)
	var text_position: Vector2 = loader.status.position
	loader.begin_cover()
	await loader.transition.finished
	assert(absf(loader.backdrop.position.x) < 0.01)
	assert(loader.status.position.is_equal_approx(text_position))
	await loader.finish_cover()
	assert(not loader.panel.visible and loader.backdrop.scale.x > 40.0)
	assert(loader.status.position.is_equal_approx(text_position))
	assert(await loader.load_scene("res://main_menu.tscn"))
	assert(current_scene.scene_file_path == "res://main_menu.tscn")
	assert(not loader.busy and not loader.panel.visible)
	assert(await loader.load_scene("res://procedural_city.tscn"))
	assert(current_scene.is_loading_ready())
	assert(not current_scene.get_node("ProceduralCity").generating)
	assert(current_scene.process_mode != Node.PROCESS_MODE_DISABLED)
	assert(not loader.busy and not loader.panel.visible)
	assert(current_scene.truck.spawn_transform.origin.is_finite())
	assert(not current_scene.loading_intro_active)
	assert(current_scene.truck.is_physics_processing())
	assert(current_scene.get_node("HUD").visible)
	print("LOADING SCREEN PASS: startup menu, threaded city load, staged generation, ready/spawn, overlay cleanup")
	quit()
