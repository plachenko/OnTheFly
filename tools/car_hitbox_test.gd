extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var city = scene.get_node("ProceduralCity")
	for path in city.traffic_car_models:
		var car = city.traffic_car_scene.instantiate()
		car.model_scene = load(path)
		city.get_node("Traffic").add_child(car)
		car.set_physics_process(false)
		var bounds: Array[AABB] = []
		car.collect_model_bounds(car.get_node("Visual"), Transform3D.IDENTITY, bounds)
		var shape = car.get_node("CarCollision").shape
		var hitbox := AABB(car.collision_center - shape.size * 0.5, shape.size)
		for box in bounds:
			assert(hitbox.position.x < box.position.x and hitbox.end.x > box.end.x)
			assert(hitbox.position.z < box.position.z and hitbox.end.z > box.end.z)
			assert(hitbox.end.y > box.end.y)
		assert(car.continuous_cd)
		print("HITBOX PASS ", path.get_file(), " size ", shape.size)
		car.free()
	quit()
