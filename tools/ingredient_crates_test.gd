extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var wood: Node
	var metal: Node
	var count := 0
	for child in scene.get_children():
		if child.has_method("collect_by_truck"):
			count += 1
			if child.reinforced: metal = child
			else: wood = child
	assert(count == 6)
	assert(scene.truck.booster_owned and scene.truck.boost_fuel > 0)
	scene.truck.boost_active = false
	assert(not metal.collect_by_truck(scene.truck))
	assert(scene.ingredients == 30 and metal.collision_layer == 1)
	assert(wood.collect_by_truck(scene.truck))
	assert(scene.ingredients == 40)
	assert(wood.collect_by_truck(scene.truck) and scene.ingredients == 40)
	scene.truck.boost_active = true
	assert(metal.collect_by_truck(scene.truck))
	assert(scene.ingredients == 60 and metal.collision_layer == 0)
	var capped = load("res://ingredient_crate.gd").new()
	scene.add_child(capped)
	scene.ingredients = 98
	assert(capped.collect_by_truck(scene.truck) and scene.ingredients == 100)
	var full = load("res://ingredient_crate.gd").new()
	scene.add_child(full)
	assert(not full.collect_by_truck(scene.truck) and not full.collected)
	scene.ingredients = 50
	full.position = Vector3(0,0,25)
	scene.truck.global_position = Vector3(0,.2,25)
	for frame in 6: await physics_frame
	assert(scene.ingredients == 60, "Driving into a wooden box must collect through the trigger")
	print("INGREDIENT_CRATES_PASS: six pickups, boost gate, single award, capacity clamp, full supply preserves box")
	quit()
