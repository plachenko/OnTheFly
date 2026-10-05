extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var loader = root.get_node("LoadingScreen")
	loader.busy = true
	loader.begin_cover()
	await loader.transition.finished
	var plan = load("res://city_topology.gd").new()
	var parks: Array[Vector2i] = []
	plan.generate(12054,parks,0,48,96)
	await loader.city_stage(plan,5,"Building sidewalks...")
	assert(loader.map_preview.visible)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/loading_map_layout.png")
	print("LOADING MAP LAYOUT PASS")
	quit()
