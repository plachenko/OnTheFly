extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var cached_menu = load("res://main_menu.tscn")
	assert(cached_menu != null)
	assert(await root.get_node("LoadingScreen").load_scene("res://main_menu.tscn"))
	var menu = current_scene
	var pass_node = menu.stage.comic_silhouette
	assert(is_instance_valid(pass_node))
	var capture = root.get_node("ScreenshotCapture")
	assert(not capture.screenshot_button_layer.visible)
	assert(menu.get_node("Menu").visible)
	menu.level.set_free_camera_look(true)
	assert(capture.screenshot_button_layer.visible)
	assert(not menu.get_node("Menu").visible)
	assert(not menu.level.get_node("HUD").visible)
	pass_node.sync()
	assert(pass_node.camera_mode and not pass_node.screen.visible)
	assert(pass_node.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	for index in pass_node.copies.size():
		assert(pass_node.copies[index].layers == pass_node.original_layers[index])
	var truck_position: Vector3 = menu.level.truck.global_position
	menu.level.move_free_camera(Vector3(1, 0, 0), 0.5)
	pass_node.sync()
	assert(menu.level.truck.global_position.is_equal_approx(truck_position))
	assert(not pass_node.screen.visible)
	menu.level.set_free_camera_look(false)
	assert(not capture.screenshot_button_layer.visible)
	assert(menu.get_node("Menu").visible)
	pass_node.sync()
	assert(not pass_node.camera_mode and pass_node.screen.visible)
	assert(pass_node.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	for mesh in pass_node.copies: assert(mesh.layers == pass_node.DRAW_LAYER)
	menu.stage.elapsed = 30.0
	if DisplayServer.get_name() == "headless": pass_node.measurements = 3
	menu.stage.update(menu, 0.0)
	var menu_camera: Camera3D = menu.get_node("MenuCamera")
	var relative_basis: Basis = menu.level.truck.global_basis.inverse() * menu_camera.global_basis
	assert(relative_basis.z.distance_to(Vector3(.3523530364, -.2778289318, .8936769366)) < .001)
	assert(is_equal_approx(menu_camera.fov, 60.0))
	assert(is_equal_approx(menu_camera.v_offset, .15386544168))
	var relative: Transform3D = menu.level.truck.global_transform.affine_inverse() * menu_camera.global_transform
	assert(relative.origin.distance_to(Vector3(2.47634124756, -.41185760498, 5.87109565735)) < .001)
	var held: Transform3D = menu_camera.global_transform
	for frame in 60: menu.stage.update(menu, .05)
	assert(menu_camera.global_transform.is_equal_approx(held), "Menu camera must not bounce or collide with terrain")
	assert(menu.stage.ground_fill.visible)
	assert(menu.stage.ground_fill.material_override.get_shader_parameter("height_threshold") < menu_camera.global_position.y)
	assert(is_equal_approx(menu.level.pitch, .42) and is_equal_approx(menu.level.distance, 14.5))
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/menu-reference-chase-fix.png")
	print("MENU CAMERA OVERLAY PASS: free camera hides stationary composite, restores live truck meshes, and restores menu pass on exit")
	quit()
