extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var store := root.get_node("CityStore")
	var start := Time.get_ticks_msec()
	var level: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = level.get_node("ProceduralCity")
	city.set_meta("full_city_required", true)
	city.randomize_each_load = false
	city.use_bundled_seed = "--shared-seed" in OS.get_cmdline_user_args()
	var expected_seed: int = load(store.BUNDLED).seed if city.use_bundled_seed else 12054
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	current_scene = level
	while city.generating: await process_frame
	assert(store.last_source == store.BUNDLED, "Must restore shipped city instead of generating")
	if "--report" in OS.get_cmdline_user_args():
		var report := {"loaded_bundle": store.last_source == store.BUNDLED, "seed": city.actual_seed, "roads": city.get_node("Roads").get_child_count(), "max_fps": Engine.max_fps, "physics_hz": Engine.physics_ticks_per_second, "recorder_excluded": not ResourceLoader.exists("res://debug_replay_recorder.gd")}
		var file := FileAccess.open(OS.get_executable_path().get_base_dir().path_join("city_cache_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
	assert(city.actual_seed == expected_seed)
	assert(city.visual_surfaces_ready)
	assert(city.get_node("Roads").get_child_count() > 20)
	assert(city.get_node("Parks").get_child_count() > 0)
	assert(city.get_node("Traffic").get_child_count() == city.traffic_car_count)
	assert(level.get_node("ParkingPads").get_child_count() > 5)
	await process_frame
	for car in city.get_node("ParkedCars").get_children():
		if not car is RigidBody3D: continue
		assert(car.get_node("Visual").get_child_count() == 1)
		if car.hybrid_reactions_enabled and car.supports_hybrid_model():
			assert(car.get_node_or_null("SharedHybridReaction") != null)
	for pad in level.get_node("ParkingPads").get_children():
		if pad.has_node("WorldMeter"): assert(pad.get_node("WorldMeter/WorldBar").texture is ViewportTexture)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_INHERIT
	for index in 10: await process_frame
	print("CITY_CACHE_TEST passed elapsed_ms=", Time.get_ticks_msec() - start)
	if "--roundtrip" in OS.get_cmdline_user_args():
		store.local_path = "res://.godot/cache_test/current_city.res"
		assert(store.save(city) == OK)
		var next_level: Node = load("res://procedural_city.tscn").instantiate()
		next_level.process_mode = Node.PROCESS_MODE_DISABLED
		var next_city: Node = next_level.get_node("ProceduralCity")
		root.add_child(next_level)
		while next_city.generating: await process_frame
		assert(store.last_source == store.local_path)
		assert(next_city.actual_seed == city.actual_seed)
		assert(next_city.has_node("BlockRenderCards"), "Saving must retain baked block cards")
		assert(next_city.get_node("BlockRenderCards").entries.size() == city.get_node("BlockRenderCards").entries.size())
		assert(next_city.hill_centers == city.hill_centers)
		assert(next_city.get_node("Roads").get_child_count() == city.get_node("Roads").get_child_count())
		assert(next_city.topology.exits == city.topology.exits)
		print("CITY_CACHE_ROUNDTRIP passed")
		next_level.queue_free()
	level.queue_free()
	await process_frame
	quit()
