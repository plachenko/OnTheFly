extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)

func run() -> void:
	var world: Node = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	world.set_process(false)
	world.truck.set_physics_process(false)
	world.get_node("PatronManager").set_process(false)
	var waves: Node = world.service_waves
	world.service_window_seconds = 5.0
	world.service_pause_seconds = 30.0
	waves.tick(0.0)
	check(waves.rotation.size() == 6, "Flat map must start with six bays")
	var pad: Node3D = waves.rotation[0]
	waves.tick(2.0)
	check(is_equal_approx(pad.service_remaining, 3.0), "Unoccupied bays must count down from wave start")
	world.truck.parking_pad = pad
	world.truck.global_position = Vector3(pad.global_position.x, world.truck.spawn_transform.origin.y, pad.global_position.z)
	world.truck.deployed = true
	world.truck.opening = 1.0
	world.truck.speed = 0.0
	check(world.active_serving_pad() == pad, "Active wave should permit serving")
	pad.tick_service(1.0, true, true)
	check(is_equal_approx(pad.service_remaining, 3.0), "Opening shop must not reset or advance the shared clock")
	waves.tick(3.0)
	check(not waves.in_service and is_equal_approx(waves.remaining, 30.0), "Wave must enter the 30 second break")
	check(world.active_serving_pad() == null, "Break must prevent sales")
	var fees: int = world.total_pad_fees
	pad.tick_service(10.0, false, true)
	check(world.total_pad_fees == fees, "Closed waves must not charge expired-pad fees")
	waves.tick(30.0)
	check(waves.rotation.size() == 5 and pad.expired, "Used bay must retire at next wave")
	while waves.rotation.size() > 1:
		waves.mark_used(waves.rotation[0])
		waves.tick(5.0)
		waves.tick(30.0)
	check(waves.rotation.size() == 1, "Single player must retain one service bay")
	waves.mark_used(waves.rotation[0])
	waves.tick(5.0)
	waves.tick(30.0)
	check(waves.rotation.size() == 1, "Final bay must stay in rotation")
	print("SERVICE WAVES PASS: synchronized clocks, sale gating, breaks, no fees, used-bay retirement, one-bay floor")
	quit()
