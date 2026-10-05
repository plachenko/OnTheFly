extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var truck = scene.truck
	var parking = truck.police_parking
	parking.city = scene.get_node("ProceduralCity")
	var bay = parking.city.get_node("ParkingSpaces/PulloverBay_Left_12")
	assert(parking.eligible(bay))
	bay.set_meta("occupied", true)
	assert(not parking.eligible(bay))
	bay.set_meta("occupied", false)
	bay.set_meta("serving", true)
	assert(not parking.eligible(bay))
	bay.set_meta("serving", false)
	truck.global_position = Vector3(0, 0.12, 24)
	truck.rotation.y = 0.0
	truck.turn_signal = 1
	assert(parking.choose_bay() != null and parking.choose_bay().global_position.x > 0.0)
	truck.turn_signal = -1
	assert(parking.choose_bay() == bay)
	scene.start_pursuit()
	var old_money: int = scene.money
	for frame in 800:
		await physics_frame
		if not root.get_node("PoliceDispatch").pursuing: break
	assert(not parking.active and not root.get_node("PoliceDispatch").pursuing)
	assert(truck.global_position.distance_to(Vector3(-6, 0.12, 12)) < 0.1)
	assert(scene.money == old_money - 25)
	assert(truck.speed == 0.0 and "PARKED SAFELY" in truck.message)
	assert(parking.toast_remaining > 0.0)
	assert(scene.cop.get_node("PoliceCircle").return_from_center)
	print("POLICE PARKING PASS: only empty nonservice bays; directional selection; automatic parking; one $25 fee; toast and green cop reset")
	quit()
