extends SceneTree

class TestCity extends Node3D:
	var topology = preload("res://city_topology.gd").new()
	var road_width := 16.0
	var blocked_direction := Vector3.ZERO
	var block_all := false
	var branch_checks := 0
	func height_at(_x: float, _z: float) -> float: return 0.0
	func road_branch_exists(point: Vector3, direction: Vector3) -> bool:
		branch_checks += 1
		if block_all or direction == blocked_direction: return false
		var target := point + direction * 25.0
		return topology.street_bounds.grow(1.0).has_point(Vector2(target.x, target.z))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var city := TestCity.new()
	level.add_child(city)
	var traffic := Node3D.new()
	city.add_child(traffic)
	# Near and distant cars share the same straight/edge controller.
	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		for preferred in [true, false]:
			var car = load("res://scenes/traffic_car.tscn").instantiate()
			car.hybrid_reactions_enabled = false
			car.travel_axis = axis
			car.lane_center = Vector3.ZERO
			car.prefer_left_turn = preferred
			traffic.add_child(car)
			car.set_physics_process(false)
			car.cache_route_end()
			var endpoint: Vector3 = car.route_end_center
			car.progress = endpoint.dot(axis) - 40.0
			city.branch_checks = 0
			for tick in 30: car.step_simple_route(1.0 / 60.0)
			assert(not car.turning and car.turn_intent == 0 and city.branch_checks == 0, "Straight travel must not scan intersections or cars")
			car.progress = endpoint.dot(axis) - 15.0
			car.step_simple_route(0.01)
			assert(car.turn_intent == (-1 if preferred else 1), "Spawn preference must select the edge turn")
			car.turn_intent = 0
			var left := Vector3(axis.z, 0, -axis.x)
			city.blocked_direction = left if preferred else -left
			car.step_simple_route(0.01)
			assert(car.turn_intent == (1 if preferred else -1), "Blocked preference must fall back to the other direction")
			city.blocked_direction = Vector3.ZERO
			car.progress = endpoint.dot(axis) - 8.0
			car.step_simple_route(0.01)
			assert(car.turning)
			car.current_driving_speed = car.driving_speed
			for tick in 500:
				car.step_simple_route(0.05)
				if not car.turning: break
			assert(not car.turning and car.travel_axis == (-left if preferred else left))
			assert(car.prefer_left_turn == preferred, "Fallback must preserve the spawn preference")
			car.free()
	# Neither branch available: no wrapping or driving off the map.
	var stopped = load("res://scenes/traffic_car.tscn").instantiate()
	stopped.hybrid_reactions_enabled = false
	stopped.travel_axis = Vector3.RIGHT
	stopped.progress = 115.0
	traffic.add_child(stopped)
	stopped.set_physics_process(false)
	city.block_all = true
	stopped.step_simple_route(0.1)
	assert(not stopped.route_has_exit and stopped.current_driving_speed == 0 and stopped.progress == 115.0)
	city.block_all = false
	stopped.free()
	# Exercise actual pose movement through an edge turn, not just route state.
	var walker = load("res://scenes/traffic_car.tscn").instantiate()
	walker.hybrid_reactions_enabled = false
	walker.horns_enabled = false
	walker.travel_axis = Vector3.RIGHT
	walker.lane_center = Vector3(0, 0, 4)
	walker.prefer_left_turn = true
	traffic.add_child(walker)
	walker.set_physics_process(false)
	walker.update_car_pose(0.0)
	for tick in 2400:
		walker._physics_process(1.0 / 60.0)
		assert(city.topology.street_bounds.grow(16.0).has_point(Vector2(walker.position.x, walker.position.z)), "Edge turns must keep physical movement within the road perimeter")
	assert(walker.travel_axis != Vector3.RIGHT and not walker.disabled, "Moving traffic must complete its turn without teleporting or crashing")
	walker.free()
	# Sweep an ordinary car into a solid body: it must not pass through it.
	var mover = load("res://scenes/traffic_car.tscn").instantiate()
	mover.hybrid_reactions_enabled = false
	mover.horns_enabled = false
	mover.travel_axis = Vector3.RIGHT
	mover.progress = 0.0
	traffic.add_child(mover)
	mover.set_physics_process(false)
	mover.update_car_pose(0.0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 4, 10)
	shape.shape = box
	wall.add_child(shape)
	traffic.add_child(wall)
	wall.position = Vector3(8, 2, 0)
	await physics_frame
	mover.current_driving_speed = 8.0
	for tick in 120:
		mover._physics_process(1.0 / 60.0)
		await physics_frame
	assert(mover.position.x < 7.5, "Physics sweep must block forward traffic at solid obstacles")
	assert(mover.disabled, "A fast collision must preserve the crash reaction")
	print("SIMPLE TRAFFIC PASS: straight travel, all headings/preferences, fallback, stable preference, dead end, swept collision and crash")
	level.queue_free()
	quit()
