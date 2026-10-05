extends Node

# Kept across maps for this play session.
var infractions: int = 0
var prior_infractions: int = 0
var pursuing: bool = false
var stopped_time: float = 0.0
var hit_cooldown: float = 0.0

func willing_stop(cop: Node3D) -> bool:
	var truck: Node3D = cop.truck
	var point := Vector2(truck.global_position.x, truck.global_position.z)
	var roadside: bool = not cop.city.on_grid_road(point, -1.0) and cop.city.distance_to_diagonal_road(point) > cop.city.diagonal_road_width * 0.5
	return absf(truck.speed) < 0.5 and (cop.truck_is_in_parking_bay() or roadside)

func report_collision(victim: Node3D) -> void:
	if pursuing:
		return
	for cop in get_tree().get_nodes_in_group("traffic_motion"):
		var circle := cop.get_node_or_null("PoliceCircle")
		if circle == null or cop.disabled or circle.yellow_remaining <= 0.0:
			continue
		var distance := Vector2(victim.global_position.x - cop.global_position.x, victim.global_position.z - cop.global_position.z).length()
		if distance > circle.radius * 1.15:
			continue
		prior_infractions = infractions
		infractions += 1
		pursuing = true
		stopped_time = 0.0
		circle.pursuing = true
		cop.set_police_lights_enabled(true)
		cop.truck.message = "POLICE PURSUIT — stop at the roadside or in a parking bay to surrender."
		cop.truck.message_timer = 8.0
		return

func _physics_process(delta: float) -> void:
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	if not pursuing:
		return
	var found := false
	for cop in get_tree().get_nodes_in_group("traffic_motion"):
		var circle := cop.get_node_or_null("PoliceCircle")
		if circle == null or not circle.pursuing or cop.disabled:
			continue
		found = true
		var truck: Node3D = cop.truck
		if truck.get("police_parking") != null and truck.police_parking.active:
			stopped_time = 0.0
			break
		if willing_stop(cop) and truck.global_position.distance_to(cop.global_position) < 28.0:
			stopped_time += delta
			if stopped_time >= 2.0:
				resolve(truck, true)
		else:
			stopped_time = 0.0
		break
	if not found:
		pursuing = false

func police_hit(truck: Node3D) -> void:
	if truck.get("highway_transit") != null and truck.highway_transit.active: return
	if truck.get("police_parking") != null and truck.police_parking.active: return
	if not pursuing or hit_cooldown > 0.0:
		return
	hit_cooldown = 1.5
	var lightly_damaged: bool = truck.health / truck.max_health >= 0.75
	truck.take_damage(10.0)
	if lightly_damaged:
		resolve(truck, false)

func resolve(truck: Node3D, voluntary: bool, parking_fee: int = -1) -> void:
	var scene: Node = truck.get_parent()
	var fine := 0 if voluntary and prior_infractions == 0 else (25 if voluntary else 100)
	if parking_fee >= 0: fine = parking_fee
	var charged: int = mini(scene.money, fine)
	scene.money -= charged
	GameOptions.round_balance = scene.money
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	truck.message = "PULLED OVER — warning. Clean record; drive carefully!" if fine == 0 else "PULLED OVER — %s fine: $%d" % ["voluntary stop" if voluntary else "police stop", charged]
	truck.message_timer = 8.0
	pursuing = false
	stopped_time = 0.0
	release_cops()

func evade(truck: Node3D) -> void:
	pursuing = false
	stopped_time = 0.0
	truck.message = "CHASE EVADED — clear escape route!"
	truck.message_timer = 5.0
	release_cops(true)

func release_cops(green_return: bool = false) -> void:
	for cop in get_tree().get_nodes_in_group("traffic_motion"):
		var circle := cop.get_node_or_null("PoliceCircle")
		if circle == null or not circle.pursuing:
			continue
		circle.pursuing = false
		if green_return:
			circle.begin_green_return()
		cop.set_police_lights_enabled(false)
		# Resume a lane from the current position without snapping back to the old route.
		cop.travel_axis = Vector3.BACK if absf(cop.global_basis.z.z) >= absf(cop.global_basis.z.x) else Vector3.RIGHT
		cop.travel_axis *= signf(cop.global_basis.z.dot(cop.travel_axis))
		cop.progress = cop.position.dot(cop.travel_axis)
		cop.lane_center = cop.position - cop.travel_axis * cop.progress
		cop.turning = false
		cop.desired_passing_offset = 0.0
