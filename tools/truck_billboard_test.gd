extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var lab = load("res://scenes/handling_lab.tscn").instantiate()
	lab.get_node("FoodTruck").use_driving_billboard = true
	root.add_child(lab); current_scene = lab
	await process_frame
	lab.running = false; lab.truck.set_physics_process(false)
	var truck = lab.truck
	while truck.billboard == null: await process_frame
	var visual = truck.billboard
	for index in 300:
		await process_frame
		if visual.sprite_visibility > .99: break
	assert(visual.sprite_visibility > .99 and not truck.model.visible)
	assert(truck.get_node("TruckCollision").disabled == false)
	var original_road: Array = truck.road_height.duplicate()
	truck.road_height.assign([.4,.4,.4,.4])
	visual._process(0)
	assert(absf(visual.position.y-(visual.basis*(visual.center+Vector3.UP*.4)).y)<.001)
	truck.road_height.assign(original_road)
	visual._process(0)
	var body: Transform3D = truck.get_node("TruckCollision").transform
	truck.longitudinal_accel=12; truck.speed=8
	for index in 180:
		await process_frame
		if visual.state == "accelerate" and visual.sprite_visibility > .99: break
	assert(visual.state == "accelerate")
	truck.tire_brake=1
	for index in 180:
		await process_frame
		if visual.state == "brake": break
	assert(visual.state == "brake")
	truck.tire_brake=0; truck.stationary_drifting=true
	for index in 180:
		await process_frame
		if visual.state == "donut": break
	assert(visual.state == "donut")
	assert(truck.get_node("TruckCollision").transform.is_equal_approx(body))
	truck.deployed=true
	for index in 60: await process_frame
	assert(truck.model.visible and not visual.card.visible)
	truck.deployed=false; visual.force_3d=true
	for index in 30: await process_frame
	assert(visual.sprite_visibility < .001)
	visual.force_3d=false; truck.stationary_drifting=false; truck.speed=0; truck.longitudinal_accel=0
	for index in 180:
		await process_frame
		if visual.sprite_visibility > .99: break
	assert(visual.sprite_visibility > .99)
	var store=root.get_node("HandlingProfiles")
	assert(lab.sliders.has("sprite_animation_strength") and lab.sliders.has("sprite_lean_delay"))
	var values: Dictionary=store.snapshot(truck)
	values.sprite_animation_strength=.65; values.sprite_animation_time_scale=1.4
	assert(store.save_profile("Sprite test",values,"res://.godot/sprite_profiles.json")==OK)
	store.load_store("res://.godot/sprite_profiles.json")
	assert(is_equal_approx(store.profiles["Sprite test"].sprite_animation_strength,.65))
	store.apply(truck,store.profiles["Sprite test"])
	assert(is_equal_approx(truck.sprite_animation_time_scale,1.4))
	assert(visual.shared.size() <= 3)
	truck.speed=8; truck.longitudinal_accel=0; truck.lateral_accel=-6
	for index in 120:
		await process_frame
		if visual.state == "lean_left": break
	assert(visual.state == "lean_left")
	truck.lateral_accel=6
	for index in 120:
		await process_frame
		if visual.state == "lean_right": break
	assert(visual.state == "lean_right")
	truck.lateral_accel=0; truck.speed=0
	for index in 120:
		await process_frame
		if visual.state == "stop": break
	assert(visual.state == "stop")
	for index in 120: await process_frame
	assert(visual.state == "idle")
	var second=load("res://scenes/truck.tscn").instantiate()
	second.use_driving_billboard = true
	lab.add_child(second); second.set_physics_process(false); second.position=Vector3(12,.12,0)
	for index in 180:
		await process_frame
		if second.billboard != null and second.billboard.sprite_visibility>.99: break
	assert(second.billboard.loaded_state == "idle")
	assert(visual.references.get("idle",0)>=2)
	second.billboard.force_3d=true
	for index in 30: await process_frame
	assert(visual.references.get("idle",0)==1)
	second.queue_free()
	await process_frame
	assert(visual.loaded_state == "idle" and visual.shared.has("idle"))
	visual.force_3d=true
	for index in 40: await process_frame
	await RenderingServer.frame_post_draw
	var mesh_calls:=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	visual.force_3d=false
	for index in 120:
		await process_frame
		if visual.sprite_visibility>.99: break
	await RenderingServer.frame_post_draw
	var sprite_calls:=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("TRUCK DRAW CALLS 3D=",mesh_calls," billboard=",sprite_calls)
	assert(sprite_calls < mesh_calls)
	lab._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/truck_billboard_lab.png")
	print("TRUCK BILLBOARD PASS: telemetry states, 3D kitchen/cinematic swap, collider unchanged, shared cache bound, saved animation sliders")
	quit()
