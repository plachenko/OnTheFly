extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for size_index in [0,1]:
		for seed_value in 30:
			var plan := preload("res://city_topology.gd").new()
			var parks: Array[Vector2i] = []
			plan.generate(seed_value, parks, size_index)
			plan.use_original_grid()
			assert(plan.arteries.is_empty() and plan.artery_types.is_empty())
			assert(plan.directed_connected())
			for rectangle in plan.blocks.values(): assert(rectangle.size == Vector2(64,64))
	var store := root.get_node("CityStore")
	store.original_grid = true
	store.preferred_size = 0
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	var city := scene.get_node("ProceduralCity")
	assert(city.original_grid)
	assert(store.last_source.ends_with("grid_small.res"))
	assert(city.topology.artery_types.is_empty())
	var menu: Node = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	while not menu.menu_ready: await process_frame
	assert(not menu.bridges_picker.button_pressed)
	menu.bridges_picker.button_pressed = true
	store.original_grid = not menu.bridges_picker.button_pressed
	assert(not store.original_grid)
	print("ORIGINAL GRID PASS: 60 deterministic connected rectangular plans, separate saved cache, menu toggle")
	quit()
