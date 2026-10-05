extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var store := root.get_node("CityStore")
	store.local_path = "res://.godot/cache_test/menu_city.res"
	var loader := root.get_node("LoadingScreen")
	assert(await loader.load_scene("res://main_menu.tscn"))
	var menu := current_scene
	assert(menu.get_node("Menu/Actions/ProceduralCity").text == "Play Saved City")
	menu.get_node("Menu/Actions/GenerateCity").pressed.emit()
	await process_frame
	while current_scene == menu or loader.busy: await process_frame
	var city: Node = current_scene.get_node("ProceduralCity")
	assert(not store.generate_next)
	assert(store.last_save_error == OK and FileAccess.file_exists(store.local_path))
	var seed_value: int = city.actual_seed
	var count: int = city.get_node("Roads").get_child_count()
	assert(await loader.load_scene("res://procedural_city.tscn"))
	city = current_scene.get_node("ProceduralCity")
	assert(store.last_source == store.local_path)
	assert(city.actual_seed == seed_value and city.get_node("Roads").get_child_count() == count)
	print("CITY_NEW_TEST passed: menu generates, saves and reopens same city seed=", seed_value)
	quit()
