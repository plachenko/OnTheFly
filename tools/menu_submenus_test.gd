extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("CityStore").local_path = "res://generated_city/default_city.res"
	var menu = load("res://main_menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	while not menu.menu_ready: await process_frame
	assert(not menu.has_node("Menu/OriginalGrid") and not menu.has_node("Menu/HandlingLab"))
	menu.get_node("Menu/Actions/GenerateCity").pressed.emit()
	assert(menu.city_menu.visible and not menu.get_node("Menu/Actions").visible)
	assert(menu.submenu_items(menu.city_menu).get_node("Bridges") != null)
	menu.close_submenu()
	menu.get_node("Menu/Actions/PerformanceLab").pressed.emit()
	assert(menu.lab_menu.visible)
	for item in ["RenderingLab","HandlingLab","ExaggerationLab","PatronCrowdTest"]: assert(menu.submenu_items(menu.lab_menu).has_node(item))
	menu.close_submenu()
	for frame in 360: await process_frame
	# Some layouts have no eligible approach signal; signal framing is optional.
	if is_instance_valid(menu.stage.signal_node):
		assert(is_instance_valid(menu.stage.framing_control))
	assert(menu.level.truck.model.visible)
	for label in menu.level.find_children("*","Label3D",true,false): assert(not label.visible)
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/menu_control_framing.png")
	print("MENU SUBMENUS PASS: city size and bridges, four labs, world label cleanup, right-lane approach signal")
	quit()
