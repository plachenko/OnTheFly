extends Node3D

@onready var truck: CharacterBody3D = $FoodTruck
@onready var camera: Camera3D = $FollowCamera
@onready var camera_clip_mask: ColorRect = $CameraClipMask/Mask
@onready var speed_label: Label = $HUD/Layout/SpeedLabel
@onready var status_label: Label = $HUD/Layout/ControlsPanel/StatusLabel
@onready var load_label: Label = $HUD/Layout/LoadLabel
@export_category("Follow Camera")
@export var orbit: float = 0.0
@export_range(0.18, 1.05) var pitch: float = 0.42
@export_range(8.0, 25.0) var distance: float = 14.5
@export var camera_smoothing: float = 7.5
@export var camera_height_smoothing: float = 2.5
@export var speed_camera_response: float = 3.0
@export var speed_camera_move_in: float = 3.0
@export var speed_fov_increase: float = 12.0
@export var camera_return_delay: float = 2.0
@export var camera_return_speed: float = 9.0
@export var camera_obstruction_padding: float = 0.35
@export var camera_obstruction_smoothing: float = 10.0
var camera_started: bool = false
@export var camera_spring_stiffness: float = 65.0
@export var camera_spring_damping: float = 9.0
var camera_spring_velocity: Vector3 = Vector3.ZERO
var camera_height_velocity: float = 0.0
@export_range(0.0, 1.0, 0.05) var camera_roll_strength: float = 0.15
@export_range(0.0, 5.0, 0.25) var camera_max_roll_degrees: float = 1.5
@export var camera_roll_response: float = 2.5
var camera_roll: float = 0.0
var camera_return_timer: float = 0.0
var camera_default_orbit: float = 0.0
var camera_default_pitch: float = 0.42
var camera_default_distance: float = 14.5
var camera_clip_amount: float = 0.0
var camera_follow_focus: Vector3 = Vector3.ZERO
var speed_camera_blend: float = 0.0
var camera_base_fov: float = 70.0
var kitchen_blend: float = 0.0
@export var joypad_camera_speed: float = 2.0
@onready var damage_bar: ProgressBar = $HUD/Layout/DamagePanel/DamageBar
@onready var damage_label: Label = $HUD/Layout/DamagePanel/DamageLabel
@export_category("Level Rules")
@export var level_duration_seconds: float = 180.0
@export var starting_money: int = 200
@export var earnings_target: int = 150
@export var food_menu: Array[Resource] = []
var money_earned: int = 0
var round_won: bool = false
@export_range(0,25) var starting_luck_range: int = 10
@export var repair_pad_path: NodePath = NodePath("ParkingPads/ParkingPad_04")
@onready var repair_pad: Area3D = get_node(repair_pad_path)
var remaining_time: float = 180.0
var money: int = 200
var total_pad_fees: int = 0
var starting_luck: int = 0
var carried_balance: bool = false
var round_finished: bool = false
@export_category("Ingredients")
@export_range(0, 100, 1) var starting_ingredients: int = 30
@export_range(1, 100, 1) var ingredient_capacity: int = 60
@export_range(1, 100, 1) var ingredient_refill_amount: int = 20
@export_range(0, 100, 1) var ingredient_refill_price: int = 20
var ingredients: int = 0
@export_category("Upgrade Shop")
@export var booster_price: int = 60
@export var boost_canister_price: int = 20
@export var boost_canister_fill: float = 50.0
@export var drifting_price: int = 70
@export var lift_kit_price: int = 80
@export var armor_price: int = 65
@export var fsd_price: int = 120

func upgrade_quote(kind: int) -> Dictionary:
	var prices = [booster_price,boost_canister_price,drifting_price,lift_kit_price,armor_price,fsd_price]
	if kind<0 or kind>5:
		return {"price":0,"available":false}
	var allowed: bool = [not truck.booster_owned,truck.booster_owned and truck.boost_fuel<truck.boost_capacity-.01,not truck.drift_owned,not truck.lift_owned,not truck.armor_owned,not truck.fsd_owned][kind]
	return {"price":maxi(0,prices[kind]),"available":allowed}

func buy_upgrade(kind: int) -> bool:
	if not can_repair():
		return false
	var quote = upgrade_quote(kind)
	if not quote.available or money<quote.price:
		return false
	money-=quote.price
	match kind:
		0: truck.booster_owned=true
		1: truck.boost_fuel=minf(truck.boost_capacity,truck.boost_fuel+boost_canister_fill)
		2: truck.drift_owned=true
		3: truck.lift_owned=true
		4: truck.armor_owned=true
		5: truck.fsd_owned=true
	truck.message="Upgrade purchased — $%d spent"%quote.price
	truck.message_timer=2.0
	return true

func can_repair() -> bool:
	var local_position = repair_pad.to_local(truck.global_position)
	var size: Vector3 = repair_pad.get_node("ParkingZone").shape.size
	var inside = absf(local_position.x)<size.x*.5 and absf(local_position.z)<size.z*.5
	return not round_finished and inside and truck.parking_pad == repair_pad and absf(truck.speed) < .5

func repair_quote(kind: int) -> Dictionary:
	var missing = maxf(0.0,truck.max_health-truck.health)
	var fraction: float = [1.0,.5,.25][clampi(kind,0,2)]
	var rate: float = [repair_pad.full_repair_rate,repair_pad.good_repair_rate,repair_pad.mid_repair_rate][clampi(kind,0,2)]
	var minimum: int = [repair_pad.full_minimum_price,repair_pad.good_minimum_price,repair_pad.mid_minimum_price][clampi(kind,0,2)]
	var restored = missing*fraction
	return {"amount":restored,"price":maxi(minimum,ceili(restored*rate)) if restored>.01 else 0}

func buy_repair(kind: int) -> bool:
	if kind < 0 or kind > 2 or not can_repair():
		return false
	var quote = repair_quote(kind)
	if quote.amount <= .01 or money < quote.price:
		return false
	money -= quote.price
	truck.health = minf(truck.max_health,truck.health+quote.amount)
	truck.message = "Repair complete — $%d spent"%quote.price
	truck.message_timer = 2.5
	return true

func recovery_transform() -> Transform3D:
	var result: Transform3D = truck.spawn_transform
	result.origin = Vector3(repair_pad.global_position.x,result.origin.y,repair_pad.global_position.z)
	return result

func advance_round(delta: float) -> void:
	if round_finished:
		return
	remaining_time = maxf(0.0,remaining_time-delta)
	if money_earned>=maxi(1,earnings_target) or remaining_time <= 0.0:
		round_won=money_earned>=maxi(1,earnings_target)
		round_finished = true
		truck.round_over = true
		truck.speed = 0.0
		truck.velocity = Vector3.ZERO
		truck.set_physics_process(false)

func charge_expired_pad_fee(pad: Area3D) -> void:
	var charge: int=mini(money,maxi(0,pad.expired_fee))
	money-=charge
	total_pad_fees+=charge
	get_node("/root/GameOptions").round_balance=money
	truck.message="RED PAD FEE  -$%d  •  Close the kitchen or move"%charge
	truck.message_timer=2.0
	$PatronManager.last_sale=truck.message

func ingredient_quote() -> Dictionary:
	return {"amount": mini(ingredient_refill_amount, maxi(0, ingredient_capacity - ingredients)), "price": ingredient_refill_price}

func buy_ingredients() -> bool:
	var quote := ingredient_quote()
	if not can_repair() or quote.amount <= 0 or money < quote.price:
		return false
	money -= quote.price
	ingredients += quote.amount
	truck.message = "Restocked +%d ingredient portions" % quote.amount
	truck.message_timer = 2.5
	return true

func has_ingredients() -> bool:
	return ingredients > 0

func active_serving_pad() -> Node3D:
	var pad=truck.parking_pad
	if round_finished or remaining_time<=0 or not has_ingredients() or not is_instance_valid(pad) or pad==repair_pad:return null
	if not pad.serving_enabled or pad.expired or not pad.contains_truck(truck):return null
	if truck.deployed and truck.opening>.99 and absf(truck.speed)<.5 and truck.health>0:return pad
	return null

func _ready() -> void:
	ingredients = clampi(starting_ingredients, 0, ingredient_capacity)
	var guides = preload("res://poi_guides.gd").new()
	guides.name = "POIGuides"
	$HUD/Layout.add_child(guides)
	var touch_controls = load("res://mobile_controls.gd").new()
	touch_controls.name = "MobileControls"
	add_child(touch_controls)
	camera_default_orbit = orbit
	camera_default_pitch = pitch
	camera_default_distance = distance
	camera_base_fov = camera.fov
	camera_follow_focus = truck.global_position + Vector3(0,1.8,0)
	remaining_time = maxf(0.0,level_duration_seconds)
	var bank=get_node("/root/GameOptions")
	carried_balance=bank.round_balance>=0
	if carried_balance:
		money=bank.round_balance
		starting_luck=0
	else:
		starting_luck = randi_range(-starting_luck_range,starting_luck_range)
		money = maxi(0,starting_money+starting_luck)
		bank.round_balance=money
	if "--smoke-test" in OS.get_cmdline_user_args():
		smoke_test()
	if "--preview" in OS.get_cmdline_user_args():
		preview()
	if "--suspension-preview" in OS.get_cmdline_user_args():
		suspension_preview()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit -= event.relative.x * .006
		pitch = clampf(pitch + event.relative.y * .004, .18, 1.05)
		camera_return_timer = camera_return_delay
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(8.0, distance-1.0)
			camera_return_timer = camera_return_delay
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(25.0, distance+1.0)
			camera_return_timer = camera_return_delay

func _process(delta: float) -> void:
	get_node("/root/GameOptions").round_balance=money
	advance_round(delta)
	if kitchen_blend < .1:
		var orbit_input := Input.get_axis("camera_right","camera_left")
		var pitch_input := Input.get_axis("camera_up","camera_down")
		if absf(orbit_input) > 0.08 or absf(pitch_input) > 0.08:
			camera_return_timer = camera_return_delay
			orbit += orbit_input * joypad_camera_speed * delta
			pitch = clampf(pitch + pitch_input * joypad_camera_speed * delta * .5,.18,1.05)
	if camera_return_timer > 0.0:
		camera_return_timer = maxf(0.0,camera_return_timer-delta)
	elif kitchen_blend < .1:
		var return_blend := 1.0-exp(-camera_return_speed*delta)
		orbit = lerp_angle(orbit,camera_default_orbit,return_blend)
		pitch = lerpf(pitch,camera_default_pitch,return_blend)
		distance = lerpf(distance,camera_default_distance,return_blend)
	var frame_transform: Transform3D = truck.model.global_transform * truck.skeleton.get_bone_global_pose(truck.chassis)
	var raw_focus: Vector3 = frame_transform.origin + Vector3(0,1.8,0)
	if camera_follow_focus.distance_to(raw_focus) > 25.0:
		camera_follow_focus = raw_focus
		camera_height_velocity = 0.0
		camera_spring_velocity = Vector3.ZERO
		camera_roll = 0.0
		camera_started = false
	var horizontal_blend: float = 1.0-exp(-camera_smoothing*delta)
	var spring_step: float = minf(delta, 0.1) / 6.0
	camera_follow_focus.x = lerpf(camera_follow_focus.x,raw_focus.x,horizontal_blend)
	camera_follow_focus.z = lerpf(camera_follow_focus.z,raw_focus.z,horizontal_blend)
	for substep in 6:
		camera_height_velocity += ((raw_focus.y - camera_follow_focus.y) * camera_height_smoothing * 18.0 - camera_height_velocity * 7.0) * spring_step
		camera_follow_focus.y += camera_height_velocity * spring_step
	var focus: Vector3 = camera_follow_focus
	var speed_ratio: float = clampf(absf(truck.speed)/maxf(1.0,truck.forward_speed),0.0,1.0)
	speed_camera_blend = lerpf(speed_camera_blend,speed_ratio,1.0-exp(-speed_camera_response*delta))
	camera.fov = camera_base_fov + speed_fov_increase*speed_camera_blend
	var yaw = truck.rotation.y + orbit
	var follow_distance: float = maxf(4.0,distance-speed_camera_move_in*speed_camera_blend)
	var offset = Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch)) * follow_distance
	var target = focus + offset
	var pad: Area3D = truck.parking_pad
	var kitchen_active = is_instance_valid(pad) and truck.deployed and absf(truck.speed) < .5
	var transition = pad.camera_transition_speed if is_instance_valid(pad) else 2.4
	kitchen_blend = move_toward(kitchen_blend,1.0 if kitchen_active else 0.0,delta*transition)
	if is_instance_valid(pad):
		target = target.lerp(truck.global_transform*pad.kitchen_camera_offset,kitchen_blend)
		focus = focus.lerp(truck.global_transform*pad.kitchen_focus_offset,kitchen_blend)
	damage_bar.value = 100.0*(1.0-truck.health/truck.max_health)
	damage_label.text = "DAMAGE %d%%" % roundi(damage_bar.value)
	if camera_started:
		for substep in 6:
			camera_spring_velocity += ((target - camera.global_position) * camera_spring_stiffness - camera_spring_velocity * camera_spring_damping) * spring_step
			camera.global_position += camera_spring_velocity * spring_step
	else:
		camera.global_position = target
		camera_started = true
	var face_hit := nearest_building_face(focus,camera.global_position)
	var building_clip := not face_hit.is_empty()
	var safe_distance := INF
	if building_clip:
		safe_distance = maxf(1.5,focus.distance_to(face_hit.position)-camera_obstruction_padding)
	else:
		var obstruction_query := PhysicsRayQueryParameters3D.create(focus,camera.global_position)
		obstruction_query.exclude = [truck.get_rid()]
		var obstruction := get_world_3d().direct_space_state.intersect_ray(obstruction_query)
		if not obstruction.is_empty():
			var obstacle: Node = obstruction.collider
			if not has_node("ProceduralCity") or obstacle.name == "HillyGround":
				safe_distance = maxf(1.5,focus.distance_to(obstruction.position)-camera_obstruction_padding)
	if safe_distance < INF:
		var visible_direction: Vector3 = camera.global_position-focus
		var safe_position: Vector3 = focus+visible_direction.normalized()*safe_distance
		camera.global_position = camera.global_position.lerp(safe_position,1.0-exp(-camera_obstruction_smoothing*delta))
		# Avoid storing spring momentum into an obstruction.
		var outward := visible_direction.normalized()
		camera_spring_velocity -= outward * maxf(0.0, camera_spring_velocity.dot(outward))
	camera.look_at(focus)
	var frame_right := frame_transform.basis.x.normalized()
	var frame_roll := asin(clampf(frame_right.y, -1.0, 1.0))
	var roll_limit := deg_to_rad(camera_max_roll_degrees)
	var target_roll := clampf(frame_roll * camera_roll_strength, -roll_limit, roll_limit) * (1.0 - kitchen_blend)
	camera_roll = lerpf(camera_roll, target_roll, 1.0 - exp(-camera_roll_response * delta))
	camera.rotate_object_local(Vector3.BACK, camera_roll)
	camera_clip_amount = move_toward(camera_clip_amount,0.88 if building_clip else 0.0,delta*6.0)
	camera_clip_mask.material.set_shader_parameter("strength",camera_clip_amount)
	speed_label.text = "%d km/h" % roundi(absf(truck.speed)*3.6)
	var loads = truck.corner_load
	var total: float = loads[0]+loads[1]+loads[2]+loads[3]
	load_label.text = "AXLE LOAD  Front %d%% / Rear %d%%\nSIDE LOAD  Left %d%% / Right %d%%" % [roundi((loads[0]+loads[1])/total*100),roundi((loads[2]+loads[3])/total*100),roundi((loads[0]+loads[2])/total*100),roundi((loads[1]+loads[3])/total*100)]
	if round_finished:
		status_label.text = "SUCCESS  •  Money target reached!" if round_won else "GAME OVER  •  N begins a new round."
	elif is_instance_valid(truck.parking_pad) and truck.parking_pad!=repair_pad and truck.parking_pad.expired and truck.deployed and truck.opening>.99:
		status_label.text="RED PAD FEE  •  Close up or drive to a green pad."
	elif truck.health <= 0.0:
		status_label.text = "TRUCK DISABLED  •  R / Y tows to the repair pad; repairs cost money."
	elif can_repair():
		status_label.text = "REPAIR PAD  •  Choose Repairs or Upgrades, or drive away. The timer keeps running."
	elif truck.health/truck.max_health < truck.critical_health_ratio:
		status_label.text = "CRITICAL DAMAGE  •  Health is draining. Reach the orange repair pad!"
	elif truck.message_timer > 0:
		status_label.text = truck.message
	elif truck.fsd_enabled:
		status_label.text = "FSD TO %s  •  Drive, brake, or steer to take over." % truck.get_node("FSDNavigator").destination_label()
	elif truck.deployed:
		status_label.text = "KITCHEN OPEN  •  E / A to pack up, or RT to close and drive."
	elif absf(truck.speed) < .5:
		status_label.text = "PARKED  •  E / A opens the kitchen. RT drives forward; LT reverses."
	else:
		status_label.text = "Explore the plaza and park in a marked bay."

func nearest_building_face(focus: Vector3, camera_position: Vector3) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	var side := truck.global_transform.basis.x.normalized() * 1.1
	for origin in [focus,focus + side,focus - side,focus + Vector3.UP * 0.9]:
		var query := PhysicsRayQueryParameters3D.create(origin,camera_position)
		query.collision_mask = 1 << 8
		query.hit_back_faces = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var distance_to_hit := focus.distance_to(hit.position)
			if distance_to_hit < nearest_distance:
				nearest_distance = distance_to_hit
				nearest = hit
	return nearest

func smoke_test() -> void:
	await get_tree().create_timer(.3).timeout
	var initial = truck.global_position
	Input.action_press("accelerate")
	await get_tree().create_timer(1.5).timeout
	assert(truck.corner_load[2] > truck.corner_load[0], "Acceleration must load the rear axle")
	assert(truck.spring_height[2] < truck.spring_height[0], "Rear springs must compress under acceleration")
	Input.action_release("accelerate")
	assert(truck.global_position.distance_to(initial) > 2.0, "Truck did not drive")
	Input.action_press("brake")
	await get_tree().create_timer(.3).timeout
	assert(truck.corner_load[0] > truck.corner_load[2], "Braking must load the front axle")
	await get_tree().create_timer(.7).timeout
	Input.action_release("brake")
	assert(absf(truck.speed) < .5, "Braking failed")
	Input.action_press("serve")
	await get_tree().physics_frame
	Input.action_release("serve")
	await get_tree().create_timer(2.0).timeout
	assert(truck.deployed and truck.opening > .99, "Serving panels did not open")
	assert(truck.awning >= 0 and truck.counter >= 0, "Missing panel bones")
	Input.action_press("serve")
	await get_tree().physics_frame
	Input.action_release("serve")
	await get_tree().create_timer(2.0).timeout
	assert(not truck.deployed and truck.opening < .01, "Panels did not close")
	truck.reset_truck()
	Input.action_press("accelerate")
	Input.action_press("left")
	await get_tree().create_timer(1.2).timeout
	assert(truck.corner_load[1] > truck.corner_load[0], "Left turn must load the outside right tires")
	assert(truck.spring_height[1] < truck.spring_height[0], "Outside spring must compress in a turn")
	truck.skeleton.force_update_all_bone_transforms()
	for bone in truck.spin_bones:
		var rest_center = truck.skeleton.get_bone_global_rest(bone).origin
		var live_center = truck.skeleton.get_bone_global_pose(bone).origin
		assert(Vector2(rest_center.x-live_center.x,rest_center.z-live_center.z).length() < .005, "Wheel drifted off its axle")
		assert(absf(rest_center.y-live_center.y) < .36, "Wheel exceeded suspension travel")
	Input.action_release("accelerate")
	Input.action_release("left")
	assert(truck.rotation.y > .05, "Steering failed")
	truck.rotation = Vector3.ZERO
	var saved_climb_height = truck.max_climb_height
	truck.max_climb_height = 0.0
	truck.global_position = Vector3(0, .12, -36)
	truck.speed = 12.0
	truck.steer = 0.0
	await get_tree().create_timer(1.0).timeout
	assert(truck.global_position.z > -39.0, "Truck crossed the boundary curb")
	assert(absf(truck.speed) < 2.0, "Collision did not slow the truck")
	truck.max_climb_height = saved_climb_height
	truck.reset_truck()
	assert(truck.global_position.distance_to(Vector3(0,.12,16)) < .01, "Reset failed")
	var cone: RigidBody3D = $Cones/Cone_01
	var cone_start = cone.global_position
	truck.global_position = Vector3(-21,.12,-23)
	truck.speed = 8.0
	Input.action_press("accelerate")
	await get_tree().create_timer(.9).timeout
	Input.action_release("accelerate")
	assert(cone.global_position.distance_to(cone_start) > .1, "Physical cone was not pushed by the truck")
	truck.reset_truck()
	print("SMOKE TEST PASS: driving, brake, steering, bone panels, curb collision, reset, rear acceleration load, front braking load, outside cornering load")
	get_tree().quit()

func preview() -> void:
	orbit = -2.3
	truck.deployed = true
	await get_tree().create_timer(2.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Playground_Preview.png")
	print("PREVIEW SAVED")
	get_tree().quit()

func suspension_preview() -> void:
	orbit = -2.3
	await get_tree().create_timer(.5).timeout
	Input.action_press("accelerate")
	Input.action_press("left")
	await get_tree().create_timer(1.8).timeout
	truck.set_physics_process(false)
	Input.action_release("accelerate")
	Input.action_release("left")
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Suspension_Preview.png")
	for i in 4:
		print(truck.corners[i], " wheel rest ",truck.skeleton.get_bone_global_rest(truck.suspension_bones[i]).origin," pose ",truck.skeleton.get_bone_global_pose(truck.suspension_bones[i]).origin," spring ",truck.spring_height[i])
	get_tree().quit()
