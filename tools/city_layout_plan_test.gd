extends SceneTree

func _initialize() -> void:
	var rare_arteries := 0
	var inner_one_ways := 0
	var minimum_spacing := INF
	for preference in [0,1]:
		for seed_value in 300:
			var plan := preload("res://city_topology.gd").new()
			var other := preload("res://city_topology.gd").new()
			var parks: Array[Vector2i] = [Vector2i(-32,16)]
			plan.generate(seed_value,parks,preference)
			other.generate(seed_value,parks,preference)
			assert(plan.bounds == other.bounds and plan.exits == other.exits and plan.plots == other.plots and plan.directions == other.directions)
			assert(plan.blocks.size() == (12 if preference == 0 else 20))
			assert(plan.exits.size() >= 3 and plan.exits.size() <= 5)
			assert(plan.directed_connected())
			assert(plan.bounds.size.x >= plan.street_bounds.size.x+28 and plan.bounds.size.x <= plan.street_bounds.size.x+44)
			for i in plan.exits.size():
				var exit: Dictionary = plan.exits[i]
				assert(plan.arteries.has(plan.key(exit.vertical,exit.center.x if exit.vertical else exit.center.y)))
				for j in range(i): minimum_spacing = minf(minimum_spacing,exit.center.distance_to(plan.exits[j].center))
			for cell in plan.blocks:
				if plan.blocks[cell].get_area() > 4096: assert(plan.edge_cell(cell),"Merges must stay on the edge")
				if plan.plots[cell] == "grey": continue
				for delta in [Vector2i(64,0),Vector2i(-64,0),Vector2i(0,64),Vector2i(0,-64)]:
					if plan.plots.get(cell+delta,"grey") != "grey": assert(plan.plots[cell] == "park")
			for vertical in [true,false]:
				for coordinate in (plan.verticals if vertical else plan.horizontals):
					for side in [-1.0,1.0]:
						var edge: float = (plan.bounds.position.y if side<0 else plan.bounds.end.y) if vertical else (plan.bounds.position.x if side<0 else plan.bounds.end.x)
						assert(plan.road_exists(vertical,coordinate,edge+side*5) == plan.exit_exists(vertical,coordinate,side),"Only highways cross the boundary")
			for road in plan.directions:
				if plan.arteries.has(road): rare_arteries += 1
				else: inner_one_ways += 1
	assert(minimum_spacing >= 95)
	assert(inner_one_ways > 0 and rare_arteries == 0)
	print("LAYOUT_PLAN_PASS 600 deterministic maps: connected arteries and directed streets, edge-only merges, highway-only boundary crossings, adjacent green parks; exit spacing=",minimum_spacing)
	quit()
