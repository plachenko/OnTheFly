extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var loader := root.get_node("LoadingScreen")
	assert(await loader.load_scene("res://main_menu.tscn"))
	var menu: Node = current_scene
	assert(menu.stage.saved_city and menu.stage.poses.size() == 3)
	assert(loader.map_preview.plan != null)
	assert(root.get_camera_3d() == menu.get_node("MenuCamera"))
	assert(root.get_camera_3d() != menu.level.camera)
	menu.stage.elapsed = 0.0
	menu.stage.update(menu,0.0)
	var reference: Transform3D = menu.level.truck.global_transform.affine_inverse() * menu.get_node("MenuCamera").global_transform
	assert(reference.origin.distance_to(Vector3(2.47634124756, -.41185760498, 5.87109565735)) < .001)
	assert(is_instance_valid(menu.stage.signal_node))
	var city = menu.level.get_node("ProceduralCity")
	var crossing = menu.stage.signal_node
	var forward: Vector3 = -menu.level.truck.global_basis.z
	var vertical: bool = crossing.crosses_vertical_road
	var junction: Vector3 = crossing.global_position+(Vector3(0,0,city.crosswalk_setback) if vertical else Vector3(city.crosswalk_setback,0,0))
	assert(preload("res://city_road_rules.gd").allows(forward,junction,city))
	assert(forward.dot(junction-crossing.global_position) > 0)
	var collision = menu.level.truck.get_node("TruckCollision")
	var bumper: float = collision.shape.size.z*.5-collision.position.z
	var boundary: float = preload("res://city_road_rules.gd").stop_boundary(city,forward,junction)
	assert(absf(forward.dot(junction-menu.stage.stop)-bumper-boundary-.21-.4) < .01)

	assert(menu.stage.signal_node.get_node("SouthSignal/VehicleRed").visible)
	assert(not menu.stage.signal_node.get_node("SouthSignal/VehicleGreen").visible)
	var previous: Vector3 = menu.get_node("MenuCamera").global_position
	var greatest_step := 0.0
	for frame in 240:
		await process_frame
		menu.stage.update(menu, .05)
		greatest_step = maxf(greatest_step,previous.distance_to(menu.get_node("MenuCamera").global_position))
		previous = menu.get_node("MenuCamera").global_position
	assert(greatest_step < 10.0)
	assert(menu.stage.brake_settled)
	assert(menu.level.truck.global_position.distance_to(menu.stage.stop) < .05)
	assert(menu.stage.signal_node.get_node("SouthSignal/VehicleRed").visible)
	assert(menu.level.get_node("Patrons").get_child_count() == 0)
	assert(not menu.level.is_processing() and not menu.level.truck.is_physics_processing())
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/menu_hill_stage.png")
	for frame in 200: menu.stage.update(menu,.05)
	var roof_pixel: Vector2 = menu.get_node("MenuCamera").unproject_position(menu.level.truck.global_position+Vector3.UP*4)
	assert(roof_pixel.is_finite())
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/menu_camera_settled.png")
	var truck_bounds := AABB()
	var first_mesh := true
	for mesh in menu.level.truck.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible or mesh.mesh == null: continue
		var world_bounds: AABB = mesh.global_transform*mesh.get_aabb()
		truck_bounds = world_bounds if first_mesh else truck_bounds.merge(world_bounds)
		first_mesh = false
	assert(menu.level.truck.model.visible)
	assert(menu.stage.framing_control.get_node("VehicleRed").visible)
	var held_basis: Basis = menu.get_node("MenuCamera").global_basis
	for frame in 240: menu.stage.update(menu,.05)
	assert(menu.get_node("MenuCamera").global_basis.is_equal_approx(held_basis))
	var playing_level: Node = menu.level
	var original_animation = menu.stage.truck_exaggeration_backup
	menu.start_game(true)
	assert(not loader.cover_started)
	await process_frame
	assert(current_scene.loading_intro_active)
	assert(root.get_camera_3d() == current_scene.cinematic_camera)
	assert(root.get_camera_3d() != current_scene.camera)
	while current_scene.loading_intro_active:
		assert(not loader.cover_started)
		await process_frame
	assert(current_scene == playing_level)
	assert(current_scene.truck.is_physics_processing())
	assert(current_scene.truck.exaggeration == original_animation, "Menu idle must not change gameplay animation")
	assert(not current_scene.loading_intro_active)
	assert(root.get_camera_3d() == current_scene.camera)
	playing_level.queue_free()
	await process_frame
	var fallback: Node = load("res://main_menu.tscn").instantiate()
	fallback.use_saved_menu_city = false
	root.add_child(fallback)
	current_scene = fallback
	while not fallback.menu_ready: await process_frame
	assert(not fallback.stage.saved_city)
	assert(fallback.stage.scenery.get_node("StreetLampSpotlight").shadow_enabled)
	for frame in 180: await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/menu_plane_stage.png")
	assert(Engine.max_fps == 0 and not root.get_node("ReplayRecorder").capture_requested())
	print("MENU STAGE PASS: cached hill city, red signal held, one-way sun camera holds, brake settle, reuse without loading overlay, spotlight plane fallback")
	quit()
