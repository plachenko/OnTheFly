extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var truck = scene.truck
	truck.set_physics_process(false)
	var effects = truck.damage_effects
	effects.set_physics_process(false)
	truck.take_damage(5.0)
	assert(effects.meshes[0].material_overlay == effects.flash_material)
	effects.update_effects(0.7)
	assert(effects.meshes[0].material_overlay == null and not effects.smoke.emitting)
	truck.health = 24.0
	effects.update_effects(0.0)
	assert(effects.smoke.emitting)
	var slow_period: float = effects.blink_period
	truck.health = 1.0
	effects.update_effects(0.0)
	assert(effects.blink_period < slow_period * 0.25)
	truck.take_damage(2.0)
	assert(effects.exploded and truck.health == 0.0)
	assert(effects.meshes[0].material_overlay == effects.wreck_material)
	var bursts: int = scene.find_children("TruckExplosion*", "AnimatedSprite3D", false, false).size()
	effects.update_effects(0.1)
	assert(scene.find_children("TruckExplosion*", "AnimatedSprite3D", false, false).size() == bursts)
	assert(not effects.smoke.emitting)
	truck.health = truck.max_health
	effects.update_effects(0.7)
	assert(not effects.exploded and effects.meshes[0].material_overlay == null)
	print("TRUCK DAMAGE PASS: impact flash, critical smoke, accelerating blink, single explosion, repair clears effects")
	quit()
