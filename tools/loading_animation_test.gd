extends SceneTree

var last_usec := 0
var worst_usec := 0
var frames := 0

func _initialize() -> void:
	run.call_deferred()

func monitor() -> void:
	var now := Time.get_ticks_usec()
	if last_usec > 0:
		worst_usec = maxi(worst_usec, now - last_usec)
		if now - last_usec > 50000:
			print("LOADING_LONG_FRAME %.1fms stage=%s" % [(now - last_usec) / 1000.0, root.get_node("LoadingScreen").status.text])
	last_usec = now
	frames += 1

func run() -> void:
	var loader = root.get_node("LoadingScreen")
	process_frame.connect(monitor)
	var success: bool = await loader.load_scene("res://procedural_city.tscn")
	assert(success)
	assert(loader.backdrop.scale == Vector2.ONE)
	assert(loader.backdrop.position == Vector2.ZERO)
	var elapsed: float = loader.backdrop.elapsed
	await create_timer(0.1).timeout
	assert(loader.backdrop.elapsed > elapsed)
	assert(not loader.panel.visible)
	print("LOADING_ANIMATION_PASS frames=%d worst_frame_ms=%.1f no zoom, animation continues through fade" % [frames, worst_usec / 1000.0])
	quit()
