extends "res://patron_manager.gd"

var pad_owners: Dictionary = {}

func _process(delta: float) -> void:
	if level.lobby_world: return
	if not NetworkSession.active or not multiplayer.is_server() or level.trucks.is_empty(): return
	if not NetworkSession.world_ready(): return
	spawn_patrons(delta)
	var ids: Array = level.trucks.keys()
	ids.sort()
	var available: Dictionary = {}
	for pad in level.get_node("ParkingPads").get_children():
		var owner: int = pad_owners.get(pad, 0)
		var candidates: Array = [owner] if ids.has(owner) else []
		for id in ids:
			if id != owner: candidates.append(id)
		owner = 0
		for id in candidates:
			var previous: int = level.select_player(id)
			var body: CharacterBody3D = level.truck
			var open_here: bool = not level.round_finished and pad != level.repair_pad and pad.contains_truck(body) and body.parking_pad == pad and body.deployed and body.opening > 0.99 and absf(body.speed) < 0.5 and body.health > 0.0
			if open_here: owner = id
			level.select_player(previous)
			if owner != 0: break
		pad_owners[pad] = owner
		var previous: int = level.select_player(owner if owner != 0 else level.local_player)
		pad.tick_service(delta, owner != 0 and level.has_ingredients(), owner != 0)
		if owner != 0 and not pad.expired and level.has_ingredients(): available[pad] = owner
		if pad.has_node("WorldMeter"): pad.get_node("WorldMeter").visible = owner == 0
		level.select_player(previous)
	for patron in level.get_node("Patrons").get_children():
		if patron.pad != null and (not available.has(patron.pad) or available[patron.pad] != patron.get_meta("player_id", 0)):
			patron.cancel_order()
		if patron.pad != null or not patron.can_be_attracted(): continue
		var nearest: Node3D
		var gap := INF
		for pad in available:
			if pad.patrons.size() >= pad.patron_capacity: continue
			var distance: float = patron.global_position.distance_to(pad.global_position)
			if distance <= pad.attraction_radius and distance < gap:
				nearest = pad
				gap = distance
		if nearest != null:
			var previous: int = level.select_player(available[nearest])
			var order := make_order(patron)
			if order.total > 0:
				patron.set_meta("player_id", available[nearest])
				patron.accept_order(nearest, order)
			level.select_player(previous)

func make_order(patron: Node) -> Dictionary:
	var portions: int = level.ingredients
	for waiting in level.get_node("Patrons").get_children():
		if waiting.get_meta("player_id", 0) == level.active_player and not waiting.order.is_empty():
			portions -= int(waiting.order.get("quantity", 0))
	var quantity := mini(clampi(ceili(patron.interest * maximum_order_items), 1, maximum_order_items), maxi(0, portions))
	var budget: int = patron.budget
	var total := 0
	var items: Array[String] = []
	for index in quantity:
		var affordable: Array = []
		for food in level.food_menu:
			if food != null and food.price > 0 and food.price <= budget: affordable.append(food)
		if affordable.is_empty(): break
		var food: Resource = affordable.pick_random()
		items.append(food.food_name)
		total += food.price
		budget -= food.price
	return {"items": items, "total": total, "quantity": items.size()}

func complete_order(patron: Node) -> bool:
	var id: int = patron.get_meta("player_id", 0)
	if not multiplayer.is_server() or not level.trucks.has(id): return false
	var previous: int = level.select_player(id)
	var result := super.complete_order(patron)
	level.select_player(previous)
	return result

func truck_for_patron(patron: Node) -> CharacterBody3D:
	return level.trucks.get(patron.get_meta("player_id", 0), level.local_truck)

func closest_truck(patron: Node3D) -> CharacterBody3D:
	var closest: CharacterBody3D = level.local_truck
	var gap := INF
	for body in level.trucks.values():
		var distance: float = patron.global_position.distance_squared_to(body.global_position)
		if distance < gap:
			closest = body
			gap = distance
	return closest
