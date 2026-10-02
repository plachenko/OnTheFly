extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	var police = load("res://scenes/traffic_car.tscn").instantiate()
	police.model_scene = load("res://assets/kenney_city/cars_rigged/police.glb")
	city.get_node("Traffic").add_child(police)
	var circle = police.get_node("PoliceCircle")
	assert(circle.top_level and circle.mesh != null)
	assert(is_equal_approx(circle.radius, (police.get_node("CarCollision").shape.size.z - police.collision_padding * 2.0) * 1.5))
	police.global_position += Vector3(12, 5, 8)
	police.rotation.z = 1.2
	circle.update_ring()
	for point in circle.mesh.get_faces():
		var flat := Vector2(point.x - police.global_position.x, point.z - police.global_position.z)
		assert(absf(flat.length() - circle.radius * 0.5) <= 0.081)
		assert(point.y >= city.terrain_surface_height_at(point.x, point.z) + 0.14)
	var truck: Node3D = scene.get_node("FoodTruck")
	truck.set_physics_process(false)
	truck.global_position = police.global_position + Vector3(circle.radius * 0.5 + 0.2, 0, 0)
	assert(circle.truck_overlaps(), "Truck footprint should overlap before its center enters")
	circle._process(0.1)
	assert(circle.warning_blend > 0.0 and circle.warning_blend < 1.0)
	assert(circle.material_override.albedo_color != Color("ffe44a"))
	circle._process(0.5)
	assert(circle.material_override.albedo_color .is_equal_approx(Color("ffe44a")))
	circle.update_ring()
	var expanded: Vector3 = circle.mesh.get_faces()[0]
	assert(is_equal_approx(Vector2(expanded.x - police.global_position.x, expanded.z - police.global_position.z).length(), circle.radius * 1.15 - 0.08))
	truck.global_position += Vector3(50, 0, 0)
	assert(not circle.truck_overlaps())
	circle._process(2.0)
	assert(circle.material_override.albedo_color .is_equal_approx(Color("ffe44a")))
	circle._process(0.6)
	assert(circle.material_override.albedo_color .is_equal_approx(Color("42f578")))
	police.exploded = true
	circle._process(0.1)
	assert(not circle.visible)
	print("POLICE CIRCLE PASS: 50% larger, truck footprint overlap, smooth yellow/growth transition, 2.5-second hold and green reset")
	quit()
