extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var store = root.get_node("CityStore")
	var city_scene = load("res://procedural_city.tscn")
	var template = city_scene.instantiate()
	var settings = template.get_node("ProceduralCity")
	assert(settings.road_width == 24 and settings.diagonal_road_width == 18)
	assert(preload("res://city_road_rules.gd").lane_scale(settings) == 1.5)
	for grid in [false,true]:
		for size in [0,1]:
			settings.original_grid = grid; settings.map_size = size
			var snapshot: Resource = load(store.bundled_path(settings))
			assert(snapshot.settings_hash == store.settings_hash(settings))
	template.free()
	var level = city_scene.instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level); current_scene = level
	while not level.is_loading_ready(): await process_frame
	var city = level.get_node("ProceduralCity")
	assert(level.get_meta("saved_city_loaded",false))
	for car in city.get_node("Traffic").get_children():
		var vertical: bool = absf(car.travel_axis.z) > .5
		var coordinate: float = car.lane_center.x if vertical else car.lane_center.z
		var road: float = roundf((coordinate+(128 if vertical else 144))/64)*64-(128 if vertical else 144)
		var offset: float = absf(coordinate-road)
		if city.topology.artery_kind(vertical,road) == "inner": assert(is_equal_approx(offset,6))
		else: assert(is_equal_approx(offset,3) or is_equal_approx(offset,9))
	var bridge_count := 0
	for road in city.get_node("Roads").get_children():
		if road.has_meta("driving_lanes_per_direction"): bridge_count += 1
	assert(bridge_count > 0 or city.topology.arteries.is_empty())
	level.camera.position = Vector3(30,55,90)
	level.camera.look_at(Vector3(0,10,48)); level.camera.make_current()
	level.get_node("HUD").hide()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/wide_roads.png")
	print("WIDE ROADS PASS: 24m road, 6m arterial lanes, traffic offsets, all four saved maps compatible")
	quit()
