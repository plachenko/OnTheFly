extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var truck = scene.truck
	truck.global_position = Vector3(0,.2,25)
	truck.drift_owned = false
	for frame in 30: await physics_frame
	var heading: float = truck.rotation.y
	Input.action_press("accelerate")
	Input.action_press("brake")
	Input.action_press("left")
	var rotation_travel := 0.0
	var pivot_start: Vector3 = truck.global_transform * truck.front_axle_pivot
	var pivot_travel := 0.0
	for frame in 150:
		await physics_frame
		rotation_travel += absf(angle_difference(heading, truck.rotation.y))
		heading = truck.rotation.y
		pivot_travel = maxf(pivot_travel, pivot_start.distance_to(truck.global_transform * truck.front_axle_pivot))
	assert(truck.stationary_drifting, "Donuts must work without purchasing drift")
	assert(rotation_travel > 2.0)
	var effects = truck.get_node("TireEffects")
	assert(effects.marks_written > 20 and effects.friction_energy > .2)
	assert(effects.smoke[2].emitting and effects.smoke[3].emitting)
	for count in effects.wheel_marks: assert(count > 0, "Inside and outside wheels must leave donut marks")
	assert(absf(truck.lateral_accel) > 1.0 and absf(truck.body_yaw_sway) > .005)
	assert(pivot_travel > .1 and pivot_travel < 5.0, "Donut pivot should drift slightly rather than remain pinned")
	assert(effects.tracks.multimesh.instance_count == effects.LIMIT)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/donuts_preview.png")
	Input.action_release("brake")
	Input.action_release("left")
	for frame in 30: await physics_frame
	assert(not truck.stationary_drifting and truck.speed > 0.0)
	Input.action_release("accelerate")
	truck.highway_transit.active = true
	effects._physics_process(1.0 / 60.0)
	assert(effects.friction_energy == 0.0 and not effects.smoke[2].emitting)
	truck.highway_transit.active = false
	print("DONUTS_PASS: no upgrade, rotation, slip marks/smoke, bounded trail buffer, normal driving restored, no highway smoke")
	quit()
