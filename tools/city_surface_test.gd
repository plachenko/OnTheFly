extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	if not OS.get_cmdline_user_args().is_empty(): city.fixed_seed = int(OS.get_cmdline_user_args()[0])
	city.time_of_day_mode = 1
	root.add_child(scene)
	current_scene = scene
	while city.generating: await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	var checked := 0
	for plot in city.get_node("Parks").get_children():
		for visual in plot.get_children():
			if not visual is MeshInstance3D or not str(visual.name) in ["Grass", "ParkGrass"]: continue
			var vertices: PackedVector3Array = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			assert(normals[0].y > 0, "Grass must face upward")
			for local in vertices:
				var world: Vector3 = visual.to_global(local)
				var point := Vector2(world.x, world.z)
				assert(not city.on_grid_road(point, city.sidewalk_width - 0.01))
				assert(city.distance_to_diagonal_road(point) >= city.diagonal_road_width * 0.5 + city.sidewalk_width - 0.01)
				checked += 1
	assert(checked > 100)
	assert(city.get_node("Parks/LampGravel") is MeshInstance3D)
	var island_count := 0
	for slab in city.get_node("Roads").get_children():
		if slab.has_meta("island_shapes"):
			island_count += slab.get_meta("island_shapes").size()
			assert(slab.get_child_count() > 0)
	assert(island_count >= 6)
	var crossings := city.get_node("Crosswalks").find_children("IslandCrosswalk*", "Node3D", false, false)
	assert(crossings.size() >= 3)
	for crossing in crossings:
		assert(crossing.wait_point(-1).distance_to(crossing.wait_point(1)) > city.diagonal_road_width)
		assert(crossing.has_node("ZebraStripes") and crossing.has_node("SouthSignal") and crossing.has_node("NorthSignal"))
		assert(crossing.find_children("CurbRamp*", "MeshInstance3D", false, false).size() == 2)
	await physics_frame
	await physics_frame
	for crossing in crossings:
		var ends: Array = crossing.get_meta("endpoints")
		var midpoint: Vector2 = (ends[0] + ends[1]) * 0.5
		for end in ends:
			var point: Vector2 = midpoint.lerp(end, 0.80)
			var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 1000, point.y), Vector3(point.x, -100, point.y), 1)
			var hit := root.world_3d.direct_space_state.intersect_ray(query)
			assert(not hit.is_empty() and str(hit.collider.get_parent().name).begins_with("CurbRamp"), "Both island ramps must be walkable")
	for point in [Vector2(0, -50), Vector2(60, -50), Vector2(50, -80), Vector2(96, -80)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 1000, point.y), Vector3(point.x, -100, point.y), 1)
		var hit := root.world_3d.direct_space_state.intersect_ray(query)
		assert(not hit.is_empty())
		assert(hit.collider.get_parent().name == "Asphalt", "Road must own collision at %s, got %s" % [point, hit.collider.get_parent().name])
	print("CITY SURFACE PASS: ", checked, " clipped grass vertices; ", island_count, " enclosed island pieces; ", crossings.size(), " crossings with walkable ramps; road/sidewalk clearance and asphalt collision")
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.position = Vector3(120, city.height_at(96, -80) + 35, -110)
		camera.look_at(Vector3(96, city.height_at(96, -80), -80))
		camera.make_current()
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/city_surface_preview.png")
	quit()
