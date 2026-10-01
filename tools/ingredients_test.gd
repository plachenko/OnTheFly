extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_process(false)
	scene.truck.set_physics_process(false)
	var manager = scene.get_node("PatronManager")
	manager.set_process(false)
	var pad = scene.get_node("ParkingPads/ParkingPad_01")
	scene.truck.parking_pad = pad
	scene.truck.global_position = pad.global_position
	scene.truck.speed = 0.0
	scene.truck.deployed = true
	scene.truck.opening = 1.0
	scene.ingredients = 0
	assert(scene.active_serving_pad() == null)
	var remaining: float = pad.service_remaining
	pad.tick_service(1.0, true)
	assert(not pad.service_started and pad.service_remaining == remaining)
	assert("INGREDIENTS" in pad.get_node("ServiceSign").text)
	scene.ingredients = 1
	assert(scene.active_serving_pad() == pad)
	var patron = manager.patron_scene.instantiate()
	patron.manager = manager
	scene.get_node("Patrons").add_child(patron)
	patron.set_physics_process(false)
	patron.interest = 1.0
	patron.budget = 100
	var order: Dictionary = manager.make_order(patron)
	assert(order.quantity == 1)
	patron.accept_order(pad, order)
	assert(manager.make_order(patron).quantity == 0, "Queued orders must reserve supply")
	patron.service_elapsed = 10.0
	patron.global_position = patron.queue_target()
	assert(manager.complete_order(patron))
	assert(scene.ingredients == 0 and scene.active_serving_pad() == null)
	scene.truck.parking_pad = scene.repair_pad
	scene.truck.global_position = scene.repair_pad.global_position
	scene.money = 100
	assert(scene.buy_ingredients())
	assert(scene.ingredients == scene.ingredient_refill_amount)
	assert(scene.money == 100 - scene.ingredient_refill_price)
	scene.ingredients = scene.ingredient_capacity
	assert(not scene.buy_ingredients())
	scene.ingredients = 0
	scene.money = 0
	assert(not scene.buy_ingredients())
	print("INGREDIENTS PASS: empty-pad lock, timer guard, order reservations, consumption, restock, capacity and affordability")
	quit()
