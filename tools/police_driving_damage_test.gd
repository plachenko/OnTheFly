extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/police_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var truck = scene.truck
	truck.network_controlled = true
	truck.network_controls = {"accelerate": 1.0}
	var initial_health: float = truck.health
	for x in [12.0, 0.0, -12.0]:
		truck.global_position = Vector3(x, 0.15, 60)
		truck.rotation.y = 0.0
		truck.travel_heading = 0.0
		truck.speed = 0.0
		truck.velocity = Vector3.ZERO
		for frame in 300:
			await physics_frame
			assert(truck.health == initial_health, "Normal driving across sandbox roads/paint must not damage the truck")
	print("POLICE DRIVING DAMAGE PASS: 15 seconds across road edges, intersections and paint without pursuit loses no health")
	quit()
