extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.time_of_day_mode = 1
	root.add_child(scene)
	current_scene = scene
	while city.generating: await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	var pad = scene.get_node("ParkingPads/CityServingPad_01")
	assert(pad.get_node("ServiceSurface").material_override.get_shader_parameter("parking_ticks"))
	var ordinary: Node3D
	for bay in city.get_node("ParkingSpaces").get_children():
		if not bay.get_meta("serving", false):
			ordinary = bay
			var strokes: Array = bay.get_meta("parking_mark_segments")
			assert(strokes.size() == 8, "Current isolated street bays need four broken corners")
			for stroke in strokes:
				assert(stroke[0].distance_to(stroke[1]) < 1.01, "No continuous bay perimeter")
		var mesh: Mesh = bay.get_node("ParkingTicks").mesh
		for point in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var world: Vector3 = point + bay.position
			assert(absf(world.y - city.terrain_surface_height_at(world.x, world.z) - 0.135) < 0.001)
	# Deliberate layouts verify adjacency independently of today's sparse spawns.
	var painter := preload("res://city_parking_paint.gd")
	for vertical in [true, false]:
		for side in [-1.0, 1.0]:
			var group := Node3D.new()
			city.add_child(group)
			var bays: Array[Node3D] = []
			for along in [-60.0, -49.8, -39.6, -24.0]:
				var bay := Node3D.new()
				bay.position = Vector3(side * 6.1, 0, along) if vertical else Vector3(along, 0, side * 6.1)
				bay.set_meta("parking_axis", Vector3.BACK if vertical else Vector3.RIGHT)
				bay.set_meta("parking_side", side)
				group.add_child(bay)
				bays.append(bay)
			var first := painter.segments(city, bays[0], vertical, 3.4, 10)
			var middle := painter.segments(city, bays[1], vertical, 3.4, 10)
			var last := painter.segments(city, bays[2], vertical, 3.4, 10)
			var isolated := painter.segments(city, bays[3], vertical, 3.4, 10)
			assert(first.size() == 8 and middle.size() == 4 and last.size() == 4 and isolated.size() == 8)
			# Exactly two capped Ts per shared boundary, emitted by one owner.
			for strokes in [first, middle]:
				var caps := 0
				for stroke in strokes:
					if is_equal_approx(stroke[0].distance_to(stroke[1]), 1.8): caps += 1
				assert(caps == 2)
			assert(painter.neighbors(city, bays[3], vertical, 10) == [null, null])
			bays[1].set_meta("serving", true)
			assert(painter.segments(city, bays[0], vertical, 3.4, 10).size() == 8)
			assert(painter.neighbors(city, bays[0], vertical, 10) == [null, null])
			# Near spacing across a junction still must not join the runs.
			bays[0].position = Vector3(side * 6.1, 0, -81) if vertical else Vector3(-65, 0, side * 6.1)
			bays[1].position = Vector3(side * 6.1, 0, -70.8) if vertical else Vector3(-54.8, 0, side * 6.1)
			bays[1].set_meta("serving", false)
			assert(painter.neighbors(city, bays[0], vertical, 10) == [null, null])
			group.free()
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		var camera := Camera3D.new()
		scene.add_child(camera)
		for car in city.get_node("ParkedCars").get_children(): car.hide()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 18
		camera.position = ordinary.global_position + Vector3(0, 120, 0)
		camera.look_at(ordinary.global_position, Vector3.FORWARD)
		camera.make_current()
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/parking_markings_preview.png")
		# Preview a deliberate adjacent series; production spawn positions stay intact.
		city.get_node("ParkingSpaces").hide()
		city.get_node("Traffic").hide()
		var preview := Node3D.new()
		city.add_child(preview)
		var series: Array[Node3D] = []
		for along in [-60.0, -49.8, -39.6]:
			var bay := Node3D.new()
			bay.position = Vector3(6.1, 0, along)
			bay.set_meta("parking_axis", Vector3.FORWARD)
			bay.set_meta("parking_side", 1.0)
			preview.add_child(bay)
			series.append(bay)
		var white := StandardMaterial3D.new()
		white.albedo_color = Color(0.94, 0.94, 0.88)
		for bay in series:
			city.add_street_parking_markings(bay, true, white, white, 3.4, 10)
		camera.size = 36
		camera.position = Vector3(6.1, 150, -49.8)
		camera.look_at(Vector3(6.1, 0, -49.8), Vector3.FORWARD)
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/parking_series_preview.png")
	print("PARKING MARKINGS PASS: isolated L corners, shared capped Ts, run ends/gaps/serving breaks in both orientations and curb sides; terrain projection and service hatch preserved")
	quit()
