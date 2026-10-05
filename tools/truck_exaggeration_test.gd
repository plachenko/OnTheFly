extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var lab = load("res://scenes/truck_exaggeration_lab.tscn").instantiate()
	root.add_child(lab); current_scene=lab
	for frame in 20: await process_frame
	assert(lab.truck.exaggeration.preview)
	assert(lab.selected_state == "brake")
	var collision: Transform3D = lab.truck.get_node("TruckCollision").transform
	var root_pose: Transform3D = lab.truck.transform
	lab.drag_pose=lab.selected_frame().duplicate()
	lab.drag_chassis(Vector2(40,-30))
	assert(lab.selected_frame().pitch > 9 and lab.selected_frame().roll > 0)
	for frame in 3: await physics_frame
	assert(lab.truck.transform == root_pose and lab.truck.get_node("TruckCollision").transform == collision)
	lab.truck.skeleton.force_update_all_bone_transforms()
	var wheels := []
	for bone in lab.truck.suspension_bones: wheels.append(lab.truck.skeleton.get_bone_global_pose(bone).origin)
	lab.edit_pose("roll",25)
	lab.edit_pose("pitch",-22)
	for frame in 3: await physics_frame
	lab.truck.skeleton.force_update_all_bone_transforms()
	for i in 4:
		var now: Vector3 = lab.truck.skeleton.get_bone_global_pose(lab.truck.suspension_bones[i]).origin
		assert(now.distance_to(wheels[i]) < .005,"Wheel contacts remain fixed under authored chassis motion")
	var module = load("res://truck_exaggeration.gd")
	assert(module.save_profile("res://assets/truck_exaggeration/example.json",module.template()) == OK)
	var rebound: Dictionary = module.sample(lab.document,"brake",.62)
	assert(rebound.pitch < 0)
	lab.scrub(.45); lab.add_key()
	assert(lab.selected_clip().keys.size() == 6)
	lab.retime_key(lab.selected_key,.48)
	assert(is_equal_approx(lab.selected_frame().time,.48))
	lab.delete_key(); assert(lab.selected_clip().keys.size() == 5)
	var path := "res://.godot/exaggeration_test.json"
	assert(lab.save_to(path) == OK)
	var reader = module.new()
	assert(reader.load_profile(path) == OK)
	for name in module.STATES:
		for channel in module.CHANNELS:
			assert(is_equal_approx(module.sample(reader.profile,name,.34)[channel],module.sample(lab.document,name,.34)[channel]))
	lab.truck.exaggeration_profile_path=path
	assert(lab.truck.reload_exaggeration_profile() == OK)
	var original: Dictionary = lab.document.duplicate(true)
	assert(lab.load_from(path) == OK)
	lab.document=original; lab.set_document(); lab.sync_editor()
	lab.live_physics=true; lab.running=true; lab.restart_run(); lab.set_document()
	for frame in 120: await physics_frame
	assert(absf(lab.truck.speed) > 1)
	assert(lab.truck.exaggeration.age > 0)
	lab.set_physics_process(false)
	var traces := []
	for enabled in [false,true]:
		lab.truck.exaggeration.enabled=enabled
		lab.restart_run()
		var trace := []
		for tick in 180:
			await physics_frame
			lab.step(1.0/60)
			trace.append([lab.truck.position.x,lab.truck.position.z,lab.truck.speed])
		traces.append(trace)
	for tick in 180:
		for channel in 3: assert(is_equal_approx(traces[0][tick][channel],traces[1][tick][channel]),"Exaggeration must not alter driving physics")
	lab.live_physics=false; lab.running=false; lab.select_clip(1); lab.edit_pose("pitch",12)
	lab.sync_editor()
	lab.set_physics_process(true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/exaggeration_lab.png")
	assert(module.validated({"version":2,"clips":{}}).is_empty())
	print("EXAGGERATION LAB PASS: dragging, peak/rebound, timeline retiming, JSON roundtrip/runtime reload, unchanged collision, planted tires, telemetry replay")
	quit()
