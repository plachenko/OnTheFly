extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var dispatch = root.get_node("PoliceDispatch")
	dispatch.set_physics_process(false)
	scene.truck.set_physics_process(false)
	scene.cop.set_physics_process(false)
	var escape = scene.escape_ring
	escape.set_physics_process(false)
	scene.start_pursuit()
	escape.begin_chase()
	var circle = scene.cop.get_node("PoliceCircle")
	circle._process(0.5)
	assert(circle.red_blend == 1.0 and circle.chase_radius_multiplier == 2.8)
	var health: float = scene.truck.health
	escape.tick_chase(3.0)
	assert(scene.truck.health == health)
	escape.tick_chase(1.5)
	assert(scene.truck.health < health)
	# Six equal-radius arc sections away from roads, converging near a street.
	escape.merge = 0.0
	var scattered: ArrayMesh = escape.build_ring(true)
	assert(scattered.get_faces().size() == 6 * 20 * 6)
	assert(is_equal_approx(Vector2(scattered.get_faces()[0].x, scattered.get_faces()[0].z).length(), escape.radius - 0.18))
	# Reverse motion along the guide works despite facing the opposite direction.
	escape.merge = 1.0
	escape.progress = 1.0
	escape.heading = Vector2(0, 1)
	escape.street_axis = Vector2(0, 1)
	escape.street_center = Vector2.ZERO
	escape.contact_cooldown = 0.0
	scene.truck.speed = -8.0
	for step in 60:
		scene.truck.global_position.z += 1.0
		escape.tick_chase(0.1)
	assert(not dispatch.pursuing and escape.fade_remaining > 0.0)
	assert(scene.money == 500 and scene.truck.speed == -8.0)
	assert(circle.return_from_center and circle.return_blend == 0.0)
	escape._process(2.0)
	circle._process(2.0)
	assert(escape.fade_remaining == 0.0 and circle.return_blend > 0.0)
	circle._process(1.2)
	assert(circle.return_blend == 1.0)
	# Contact prevents an otherwise completed escape.
	scene.start_pursuit()
	escape.begin_chase()
	escape.progress = 20.0
	escape.merge = 1.0
	escape.heading = Vector2(0, 1)
	escape.street_axis = Vector2(0, 1)
	escape.street_center = Vector2.ZERO
	scene.truck.global_position = scene.cop.global_position
	escape.tick_chase(0.1)
	assert(dispatch.pursuing and escape.progress == 0.0 and escape.contact_cooldown > 0.0)
	print("POLICE ESCAPE PASS: larger red rings, grace/drain, six equal-radius blue arcs, reverse escape, no fine, fade/green return, contact blocks escape")
	quit()
