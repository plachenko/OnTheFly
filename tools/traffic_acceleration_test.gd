extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var car = load("res://traffic_car.gd").new()
	var spring_velocity: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	car.spring_velocities = spring_velocity
	car.update_drive_speed(8.0, 0.1)
	assert(car.current_driving_speed > 0.0 and car.current_driving_speed < 0.1)
	assert(car.driving_acceleration <= car.acceleration_jerk * 0.1 + 0.001)
	car.update_driving_suspension(2.0, 0.1)
	assert(car.spring_velocities[1] > 0.0 and car.spring_velocities[3] < 0.0)
	for step in 500:
		car.update_drive_speed(8.0, 0.016)
	assert(is_equal_approx(car.current_driving_speed, 8.0))
	var starting_distance: float = car.braking_lookahead()
	car.update_drive_speed(0.0, 0.1)
	assert(car.current_driving_speed < 8.0 and car.current_driving_speed > 7.8)
	assert(absf(car.driving_acceleration) < car.braking_rate)
	car.spring_velocities.fill(0.0)
	car.update_driving_suspension(-3.0, 0.1)
	assert(car.spring_velocities[1] < 0.0 and car.spring_velocities[3] > 0.0)
	var distance := 0.0
	for step in 500:
		var previous: float = car.current_driving_speed
		car.update_drive_speed(0.0, 0.016)
		assert(car.current_driving_speed <= previous)
		distance += car.current_driving_speed * 0.016
	assert(car.current_driving_speed == 0.0)
	assert(distance < starting_distance)
	car.free()
	print("TRAFFIC ACCELERATION PASS: smooth startup, eased braking, full stop, load transfer, safe stopping distance")
	quit()
