extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var store = root.get_node("CityStore")
	store.preferred_size = 0 if "--small" in OS.get_cmdline_user_args() else 1
	store.original_grid = "--grid" in OS.get_cmdline_user_args()
	var level = load("res://procedural_city.tscn").instantiate()
	var city = level.get_node("ProceduralCity")
	city.map_size = store.preferred_size
	city.original_grid = store.original_grid
	store.local_path = store.bundled_path(city)
	var baseline_data = load(store.local_path)
	var expected_buildings := 0
	var expected_roads := 0
	for section in baseline_data.sections:
		var section_root: Node = section.instantiate()
		if section_root.has_node("Buildings"): expected_buildings += section_root.get_node("Buildings").get_child_count()
		if section_root.has_node("Roads"): expected_roads += section_root.get_node("Roads").get_child_count()
		section_root.free()
	var started := Time.get_ticks_msec()
	root.add_child(level)
	current_scene = level
	while not level.is_loading_ready(): await process_frame
	var ready_ms := Time.get_ticks_msec() - started
	var stream = city.get_node("CityStream")
	var cards = city.get_node("BlockRenderCards")
	assert(cards.entries.size() == baseline_data.block_cards.size())
	var streaming: bool = city.get_meta("streaming_city")
	if not "--small" in OS.get_cmdline_user_args(): assert(streaming and stream.initial_sections < stream.total_sections)
	assert(city.get_node("Roads").get_child_count() == expected_roads)
	assert(city.get_node("Terrain").get_child_count() > 0)
	assert(city.get_node("Traffic").get_child_count() == city.traffic_car_count)
	if streaming: assert(store.save(city) == ERR_BUSY, "An incomplete city must not replace the saved map")
	var initial_buildings: int = city.get_node("Buildings").get_child_count()
	assert(initial_buildings <= expected_buildings)
	level.truck.set_physics_process(false)
	level.set_process(false)
	paused = true
	var count: int = stream.loaded_sections
	for frame in 5: await process_frame
	assert(stream.loaded_sections == count, "Streaming pauses with gameplay")
	paused = false
	while city.get_meta("streaming_city"): await process_frame
	assert(city.get_node("Buildings").get_child_count() == expected_buildings)
	assert(stream.loaded_sections == stream.total_sections)
	for entry in cards.entries:
		assert(entry.loaded and not entry.models.is_empty())
		for model in entry.models:
			assert(model.has_meta("block_card_managed"))
			for geometry in model.find_children("*", "GeometryInstance3D", true, false):
				assert(geometry.visibility_range_end == 0, "Block cards replace the old hard switch")
	assert(city.actual_seed == baseline_data.seed)
	print("CITY STREAM PASS ready_ms=", ready_ms, " initial_sections=", stream.initial_sections, "/", stream.total_sections, " initial_buildings=", initial_buildings, "/", expected_buildings, " full_ms=", Time.get_ticks_msec() - started)
	quit()
