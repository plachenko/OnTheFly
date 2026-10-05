extends SceneTree

class TestCity extends Node3D:
	var topology = preload("res://city_topology.gd").new()
	var road_width := 16.0
	var left_open := true
	var right_open := true
	func road_branch_exists(_junction: Vector3, direction: Vector3) -> bool:
		return left_open if direction.x > 0 else right_open
	func height_at(_x: float, _z: float) -> float:
		return 0.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var city := TestCity.new()
	var car = load("res://traffic_car.gd").new()
	car.city = city
	car.travel_axis = Vector3.BACK
	car.lane_center = Vector3(60, 0, 0)
	car.progress = 0
	car.step_simple_route(0.1)
	assert(car.turn_intent == 0, "Interior junctions must be crossed straight")
	assert(car.route_end_center == Vector3(64, 0, 176), "End must use the closest street, not the first street")
	for preferred_left in [true, false]:
		for preferred_available in [true, false]:
			car.prefer_left_turn = preferred_left
			city.left_open = preferred_available if preferred_left else true
			city.right_open = true if preferred_left else preferred_available
			car.progress = 160
			car.turn_intent = 0
			car.turning = false
			car.route_end_cached = false
			car.step_simple_route(0.0)
			var expected := -1 if preferred_left == preferred_available else 1
			assert(car.turn_intent == expected, "Turn must prefer the spawn boolean and fall back to the open side")
			car.progress = 170
			car.step_simple_route(0.0)
			assert(car.turning)
			car.current_driving_speed = car.turn_length
			car.advance_turn(1.0)
			assert(not car.turning and not car.route_end_cached)
			assert(car.prefer_left_turn == preferred_left, "Preference must survive turns")
			car.travel_axis = Vector3.BACK
			car.lane_center = Vector3(60, 0, 0)
	city.left_open = false
	city.right_open = false
	car.progress = 160
	car.turn_intent = 0
	car.route_end_cached = false
	car.step_simple_route(0.1)
	assert(not car.route_has_exit and car.progress == 160, "No road on either side must not drive off the map")
	car.distant_mode = true
	car.update_proximity_mode()
	assert(not car.distant_mode and car.collision_layer == 1 and car.collision_mask == 1)
	car.free()
	root.add_child(city)
	current_scene = city
	var traffic := Node3D.new()
	city.add_child(traffic)
	var moving = load("res://scenes/traffic_car.tscn").instantiate()
	moving.travel_axis = Vector3.BACK
	moving.hybrid_reactions_enabled = false
	moving.horns_enabled = false
	moving.disabling_impact_speed = 1000.0
	traffic.add_child(moving)
	moving.set_physics_process(false)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 1)
	collider.shape = box
	wall.add_child(collider)
	city.add_child(wall)
	wall.position = Vector3(0, 2, 6)
	await physics_frame
	await physics_frame
	for tick in 60:
		moving.current_driving_speed = 8.0
		moving.update_car_pose(1.0 / 60.0)
		await physics_frame
	assert(moving.position.z > 1.0 and moving.position.z < 4.0, "Driving must advance and stop physically at a solid collider")
	assert(not moving.disabled and moving.collision_layer == 1)
	print("SIMPLE TRAFFIC PASS: straight interiors, closest edge road, both preferences, fallback, repeated turns, closed edge, active collisions, swept driving collision")
	quit()
