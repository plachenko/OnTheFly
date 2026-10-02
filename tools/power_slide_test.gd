extends SceneTree

func _initialize() -> void:
	var truck = load("res://truck.gd").new()
	truck.speed = 10.0
	truck.update_power_slide(1.0, 1.0, 0.0, true, 0.1)
	assert(truck.power_slide_active and truck.power_slide_blend > 0.0)
	truck.update_power_slide(1.0, 1.0, 0.0, true, 0.1)
	assert(truck.power_slide_blend == 1.0)
	truck.update_power_slide(0.0, -1.0, 0.0, true, 0.1)
	assert(not truck.power_slide_active and truck.power_slide_blend > 0.0)
	for step in 10:
		truck.update_power_slide(0.0, 0.0, 0.0, true, 0.1)
	assert(truck.power_slide_blend == 0.0)
	truck.speed = 0.0
	truck.update_power_slide(1.0, 1.0, 0.0, true, 0.1)
	assert(not truck.power_slide_active)
	truck.speed = 10.0
	truck.update_power_slide(1.0, 1.0, 0.0, false, 0.1)
	assert(not truck.power_slide_active)
	for step in 25:
		truck.update_power_slide(1.0, 1.0, 0.0, true, 0.1)
	assert(not truck.power_slide_active and truck.power_slide_blend == 0.0)
	truck.free()
	print("POWER SLIDE PASS: brake/steer activation, momentum blend, gradual grip recovery, stationary/airborne guard and timeout")
	integration.call_deferred()

func integration() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	var truck = scene.get_node("FoodTruck")
	for frame in 12:
		await physics_frame
	truck.speed = 10.0
	Input.action_press("brake")
	Input.action_press("right")
	var largest_slip := 0.0
	for frame in 35:
		await physics_frame
		largest_slip = maxf(largest_slip, absf(wrapf(truck.rotation.y - truck.travel_heading, -PI, PI)))
	Input.action_release("brake")
	Input.action_release("right")
	assert(largest_slip > 0.25, "Truck should rotate while its momentum continues sideways")
	for frame in 40:
		await physics_frame
	assert(truck.power_slide_blend == 0.0)
	print("POWER SLIDE DRIVING PASS: sideways momentum, countersteer-ready rotation, grip recovery")
	quit()
