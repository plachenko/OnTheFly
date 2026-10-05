extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var lab = load("res://scenes/handling_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	for frame in 30: await process_frame
	assert(lab.truck.billboard == null)
	assert(lab.truck.model.visible)
	assert(not lab.truck.get_node("TruckCollision").disabled)
	for key in lab.sliders: assert(not key.begins_with("sprite_"))
	lab.automatic = true
	lab.restart_run()
	for frame in 60:
		await physics_frame
		lab.step(1.0/60)
	assert(lab.truck.model.visible and lab.truck.billboard == null)
	assert(absf(lab.truck.speed) > .1)
	print("TRUCK 3D PASS: original mesh, collision, automated driving, dormant sprite controls")
	quit()
