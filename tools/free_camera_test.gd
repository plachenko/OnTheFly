extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	scene.get_node("ProceduralCity").randomize_each_load = false
	root.add_child(scene)
	await process_frame
	scene.truck.set_physics_process(false)
	scene.set_free_camera_look(true)
	assert(not scene.truck.manual_controls_enabled)
	assert(scene.camera_pose_label.visible)
	scene.camera.global_position = scene.truck.global_position + Vector3(12, 8, -17)
	scene.camera.global_rotation = Vector3(-0.3, 0.7, 0.05)
	scene.camera.fov = 64.0
	var saved_transform: Transform3D = scene.camera.global_transform
	var saved: Dictionary = JSON.parse_string(JSON.stringify(scene.camera_view_state()))
	var orbit_yaw: float = deg_to_rad(saved.orbit_yaw_degrees)
	var orbit_pitch: float = deg_to_rad(saved.orbit_pitch_degrees)
	var focus := Vector3(saved.orbit_focus[0], saved.orbit_focus[1], saved.orbit_focus[2])
	var orbit_offset := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * float(saved.orbit_distance)
	assert((focus + scene.truck.global_basis.orthonormalized() * orbit_offset).distance_to(saved_transform.origin) < 0.001)
	scene.camera.global_position = Vector3.ZERO
	scene.restore_camera_view(saved)
	assert(scene.camera.global_transform.is_equal_approx(saved_transform))
	assert(is_equal_approx(scene.camera.fov, 64.0))
	scene.update_free_camera(0.0)
	assert(scene.camera.global_transform.is_equal_approx(saved_transform))
	assert("Truck orbit" in scene.camera_pose_label.text)
	var original: Vector3 = scene.camera.global_position
	scene.truck.global_position += Vector3(100, 20, 100)
	scene.update_free_camera(0.1)
	assert(scene.camera.global_position.is_equal_approx(original))
	scene.move_free_camera(Vector3(0, -1, 0), 100.0)
	assert(scene.camera.global_position.y < -1000.0)
	scene.update_free_camera(0.1)
	assert(scene.camera.global_position.y < -1000.0)
	assert(scene.camera_clip_amount == 0.0)
	scene.focus_free_camera_on_truck()
	var target: Vector3 = scene.truck.global_position + Vector3(0, 1.8, 0)
	assert((-scene.camera.global_basis.z).dot((target - scene.camera.global_position).normalized()) > 0.999)
	var before: Vector3 = scene.camera.global_position
	scene.move_free_camera(Vector3(0, 0, 1), 1.0)
	assert(absf(before.distance_to(scene.camera.global_position) - scene.free_camera_speed) < 0.001)
	scene.set_free_camera_look(false)
	assert(scene.truck.manual_controls_enabled)
	assert(not scene.camera_pose_label.visible)
	scene.update_follow_camera(0.016)
	assert(scene.camera.global_position.distance_to(target) < 30.0)
	print("FREE CAMERA PASS: detached flight, orbit readout, JSON pose restoration, focus, movement, follow restoration")
	quit()
