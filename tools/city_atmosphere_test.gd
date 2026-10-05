extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.loading_intro_active = false
	var city = scene.get_node("ProceduralCity")
	var atmosphere = city.get_node("FogBoundary/CityAtmosphere")
	var center: Vector2 = city.topology.bounds.get_center()
	var half: Vector2 = city.topology.bounds.size*.5
	scene.remaining_time = scene.level_duration_seconds
	var clear_samples := 0
	for x in [-.99,-.75,0.0,.75,.99]:
		for z in [-.99,-.75,0.0,.75,.99]:
			var branch_point = center + half*Vector2(x,z)
			if atmosphere.highway_blend(Vector3(branch_point.x,2,branch_point.y)) > 0.0: continue
			clear_samples += 1
			atmosphere.update_position(Vector3(branch_point.x,2,branch_point.y))
			assert(atmosphere.edge_blend == 0.0 and not atmosphere.environment.fog_enabled, "Initial playable streets must be clear")
	assert(clear_samples >= 20)
	var highways := 0
	for road_sign in city.get_node("HighwayApproaches").get_children():
		if not road_sign.has_meta("highway_axis"): continue
		var axis: int = road_sign.get_meta("highway_axis")
		var branch_point: Vector3 = road_sign.global_position
		branch_point[axis] += float(road_sign.get_meta("highway_side"))*24.0
		atmosphere.update_position(branch_point)
		assert(atmosphere.edge_blend == 1.0 and atmosphere.environment.fog_enabled)
		highways += 1
	assert(highways >= 3)
	var last := 0.0
	var point := center + half*Vector2(.7,0)
	for progress in [0.0,.1,.2,.35,.5,.7,.95,1.0]:
		scene.remaining_time = scene.level_duration_seconds*(1.0-progress)
		atmosphere.update_position(Vector3(point.x,2,point.y))
		assert(atmosphere.edge_blend >= last)
		if progress <= .2: assert(atmosphere.edge_blend == 0.0)
		last = atmosphere.edge_blend
	assert(last == 1.0)
	atmosphere.update_position(Vector3(center.x,2,center.y))
	assert(not atmosphere.environment.fog_enabled)
	point = center + half*Vector2(.4,0)
	atmosphere.update_position(Vector3(point.x,2,point.y))
	assert(atmosphere.edge_blend == 1.0)
	print("CITY FOG PASS: clear initial streets, ",highways," highway exits fogged, timer-driven inward advance, clear center")
	quit()
