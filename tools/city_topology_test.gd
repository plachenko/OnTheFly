extends SceneTree

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var edge_merges := 0
	var middle_merges := 0
	var triple_count := 0
	var exit_counts := {}
	var smallest_spacing := INF
	for seed_value in 100:
		var a = load("res://city_topology.gd").new()
		var b = load("res://city_topology.gd").new()
		var parks: Array[Vector2i] = [Vector2i(-32,16)]
		a.generate(seed_value,parks)
		b.generate(seed_value,parks)
		assert(a.blocks == b.blocks and a.exits == b.exits)
		assert(a.exits.size() >= 3 and a.exits.size() <= 5)
		exit_counts[a.exits.size()] = true
		for i in a.exits.size():
			for j in range(i): smallest_spacing = minf(smallest_spacing,a.exits[i].center.distance_to(a.exits[j].center))
		assert(a.bounds_for(Vector2(-32,16)).size == Vector2(64,64))
		for cell in a.blocks:
			var rect: Rect2 = a.blocks[cell]
			var count := roundi(rect.get_area()/4096.0)
			assert(count >= 1 and count <= 3)
			if count == 1: continue
			if abs(cell.x) == 96 or cell.y in [-112,144]: edge_merges += 1
			else: middle_merges += 1
			if not a.primary(Vector2(cell)): continue
			if count == 3: triple_count += 1
			var vertical := rect.size.x > 64
			var coordinate: float = rect.position.x+64 if vertical else rect.position.y+64
			var along: float = rect.get_center().y if vertical else rect.get_center().x
			assert(not a.road_exists(vertical,coordinate,along), "Internal street must be removed")
	assert(triple_count > 0 and edge_merges > middle_merges)
	assert(exit_counts.size() == 3 and smallest_spacing >= 100, "Exits must be separated by at least 100 meters: %f" % smallest_spacing)
	print("TOPOLOGY_PASS: 100 repeatable seeds, 2–3 block spans, edge bias, park preserved, 3–5 exits, minimum spacing ",smallest_spacing)
	quit()
