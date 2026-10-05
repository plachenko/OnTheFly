extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var level = load("res://procedural_city.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level); current_scene = level
	while not level.is_loading_ready(): await process_frame
	var city = level.get_node("ProceduralCity")
	for crossing in city.get_node("Crosswalks").get_children(): crossing.free()
	for car in city.get_node("Traffic").get_children(): car.free()
	var junction := Vector3(-64,0,48)
	var signals: Array = []
	for vertical in [false,true]:
		var crossing = load("res://scenes/crosswalk_signal.tscn").instantiate()
		crossing.crosses_vertical_road = vertical
		crossing.position = junction-(Vector3(0,0,city.crosswalk_setback) if vertical else Vector3(city.crosswalk_setback,0,0))
		city.get_node("Crosswalks").add_child(crossing)
		crossing.walk_allowed = true; crossing.vehicle_yellow = false
		signals.append(crossing)
	for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD]:
		for model in ["sedan","delivery"]:
			for distant in [false,true]:
				var car = load("res://scenes/traffic_car.tscn").instantiate()
				car.model_scene = load("res://assets/kenney_city/cars_rigged/%s.glb" % model)
				car.travel_axis = axis; car.intersection_turn_chance = 0; car.driving_speed = 12
				car.lane_center = junction+Vector3(-axis.z,0,axis.x)*9
				car.progress = -65
				city.get_node("Traffic").add_child(car)
				car.update_car_pose(0)
				car.current_driving_speed = 12; car.driving_acceleration = 0
				for tick in 1200:
					var dt := .2 if distant else 1.0/60
					if distant: car.step_distant_route(dt)
					else:
						car.update_drive_speed(car.signal_target_speed(),dt)
						car.update_car_pose(dt)
					if car.current_driving_speed < .01 and car.signal_stop_gap() < .05: break
				assert(car.signal_stop_gap() < .08,"Vehicle must reach the painted line instead of stopping early")
				assert(car.signal_stop_gap() >= 0)
				var boundary: float = preload("res://city_road_rules.gd").stop_boundary(city,axis,junction)
				var bumper: float = (junction-car.global_position).dot(axis)-car.front_bumper_distance()
				assert(absf(bumper-(boundary+.46)) < .09,"Bumper must align with the near edge of the painted stop line")
				for signal_node in signals: signal_node.walk_allowed = false
				assert(car.signal_target_speed() == car.driving_speed)
				for signal_node in signals: signal_node.walk_allowed = true
				car.free()
	print("TRAFFIC STOP LINE PASS: four directions, sedan and delivery, near and distant traffic, bumper alignment, green release")
	quit()
