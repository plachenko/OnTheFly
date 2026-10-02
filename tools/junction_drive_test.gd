extends SceneTree

func _initialize() -> void: run.call_deferred()

func drive(truck: CharacterBody3D, city: Node3D, start: Vector2, finish: Vector2) -> void:
	var direction := (finish - start).normalized()
	truck.global_position = Vector3(start.x, city.terrain_surface_height_at(start.x, start.y) + 0.8, start.y)
	truck.rotation = Vector3(0, atan2(-direction.x, -direction.y), 0)
	truck.health = truck.max_health
	truck.deployed = false
	truck.opening = 0
	truck.round_over = false
	truck.manual_controls_enabled = true
	truck.velocity = Vector3.ZERO
	truck.speed = 0
	for i in range(20):
		truck.velocity = Vector3.DOWN * 8
		truck.move_and_slide()
		await physics_frame
	Input.action_press("accelerate")
	var frames := ceili(start.distance_to(finish) / 18.0 * 60) + 2
	for i in range(frames):
		truck.speed = 18
		truck._physics_process(1.0 / 60)
		await physics_frame
	Input.action_release("accelerate")
	assert(is_equal_approx(truck.health, truck.max_health), "Road seam damaged truck: %s -> %s, health %s" % [start, finish, truck.health])
	var reached := Vector2(truck.position.x, truck.position.z)
	assert((reached - start).dot(direction) > start.distance_to(finish) * 0.9, "Invisible obstruction stopped truck at %s" % reached)

func run() -> void:
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.fixed_seed = 2602315664
	city.time_of_day_mode = 2
	city.traffic_car_count = 0
	city.parked_car_fraction = 0
	scene.get_node("PatronManager").maximum_patrons = 0
	root.add_child(scene)
	current_scene = scene
	while city.generating: await process_frame
	scene.set_process(false)
	var truck: CharacterBody3D = scene.truck
	truck.set_physics_process(false)
	await physics_frame
	await physics_frame
	assert(city.get_node("Roads").find_children("Asphalt", "MeshInstance3D", true, false).size() == 1)
	await drive(truck, city, Vector2(-68, 90), Vector2(-68, 130))
	await drive(truck, city, Vector2(100, -84), Vector2(140, -84))
	await drive(truck, city, Vector2(124, -36), Vector2(74, -86))
	# Ground tagging must not suppress impacts with real, visible obstacles.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 5, 0.5)
	shape.shape = box
	wall.add_child(shape)
	var visible_wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	visible_wall.mesh = mesh
	wall.add_child(visible_wall)
	root.add_child(wall)
	wall.global_position = Vector3(-68, city.terrain_surface_height_at(-68, 120) + 2.5, 120)
	truck.global_position = Vector3(-68, city.terrain_surface_height_at(-68, 108) + 0.2, 108)
	truck.rotation = Vector3(0, PI, 0)
	truck.impact_cooldown = 0
	Input.action_press("accelerate")
	for i in range(60):
		truck.speed = 18
		truck._physics_process(1.0 / 60)
		await physics_frame
	Input.action_release("accelerate")
	assert(truck.health < truck.max_health, "Visible wall impacts must still cause damage")
	wall.queue_free()
	if DisplayServer.get_name() != "headless":
		scene.get_node("HUD").hide()
		scene.get_node("MobileControls").hide()
		var camera: Camera3D = scene.camera
		camera.global_transform = Transform3D(Basis(Vector3(-0.17800449,0.022015,-0.98378342),Vector3(-0.52921277,0.84071869,0.11456858),Vector3(0.82960731,0.54102445,-0.13800108)), Vector3(120.09453,26.19007,-52.02346))
		camera.make_current()
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/junction_reproduction.png")
	print("JUNCTION DRIVE PASS: exact reported seed; north/south, east/west and diagonal junctions; no invisible obstruction or damage; one asphalt mesh/collider; visible wall still damages truck")
	quit()
