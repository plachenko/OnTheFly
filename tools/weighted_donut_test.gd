extends SceneTree

func _initialize() -> void: run.call_deferred()

func sample(lab: Node, mass: float) -> Dictionary:
	lab.restart_run()
	var truck: CharacterBody3D = lab.truck
	truck.vehicle_mass = mass
	truck.test_controls_enabled = true
	truck.test_controls = {"accelerate":1.0,"brake":1.0,"left":1.0}
	var peak_velocity := 0.0
	for i in 150:
		await physics_frame
		truck._physics_process(1.0/60.0)
		peak_velocity = maxf(peak_velocity, truck.donut_drift_velocity.length())
	var peak_sway: float = absf(truck.body_yaw_sway)
	truck.test_controls = {}
	for i in 240:
		await physics_frame
		truck._physics_process(1.0/60.0)
	assert(absf(truck.body_yaw_sway) < .002 and truck.donut_drift_velocity.length() < .002)
	return {"drift":peak_velocity,"sway":peak_sway}

func run() -> void:
	var lab: Node = load("res://scenes/handling_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_physics_process(false)
	var light := await sample(lab,1800)
	var heavy := await sample(lab,3600)
	assert(heavy.drift > light.drift * 1.4)
	assert(light.sway > .01 and heavy.sway > .01)
	assert(lab.sliders.has("donut_drift_speed") and lab.sliders.has("body_yaw_lag") and lab.sliders.has("rear_suspension_firmness"))
	print("WEIGHTED DONUT PASS: heavy drift=",heavy.drift," light=",light.drift,"; body sway and release settling; tuning sliders")
	quit()
