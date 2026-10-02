extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func block(parent: Node, at: Vector3, size: Vector3, sidewalk: bool = false) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.set_meta("sidewalk", sidewalk)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(scene)
	await process_frame
	for frame in 8:
		await physics_frame
	scene.set_process(false)
	city.set_physics_process(false)
	city.set_process(false)
	var truck = scene.truck
	truck.set_physics_process(false)
	city.get_node("Terrain/HillyGround").collision_layer = 0
	block(scene, Vector3(-220, -0.5, 0), Vector3(40, 1, 40))
	block(scene, Vector3(-220, 0.17, -6), Vector3(10, 0.34, 4), true)
	await physics_frame
	truck.global_position = Vector3(-220, 0.0, 0)
	truck.rotation = Vector3.ZERO
	truck.velocity = Vector3.DOWN * 10.0
	truck.move_and_slide()
	assert(truck.is_on_floor())
	var before: float = truck.global_position.y
	var health: float = truck.health
	truck.speed = 3.0
	assert(truck.try_climb_obstacle(Vector3(0, 0, -0.7)))
	assert(absf(truck.global_position.y - before - 0.34) < 0.02)
	assert(truck.health == health)
	assert(truck.velocity.y == 0.0)
	# Reproduce real per-frame approach distances, instead of a large one-shot
	# sweep that already reaches well past the curb edge.
	truck.global_position = Vector3(-220, 0.0, 0)
	truck.velocity = Vector3.DOWN * 10.0
	truck.move_and_slide()
	var climbed := false
	for frame in 60:
		var motion := Vector3(0, 0, -0.05)
		climbed = truck.try_climb_obstacle(motion) or climbed
		truck.velocity = Vector3(0, -0.1, -3.0)
		truck.move_and_slide()
		await physics_frame
	assert(climbed)
	assert(truck.global_position.y > before + 0.30)
	assert(truck.health == health)
	var camera_position: Vector3 = scene.camera.global_position
	scene.trigger_impact_shake(18.0)
	scene.update_impact_shake(0.016)
	assert(absf(scene.camera.h_offset) > 0.01)
	assert(scene.camera.global_position.is_equal_approx(camera_position))
	scene.update_impact_shake(1.0)
	assert(scene.impact_shake == 0.0 and scene.camera.h_offset == 0.0 and scene.camera.v_offset == 0.0)
	print("IMPACT/CURB PASS: full-height sidewalk climb, no damage or launch, camera shake and decay")
	quit()
