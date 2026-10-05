extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var store = root.get_node("CityStore")
	var source = load(store.BUNDLED)
	var saved := Node3D.new()
	saved.name = "SavedCity"
	for section in source.sections:
		var section_root: Node = section.instantiate()
		for container in section_root.get_children():
			var target := saved.get_node_or_null(str(container.name))
			if target == null:
				target = Node3D.new()
				target.name = container.name
				saved.add_child(target)
			for child in container.get_children():
				container.remove_child(child)
				store.clear_owners(child)
				target.add_child(child)
		section_root.free()
	store.own_tree(saved, saved)
	var packed := PackedScene.new()
	assert(packed.pack(saved) == OK)
	saved.free()
	var legacy := preload("res://saved_city.gd").new()
	for key in ["format_version", "original_grid", "map_size", "settings_hash", "seed", "night", "hills", "traffic_state"]: legacy.set(key, source.get(key))
	legacy.snapshot = packed
	store.local_path = "res://.godot/stream-test/legacy-upgrade.res"
	assert(ResourceSaver.save(legacy, store.local_path, ResourceSaver.FLAG_COMPRESS) == OK)
	var level = load("res://procedural_city.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	while not level.is_loading_ready(): await process_frame
	var upgraded = ResourceLoader.load(store.local_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(not upgraded.sections.is_empty() and upgraded.snapshot == null)
	assert(upgraded.seed == legacy.seed and upgraded.settings_hash == legacy.settings_hash)
	print("CITY STREAM UPGRADE PASS: legacy map fully restored and atomically upgraded without changing seed/settings")
	quit()
