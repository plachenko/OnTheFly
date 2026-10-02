extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for seed_value in [12054, 42, 9876, -1]:
		var scene = load("res://procedural_city.tscn").instantiate()
		var city = scene.get_node("ProceduralCity")
		city.randomize_each_load = false
		city.fixed_seed = seed_value
		city.parking_bay_length = 11.4 if seed_value == 42 else (12.0 if seed_value == 9876 else 10.0)
		if seed_value == -1:
			city.parking_bay_count = 0
		root.add_child(scene)
		current_scene = scene
		scene.truck.set_physics_process(false)
		await process_frame
		while not scene.is_loading_ready(): await process_frame
		var truck = scene.truck
		if seed_value != -1:
			var bays: Array = city.get_node("ParkingSpaces").get_children()
			assert(bays.size() >= 12)
			for bay in bays:
				assert(bay.get_meta("parking_row", 0) == 0)
				var axis: Vector3 = bay.get_meta("parking_axis")
				var vertical := absf(axis.z) > 0.5
				var along: float = bay.position.z if vertical else bay.position.x
				var valid: Vector2 = bay.get_meta("parking_valid_range")
				assert(along >= valid.x - 0.001 and along <= valid.y + 0.001)
				var grid_start := -144.0 if vertical else -128.0
				var segment_start := floorf((along - grid_start) / 64.0) * 64.0 + grid_start
				var direction: float = axis.z if vertical else axis.x
				var junction := segment_start + (64.0 if direction > 0 else 0.0)
				var line_distance := maxf(city.stop_line_setback, city.crosswalk_setback + 4.5)
				var gap: float = absf(junction - along) - line_distance - 0.21 - city.parking_bay_length * 0.5 - 0.06
				assert(gap >= city.parking_bay_length - 0.001)
				var rules := preload("res://city_road_rules.gd")
				# Street coordinates use a different grid origin from intersections.
				var coordinate := roundf(((bay.position.x if vertical else bay.position.z) + (128.0 if vertical else 144.0)) / 64.0) * 64.0 - (128.0 if vertical else 144.0)
				var intersection := Vector3(coordinate, 0, junction) if vertical else Vector3(junction, 0, coordinate)
				var right := Vector3(-axis.z, 0, axis.x)
				if rules.approach_kind(axis, intersection, (bay.position - intersection).dot(right)) != "unmarked":
					var arrow_gap: float = absf(junction - along) - 26.0 - city.parking_bay_length * 0.5 - 0.06
					assert(arrow_gap >= city.parking_bay_length - 0.001)
				assert(bay.has_node("ParkingTicks"))
				assert(not bay.get_node("ParkingBaySurface").visible)
				assert(bay.find_children("BaySideLine*", "MeshInstance3D", false, false).is_empty())
			print("VALID PARKING BAYS: ", bays.size())
		var found := false
		for bay in city.get_node("ParkingSpaces").get_children():
			if Vector2(truck.position.x, truck.position.z).distance_to(Vector2(bay.position.x, bay.position.z)) < 0.01:
				assert(not bay.get_meta("occupied", false))
				var surface: MeshInstance3D
				for child in bay.get_children():
					if child is MeshInstance3D and not child.is_queued_for_deletion():
						surface = child
						break
				assert(surface != null)
				var size := surface.mesh.get_aabb().size
				var truck_shape: BoxShape3D = truck.get_node("TruckCollision").shape
				assert(minf(size.x, size.z) > truck_shape.size.x + 0.5)
				assert(maxf(size.x, size.z) > truck_shape.size.z + 2.0)
				var axis: Vector3 = bay.get_meta("parking_axis")
				assert((-truck.global_basis.z).dot(axis) > 0.99)
				found = true
		if seed_value == -1:
			assert(truck.parking_pad.contains_truck(truck))
		else:
			assert(found)
		assert(truck.spawn_transform.origin.is_equal_approx(truck.global_position))
		print("PARKING SPAWN PASS seed ", seed_value)
		scene.free()
	var plaza = load("res://main.tscn").instantiate()
	root.add_child(plaza)
	current_scene = plaza
	plaza.truck.set_physics_process(false)
	assert(plaza.truck.parking_pad.contains_truck(plaza.truck))
	print("PARKING SPAWN PASS plaza")
	quit()
