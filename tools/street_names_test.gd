extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	var names: Dictionary = city.get_meta("street_names")
	assert(names.avenues.size() == 5 and names.streets.size() == 6)
	assert(names.diagonals.size() == city.diagonal_road_segments.size())
	var signs = city.get_node("StreetSigns").find_children("StreetName*", "Node3D", false, false)
	assert(signs.size() >= 30)
	var diagonals := 0
	for post in signs:
		var labels = post.find_children("*", "Label3D", true, false)
		assert(labels.size() == 4)
		assert(labels[0].text == labels[1].text and labels[2].text == labels[3].text)
		assert(not city.on_grid_road(Vector2(post.position.x, post.position.z)))
		assert(city.distance_to_diagonal_road(Vector2(post.position.x, post.position.z)) >= city.diagonal_road_width * 0.5)
		if "Way" in labels[0].text:
			diagonals += 1
	assert(diagonals > 0)
	print("STREET NAMES PASS: ", signs.size(), " double-sided intersection posts, ", diagonals, " diagonal junctions")
	quit()
