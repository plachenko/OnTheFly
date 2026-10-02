extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab: Node = load("res://performance_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	assert(lab.instances.get_child_count() == 0)
	assert(not lab.has_node("ProceduralCity") and not lab.has_node("FoodTruck"))
	lab.count_input.value = 9
	await lab.spawn_batch()
	assert(lab.instances.get_child_count() == 9)
	assert(lab.instances.get_child(0).get_child(0) is MeshInstance3D)
	assert(lab.last_spawn_ms > 0)
	lab.clear_items()
	assert(lab.instances.get_child_count() == 0 and not lab.busy)
	# Every preset is a standalone usable resource, including actual prop scenes.
	lab.count_input.value = 1
	for index in range(1, lab.ITEMS.size() - 1):
		lab.picker.select(index)
		lab.scale_input.value = lab.ITEMS[index][2]
		await lab.spawn_batch()
		assert(lab.instances.get_child_count() == index)
		assert(lab.mesh_bounds(lab.instances.get_child(index - 1)).size.length() > 0)
	lab.clear_items()
	lab.picker.select(0)
	lab.scale_input.value = 1
	lab.physics_picker.select(3)
	lab.count_input.value = 4
	await lab.spawn_batch()
	var body: RigidBody3D = lab.instances.get_child(0)
	assert(not body.freeze and body.has_node("BoundsCollision"))
	var before: float = body.position.y
	await create_timer(0.5).timeout
	assert(body.position.y < before)
	lab.clear_items()
	lab.physics_picker.select(2)
	lab.staggered.button_pressed = true
	lab.chunk_input.value = 2
	lab.count_input.value = 12
	lab.spawn_batch()
	assert(lab.busy and lab.instances.get_child_count() == 2)
	lab.clear_items()
	await process_frame
	assert(not lab.busy and lab.instances.get_child_count() == 0)
	await lab.spawn_batch()
	assert(lab.instances.get_child_count() == 12 and not lab.busy)
	assert(lab.instances.get_child(0) is StaticBody3D)
	lab.clear_items()
	lab.picker.select(lab.ITEMS.size() - 1)
	lab.path_input.text = "res://missing.tscn"
	await lab.spawn_batch()
	assert(not lab.busy and lab.instances.get_child_count() == 0)
	lab.path_input.text = "res://scenes/cone.tscn"
	lab.count_input.value = 1
	await lab.spawn_batch()
	assert(lab.instances.get_child_count() == 1)
	lab.clear_items()
	lab.picker.select(0)
	lab.physics_picker.select(0)
	lab.count_input.value = 25
	lab.staggered.button_pressed = false
	await lab.spawn_batch()
	await create_timer(0.5).timeout
	assert(lab.menu.size.x < 460)
	print("PERFORMANCE LAB PASS: empty baseline, all presets/custom paths, batches, cancellation, render/static/dynamic modes and timed spawning")
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/performance_lab_preview.png")
	quit()
