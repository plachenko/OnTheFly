extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.truck.set_physics_process(false)
	scene.set_process(false)
	var display: Control = scene.get_node("HUD/Layout/StreetNavigation")
	display.set_process(false)
	display.update_location(Vector2(-4, -50), Vector2.DOWN)
	assert(display.current_label.text == "ON  Pizza Avenue")
	assert(display.next_street.name == "Burrito Street" and display.past_street.name == "Noodle Street")
	assert(display.next_card.visible and display.past_card.visible)
	var distant: float = display.next_target.x
	var small: float = display.next_scale
	display.update_location(Vector2(-4, -25), Vector2.DOWN)
	assert(display.next_target.x < distant and display.next_scale > small)
	display.update_location(Vector2(-4, -16), Vector2.DOWN)
	assert(display.current_label.text == "ON  Burrito Street")
	display.update_location(Vector2(-4, -5), Vector2.DOWN)
	assert(display.past_street.name == "Burrito Street")
	assert(display.next_street.name == "Waffle Street")
	var left_offset: float = absf(display.past_target.x)
	display.update_location(Vector2(-4, -10), Vector2.DOWN, true)
	assert(absf(display.past_target.x) < left_offset)
	assert(display.past_card.get_child(0).text.begins_with("BACKING TOWARD"))
	display.update_location(Vector2(-4, -50), Vector2.DOWN)
	var old_past: Control = display.past_card
	var old_next: Control = display.next_card
	display.update_location(Vector2(-4, -50), Vector2.UP)
	assert(display.next_street.name == "Noodle Street" and display.past_street.name == "Burrito Street")
	assert(display.next_card == old_past and display.past_card == old_next and display.swapping)
	await create_timer(0.7).timeout
	assert(not display.swapping)
	display.update_location(Vector2(16, -12), Vector2.RIGHT)
	assert(display.current_label.text == "ON  Burrito Street")
	assert(display.next_street.name == "Ramen Avenue")
	display.update_location(Vector2(500, 500), Vector2.RIGHT)
	assert(display.current_label.text == "Off street" and not display.next_card.visible and not display.past_card.visible)
	display.update_location(Vector2(-4, -50), Vector2.DOWN)
	display.refresh_timer = 100
	for i in range(60): display._process(0.016)
	print("STREET HUD PASS: persistent inline neighbors, approach scaling, center crossing, left departure, backing, U-turn swap and road changes")
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/street_hud_preview.png")
	quit()
