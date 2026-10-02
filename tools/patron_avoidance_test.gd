extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_process(false)
	var truck = scene.get_node("FoodTruck")
	truck.set_physics_process(false)
	truck.global_position = Vector3(-220, 2, 0)
	truck.velocity = Vector3(0, 0, 8)
	var patrons: Array = []
	for style in [1, 2]:
		var patron = load("res://scenes/hungry_patron.tscn").instantiate()
		patron.manager = scene.get_node("PatronManager")
		patron.home_position = truck.global_position + Vector3(1, 0, 8)
		patron.avoidance_style = style
		scene.get_node("Patrons").add_child(patron)
		patron.set_physics_process(false)
		patron.global_position = patron.home_position
		patron.check_dodge()
		assert(patron.dodge_count == 1 and patron.dodge_direction.length() > 0.9)
		assert(patron.visual_anim.current_animation == ("Dodge" if style == 1 else "Run"))
		assert(patron.velocity.y > 0.0 if style == 1 else patron.velocity.y == 0.0)
		patrons.append(patron)
	var first = patrons[0]
	var second = patrons[1]
	assert(first.personal_space_velocity().dot(second.personal_space_velocity()) < 0.0)
	second.global_position += Vector3(0.5, 0, 0)
	assert(first.personal_space_velocity().x < 0.0 and second.personal_space_velocity().x > 0.0)
	second.global_position += Vector3(5, 0, 0)
	assert(first.personal_space_velocity().length() == 0.0)
	first.dodge_cooldown = 0.0
	first.dodge_count = 0
	truck.velocity = Vector3.ZERO
	first.check_dodge()
	assert(first.dodge_count == 0)
	assert(first.get_node("VisualVariants").scale == Vector3.ONE * 1.2)
	assert(is_equal_approx(first.get_node("CollisionShape3D").shape.height, 1.98))
	# Destination weighting adds progress without crossing the truck's path.
	var destination: Vector3 = first.global_position + Vector3(0, 0, 20)
	var averages: Array[float] = []
	for bias in [0.0, 1.0]:
		first.destination_dodge_chance = bias
		seed(2418)
		var forward_total := 0.0
		var minimum_z := 1.0
		var maximum_z := -1.0
		for i in range(300):
			var direction: Vector3 = first.choose_dodge_direction(Vector3.LEFT, -1.0, destination)
			assert(direction.x > 0.79 and is_zero_approx(direction.y))
			forward_total += direction.z
			minimum_z = minf(minimum_z, direction.z)
			maximum_z = maxf(maximum_z, direction.z)
		assert(maximum_z - minimum_z > 0.3)
		averages.append(forward_total / 300.0)
	assert(averages[1] > averages[0] + 0.15)
	first.avoidance_style = 0
	first.destination_dodge_chance = 0.6
	truck.velocity = Vector3(0, 0, 8)
	var hops := 0
	for i in range(300):
		first.dodge_cooldown = 0
		first.velocity = Vector3.ZERO
		first.check_dodge()
		if first.jumps_aside: hops += 1
		else: assert(is_zero_approx(first.velocity.y) and first.visual_anim.current_animation == "Run")
	assert(hops > 0 and hops < 60)
	# A wall blocks escape: no in-place jump is substituted for lateral movement.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 4, 20)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = first.global_position + Vector3(1.5, 1, 0)
	await physics_frame
	await physics_frame
	assert(first.choose_dodge_direction(Vector3.LEFT, -1.0, destination) == Vector3.ZERO)
	print("PATRON AVOIDANCE PASS: larger visuals/collider, varied lateral escapes, destination bias, mostly grounded reactions, blocked escape, stationary guard and separation")
	quit()
