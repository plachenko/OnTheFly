extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var controls = scene.get_node("MobileControls")
	assert(controls.enabled, "Run with -- --touch-controls")
	var left = controls.buttons[0]
	var drive = controls.buttons[4]
	touch(0, left.position, true)
	touch(1, drive.position, true)
	await process_frame
	assert(Input.is_action_pressed("left") and Input.is_action_pressed("accelerate"), "Steering and pedal must work together")
	touch(0, left.position, false)
	await process_frame
	assert(not Input.is_action_pressed("left") and Input.is_action_pressed("accelerate"), "Fingers must release independently")
	paused = true
	await process_frame
	await process_frame
	assert(not Input.is_action_pressed("accelerate"), "Pausing must release pedals")
	touch(1, drive.position, false)
	paused = false
	await process_frame
	var old_orbit: float = scene.orbit
	touch(2, Vector2(640, 400), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(670, 400)
	drag.relative = Vector2(30, 0)
	root.push_input(drag, true)
	assert(scene.orbit < old_orbit, "Swipe must orbit camera")
	touch(2, drag.position, false)
	for screen_size in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(640, 360)]:
		root.size = screen_size
		await process_frame
		controls.arrange()
		var viewport_rect := root.get_visible_rect()
		for button in controls.buttons:
			var half_size: Vector2 = button.shape.size * button.scale * 0.5
			assert(viewport_rect.encloses(Rect2(button.position - half_size, half_size * 2.0)), "Touch button must fit screen")
		var layout: Control = scene.get_node("HUD/Layout")
		assert(viewport_rect.encloses(Rect2(layout.position, layout.size * layout.scale)), "HUD must fit screen")
	root.size = Vector2i(1280, 800)
	await process_frame
	var second = controls.buttons[4]
	touch(3, second.position, true)
	assert(Input.is_action_pressed("accelerate"))
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not Input.is_action_pressed("accelerate"), "Focus loss must release touch actions")
	touch(3, second.position, false)
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var traffic = scene.get_node("ProceduralCity/Traffic")
	var car = traffic.get_child(0)
	for other in traffic.get_children():
		other.set_physics_process(false)
		if other != car:
			other.disabled = true
	car.obey_crosswalks = false
	car.intersection_turn_chance = 0.0
	car.turn_intent = 0
	car.turning = false
	car.progress = 0.0
	car.update_car_pose(0.0)
	var side := Vector3(-car.travel_axis.z, 0, car.travel_axis.x)
	scene.truck.global_position = car.global_position + car.travel_axis * 6.0 + side * 3.0
	car._physics_process(0.1)
	assert(car.progress > 0.0, "Partial truck obstruction must not stop traffic")
	car.progress = 0.0
	scene.truck.global_position = car.global_position + car.travel_axis * 6.0
	car._physics_process(0.1)
	assert(car.progress > 0.0, "Traffic must attempt forward motion toward truck")
	var leader = traffic.get_child(1)
	leader.disabled = false
	leader.turning = false
	leader.travel_axis = car.travel_axis
	leader.lane_center = car.lane_center
	leader.global_position = car.global_position + car.travel_axis * 5.0
	assert(car.should_follow_car(), "Spacing behind another car must remain intact")
	leader.disabled = true
	assert(car.disable_from_impact(8.0, car.travel_axis, car.global_position), "Impact must still disable car")
	var stopped_progress: float = car.progress
	car._physics_process(0.1)
	assert(car.progress == stopped_progress and not car.freeze, "Disabled car must switch to physics")
	print("MOBILE / TRAFFIC PASS: multitouch, independent/pause/focus release, swipe camera, portrait/landscape fit, partial/full obstruction, car spacing, impact physics")
	quit()
