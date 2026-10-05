extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var initial_fps := Engine.max_fps
	var scene = load("res://scenes/profiler_route.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_physics_process(false)
	assert(Engine.max_fps == initial_fps)
	assert(Engine.physics_ticks_per_second == 60)
	assert(not root.get_node("ReplayRecorder").is_processing())
	assert(not scene.truck.is_physics_processing() and not scene.truck.manual_controls_enabled)
	assert(scene.get_tree().get_nodes_in_group("patrons").is_empty())
	assert(scene.get_tree().get_nodes_in_group("traffic_motion").is_empty())
	assert(scene.sample(0).position == scene.A)
	assert(scene.sample(720).position == scene.B and scene.sample(720).deployed)
	assert(scene.sample(1080).position == scene.B and not scene.sample(1080).deployed)
	assert(scene.sample(1800).position == scene.C)
	assert(scene.sample(2160).reverse and scene.sample(2520).position == scene.D)
	assert(scene.sample(3599).position == scene.A)
	var checksum := 0.0
	for t in scene.LAP_TICKS:
		var first: Dictionary = scene.sample(t)
		assert(first == scene.sample(t))
		checksum += first.position.x * 3.0 + first.position.z * 7.0
	Input.action_press("accelerate")
	Input.action_press("serve")
	scene.tick = scene.WARMUP_TICKS + 200
	scene._physics_process(0.001)
	assert(scene.truck.position == scene.sample(200).position)
	assert(not scene.truck.deployed)
	Input.action_release("accelerate")
	Input.action_release("serve")
	print("PROFILER ROUTE PASS: fixed destinations/actions, input ignored, 60 Hz, debug cap unchanged, no replay/traffic/patrons; path checksum=", checksum)
	quit()
