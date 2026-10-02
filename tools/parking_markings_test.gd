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
	for bay in city.get_node("ParkingSpaces").get_children():
		var mesh: Mesh = bay.get_node("ParkingTicks").mesh
		for point in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var world: Vector3 = point + bay.position
			assert(absf(world.y - city.terrain_surface_height_at(world.x, world.z) - 0.135) < 0.001)
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.position = pad.global_position + Vector3(0, 30, 0.01)
		camera.look_at(pad.global_position)
		camera.make_current()
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/parking_markings_preview.png")
	print("PARKING MARKINGS PASS: solid outlines follow asphalt and service hatch material configured")
	quit()
