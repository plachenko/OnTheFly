extends Node3D

@onready var truck: CharacterBody3D = $FoodTruck
@onready var camera: Camera3D = $FollowCamera
@onready var camera_clip_mask: ColorRect = $CameraClipMask/Mask
@onready var speed_label: Label = $HUD/Layout/SpeedLabel
@onready var heading_label: Label = $HUD/Layout/HeadingLabel
@onready var camera_pose_label: Label = $HUD/Layout/CameraPoseLabel
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
signal loading_intro_finished
var loading_intro_active := false
var loading_intro_elapsed := -1.0
var loading_intro_truck_physics := true
var loading_intro_hud_visible := true

func begin_loading_intro() -> void:
	loading_intro_active = true
	loading_intro_elapsed = -1.0
	loading_intro_truck_physics = truck.is_physics_processing()
	loading_intro_hud_visible = $HUD.visible
	truck.set_physics_process(false)
	$HUD.hide()
	camera.make_current()
	update_loading_intro(0.0)

func play_loading_intro() -> void:
	loading_intro_elapsed = 0.0

func update_loading_intro(delta: float) -> void:
	if loading_intro_elapsed >= 0.0:
		loading_intro_elapsed += delta
	var fraction := clampf(loading_intro_elapsed / 3.0, 0.0, 1.0)
	var focus: Vector3 = truck.global_transform * Vector3(0, 1.8, 0)
	# The kitchen/service window is on the truck's positive X side.
	var offset := Vector3(lerpf(14.0, 4.8, fraction), lerpf(3.0, 2.2, fraction), -0.5)
	camera.global_position = truck.global_transform * offset
	camera.look_at(focus)
	camera.fov = 45.0
	if fraction >= 1.0:
		loading_intro_active = false
		camera_started = false
		camera_spring_velocity = Vector3.ZERO
		camera_height_velocity = 0.0
		camera_follow_focus = truck.global_position + Vector3(0, 1.8, 0)
		orbit = camera_default_orbit
		pitch = camera_default_pitch
		distance = camera_default_distance
		update_follow_camera(0.0)
		truck.set_physics_process(loading_intro_truck_physics)
		$HUD.visible = loading_intro_hud_visible
		loading_intro_finished.emit()
@export var camera_spring_stiffness: float = 65.0
@export var camera_spring_damping: float = 9.0
var camera_spring_velocity: Vector3 = Vector3.ZERO
var camera_height_velocity: float = 0.0
@export_range(0.0, 1.0, 0.05) var camera_roll_strength: float = 0.15
@export_range(0.0, 5.0, 0.25) var camera_max_roll_degrees: float = 1.5
@export var camera_roll_response: float = 2.5
var camera_roll: float = 0.0
var impact_shake: float = 0.0
var impact_shake_time: float = 0.0

func trigger_impact_shake(strength: float) -> void:
	impact_shake = maxf(impact_shake, clampf(strength / 18.0, 0.08, 1.0))

func update_impact_shake(delta: float) -> void:
	impact_shake_time += delta
	impact_shake = move_toward(impact_shake, 0.0, delta * 2.5)
	var amplitude := impact_shake * impact_shake
	camera.h_offset = sin(impact_shake_time * 83.0) * amplitude * 0.24
	camera.v_offset = sin(impact_shake_time * 97.0 + 1.7) * amplitude * 0.18

var camera_return_timer: float = 0.0
var camera_default_orbit: float = 0.0
var camera_default_pitch: float = 0.42
var camera_default_distance: float = 14.5
var camera_clip_amount: float = 0.0
var camera_follow_focus: Vector3 = Vector3.ZERO
var speed_camera_blend: float = 0.0
var camera_base_fov: float = 70.0
var kitchen_blend: float = 0.0
var free_camera_look: bool = false
var free_camera_heading: float = 0.0
var free_camera_pitch: float = 0.0
var free_camera_roll: float = 0.0
@export var free_camera_speed: float = 20.0
@export var joypad_camera_speed: float = 2.0
@onready var damage_bar: ProgressBar = $HUD/Layout/DamagePanel/DamageBar
@onready var damage_label: Label = $HUD/Layout/DamagePanel/DamageLabel
@export_category("Level Rules")
@export var level_duration_seconds: float = 900.0
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

@export_category("Service Waves")
@export var service_window_seconds := 45.0
@export var service_pause_seconds := 30.0
@export_range(0, 10) var service_final_hold_waves := 1
var service_waves: Node

func service_player_count() -> int:
	return 1

func can_open_shop(body: CharacterBody3D) -> bool:
	var pad: Node3D = body.parking_pad
	return is_instance_valid(pad) and pad.serving_enabled and not pad.expired and pad.contains_truck(body)

var loading_ready := false

func is_loading_ready() -> bool:
	return loading_ready

func _ready() -> void:
	var generated_city := get_node_or_null("ProceduralCity")
	if generated_city != null and generated_city.generating:
		await generated_city.generation_finished
	# The flat playground starts with six service bays, more than a full lobby.
	if generated_city == null:
		var template: Node3D = $ParkingPads/ParkingPad_01
		for index in 3:
			var extra: Node3D = template.duplicate()
			extra.name = "WaveBay_%02d" % index
			extra.position = Vector3(-36, template.position.y, -16 + index * 13)
			$ParkingPads.add_child(extra)
			var spawn: Node3D = $PatronSpawns/PatronSpawn_01.duplicate()
			spawn.name = "WavePatronSpawn_%02d" % index
			spawn.position = Vector3(-27, 0.1, -10 + index * 13)
			$PatronSpawns.add_child(spawn)
		$PatronManager.maximum_patrons = maxi(24, $PatronManager.maximum_patrons)
	ingredients = clampi(starting_ingredients, 0, ingredient_capacity)
	service_waves = preload("res://service_waves.gd").new()
	service_waves.level = self
	add_child(service_waves)
	for pad in $ParkingPads.get_children():
		if pad.serving_enabled:
			pad.wave_managed = true
			pad.expired = true
	start_in_parking_spot()
	$HUD/Layout/FreeCameraButton.toggled.connect(set_free_camera_look)
	var guides = preload("res://poi_guides.gd").new()
	guides.name = "POIGuides"
	$HUD/Layout.add_child(guides)
	var street_display := preload("res://street_hud.gd").new()
	street_display.name = "StreetNavigation"
	street_display.level = self
	$HUD/Layout.add_child(street_display)
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
	loading_ready = true

func set_free_camera_look(enabled: bool) -> void:
	if enabled == free_camera_look:
		return
	if enabled:
		free_camera_heading = camera.global_rotation.y
		free_camera_pitch = camera.global_rotation.x
		free_camera_roll = camera.global_rotation.z
	else:
		orbit = camera_default_orbit
		pitch = camera_default_pitch
		camera_return_timer = 0.0
		camera_started = false
		camera_spring_velocity = Vector3.ZERO
		camera_follow_focus = truck.global_position + Vector3(0, 1.8, 0)
		camera_height_velocity = 0.0
	free_camera_look = enabled
	truck.manual_controls_enabled = not enabled
	if enabled:
		camera_clip_amount = 0.0
		camera_clip_mask.material.set_shader_parameter("strength", 0.0)
		camera.fov = camera_base_fov
		kitchen_blend = 0.0
	$HUD/Layout/FreeCameraButton.set_pressed_no_signal(enabled)
	$HUD/Layout/FreeCameraButton.text = "Free camera: ON" if enabled else "Free camera / C"
	$HUD/Layout/FreeCameraButton.tooltip_text = "C: toggle • Mouse: look • WASD: fly • Q/E: down/up • F: focus truck • Shift: faster"
	$HUD/Layout/FreeCameraButton.release_focus()
	camera_pose_label.visible = enabled
	if enabled:
		update_camera_pose_readout()

func focus_free_camera_on_truck() -> void:
	var target := truck.global_position + Vector3(0, 1.8, 0)
	if camera.global_position.distance_squared_to(target) < 0.01:
		camera.global_position += Vector3(0, 3, 8)
	camera.look_at(target)
	free_camera_heading = camera.global_rotation.y
	free_camera_pitch = camera.global_rotation.x
	free_camera_roll = camera.global_rotation.z

func move_free_camera(direction: Vector3, delta: float, faster: bool = false) -> void:
	var movement := camera.global_basis.x * direction.x - camera.global_basis.z * direction.z + Vector3.UP * direction.y
	camera.global_position += movement.limit_length() * free_camera_speed * (3.0 if faster else 1.0) * delta

func update_free_camera(delta: float) -> void:
	var movement := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	camera.global_rotation = Vector3(free_camera_pitch, free_camera_heading, free_camera_roll)
	move_free_camera(movement, delta, Input.is_physical_key_pressed(KEY_SHIFT))
	update_camera_pose_readout()

func vector_values(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func camera_view_state() -> Dictionary:
	var focus := truck.global_position + Vector3(0, 1.8, 0)
	var truck_basis := truck.global_basis.orthonormalized()
	var offset := truck_basis.inverse() * (camera.global_position - focus)
	var radius := offset.length()
	var orbit_yaw := atan2(offset.x, offset.z)
	var orbit_pitch := atan2(offset.y, Vector2(offset.x, offset.z).length())
	var baseline := camera.global_basis
	if radius > 0.001:
		var up := Vector3.FORWARD if absf((focus - camera.global_position).normalized().dot(Vector3.UP)) > 0.999 else Vector3.UP
		baseline = Transform3D(Basis.IDENTITY, camera.global_position).looking_at(focus, up).basis
	var extra_rotation := (baseline.inverse() * camera.global_basis).get_euler()
	var city := get_node_or_null("ProceduralCity")
	return {
		"version": 1, "scene": scene_file_path, "free_camera": free_camera_look,
		"position": vector_values(camera.global_position),
		"rotation_degrees": vector_values(camera.global_rotation * (180.0 / PI)),
		"basis_x": vector_values(camera.global_basis.x), "basis_y": vector_values(camera.global_basis.y), "basis_z": vector_values(camera.global_basis.z),
		"fov": camera.fov, "near": camera.near, "far": camera.far,
		"horizontal_offset": camera.h_offset, "vertical_offset": camera.v_offset,
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"truck_position": vector_values(truck.global_position), "truck_rotation_degrees": vector_values(truck.global_rotation * (180.0 / PI)),
		"orbit_focus": vector_values(focus), "orbit_yaw_degrees": rad_to_deg(orbit_yaw), "orbit_pitch_degrees": rad_to_deg(orbit_pitch), "orbit_distance": radius,
		"extra_rotation_degrees": vector_values(extra_rotation * (180.0 / PI)),
		"map_seed": city.actual_seed if city else 0, "night": city.is_night if city else false,
	}

func update_camera_pose_readout() -> void:
	var state := camera_view_state()
	var p: Array = state.position
	var r: Array = state.rotation_degrees
	var extra: Array = state.extra_rotation_degrees
	camera_pose_label.text = "CAMERA  World XYZ: %.3f, %.3f, %.3f\nRotation XYZ (deg): %.2f, %.2f, %.2f · FOV %.2f\nTruck orbit: yaw %.2f° · pitch %.2f° · distance %.3f\nExtra rotation XYZ (deg): %.2f, %.2f, %.2f\nMap seed: %s · %s · F9 saves image + camera JSON" % [p[0], p[1], p[2], r[0], r[1], r[2], state.fov, state.orbit_yaw_degrees, state.orbit_pitch_degrees, state.orbit_distance, extra[0], extra[1], extra[2], str(state.map_seed), "Night" if state.night else "Day"]

func restore_camera_view(state: Dictionary) -> void:
	set_free_camera_look(true)
	var p: Array = state.position
	var x: Array = state.basis_x
	var y: Array = state.basis_y
	var z: Array = state.basis_z
	camera.global_transform = Transform3D(Basis(Vector3(x[0], x[1], x[2]), Vector3(y[0], y[1], y[2]), Vector3(z[0], z[1], z[2])), Vector3(p[0], p[1], p[2]))
	free_camera_pitch = camera.global_rotation.x
	free_camera_heading = camera.global_rotation.y
	free_camera_roll = camera.global_rotation.z
	camera.fov = state.fov
	camera.near = state.near
	camera.far = state.far
	camera.h_offset = state.horizontal_offset
	camera.v_offset = state.vertical_offset
	update_camera_pose_readout()

func start_in_parking_spot() -> void:
	var city := get_node_or_null("ProceduralCity")
	var selected: Node3D
	var nearest := INF
	if city:
		for bay in city.get_node("ParkingSpaces").get_children():
			if bay.get_meta("occupied", false) or bay.get_meta("serving", false):
				continue
			var gap: float = truck.global_position.distance_squared_to(bay.global_position)
			if gap < nearest:
				nearest = gap
				selected = bay
	if selected:
		truck.global_position = selected.global_position
		var axis: Vector3 = selected.get_meta("parking_axis", Vector3.FORWARD)
		truck.rotation.y = atan2(-axis.x, -axis.z)
		truck.parking_pad = null
		# Give the larger food truck its own properly sized parking markings.
		for child in selected.get_children():
			child.free()
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.94, 0.94, 0.88)
		var asphalt := StandardMaterial3D.new()
		asphalt.albedo_color = Color(0.2, 0.22, 0.23)
		city.add_street_parking_markings(selected, absf(axis.z) > 0.5, asphalt, paint, city.parking_bay_width, city.parking_bay_length)
	else:
		# The plaza map and cities with parking disabled use an existing pad.
		selected = get_node_or_null("ParkingPads/ParkingPad_01") as Node3D
		if not selected:
			selected = repair_pad
		truck.global_position = selected.global_position
		truck.rotation.y = selected.global_rotation.y
		truck.parking_pad = selected
	truck.global_position.y = float(city.height_at(truck.position.x, truck.position.z)) + 0.2 if city else truck.spawn_transform.origin.y
	truck.velocity = Vector3.ZERO
	truck.speed = 0.0
	truck.travel_heading = truck.rotation.y
	truck.spawn_transform = truck.global_transform

func _unhandled_input(event: InputEvent) -> void:
	if loading_intro_active:
		return
	if event is InputEventKey and event.physical_keycode == KEY_C and event.pressed and not event.echo:
		set_free_camera_look(not free_camera_look)
		get_viewport().set_input_as_handled()
	if free_camera_look:
		if event is InputEventKey and event.physical_keycode == KEY_F and event.pressed and not event.echo:
			focus_free_camera_on_truck()
			get_viewport().set_input_as_handled()
		if event is InputEventMouseMotion:
			free_camera_heading -= event.relative.x * .006
			free_camera_pitch = clampf(free_camera_pitch - event.relative.y * .004, -PI * .499, PI * .499)
		return
	if event is InputEventMouseMotion and (free_camera_look or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
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
	if loading_intro_active:
		update_loading_intro(delta)
		return
	get_node("/root/GameOptions").round_balance=money
	advance_round(delta)
	if not round_finished and not NetworkSession.active:
		service_waves.tick(delta)
	if free_camera_look:
		update_free_camera(delta)
	else:
		update_follow_camera(delta)
	update_impact_shake(delta)
	damage_bar.value = 100.0*(1.0-truck.health/truck.max_health)
	damage_label.text = "DAMAGE %d%%" % roundi(damage_bar.value)
	speed_label.text = "%d km/h" % roundi(absf(truck.speed)*3.6)
	heading_label.text = "HDG  " + compass_heading(-truck.global_basis.z)
	var loads = truck.corner_load
	var total: float = loads[0]+loads[1]+loads[2]+loads[3]
	load_label.text = "AXLE LOAD  Front %d%% / Rear %d%%\nSIDE LOAD  Left %d%% / Right %d%%" % [roundi((loads[0]+loads[1])/total*100),roundi((loads[2]+loads[3])/total*100),roundi((loads[0]+loads[2])/total*100),roundi((loads[1]+loads[3])/total*100)]
	if free_camera_look:
		status_label.text = "FREE CAMERA  •  Mouse look · WASD fly · Q/E down/up · F focus truck · Shift faster · C return"
	elif round_finished:
		status_label.text = "SUCCESS  •  Money target reached!" if round_won else "GAME OVER  •  N begins a new round."
	elif is_instance_valid(truck.parking_pad) and truck.parking_pad!=repair_pad and truck.parking_pad.expired and truck.deployed and truck.opening>.99:
		status_label.text="SERVICE CLOSED • Pack up for repairs or ingredients."
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
	if not round_finished and service_waves != null:
		status_label.text += "\n" + service_waves.text()

func compass_heading(direction: Vector3) -> String:
	var angle := atan2(direction.x, -direction.z)
	var index := posmod(roundi(angle / (PI * 0.25)), 8)
	return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][index]

func update_follow_camera(delta: float) -> void:
	if kitchen_blend < .1:
		var orbit_input := Input.get_axis("camera_right","camera_left")
		var pitch_input := Input.get_axis("camera_up","camera_down")
		if absf(orbit_input) > 0.08 or absf(pitch_input) > 0.08:
			camera_return_timer = camera_return_delay
			orbit += orbit_input * joypad_camera_speed * delta
			pitch = clampf(pitch + pitch_input * joypad_camera_speed * delta * .5,.18,1.05)
	if free_camera_look:
		camera_return_timer = 0.0
	elif camera_return_timer > 0.0:
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
	var yaw = (free_camera_heading if free_camera_look else truck.rotation.y) + orbit
	var follow_distance: float = maxf(4.0,distance-speed_camera_move_in*speed_camera_blend)
	var offset = Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch)) * follow_distance
	var target = focus + offset
	var pad: Area3D = truck.parking_pad
	var kitchen_active = not free_camera_look and is_instance_valid(pad) and truck.deployed and absf(truck.speed) < .5
	var transition = pad.camera_transition_speed if is_instance_valid(pad) else 2.4
	kitchen_blend = move_toward(kitchen_blend,1.0 if kitchen_active else 0.0,delta*transition)
	if is_instance_valid(pad):
		target = target.lerp(truck.global_transform*pad.kitchen_camera_offset,kitchen_blend)
		focus = focus.lerp(truck.global_transform*pad.kitchen_focus_offset,kitchen_blend)
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
	var target_roll := 0.0 if free_camera_look else clampf(frame_roll * camera_roll_strength, -roll_limit, roll_limit) * (1.0 - kitchen_blend)
	camera_roll = lerpf(camera_roll, target_roll, 1.0 - exp(-camera_roll_response * delta))
	camera.rotate_object_local(Vector3.BACK, camera_roll)
	camera_clip_amount = move_toward(camera_clip_amount,0.88 if building_clip else 0.0,delta*6.0)
	camera_clip_mask.material.set_shader_parameter("strength",camera_clip_amount)

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
