extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var loader = root.get_node("LoadingScreen")
	var store = root.get_node("CityStore")
	store.generate_next = true
	loader.begin_cover()
	assert(loader.map_preview.visible and loader.map_preview.plan.exits.size() >= 3)
	assert(store.pending_generation_seed >= 0)
	var opening = loader.map_preview.plan
	var plan = load("res://city_topology.gd").new()
	var parks: Array[Vector2i] = []
	plan.generate(store.pending_generation_seed,parks,store.preferred_size,14,22)
	assert(plan.bounds == opening.bounds and plan.exits == opening.exits)
	assert(loader.logo_background.polygon.size() == 3)
	assert(loader.logo_title.position.y > 800 and loader.map_preview.position.y >= 800)
	assert(loader.text_layer.get_children().find(loader.logo_background) < loader.text_layer.get_children().find(loader.logo_title))
	loader.animate_logo_arc(.78)
	assert(loader.map_preview.position.y == -12)
	assert(loader.logo_title.position.y == loader.LOGO_POSITION.y-12)
	await loader.transition.finished
	assert(loader.map_preview.position.is_equal_approx(Vector2.ZERO))
	assert(loader.logo_title.position.is_equal_approx(loader.LOGO_POSITION))
	assert(is_equal_approx(loader.logo_title.rotation,deg_to_rad(-26)))
	loader.busy = true
	await loader.city_stage(plan,0,"Mapping exits...")
	assert(loader.map_preview.phase == 1)
	Input.action_press("right",.8)
	await create_timer(.65).timeout
	Input.action_release("right")
	assert(loader.backdrop.steering_offset > .03)
	assert(loader.backdrop.trails.left_track.size() > 10)
	var tracks_before: int = loader.backdrop.trails.left_track.size()
	Input.action_press("left",.8)
	await create_timer(.4).timeout
	Input.action_release("left")
	assert(loader.backdrop.trails.left_track.size() > tracks_before)
	await loader.city_stage(plan,5,"Building sidewalks...")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/loading_logo.png")
	await loader.finish_cover()
	loader.begin_cover()
	assert(loader.logo_title.position.y > 800)
	assert(loader.backdrop.trails.left_track.is_empty())
	assert(loader.backdrop.steering_offset == 0.0)
	await loader.transition.finished
	await loader.finish_cover()
	store.generate_next = false
	store.pending_generation_seed = -1
	loader.busy = false
	print("LOADING LOGO PASS: subtle synchronized toss, triangle, title rotation, reserved map bounds/exits, steerable truck, persistent tire marks, reset")
	quit()
