extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var packed := load("res://main_menu.tscn") as PackedScene
	var menu := packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.start_game()
	await create_timer(2.1).timeout
	var level := current_scene
	assert(level.has_method("begin_loading_intro"))
	assert(level.loading_intro_active)
	assert(not level.truck.is_physics_processing())
	assert(not level.get_node("HUD").visible)
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/loading_intro_side.png")
	while level.loading_intro_active:
		await process_frame
	assert(level.camera_started)
	assert(level.truck.is_physics_processing())
	assert(level.get_node("HUD").visible)
	assert(not root.get_node("LoadingScreen").panel.visible)
	print("LOADING INTRO PASS: new game, service-side reveal, three-second push-in, chase snap and controls restored")
	quit()
