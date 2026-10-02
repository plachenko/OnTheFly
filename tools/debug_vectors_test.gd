extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var debug = root.get_node("DebugMenu")
	var capture = root.get_node("ScreenshotCapture")
	var car = get_nodes_in_group("traffic_motion")[0]
	car.set_physics_process(false)
	car.current_driving_speed = 4.0
	car.progress += 0.4
	car.update_car_pose(0.1)
	assert(car.motion_vector.length() > 0.1 and car.motion_vector.length() < 50.0)
	debug.vectors_enabled = true
	debug.update_vectors()
	assert(debug.arrows.mesh.get_surface_count() == 1)
	debug.hide_ui.set_pressed(true)
	assert(capture.screenshot_mode and not scene.get_node("HUD").visible)
	debug.panel.show()
	assert(debug.panel.visible)
	debug.hide_ui.set_pressed(false)
	assert(not capture.screenshot_mode and scene.get_node("HUD").visible)
	debug.vectors_enabled = false
	debug._process(0.1)
	assert(not debug.arrows.visible)
	print("DEBUG VECTORS PASS: route motion arrows, toggles, UI hide/restore, debug menu remains available")
	quit()
