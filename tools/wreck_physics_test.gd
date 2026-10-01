extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var car = scene.get_node("ProceduralCity/Traffic").get_child(0)
	car.set_physics_process(false)
	assert(car.disable_from_impact(12.0, Vector3.FORWARD, car.global_position))
	assert(car.linear_velocity.y >= 5.5 and car.linear_velocity.z < -7.0)
	assert(not car.axis_lock_angular_x and not car.axis_lock_angular_z)
	assert(car.angular_velocity.length() >= 3.0)
	car._physics_process(1.0)
	assert(car.boost_bounce(Vector3.RIGHT, 20.0))
	assert(car.linear_velocity.x >= 18.0 and car.linear_velocity.y == 9.0)
	assert(car.disabled_elapsed == 1.0, "Boost must not restart the fuse")
	assert(not car.boost_bounce(Vector3.RIGHT, 20.0), "Repeated contacts need a cooldown")
	car._physics_process(3.0)
	assert(car.exploded and car.collision_layer == 0)
	assert(not car.boost_bounce(Vector3.RIGHT, 20.0))
	car._physics_process(0.9)
	assert(car.is_queued_for_deletion(), "Wreck must fade out quickly")
	print("WRECK PASS: airborne launch, random spin, boost direction, fixed fuse, explosion, rapid cleanup")
	quit()
