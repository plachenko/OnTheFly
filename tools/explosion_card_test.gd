extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var card = preload("res://explosion_card.gd").spawn(root, Vector3.ZERO, 13.0)
	assert(card.sprite_frames.get_frame_count("default") == 16)
	assert(not card.sprite_frames.get_animation_loop("default"))
	assert(card.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	for index in 16:
		var texture: AtlasTexture = card.sprite_frames.get_frame_texture("default", index)
		assert(texture.region.position.x == (index % 4) * texture.region.size.x)
		assert(texture.region.position.y == floori(float(index) / 4.0) * texture.region.size.y)
	var reference: WeakRef = weakref(card)
	await create_timer(1.6).timeout
	assert(reference.get_ref() == null, "Animation must clean itself up")
	print("EXPLOSION CARD PASS: 16 ordered frames, camera billboard, one-shot playback, cleanup")
	quit()
