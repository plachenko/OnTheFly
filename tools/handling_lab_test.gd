extends SceneTree

func _initialize() -> void: run.call_deferred()

func simulate(lab: Node, values: Dictionary, kind: int) -> Dictionary:
	var store: Node = root.get_node("HandlingProfiles")
	store.apply(lab.truck,values)
	lab.maneuver = kind
	lab.automatic = true
	lab.restart_run()
	var trace := []
	var slide_ticks := 0
	var donut_ticks := 0
	var peak_yaw := 0.0
	for i in 479:
		await physics_frame
		lab.step(1.0/60)
		if lab.truck.power_slide_active: slide_ticks += 1
		if lab.truck.stationary_drifting: donut_ticks += 1
		peak_yaw = maxf(peak_yaw,absf(lab.yaw_rate))
		if i%30 == 0: trace.append([lab.truck.position.x,lab.truck.position.z,lab.truck.rotation.y,lab.truck.speed])
	return {"trace":trace,"slide_ticks":slide_ticks,"donut_ticks":donut_ticks,"peak_slip":lab.peak_slip,"peak_yaw":peak_yaw}

func run() -> void:
	var store: Node = root.get_node("HandlingProfiles")
	var path := "res://.godot/handling_test_profiles.json"
	var original: Dictionary = store.original()
	assert(store.validated({"forward_speed":999,"acceleration":-9,"health":1,"braking_force":"bad"}) == {"forward_speed":40.0,"acceleration":2.0})
	assert(store.save_profile("Test calm",store.gentle(),path) == OK)
	assert(store.set_default("test_food_truck","Test calm",path) == OK)
	store.load_store(path)
	assert(store.defaults.test_food_truck == "Test calm")
	var lab: Node = load("res://scenes/handling_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_physics_process(false)
	var other: Node = load("res://scenes/truck.tscn").instantiate()
	other.handling_id = "test_food_truck"
	other.set_physics_process(false)
	lab.add_child(other)
	assert(is_equal_approx(other.power_slide_turn_multiplier,2.2))
	other.free()
	var first := await simulate(lab,original,1)
	var second := await simulate(lab,original,1)
	for i in first.trace.size():
		for field in 4: assert(absf(first.trace[i][field]-second.trace[i][field]) < .001,"Repeated fixed inputs must yield matching physics traces")
	assert(first.slide_ticks > 0)
	var gentle := await simulate(lab,store.gentle(),1)
	assert(gentle.peak_yaw < first.peak_yaw and gentle.peak_slip < first.peak_slip,"Gentler preset reduces rotation and slip")
	var turn := await simulate(lab,original,0)
	assert(turn.slide_ticks == 0 and turn.peak_yaw > 0)
	var donut := await simulate(lab,original,2)
	assert(donut.donut_ticks > 0)
	lab.begin_recording()
	for i in 100:
		await physics_frame
		lab.step(1.0/60)
	lab.sliders.power_slide_turn_multiplier.value = 2.8
	for i in 420:
		await physics_frame
		lab.step(1.0/60)
	assert(lab.finish_recording("res://.godot/handling_test_capture.json") == OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/handling_test_capture.json"))
	assert(data.samples.size() == 520 and data.physics_hz == 60)
	var property_event := false
	var run_starts := 0
	for event in data.events:
		if event.type == "property":
			assert(event.tick == 100 and event.data.key == "power_slide_turn_multiplier")
			property_event = true
		if event.type == "run_start": run_starts += 1
	assert(property_event and run_starts == 2)
	var profile: Resource = store.PROFILE_SCRIPT.new()
	profile.values = store.gentle()
	assert(ResourceSaver.save(profile,"res://.godot/test_handling.tres") == OK)
	var authored: Node = load("res://scenes/truck.tscn").instantiate()
	authored.use_saved_handling_default = false
	authored.handling_profile = load("res://.godot/test_handling.tres")
	authored.set_physics_process(false)
	lab.add_child(authored)
	assert(is_equal_approx(authored.power_slide_turn_multiplier,2.2))
	authored.free()
	lab.running = false
	lab.automatic = false
	lab.restart_run()
	lab.tick = 295
	lab.truck.position = Vector3(0,.12,0)
	lab.truck.speed = 12
	lab.truck.rotation.y = .65
	lab.truck.travel_heading = .3
	lab._process(0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/handling_lab.png")
	print("HANDLING_LAB_PASS repeated physics traces, all maneuvers, gentle preset, live sliders, 60 Hz capture/change events, saved per-truck defaults and authored resource")
	print("SLIDE_COMPARISON original yaw=",first.peak_yaw," slip=",first.peak_slip," gentle yaw=",gentle.peak_yaw," slip=",gentle.peak_slip)
	lab.queue_free()
	await process_frame
	quit()
