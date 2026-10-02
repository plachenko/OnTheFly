extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	scene.get_node("ProceduralCity").randomize_each_load = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var truck = scene.truck
	truck.set_physics_process(false)
	truck.network_controlled = true
	for existing in get_nodes_in_group("traffic_motion"):
		existing.set_physics_process(false)
	var city = scene.get_node("ProceduralCity")
	var car = city.traffic_car_scene.instantiate()
	car.model_scene = load("res://assets/kenney_city/cars_rigged/sedan.glb")
	car.parked = true
	city.get_node("Traffic").add_child(car)
	car.set_physics_process(false)
	car.global_position = Vector3(40, city.height_at(40, 40) + 0.09, 40)
	car.distant_mode = false
	car.collision_layer = car.active_collision_layer
	car.collision_mask = car.active_collision_mask
	await physics_frame
	var roof: Vector3 = car.get_node("CarCollision").to_global(Vector3(0, car.get_node("CarCollision").shape.size.y * 0.5, 0))
	assert(car.is_roof_landing(Vector3.UP, roof, Vector3.DOWN * 8, 3))
	assert(not car.is_roof_landing(Vector3.RIGHT, roof, Vector3.LEFT * 20, 3))
	assert(not car.is_roof_landing(Vector3.DOWN, roof, Vector3.UP * 8, 3))
	assert(not car.is_roof_landing(Vector3.UP, car.global_position, Vector3.DOWN * 8, 3))
	assert(not car.is_roof_landing(Vector3.UP, roof, Vector3.DOWN, 3))
	car.motion_vector = Vector3.DOWN * 9
	assert(not car.is_roof_landing(Vector3.UP, roof, Vector3.DOWN * 8, 3))
	car.motion_vector = Vector3.ZERO
	truck.network_controlled = false
	truck.rotation = Vector3.ZERO
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.05
	Input.parse_input_event(stick.duplicate())
	Input.flush_buffered_events()
	assert(truck.car_landing_direction() == Vector3.ZERO, "Small actual stick input is in deadzone")
	stick.axis_value = 0.6
	Input.parse_input_event(stick.duplicate())
	Input.flush_buffered_events()
	var analog_direction: Vector3 = truck.car_landing_direction()
	assert(analog_direction.x > 0 and analog_direction.length() < 1, "Actual stick magnitude remains analog")
	stick.axis_value = 0
	Input.parse_input_event(stick.duplicate())
	Input.flush_buffered_events()
	Input.action_press("reverse")
	assert(truck.car_landing_direction() == Vector3.BACK, "Keyboard reverse action selects backward launch")
	Input.action_release("reverse")
	truck.network_controlled = true
	for controls in [{}, {"accelerate": 1.0}, {"reverse": 1.0}, {"left": 1.0}, {"right": 1.0}, {"accelerate": 1.0, "left": 1.0}, {"reverse": 1.0, "right": 1.0}, {"right": 0.25}]:
		truck.network_controls = controls
		truck.rotation.y = 0.7
		var local := Vector3(float(controls.get("right", 0)) - float(controls.get("left", 0)), 0, float(controls.get("reverse", 0)) - float(controls.get("accelerate", 0))).limit_length(1)
		assert(truck.car_landing_direction().is_equal_approx(Basis(Vector3.UP, 0.7) * local))
	# Exercise actual production move_and_slide landing, then ensure next tick
	# retains its airborne lateral velocity rather than replacing it with speed.
	truck.network_controls = {"accelerate": 0.5, "left": 0.5}
	truck.global_position = roof + Vector3.UP * 1.0
	truck.velocity = Vector3.DOWN * 10
	truck.speed = 0
	await physics_frame
	for tick in 30:
		truck._physics_process(1.0 / 60.0)
		await physics_frame
		if car.exploded:
			break
	assert(car.exploded and car.disabled and car.hybrid.explosion_count == 1, "Actual roof landing must consume car")
	assert(truck.car_launch_active and truck.velocity.y > 0)
	var lateral: Vector3 = truck.car_launch_horizontal
	assert(lateral.length() > 0 and lateral.length() <= 14)
	truck._physics_process(1.0 / 60.0)
	assert(Vector3(truck.velocity.x, 0, truck.velocity.z).is_equal_approx(lateral))
	assert(not truck.try_car_landing_launch(car, Vector3.UP, roof, Vector3.DOWN * 10))
	assert(not car.consume_truck_landing() and car.hybrid.explosion_count == 1)
	var payload: Dictionary = car.get_hybrid_snapshot()
	assert(payload.exploded and payload.layer == 0 and payload.mask == 0 and payload.state == car.hybrid.State.EXPLODED)
	truck.network_controls = {}
	assert(truck.car_landing_direction() == Vector3.ZERO)
	var neutral_car = city.traffic_car_scene.instantiate()
	neutral_car.model_scene = car.model_scene
	neutral_car.parked = true
	city.get_node("Traffic").add_child(neutral_car)
	neutral_car.set_physics_process(false)
	neutral_car.global_position = car.global_position + Vector3.RIGHT * 12
	var neutral_roof: Vector3 = neutral_car.get_node("CarCollision").to_global(Vector3(0, neutral_car.get_node("CarCollision").shape.size.y * 0.5, 0))
	assert(not truck.try_car_landing_launch(neutral_car, Vector3.UP, neutral_roof, Vector3.DOWN * 8), "Cooldown also prevents boosts from another car")
	truck.car_landing_cooldown = 0
	assert(truck.try_car_landing_launch(neutral_car, Vector3.UP, neutral_roof, Vector3.DOWN * 8))
	assert(truck.velocity.is_equal_approx(Vector3.UP * 12), "No input gives upward-only launch")
	truck.car_landing_cooldown = 0
	assert(not truck.try_car_landing_launch(neutral_car, Vector3.UP, neutral_roof, Vector3.DOWN * 8), "Consumed car never launches twice even after cooldown")
	for tick in 600:
		neutral_car._physics_process(1.0 / 60.0)
		if neutral_car.is_queued_for_deletion():
			break
	assert(neutral_car.is_queued_for_deletion(), "Consumed car uses normal explosion cleanup")
	print("CAR LANDING PASS: actual production slide landing, roof/normal/relative-speed rejection, rotated cardinal/reverse/analog drive input, persistent bounded launch, one explosion, cooldown, snapshot")
	quit()

