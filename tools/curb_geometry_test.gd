extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	var outer: PackedVector2Array = city.rounded_block_contour(Vector2.ZERO)
	var inner: PackedVector2Array = city.rounded_block_contour(Vector2.ZERO, city.sidewalk_width)
	assert(outer.size() == inner.size())
	for index in outer.size():
		assert(outer[index].distance_to(outer[(index + 1) % outer.size()]) <= 1.01)
		assert(absf(outer[index].distance_to(inner[index]) - city.sidewalk_width) < 0.001)
	assert(city.get_node("Roads").find_children("RoundedSidewalk*", "MeshInstance3D", false, false).size() == 20)
	assert(city.get_node("Roads/CurbMarkings").get_child_count() + city.get_node("Roads").find_children("IslandCurbOutline*", "MeshInstance3D", false, false).size() >= 20)
	assert(city.sidewalk_height > 0.3)
	print("CURB GEOMETRY PASS: closed rounded contours, matching paint edges, raised sidewalks")
	quit()
