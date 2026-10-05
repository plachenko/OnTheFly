extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var city = scene.get_node("ProceduralCity")
	assert(scene.has_meta("saved_city_loaded"))
	assert(city.find_children("ParkTree*", "", true, false).is_empty())
	assert(city.find_children("EdgeForest*", "", true, false).is_empty())
	assert(city.find_children("EdgeCliff*", "", true, false).is_empty())
	var walls = city.get_node("HighwayApproaches").get_children().filter(func(node): return node.has_meta("city_boundary"))
	assert(walls.size() == 1)
	var wall = walls[0]
	assert(wall is StaticBody3D and str(wall.name).begins_with("EdgeWall"))
	assert(wall.get_meta("wall_segments") > 100)
	assert(wall.find_children("*", "MeshInstance3D", false, false).size() == 1)
	assert(wall.get_node("SplineWallVisual").mesh is ArrayMesh)
	for collision in wall.find_children("*", "CollisionShape3D", false, false):
		assert(collision.shape is BoxShape3D)
		assert(not load("res://city_edge_boundary.gd").exit_opening(city,collision.position))
		for exit in city.topology.exits:
			var delta = Vector2(collision.position.x,collision.position.z) - exit.center
			assert(absf(delta.x) > 23 or absf(delta.y) > 23, "Keep exits unobstructed")
	var curve = load("res://city_edge_boundary.gd").perimeter(city.topology.bounds)
	assert(curve.point_count == 9 and curve.get_point_position(0).is_equal_approx(curve.get_point_position(8)))
	await load("res://city_edge_boundary.gd").generate(city)
	var rebuilt = city.get_node("HighwayApproaches").get_children().filter(func(node): return node.has_meta("city_boundary"))
	assert(rebuilt.size() == walls.size())
	scene.get_node("HUD").hide()
	scene.get_node("MobileControls").hide()
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	var corner: Vector2 = city.topology.bounds.position
	var ground: float = city.height_at(corner.x,corner.y)
	camera.global_position = Vector3(corner.x+65,ground+48,corner.y+65)
	camera.look_at(Vector3(corner.x-12,ground+10,corner.y-12))
	city.get_node("FogBoundary/CityAtmosphere").environment.fog_enabled = false
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/spline_wall.png")
	print("CITY WALL PASS: saved city upgraded; ",rebuilt.size()," continuous spline wall, simple collision, clear highways, no trees, idempotent generation")
	quit()
