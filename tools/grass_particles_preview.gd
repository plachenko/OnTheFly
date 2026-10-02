extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.time_of_day_mode = 1
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	scene.get_node("HUD").hide()
	scene.get_node("MobileControls").hide()
	var emitters: Array = city.get_node("Parks").find_children("GrassClumps*", "MultiMeshInstance3D", false, false)
	assert(not emitters.is_empty())
	var point: Vector3 = emitters[0].get_meta("grass_positions")[0]
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.global_position = point + Vector3(4, 2.5, 4)
	camera.look_at(point)
	camera.make_current()
	await create_timer(2.0).timeout
	RenderingServer.force_draw(false)
	get_root().get_texture().get_image().save_png("res://.godot/grass_preview.png")
	print("GRASS PREVIEW SAVED")
	quit()
