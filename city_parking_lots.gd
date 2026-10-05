extends RefCounted

static func generate(city: Node3D) -> void:
	# Existing snapshots gain lots once; new snapshots keep compact colliders and metadata.
	var existing := city.get_node("ParkedCars").get_node_or_null("AsphaltParkingLots")
	if existing != null:
		if not existing is RigidBody3D: return
		# Old saves treated the lot container as a traffic car; rebuild its lots.
		existing.get_parent().remove_child(existing)
		existing.free()
	var lots := Node3D.new(); lots.name = "AsphaltParkingLots"; city.get_node("ParkedCars").add_child(lots)
	var occupied: Array[Rect2] = []
	for building in city.get_node("Buildings").get_children():
		for shape in building.find_children("*","CollisionShape3D",true,false):
			if not shape.shape is BoxShape3D: continue
			var center: Vector3 = shape.global_position
			var half: Vector3 = shape.shape.size*.5
			# Conservative world-space footprint also covers rotated models and fences.
			var basis: Basis = shape.global_basis
			var extent := Vector2(absf(basis.x.x)*half.x+absf(basis.z.x)*half.z,absf(basis.x.z)*half.x+absf(basis.z.z)*half.z)
			occupied.append(Rect2(Vector2(center.x,center.z)-extent,extent*2).grow(2))
	var rng := RandomNumberGenerator.new(); rng.seed = city.actual_seed+93471
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("d2d4c8")
	for cell in city.topology.blocks:
		await city.loading_checkpoint()
		if not city.topology.primary(Vector2(cell)) or city.topology.plot_kind(Vector2(cell)) != "grey": continue
		var polygons: Array = preload("res://city_islands.gd").inner_pieces(city,Vector2(cell))
		var bounds: Rect2 = city.topology.blocks[cell]
		var candidates: Array[Vector2] = []
		for z in range(ceili(bounds.position.y+8),floori(bounds.end.y-8),12):
			for x in range(ceili(bounds.position.x+8),floori(bounds.end.x-8),4):
				var point := Vector2(x,z)
				var footprint := Rect2(point-Vector2(1.8,5.2),Vector2(3.6,10.4))
				var valid := false
				for polygon in polygons:
					var inside := true
					for corner in [footprint.position,footprint.end,Vector2(footprint.position.x,footprint.end.y),Vector2(footprint.end.x,footprint.position.y)]:
						if not Geometry2D.is_point_in_polygon(corner,polygon): inside = false; break
					if inside: valid = true; break
				if not valid: continue
				for obstacle in occupied:
					if footprint.intersects(obstacle): valid = false; break
				if not valid or city.parking_near_gameplay_object(point): continue
				if absf(city.height_at(x,z-5)-city.height_at(x,z+5)) > 1.2: continue
				candidates.append(point)
		if candidates.size() < 4: continue
		var lot := Node3D.new(); lot.name = "Lot_%d_%d" % [cell.x,cell.y]
		lot.set_script(preload("res://parking_lot_visuals.gd")); lots.add_child(lot)
		var markings: Array[Transform3D] = []
		for i in candidates.size():
			var point: Vector2 = candidates[i]
			var position := Vector3(point.x,city.height_at(point.x,point.y)+city.sidewalk_height+.03,point.y)
			var bay := Node3D.new(); bay.name = "LotBay_%d_%d_%d" % [cell.x,cell.y,i]
			bay.position = position
			bay.set_meta("parking_axis",Vector3.FORWARD); bay.set_meta("serving",false)
			var vacant := i%4 == 0
			bay.set_meta("occupied",not vacant); bay.set_meta("lot_bay",true)
			city.get_node("ParkingSpaces").add_child(bay)
			# Narrow lines follow terrain rather than floating above slopes.
			for side in [-1,1]:
				for segment in 10:
					var stripe_at := Vector3(point.x+side*1.8,city.height_at(point.x+side*1.8,point.y+segment-4.5)+city.sidewalk_height+.045,point.y+segment-4.5)
					markings.append(Transform3D(Basis.IDENTITY,stripe_at))
			if vacant: continue
			var car := StaticBody3D.new(); car.set_script(preload("res://lot_parked_car.gd"))
			car.name = "Car_%d" % i; car.position = position
			car.model_key = ["sedan","suv","taxi"][rng.randi_range(0,2)]
			car.body_color = Color.from_hsv(rng.randf(),.35,.55)
			var collision := CollisionShape3D.new(); collision.shape = BoxShape3D.new(); collision.shape.size = Vector3(2.2,1.7,4.6); collision.position.y = .85
			car.add_child(collision); lot.add_child(car)
		var paint_mesh := BoxMesh.new(); paint_mesh.size = Vector3(.08,.025,1); paint_mesh.material = paint
		var multimesh := MultiMesh.new(); multimesh.transform_format = MultiMesh.TRANSFORM_3D; multimesh.mesh = paint_mesh
		multimesh.instance_count = markings.size()
		for i in markings.size(): multimesh.set_instance_transform(i,markings[i])
		var visual := MultiMeshInstance3D.new(); visual.name = "LotBayPaint"; visual.multimesh = multimesh; lot.add_child(visual)
