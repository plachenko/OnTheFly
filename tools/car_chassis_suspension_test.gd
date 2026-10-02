extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	scene.get_node("ProceduralCity").randomize_each_load = false
	root.add_child(scene)
	await process_frame
	var tested := 0
	for car in scene.get_node("ProceduralCity/Traffic").get_children():
		car.hybrid_reactions_enabled = false # Existing suspension fallback remains supported.
		car.set_physics_process(false)
		var skeleton: Skeleton3D = car.spring_skeleton
		assert(skeleton != null)
		car.spring_offsets[0] = 0.2
		car.spring_offsets[1] = 0.12
		car.spring_offsets[2] = 0.1
		car.spring_offsets[3] = -0.12
		car.spring_offsets[4] = -0.1
		car.apply_chassis_suspension_pose()
		skeleton.force_update_all_bone_transforms()
		var chassis: int = car.spring_bones[0]
		assert(skeleton.get_bone_global_pose(chassis).origin.distance_to(skeleton.get_bone_global_rest(chassis).origin) > 0.1)
		for index in range(1, 5):
			var bone: int = car.spring_bones[index]
			assert(skeleton.get_bone_global_pose(bone).origin.distance_to(skeleton.get_bone_global_rest(bone).origin) < 0.001)
			assert(skeleton.get_bone_global_pose(bone).basis.is_equal_approx(skeleton.get_bone_global_rest(bone).basis))
		car.get_node("VehicleLights").sync_with_chassis()
		assert(car.get_node("VehicleLights").global_position.distance_to(car.global_position) > 0.05)
		tested += 1
	assert(tested > 0)
	print("CHASSIS SUSPENSION PASS: ", tested, " cars, body heave/pitch, planted wheel bones, attached lights")
	quit()
