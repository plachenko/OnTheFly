extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	scene.get_node("ProceduralCity").randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	# Unobstructed placement verifies the follow camera independently of scenery.
	for heading in [0.0, -PI / 2.0, 1.2]:
		scene.truck.global_position = Vector3(0, 200, 0)
		scene.truck.rotation = Vector3(0, heading, 0)
		scene.truck.speed = 0.0
		scene.camera_follow_focus = scene.truck.global_position + Vector3.UP * 1.8
		scene.camera_started = false
		scene.kitchen_blend = 0.0
		scene.camera_roll = 0.0
		for speed_blend in [0.0, 0.5, 1.0]:
			scene.speed_camera_blend = speed_blend
			scene.camera_started = false
			scene.update_follow_camera(0.0)
			var offset: Vector3 = scene.truck.global_basis.inverse() * (scene.camera.global_position - scene.camera_follow_focus)
			assert(absf(offset.x) < .001 and offset.y > 0 and offset.z > 0)
			assert(absf(offset.length() - (12.5 + 2.0 * speed_blend)) < .001)
			assert(absf(scene.camera.fov - (60.0 + 12.0 * speed_blend)) < .001)
			assert(is_zero_approx(scene.camera.v_offset))
		assert(scene.truck.manual_controls_enabled)
	print("CHASE CAMERA PASS: elevated rear view at three headings, 12.5 to 14.5 distance across speeds, FOV response and driving controls retained")
	quit()
