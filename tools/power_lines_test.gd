extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	var network: Node = city.get_node("StreetSigns/UtilityPolesAndWires")
	var poles := 0
	var wires := 0
	var crossing := 0
	for node in network.get_children():
		if node.has_meta("wire_points"):
			wires += 1
			crossing += int(node.get_meta("crosses_road"))
			for point in node.get_meta("wire_points"):
				assert(point.y >= city.terrain_surface_height_at(point.x, point.z) + 6.49)
		elif node.has_node("KnockablePole"):
			poles += 1
	assert(poles > 20 and wires > 30 and crossing > 0)
	print("POWER LINES PASS: ", poles, " poles, ", wires, " sagging wires, ", crossing, " road-crossing spans, truck clearance")
	quit()
