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
	var truck = scene.truck
	truck.exaggeration.profile.clear()
	truck.exaggeration_profile_path = "res://.godot/no-idle-profile.json"
	assert(truck.reload_exaggeration_profile() == ERR_FILE_NOT_FOUND)
	assert(truck.exaggeration.profile.clips.idle == preload("res://truck_idle_motion.gd").idle_profile().clips.idle)
	truck.speed = 0.0
	truck.longitudinal_accel = 0.0
	truck.lateral_accel = 0.0
	var strongest := 0.0
	for frame in 120:
		var pose: Dictionary = truck.exaggeration.step(truck, 1.0/60.0)
		strongest = maxf(strongest, absf(pose.heave))
	assert(strongest > .005)
	truck.speed = 8.0
	for frame in 60: truck.exaggeration.step(truck, 1.0/60.0)
	assert(absf(truck.exaggeration.current_pose.heave) < .0001)
	truck.speed = 0.0
	truck.health = 0.0
	for frame in 60: truck.exaggeration.step(truck, 1.0/60.0)
	assert(absf(truck.exaggeration.current_pose.heave) < .0001)
	print("GAME IDLE PASS: shared menu jitter active at rest, fades while driving, stops with failed engine")
	quit()
