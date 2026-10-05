extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var store := root.get_node("CityStore")
	store.bake_path = "res://generated_city/default_city.res"
	var level: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = level.get_node("ProceduralCity")
	var args := OS.get_cmdline_user_args()
	store.original_grid = "--original-grid" in args
	city.original_grid = store.original_grid
	var size_index := args.find("--map-size")
	city.map_size = int(args[size_index + 1]) if size_index >= 0 and size_index + 1 < args.size() else 1
	store.bake_path = store.bundled_path(city)
	var source_index := args.find("--city-file")
	if source_index >= 0:
		if source_index + 1 >= args.size(): quit(1); return
		var data := ResourceLoader.load(args[source_index + 1])
		var target_size: int = city.map_size
		if data != null: city.map_size = int(data.get("map_size"))
		if data == null or data.get_script() != preload("res://saved_city.gd") or data.format_version != store.FORMAT_VERSION or data.settings_hash != store.settings_hash(city) or (data.snapshot == null and data.sections.is_empty()):
			push_error("Saved city is incompatible with this build. Generate it using this version first.")
			level.free()
			quit(1)
			return
		city.map_size = target_size
		if data.map_size == target_size:
			DirAccess.make_dir_recursive_absolute(store.bake_path.get_base_dir())
			var error := ResourceSaver.save(data, store.bake_path, ResourceSaver.FLAG_COMPRESS)
			print("CITY_BAKE imported seed=", data.seed)
			level.free()
			quit(0 if error == OK else 1)
			return
	if ResourceLoader.exists(store.bake_path) and "--force" not in args:
		var existing: Resource = load(store.bake_path)
		if existing.format_version == store.FORMAT_VERSION and existing.settings_hash == store.settings_hash(city):
			print("CITY_BAKE reused ",store.bake_path)
			level.free()
			quit()
			return
	city.randomize_each_load = false
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	current_scene = level
	while city.generating: await process_frame
	if store.last_save_error != OK or not FileAccess.file_exists(store.bake_path):
		push_error("City bake failed")
		quit(1)
		return
	print("CITY_BAKE complete seed=", city.actual_seed)
	quit()
