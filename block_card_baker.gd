extends RefCounted

const CELL := Vector2i(192, 192)

static func bake(tree: SceneTree, data: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 4000.0
	viewport.add_child(camera)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.TRANSPARENT
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.37, 0.45, 0.70) if data.night else Color.WHITE
	world.environment.ambient_light_energy = 0.28 if data.night else 0.7
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.15 if data.night else 0.8
	sun.light_color = Color(0.40, 0.52, 0.82) if data.night else Color.WHITE
	viewport.add_child(sun)
	for index in data.sections.size():
		var state: SceneState = data.sections[index].get_state()
		if state.get_node_count() < 2 or state.get_node_name(1) != &"Buildings": continue
		var section: Node3D = data.sections[index].instantiate()
		# Map-wide fence/helper roots also live in Buildings; they are not a block.
		for child in section.get_node("Buildings").get_children():
			if not child.has_node("KenneyBuilding"): child.free()
		section.process_mode = Node.PROCESS_MODE_DISABLED
		viewport.add_child(section)
		var pieces: Array[AABB] = []
		collect_bounds(section, Transform3D.IDENTITY, pieces)
		if pieces.is_empty(): section.free(); continue
		var bounds: AABB = pieces[0]
		for piece in pieces: bounds = bounds.merge(piece)
		var center := bounds.get_center()
		var extent := maxf(bounds.size.length(), 1.0) * 1.1
		camera.size = extent
		var atlas := Image.create(CELL.x * 8, CELL.y * 3, false, Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for row in 3:
			var elevation := deg_to_rad(row * 25.0)
			for angle in 8:
				var heading := angle * TAU / 8.0
				camera.position = center + Vector3(sin(heading) * cos(elevation), sin(elevation), cos(heading) * cos(elevation)) * extent * 2.0
				camera.look_at(center)
				await tree.process_frame
				await RenderingServer.frame_post_draw
				atlas.blit_rect(viewport.get_texture().get_image(), Rect2i(Vector2i.ZERO, CELL), Vector2i(angle * CELL.x, row * CELL.y))
		section.free()
		var baked_light := preload("res://block_cards.gd").light_level(world.environment.ambient_light_color, world.environment.ambient_light_energy, sun.light_color, sun.light_energy)
		result.append({"section": index, "center": center, "bounds": bounds, "extent": extent, "texture": ImageTexture.create_from_image(atlas), "baked_light": baked_light})
		print("BLOCK_CARD_BAKED section=", index)
	viewport.queue_free()
	return result

static func collect_bounds(node: Node3D, relative: Transform3D, pieces: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh: pieces.append(relative * node.mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D: collect_bounds(child, relative * child.transform, pieces)
