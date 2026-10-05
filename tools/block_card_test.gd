extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var data = load("res://generated_city/default_city.res")
	assert(not data.block_cards.is_empty())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var cards = load("res://block_cards.gd").new()
	viewport.add_child(cards)
	var card: Dictionary = data.block_cards[0]
	var city := Node3D.new()
	viewport.add_child(city)
	var section: Node3D = data.sections[int(card.section)].instantiate()
	var buildings := section.get_node("Buildings")
	section.remove_child(buildings)
	root.get_node("CityStore").clear_owners(buildings)
	city.add_child(buildings)
	section.free()
	var single = data.duplicate()
	single.block_cards.clear()
	single.block_cards.append(card)
	var installed = load("res://block_cards.gd").install_loaded(city, single)
	assert(not installed.entries[0].models.is_empty(), "Background baking must find the existing block models")
	assert(installed.entries[0].models.size() == buildings.get_child_count())
	city.free()
	cards.add_card(card)
	var bounds: AABB = card.bounds
	var model := Node3D.new()
	viewport.add_child(model)
	var models: Array[Node3D] = [model]
	camera.position = Vector3(bounds.get_center().x, bounds.get_center().y, bounds.end.z + 95.0)
	camera.look_at(card.center)
	cards.update_entry(cards.entries[0], camera)
	assert(is_equal_approx(cards.entries[0].material.get_shader_parameter("opacity"), 1.0), "Pending card must cover missing geometry")
	cards.section_loaded(card.section, models)
	assert(is_equal_approx(cards.entries[0].material.get_shader_parameter("opacity"), 1.0), "Loading must hand off smoothly")
	cards.entries[0].handoff = 0.0
	cards.update_entry(cards.entries[0], camera)
	assert(is_equal_approx(cards.entries[0].material.get_shader_parameter("opacity"), 0.5))
	assert(model.visible, "Geometry must exist underneath throughout the fade")
	camera.position.z = bounds.end.z + 111.0
	cards.update_entry(cards.entries[0], camera)
	assert(not model.visible and cards.entries[0].card.visible)
	var diagnostics := root.get_node("PerformanceDiagnostics")
	var enabled: bool = diagnostics.rendering_lod_enabled
	diagnostics.rendering_lod_enabled = false
	cards.update_entry(cards.entries[0], camera)
	assert(model.visible and not cards.entries[0].card.visible)
	diagnostics.rendering_lod_enabled = enabled
	camera.position.z = bounds.end.z + 79.0
	cards.update_entry(cards.entries[0], camera)
	assert(model.visible and not cards.entries[0].card.visible)
	if DisplayServer.get_name() != "headless":
		camera.position.z = bounds.end.z + 111.0
		cards.update_entry(cards.entries[0], camera)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := viewport.get_texture().get_image()
		var pixels := 0
		for y in picture.get_height():
			for x in picture.get_width():
				if picture.get_pixel(x, y).a > 0.2: pixels += 1
		assert(pixels > 100, "Card shader must draw real building silhouettes")
		DirAccess.make_dir_recursive_absolute("res://.godot/block-card-test")
		picture.save_png("res://.godot/block-card-test/card.png")
		card.texture.get_image().save_png("res://.godot/block-card-test/atlas.png")
		print("BLOCK CARD RENDER PASS pixels=", pixels)
		# The same captured texture must darken and turn blue with the live scene.
		var level := Node3D.new()
		viewport.add_child(level)
		var lighting_city := Node3D.new()
		level.add_child(lighting_city)
		cards.reparent(lighting_city)
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.light_energy = 0.8
		level.add_child(sun)
		var world := WorldEnvironment.new()
		world.name = "WorldEnvironment"
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color.TRANSPARENT
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color.WHITE
		world.environment.ambient_light_energy = 0.7
		level.add_child(world)
		cards.refresh_lighting()
		var day_tint: Vector3 = cards.entries[0].material.get_shader_parameter("scene_tint")
		assert(day_tint.is_equal_approx(Vector3.ONE))
		await process_frame
		await RenderingServer.frame_post_draw
		var day := visible_color(viewport.get_texture().get_image())
		world.environment.ambient_light_color = Color(0.37, 0.45, 0.70)
		world.environment.ambient_light_energy = 0.28
		sun.light_color = Color(0.40, 0.52, 0.82)
		sun.light_energy = 0.16
		cards.refresh_lighting()
		var night_tint: Vector3 = cards.entries[0].material.get_shader_parameter("scene_tint")
		assert(night_tint.x < day_tint.x * 0.5 and night_tint.z > night_tint.x)
		await process_frame
		await RenderingServer.frame_post_draw
		var night_picture := viewport.get_texture().get_image()
		var night := visible_color(night_picture)
		assert(night.length() < day.length() * 0.75, "Night cards must render darker")
		assert(night.z / maxf(night.x, 0.001) > day.z / maxf(day.x, 0.001), "Night cards must reflect blue lighting")
		night_picture.save_png("res://.godot/block-card-test/night.png")
		print("BLOCK CARD LIGHTING PASS day=", day, " night=", night)
	viewport.queue_free()
	await process_frame
	print("BLOCK CARD TEST PASS")
	quit()

func visible_color(picture: Image) -> Vector3:
	var color := Vector3.ZERO
	var count := 0
	for y in picture.get_height():
		for x in picture.get_width():
			var pixel := picture.get_pixel(x, y)
			if pixel.a <= 0.2: continue
			color += Vector3(pixel.r, pixel.g, pixel.b)
			count += 1
	return color / maxf(count, 1.0)
