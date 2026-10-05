extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	while not scene.is_loading_ready(): await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var city = scene.get_node("ProceduralCity")
	var checked := 0
	var biggest_old_error := 0.0
	for car in city.get_node("ParkedCars").get_children():
		if not car.has_method("align_to_landscape"): continue
		if car.disabled: continue
		for progress in [-90.0,-35.0,15.0,55.0,105.0]:
			car.progress = progress; car.turning = false
			car.update_car_pose(0.0)
			if car.hybrid: car.step_hybrid(1.0/60)
			var at: Vector3 = car.global_position
			biggest_old_error = maxf(biggest_old_error,absf(city.height_at(at.x,at.z)-city.road_visual_height_at(at.x,at.z)))
			check_clearance(car,city)
			car.distant_mode = true; car.step_distant_route(.2)
			check_clearance(car,city)
			var lod = car.get_node_or_null("TrafficVisualLOD")
			if lod != null:
				car.distant_elapsed = .1; lod.force_detail = false; lod._process(.016)
				assert(lod.global_position.y >= load("res://traffic_ground.gd").height(city,lod.global_position.x,lod.global_position.z)+.085)
			car.distant_mode = false; car.distant_elapsed = 0
			checked += 1
	assert(checked > 20)
	print("TRAFFIC LANDSCAPE PASS: ",checked," near/far/switch samples; previous surface mismatch=",biggest_old_error)
	quit()
func check_clearance(car: Node3D,city: Node3D) -> void:
	var collision = car.get_node("CarCollision")
	var half: Vector3 = collision.shape.size*.5
	for x in [-half.x,half.x]:
		for z in [-half.z,half.z]:
			var point: Vector3 = collision.global_transform*Vector3(x,-half.y,z)
			assert(point.y >= load("res://traffic_ground.gd").height(city,point.x,point.z)+.024)
