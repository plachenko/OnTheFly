extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.fixed_seed = 12054
	city.time_of_day_mode = 1
	root.add_child(scene)
	current_scene = scene
	while city.generating: await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	var signs: Array = []
	var closed := 0
	for node in city.get_node("HighwayApproaches").get_children():
		if node.has_meta("highway_axis"): signs.append(node)
		if str(node.name).begins_with("ClosedHighwayEnd"): closed += 1
	assert(signs.size() == city.topology.exits.size() and signs.size() >= 3 and signs.size() <= 5)
	assert(closed + signs.size() == 20)
	var tested := 0
	for cell in city.topology.blocks:
		var rect: Rect2 = city.topology.blocks[cell]
		if not city.topology.primary(Vector2(cell)) or rect.size == Vector2(64,64): continue
		var point := rect.get_center()
		if city.distance_to_diagonal_road(point) < 10: continue
		assert(not city.on_grid_road(point))
		tested += 1
	assert(tested > 0)
	var road_sign: Node3D = signs[0]
	var axis: int = road_sign.get_meta("highway_axis")
	var side: float = road_sign.get_meta("highway_side")
	scene.truck.global_position = road_sign.global_position
	scene.truck.global_position[axis] += side
	assert(scene.truck.highway_transit.drive(1.0/60.0))
	assert(scene.truck.highway_transit.active and scene.truck.collision_mask == 0)
	for tick in 90:
		scene.truck.highway_transit.drive(1.0/60.0)
		city._physics_process(1.0/60.0)
	assert(scene.truck.highway_transit.active and scene.truck.highway_transit.wrapped)
	var lateral := 2 if axis == 0 else 0
	assert(is_equal_approx(scene.truck.global_position[lateral],scene.truck.highway_transit.lane_coordinate))
	for i in 4:
		var wheel: Vector3 = scene.truck.skeleton.to_global(scene.truck.skeleton.get_bone_global_pose(scene.truck.suspension_bones[i]).origin)
		assert(absf(wheel.y-.59-scene.truck.highway_transit.surface_height(wheel)) < .15)
	scene.truck.highway_transit.finish()
	if is_instance_valid(city.highway_wipe):
		city.highway_wipe.phase = 0
		city.highway_wipe.panel.hide()
	# At every missing forward branch, route planning must choose an open turn.
	var car = city.get_node("Traffic").get_child(0)
	car.turning = false
	var routed := 0
	for ix in [-128,-64,0,64,128]:
		for iz in [-144,-80,-16,48,112]:
			var junction := Vector3(ix,0,iz)
			for axis_vector in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
				if city.road_branch_exists(junction,axis_vector) or not city.road_branch_exists(junction,-axis_vector): continue
				var rules = load("res://city_road_rules.gd")
				if not rules.allows(axis_vector,junction): continue
				var left := Vector3(axis_vector.z,0,-axis_vector.x)
				if not ((rules.allows(left,junction) and city.road_branch_exists(junction,left)) or (rules.allows(-left,junction) and city.road_branch_exists(junction,-left))): continue
				car.travel_axis = axis_vector
				car.lane_center = junction - axis_vector*16 + Vector3(-axis_vector.z,0,axis_vector.x)*4
				car.progress = 0
				car.turn_intent = 0
				car.considered_intersections.clear()
				car.plan_intersection_turn()
				assert(car.turn_intent != 0)
				assert(city.road_branch_exists(junction,left if car.turn_intent < 0 else -left))
				routed += 1
	assert(routed > 0)
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		city.get_node("FogBoundary/CityAtmosphere").set_process(false)
		var environment = scene.get_node("WorldEnvironment").environment
		environment.fog_enabled = false
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 390
		camera.far = 1000
		camera.position = Vector3(0,250,16)
		camera.look_at(Vector3(0,0,16),Vector3.FORWARD)
		camera.make_current()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/city_topology_preview.png")
	print("CITY_TOPOLOGY_INTEGRATION_PASS: ",signs.size()," exits, closed alternatives, ",tested," merged islands, ",routed," forced turns, boost-free seamless highway entry")
	quit()
