extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var store = root.get_node("CityStore")
	store.earlier_style = true
	store.preferred_size = 0
	store.generate_next = true
	store.pending_generation_seed = 12054
	store.local_path = "res://.godot/earlier_city_test.res"
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	var city = scene.get_node("ProceduralCity")
	assert(city.earlier_style and city.map_size == 0)
	assert(not city.visual_surfaces_ready)
	assert(city.road_width == 16.0 and city.diagonal_road_width == 12.0)
	assert(city.diagonal_roads_enabled and city.topology.arteries.is_empty())
	var islands = city.get_node("Roads").find_children("RoundedSidewalk*", "MeshInstance3D", true, false).filter(func(node): return node.has_meta("island_shapes"))
	assert(not islands.is_empty(), "Diagonal streets must generate sidewalk islands")
	assert(islands.any(func(node): return node.get_meta("island_shapes").size() > 1), "Diagonal roads split a block into islands")
	assert(store.last_save_error == OK)
	assert(city.get_node("Roads").get_child_count() > 0)
	for node in city.get_node("HighwayApproaches").get_children():
		assert(not node.has_meta("city_boundary"))
	for visual in city.get_node("Roads").find_children("*", "MeshInstance3D", true, false):
		assert(not visual.has_meta("smoothed_visual_surface"))
	var earlier_path: String = store.private_path(city)
	var earlier_hash: String = store.settings_hash(city)
	city.earlier_style = false
	store.local_path = store.LOCAL
	assert(store.private_path(city) != earlier_path)
	assert(store.settings_hash(city) != earlier_hash)
	city.earlier_style = true
	store.local_path = earlier_path
	assert(is_equal_approx(city.road_visual_height_at(12, 15), city.terrain_surface_height_at(12, 15)))
	assert(await store.restore(city))
	assert(not city.visual_surfaces_ready)
	for node in city.get_node("HighwayApproaches").get_children():
		assert(not node.has_meta("city_boundary"))
	print("EARLIER CITY PASS: generated roads, no walls or smoothing, separate cache and unsmoothed height sampling")
	quit()
