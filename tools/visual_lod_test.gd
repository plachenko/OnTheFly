extends SceneTree

func _initialize() -> void: run.call_deferred()

func camera_view(world: World3D, center: Vector3, offset: Vector3) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.world_3d = world
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.cull_mask = 1<<19
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	viewport.add_child(camera)
	camera.position = center+offset
	camera.look_at(center)
	return viewport

func settle() -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var diagnostics: Node = root.get_node("PerformanceDiagnostics")
	var level: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = level.get_node("ProceduralCity")
	city.randomize_each_load = false
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	current_scene = level
	while city.generating: await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("HUD").hide()
	level.get_node("MobileControls").hide()
	var cars: Array = city.get_node("Traffic").get_children()
	var car: Node = cars[0]
	assert(car.has_node("TrafficVisualLOD"))
	var lod: Node = car.get_node("TrafficVisualLOD")
	assert(lod.enabled and lod.impostor.mesh is QuadMesh)
	for mesh in lod.detailed: mesh.layers = 1<<19
	lod.impostor.layers = 1<<19
	var center: Vector3 = car.global_position+Vector3(0,1,0)
	var near_view := camera_view(level.get_world_3d(),center,Vector3(14,7,14))
	var far_view := camera_view(level.get_world_3d(),center,Vector3(110,55,110))
	await settle()
	var near_primitives := near_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var far_primitives := far_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	assert(near_primitives > far_primitives and far_primitives > 0,"Each camera independently draws full 3D nearby and a two-triangle distant car")
	near_view.get_texture().get_image().save_png("res://.godot/car_lod_near.png")
	far_view.get_texture().get_image().save_png("res://.godot/car_lod_far.png")
	print("CAR_LOD_VIEW near_primitives=",near_primitives," far_primitives=",far_primitives)
	var level_truck: Node = level.truck
	level_truck.global_position = car.global_position+Vector3(1000,0,1000)
	car.update_proximity_mode()
	assert(car.distant_mode and car.collision_layer == 0)
	car.obey_crosswalks = false
	car.intersection_turn_chance = 0
	car.current_driving_speed = 8
	car.distant_elapsed = .1
	var progress_before: float = car.progress
	car.step_distant_route(.2)
	assert(car.progress != progress_before or car.turning,"Distant traffic continues its independent route logic")
	level_truck.global_position = car.global_position+Vector3(0,0,30)
	level_truck.rotation.y = PI # Facing away must never turn off nearby collisions.
	car.update_proximity_mode()
	assert(not car.distant_mode and car.collision_layer != 0 and car.distant_elapsed == 0)
	assert(car.disable_from_impact(30,Vector3.RIGHT,car.global_position))
	lod.refresh()
	assert(lod.force_detail and not lod.impostor.visible)
	for mesh in lod.detailed: assert(mesh.visibility_range_end == 0)
	car.set_ambient_active(false)
	assert(not lod.impostor.visible)
	car.set_ambient_active(true)
	var buildings := 0
	for body in city.get_node("Buildings").get_children():
		if body.has_node("BuildingVisualLOD"):
			var building_lod: Node = body.get_node("BuildingVisualLOD")
			assert(building_lod.proxy.mesh is BoxMesh)
			assert(building_lod.proxy.visibility_range_begin == 96)
			assert(body.has_node("BuildingCollision"))
			buildings += 1
	assert(buildings > 0)
	near_view.queue_free()
	far_view.queue_free()
	for mesh in lod.detailed: mesh.layers = 1
	lod.impostor.layers = 1
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.position = Vector3(-110,70,210)
	camera.look_at(Vector3(0,0,10))
	camera.make_current()
	var measurements := []
	for enabled in [false,true]:
		diagnostics.rendering_lod_enabled = enabled
		await settle()
		var samples := []
		for i in 30:
			await process_frame
			samples.append([root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)])
		var calls := 0.0
		var primitives := 0.0
		for sample in samples: calls += sample[0]; primitives += sample[1]
		measurements.append({"enabled":enabled,"draw_calls":calls/samples.size(),"primitives":primitives/samples.size()})
		root.get_texture().get_image().save_png("res://.godot/city_render_lod_%s.png" % str(enabled))
		print("CITY_RENDER_LOD ",measurements.back())
	assert(measurements[1].primitives < measurements[0].primitives)
	var file := FileAccess.open("res://.godot/visual_lod_measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t"))
	print("VISUAL_LOD_PASS per-camera near/far sprites, continued distant route, nearby collisions independent of facing, wreck promotion, building boxes/collisions, runtime A/B switch; buildings=",buildings)
	level.queue_free()
	await process_frame
	quit()

