extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var menu: Node = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	while not menu.menu_ready: await process_frame
	menu.show_submenu(menu.lab_menu)
	menu.submenu_items(menu.lab_menu).get_node("HandlingLab").pressed.emit()
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/handling_lab.tscn": break
	var lab: Node = current_scene
	assert(lab.scene_file_path == "res://scenes/handling_lab.tscn")
	while root.get_node("LoadingScreen").busy: await process_frame
	await create_timer(.5).timeout
	assert(lab.automatic and lab.truck.test_controls_enabled)
	lab.apply_values(root.get_node("HandlingProfiles").gentle(),"Gentler slide")
	lab.running = false
	lab._process(0)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/handling_lab.png")
	assert(not root.get_node("ReplayRecorder").capture_requested())
	assert(Engine.max_fps == 0 and Engine.physics_ticks_per_second == 60)
	print("HANDLING_UI_PASS menu navigation, slide-first overlay, optional gentler preset, debug frame cap and replay policy unchanged")
	quit()
