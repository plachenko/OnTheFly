extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var cached_menu = load("res://main_menu.tscn")
	assert(cached_menu != null)
	assert(await root.get_node("LoadingScreen").load_scene("res://main_menu.tscn"))
	var menu = current_scene
	var capture = root.get_node("ScreenshotCapture")
	capture.startup_camera_path = "res://.godot/startup-camera-test.json"
	menu.level.set_free_camera_look(true)
	menu.level.camera.global_position += Vector3(2, 3, -1)
	menu.level.camera.fov = 57.0
	menu.level.camera.h_offset = .12
	menu.level.camera.v_offset = -.07
	var expected: Dictionary = menu.level.camera_view_state()
	capture.bake_startup_camera()
	assert(not capture.startup_camera_state.is_empty())
	# Simulate a fresh session's file load and a different truck placement.
	capture.startup_camera_state.clear()
	menu.level.truck.global_position += Vector3(10, 0, 20)
	menu.level.truck.rotation.y += .5
	capture.load_startup_camera()
	assert(menu.level.camera_reference_lock)
	var relative: Transform3D = menu.level.truck_camera_frame().affine_inverse() * menu.level.camera.global_transform
	var expected_relative := preload("res://camera_timeline.gd").pose_transform(expected, true)
	assert(relative.is_equal_approx(expected_relative))
	menu.level.set_free_camera_look(false)
	menu.stage.update(menu, 0.0)
	var menu_camera: Camera3D = menu.get_node("MenuCamera")
	relative = menu.level.truck_camera_frame().affine_inverse() * menu_camera.global_transform
	assert(relative.is_equal_approx(expected_relative))
	assert(is_equal_approx(menu_camera.fov, 57.0))
	assert(is_equal_approx(menu_camera.h_offset, .12) and is_equal_approx(menu_camera.v_offset, -.07))
	assert(is_equal_approx(menu.level.pitch, .42) and is_equal_approx(menu.level.distance, 14.5))
	var invalid := expected.duplicate(true)
	invalid.truck_relative_basis_x = [0, 0, 0]
	assert(preload("res://startup_camera_store.gd").write_pose(capture.startup_camera_path, invalid) == ERR_INVALID_DATA)
	assert(not preload("res://startup_camera_store.gd").read_pose(capture.startup_camera_path).is_empty())
	print("STARTUP CAMERA PASS: baked file reload, truck-relative restoration, menu uses saved pose and lens, chase defaults retained, invalid save rejected")
	quit()
