extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	scene.get_node("ProceduralCity").randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.truck.set_physics_process(false)
	scene.set_process(false)
	scene.set_free_camera_look(true)
	scene.camera.global_position = scene.truck.global_position + Vector3(10, 7, 15)
	scene.camera.global_rotation = Vector3(-.3, .4, .05)
	var original: Transform3D = scene.camera.global_transform
	var pose_a: Dictionary = scene.camera_view_state()
	var relative: Transform3D = scene.truck_camera_frame().affine_inverse() * original
	scene.set_camera_reference_lock(true)
	scene.truck.global_position += Vector3(20, 0, 30)
	scene.truck.rotate_y(.5)
	scene.update_free_camera(0.0)
	assert(scene.camera.global_transform.is_equal_approx(scene.truck_camera_frame() * relative))
	scene.restore_camera_view(pose_a, true)
	assert(scene.camera.global_transform.is_equal_approx(scene.truck_camera_frame() * relative))
	var pose_b := pose_a.duplicate(true)
	pose_b.position[0] += 20.0
	pose_b.truck_relative_position[0] += 20.0
	pose_b.fov = 50.0
	var clip := {"format": "onthefly.camera_timeline", "version": 1, "space": "truck_relative", "sample_rate": 30, "duration": 4.0, "keys": [{"time": 0.0, "pose": pose_a}, {"time": 4.0, "pose": pose_b}]}
	var script = preload("res://camera_timeline.gd")
	assert(script.valid_document(clip))
	var midpoint: Dictionary = script.sample_pose(clip, 1.0)
	assert(is_equal_approx(float(midpoint.truck_relative_position[0]), float(pose_a.truck_relative_position[0]) + 5.0), "Timestamp interpolation must respect quarter duration")
	assert(is_equal_approx(float(midpoint.fov), lerpf(float(pose_a.fov), 50.0, .25)))
	var invalid := clip.duplicate(true)
	invalid.keys[1].time = 0.0
	assert(not script.valid_document(invalid))
	invalid = clip.duplicate(true)
	invalid.keys[0].pose.truck_relative_basis_x = [0, 0, 0]
	assert(not script.valid_document(invalid))
	var capture = root.get_node("ScreenshotCapture")
	var timeline = capture.camera_timeline
	timeline.document = clip
	var path := "res://.godot/camera-timeline-test.json"
	assert(timeline.save_json(path) == OK)
	assert(timeline.load_json(path))
	assert(timeline.document.keys.size() == 2 and timeline.document.duration == 4.0)
	timeline.scrub(1.0)
	assert(scene.camera.global_transform.is_equal_approx(scene.truck_camera_frame() * script.pose_transform(midpoint, true)))
	# Exercise second-press/hold/release without rendering a first screenshot.
	capture.last_bumper_press = 1000
	capture.handle_left_bumper(true, 1200)
	assert(timeline.recording and not paused)
	timeline.elapsed = .2
	capture.handle_left_bumper(false, 1400)
	assert(not timeline.recording and paused and timeline.paused_for_scrub)
	timeline.scrub(.1)
	timeline.play()
	assert(scene.camera_timeline_playing)
	timeline.stop_playback()
	assert(not scene.camera_timeline_playing)
	timeline.resume_game()
	assert(not paused)
	assert(scene.camera_deadzone(.1) == 0.0 and is_equal_approx(scene.camera_deadzone(1.0), 1.0))
	# Menu/preview cameras are captured as rendered and adopted without a jump.
	scene.set_camera_reference_lock(false)
	scene.set_free_camera_look(false)
	var preview_camera := Camera3D.new()
	scene.add_child(preview_camera)
	preview_camera.global_transform = Transform3D(Basis.from_euler(Vector3(-.2, .7, 0)), Vector3(8, 12, 30))
	preview_camera.fov = 45.0
	preview_camera.make_current()
	var preview_pose: Dictionary = scene.camera_view_state(preview_camera)
	assert(preview_pose.position == scene.vector_values(preview_camera.global_position))
	scene.set_free_camera_look(true)
	assert(scene.camera.global_transform.is_equal_approx(preview_camera.global_transform) and scene.camera.fov == 45.0)
	scene.set_free_camera_look(false)
	assert(preview_camera.is_current())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CAMERA TIMELINE PASS: truck-relative lock, JSON round trip, timestamp interpolation, scrub, playback, double-LB recording and release pause/resume, invalid-data rejection")
	quit()
