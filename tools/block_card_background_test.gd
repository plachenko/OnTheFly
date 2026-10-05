extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Background baking needs rendering")
	var store := root.get_node("CityStore")
	var level = load("res://procedural_city.tscn").instantiate()
	var city = level.get_node("ProceduralCity")
	city.set_meta("full_city_required", true)
	city.randomize_each_load = false
	root.add_child(level)
	while not level.is_loading_ready(): await process_frame
	level.set_process(false)
	level.truck.set_physics_process(false)
	var old = city.get_node("BlockRenderCards")
	for entry in old.entries:
		for model in entry.models: model.visible = true
	old.free()
	var data = load(store.BUNDLED).duplicate()
	data.block_cards.clear()
	var path := "res://.godot/background_card_city.res"
	store.card_bake_queue.append({"city": weakref(city), "data": data, "path": path})
	store.card_bake_running = true
	await store.bake_saved_cards()
	assert(not store.card_bake_running)
	var saved = load(path)
	assert(saved.block_cards.size() == 18)
	for card in saved.block_cards: assert(card.has("baked_light") and card.baked_light is Vector3)
	var cards = city.get_node("BlockRenderCards")
	assert(cards.entries.size() == saved.block_cards.size())
	for entry in cards.entries: assert(entry.loaded and not entry.models.is_empty())
	print("BLOCK CARD BACKGROUND PASS: baked, saved, installed on current city")
	level.queue_free()
	await process_frame
	quit()
