extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/hybrid_car_demo.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_process(false)
	var car = scene.car
	car.set_physics_process(false)
	car.receive_impact(Vector3.RIGHT * 3, Vector3.RIGHT)
	for tick in 120:
		car._physics_process(1.0 / 60.0)
	assert(car.disabled_cue == null and car.collision_layer != 0, "Recoverable hits must remain collidable and uncued")
	car.receive_impact(Vector3.RIGHT * 11.8, Vector3.RIGHT)
	for tick in 80:
		car._physics_process(1.0 / 60.0)
	assert(car.state == car.State.DISABLED and car.explosion_count == 0)
	assert(car.collision_layer == 0 and car.collision_mask == 0)
	await physics_frame
	assert(car.driving_shape.disabled)
	var cue = car.disabled_cue
	assert(cue.start_count == 1 and cue.smoke.emitting and cue.overlays.size() >= 5)
	assert(cue.outline.grow and cue.outline.cull_mode == BaseMaterial3D.CULL_FRONT)
	car.ensure_disabled_cue()
	assert(car.disabled_cue == cue and cue.start_count == 1)
	for tick in 160:
		car._physics_process(1.0 / 60.0)
	assert(car.rollover_settled)
	var reference = preload("res://hybrid_car.gd").new()
	scene.add_child(reference)
	reference.set_physics_process(false)
	var untouched = reference.model_root.find_children("*", "MeshInstance3D", true, false)[0]
	assert(untouched.material_overlay == null and untouched.transparency == 0)
	cue.set_age(3.5)
	var early: float = cue.opacity
	cue.set_age(4.0)
	assert(cue.opacity > 0.45 and cue.opacity < 0.55 and cue.opacity < early)
	for item in cue.overlays:
		assert(item.mesh.material_overlay == cue.outline)
	for material in cue.fading_materials:
		assert(is_equal_approx(material.material.albedo_color.a, material.alpha * 0.5))
	assert(cue.outline.albedo_color.a == cue.opacity and cue.soot.albedo_color.a < 0.45)
	assert(untouched.material_overlay == null and untouched.transparency == 0)
	# Pass-through checked against actual physics query, not only exported flags.
	var probe := BoxShape3D.new()
	probe.size = Vector3(0.2, 0.2, 0.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform.origin = car.global_position + Vector3.UP
	for hit in scene.get_world_3d().direct_space_state.intersect_shape(query):
		assert(hit.collider != car, "Disabled car must not appear in player collision queries")
	cue.set_age(5.0)
	assert(cue.complete() and cue.opacity == 0 and not cue.smoke.emitting and not car.visual.visible)
	car._physics_process(1.0 / 60.0)
	assert(car.is_queued_for_deletion())
	await process_frame
	scene._process(1.0 / 60.0) # Empty demo remains usable after removal.
	scene.selected_model = 2
	scene.reset_car()
	assert(scene.car.model_index == 2 and scene.car.disabled_cue == null and scene.car.collision_layer != 0)
	print("DISABLED CUE PASS: recoverable unaffected, one outline/smoke, collision/query pass-through, smooth body/outline/smoke fade, instance isolation, final removal and demo model/reset")
	quit()
