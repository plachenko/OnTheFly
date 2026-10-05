extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("PlayerProgress").save_path = "res://.godot/parking_lot_test_progress.cfg"
	var level = load("res://procedural_city.tscn").instantiate()
	root.add_child(level); current_scene = level
	while not level.is_loading_ready(): await process_frame
	level.truck.set_physics_process(false)
	var city = level.get_node("ProceduralCity")
	var _lots = city.get_node("ParkedCars/AsphaltParkingLots")
	var cars := get_nodes_in_group("lot_parked_cars")
	assert(not cars.is_empty())
	var vacant := 0
	for bay in city.get_node("ParkingSpaces").get_children():
		if bay.get_meta("lot_bay",false) and not bay.get_meta("occupied",true): vacant += 1
	assert(vacant > 0)
	var car = cars[0]
	level.camera.global_position = car.global_position+Vector3(0,8,12)
	level.camera.look_at(car.global_position+Vector3.UP)
	level.camera.make_current(); level.set_process(false)
	level.truck.global_position = car.global_position+Vector3(0,0,10)
	for frame in 180: await process_frame
	assert(car.card != null and not car.proxy.visible)
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://.godot/parking_lot_preview.png")
	var original: Vector3 = car.global_position
	car.receive_lot_contact(8)
	for frame in 5: await process_frame
	assert(car.hit_count == 1 and car.visual.position.length() > .001)
	assert(car.global_position == original)
	for frame in 60: await process_frame
	assert(car.visual.position == Vector3.ZERO)
	level.truck.global_position = Vector3(900,0,900)
	level.camera.global_position = Vector3(900,20,910)
	for frame in 30: await process_frame
	assert(car.card == null and car.proxy.visible)
	# Actual truck contact invokes the jolt without moving the static parked car.
	level.truck.global_transform = Transform3D(Basis.IDENTITY,car.global_position+Vector3(0,.2,5.5))
	level.truck.travel_heading = 0
	level.truck.manual_controls_enabled = false
	level.truck.deployed = false; level.truck.opening = 0
	level.truck.speed = 12; level.truck.velocity = Vector3(0,0,-12)
	level.truck.set_physics_process(true)
	var before: int = car.hit_count
	for frame in 80: await physics_frame
	assert(car.hit_count > before)
	assert(car.global_position == original)
	level.truck.set_physics_process(false)
	var snapshot := Node3D.new()
	var compact: Node = car.duplicate()
	snapshot.add_child(compact)
	root.get_node("CityStore").own_tree(snapshot,snapshot)
	assert(not compact.has_node("LotCarVisual"))
	assert(compact.get_child_count() == 1)
	var packed := PackedScene.new()
	assert(packed.pack(snapshot) == OK)
	var restored: Node = packed.instantiate()
	root.add_child(restored)
	assert(restored.get_child(0).proxy != null and restored.get_child(0).card == null)
	restored.free(); snapshot.free()
	var old_count := cars.size()
	await preload("res://city_parking_lots.gd").generate(city)
	assert(get_nodes_in_group("lot_parked_cars").size() == old_count)
	print("PARKING LOT PASS cars=",old_count," empty bays=",vacant," lazy sprites, jolt, release, cached map augmentation")
	quit()
