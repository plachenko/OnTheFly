extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var comic := preload("res://comic_burst.gd")
	for word in ["HONK", "HOOOOONK", "BOOM!"]:
		var texture := comic.lettering(word)
		assert(texture.get_width() > 0)
		assert(not texture.get_image().is_invisible())
	var short_burst = comic.spawn(root, Vector3.ZERO, "HONK", 0.2, 3.0)
	var held_burst = comic.spawn(root, Vector3.ZERO, "HOOOOONK", 2.7, 5.5)
	var short_ref: WeakRef = weakref(short_burst)
	var held_ref: WeakRef = weakref(held_burst)
	await create_timer(0.6).timeout
	assert(short_ref.get_ref() == null)
	assert(held_ref.get_ref() != null)
	await create_timer(2.5).timeout
	assert(held_ref.get_ref() == null)
	print("COMIC BURST PASS: drawn textures, short cleanup, held duration, held cleanup")
	quit()
