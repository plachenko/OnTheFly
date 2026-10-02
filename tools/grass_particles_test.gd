extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	var emitters: Array = city.get_node("Parks").find_children("GrassClumps*", "MultiMeshInstance3D", false, false)
	assert(emitters.size() > 0)
	var count := 0
	for emitter in emitters:
		assert(emitter.multimesh.mesh != null)
		var points: PackedVector3Array = emitter.get_meta("grass_positions")
		assert(emitter.multimesh.instance_count == points.size())
		for point in points:
			assert(not city.on_grid_road(Vector2(point.x, point.z), city.sidewalk_width + 0.5))
			assert(city.distance_to_diagonal_road(Vector2(point.x, point.z)) >= city.diagonal_road_width * 0.5 + city.sidewalk_width + 0.5)
		count += points.size()
	var fringe = city.get_node("Parks").find_children("GrassFringe*", "MultiMeshInstance3D", false, false)
	assert(not fringe.is_empty())
	for patch in fringe:
		for point in patch.get_meta("grass_positions"):
			assert(not city.on_grid_road(Vector2(point.x, point.z), city.sidewalk_width + 0.08))
	print("GRASS CLUMPS PASS: ", emitters.size(), " patches, ", count, " anchored grass tufts, road/sidewalk clearance")
	quit()
