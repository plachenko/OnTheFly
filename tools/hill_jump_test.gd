extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var truck = scene.truck
	truck.set_physics_process(false)
	truck.health = truck.max_health
	truck.speed = 20.0
	truck.uphill_momentum = 3.0
	var launch: float = truck.hill_launch_speed(0.4, 0.18)
	assert(launch > 0.0 and launch <= truck.uphill_momentum)
	assert(truck.hill_launch_speed(0.4, 0.0) == 0.0, "Flat ground must not launch")
	assert(truck.hill_launch_speed(0.4, -0.18) == 0.0, "Downhill travel must not create upward momentum")
	assert(truck.hill_launch_speed(0.0, 0.18) == 0.0, "Climbing without a crest must not add a jump")
	truck.speed = 5.0
	assert(truck.hill_launch_speed(0.4, 0.18) == 0.0)
	truck.speed = 20.0
	truck.uphill_momentum = 0.0
	assert(truck.hill_launch_speed(0.4, 0.18) == 0.0, "A crest alone must not launch")
	truck.global_position += Vector3.UP * 100.0
	truck.velocity = Vector3.UP * 20.0
	truck.speed = 0.0
	truck.hill_jump_active = false
	truck._physics_process(1.0 / 60.0)
	assert(truck.velocity.y <= 0.0, "Unapproved airborne upward velocity must be suppressed")
	truck.hill_jump_active = true
	truck.velocity.y = 3.0
	truck._physics_process(1.0 / 60.0)
	assert(truck.velocity.y > 0.0 and truck.velocity.y < 3.0, "Approved jump must retain momentum and obey gravity")
	truck.reset_truck()
	assert(truck.uphill_momentum == 0.0 and not truck.hill_jump_active)
	print("HILL JUMP PASS: speed/slope/crest/momentum gates, bounded launch, stray ascent clamp, gravity, reset")
	quit()
