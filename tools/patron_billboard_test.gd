extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/patron_billboard_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	assert(scene.sprites.size() == 8)
	assert(scene.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(scene.find_children("*", "AnimationPlayer", true, false).is_empty())
	var texture_bytes := 0
	for pair in scene.sprites[0].sheets.values():
		for texture in pair: texture_bytes += texture.get_image().get_data().size()
	print("PATRON_TEXTURE_BYTES ", texture_bytes)
	for sprite in scene.sprites:
		sprite.play("Run")
		sprite._process(0.3)
		assert(sprite.last_frame > 0)
		var phase: float = sprite.animation_elapsed
		var transform: Transform3D = sprite.transform
		scene.orbit += PI * 0.25
		scene.update_camera()
		assert(sprite.transform == transform and sprite.animation_elapsed == phase)
		sprite.play("Dodge")
		sprite._process(1.5)
		assert(sprite.last_frame == 11)
		assert(sprite.material_override.get_shader_parameter("atlas") == sprite.sheets[sprite.variant][0])
	if DisplayServer.get_name() != "headless":
		for sprite in scene.sprites: sprite.play("Walk")
		scene.orbit = 0.0
		scene.update_camera()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/patron_billboard_front.png")
		scene.orbit = PI
		scene.update_camera()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/patron_billboard_back.png")
	print("PATRON_BILLBOARD_PASS: eight sprites, zero skeletons/AnimationPlayers, frame progression, stable camera-local transforms, Dodge finish, shared atlases")
	quit()
