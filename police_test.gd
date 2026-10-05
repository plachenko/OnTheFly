extends Node3D

var money := 500
var ingredients := 30
var ingredient_capacity := 100
var police_role := false
var police_speed := 0.0
var camera: Camera3D
var label: Label
@onready var truck = $FoodTruck
@onready var cop = $ProceduralCity/Traffic/Police
var saved_dispatch: Array = []
var saved_balance := 0
var cops: Array = []
var escape_ring: Node3D

func _enter_tree() -> void:
	# The model must be assigned before the production car's _ready runs.
	$ProceduralCity/Traffic/Police.model_scene = preload("res://assets/kenney_city/cars_rigged/police.glb")
	saved_dispatch = [PoliceDispatch.infractions, PoliceDispatch.prior_infractions, PoliceDispatch.pursuing, PoliceDispatch.stopped_time, PoliceDispatch.hit_cooldown]
	saved_balance = GameOptions.round_balance

func _ready() -> void:
	_surface(Vector3(100, 1, 160), Vector3(0, -0.5, 0), Color("415448"))
	for x in [-28.0, 0.0, 28.0]:
		_surface(Vector3(16, 0.02, 150), Vector3(x, 0.01, 0), Color("343b45"))
	for z in [-40.0, 0.0, 40.0]:
		_surface(Vector3(90, 0.02, 16), Vector3(0, 0.02, z), Color("343b45"))
	for z in range(-70, 71, 10):
		_surface(Vector3(0.15, 0.02, 4), Vector3(0, 0.03, z), Color.WHITE)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("8ba7ba")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	cops.append(cop)
	cop.get_node("PoliceCircle").chase_radius_multiplier = 2.8
	escape_ring = preload("res://police_escape_ring.gd").new()
	escape_ring.name = "PlayerEscapeRing"
	add_child(escape_ring)
	reset_test()
	for z in [-24.0, 12.0, 48.0]:
		for side in [-1, 1]:
			var parking := Node3D.new()
			parking.name = "PulloverBay_%s_%d" % ["Left" if side < 0 else "Right", int(z)]
			parking.position = Vector3(side * 6, 0, z)
			parking.set_meta("parking_axis", Vector3.FORWARD)
			parking.set_meta("occupied", false)
			parking.set_meta("serving", false)
			$ProceduralCity/ParkingSpaces.add_child(parking)
			mark_parking_bay(parking)
	spawn_ingredient_crates()

func spawn_ingredient_crates() -> void:
	var locations := [Vector3(-3,0,-20), Vector3(28,0,24), Vector3(-28,0,-56), Vector3(16,0,40), Vector3(3,0,-54), Vector3(-28,0,24)]
	for i in locations.size():
		var crate = preload("res://ingredient_crate.gd").new()
		crate.reinforced = i >= 4
		crate.portions = 20 if crate.reinforced else 10
		crate.position = locations[i]
		add_child(crate)

func mark_parking_bay(parking: Node3D) -> void:
	for side in [-1, 1]:
		for segment in 8:
			var line := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.10, 0.02, 0.9)
			line.mesh = box
			line.position = Vector3(side * 1.7, 0.06, -4.5 + segment * 1.3)
			parking.add_child(line)
		var end_line := MeshInstance3D.new()
		var end_box := BoxMesh.new()
		end_box.size = Vector3(3.4, 0.02, 0.10)
		end_line.mesh = end_box
		end_line.position = Vector3(0, 0.06, side * 5.0)
		parking.add_child(end_line)
	var road_sign := Label3D.new()
	road_sign.text = "PARKING"
	road_sign.position = Vector3(0, 1.0, 0)
	road_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	road_sign.font_size = 28
	parking.add_child(road_sign)

func _surface(size: Vector3, at: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.set_meta("drivable_surface", true)
	# Roads and lane paint are decals over the flat ground, not tiny obstacles.
	# Their raised collider edges were triggering suspension/climb damage.
	if size.y > 0.05:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	add_child(body)

func reset_test() -> void:
	PoliceDispatch.infractions = 0
	PoliceDispatch.prior_infractions = 0
	PoliceDispatch.pursuing = false
	PoliceDispatch.stopped_time = 0.0
	PoliceDispatch.hit_cooldown = 0.0
	money = 500
	ingredients = 30
	truck.booster_owned = true
	truck.boost_fuel = truck.boost_capacity
	truck.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 8))
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	truck.health = truck.max_health
	truck.message = ""
	cop.global_transform = Transform3D(Basis.IDENTITY, Vector3(4, 0.09, 0))
	cop.progress = 0.0
	cop.lane_center = Vector3(4, 0, 0)
	cop.current_driving_speed = 0.0
	cop.motion_vector = Vector3.ZERO
	cop.disabled = false
	cop.exploded = false
	cop.get_node("PoliceCircle").pursuing = false
	cop.get_node("PoliceCircle").yellow_remaining = 0.0
	cop.set_police_lights_enabled(false)
	police_speed = 0.0
	apply_role()
	camera.position = truck.position + Vector3(0, 16, 22)

func apply_role() -> void:
	truck.manual_controls_enabled = not police_role
	# Keep the unselected truck stationary; the unselected cop uses real pursuit AI.
	truck.set_physics_process(not police_role)
	for officer in cops:
		officer.set_physics_process(not (police_role and officer == cop))
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	police_speed = 0.0

func start_pursuit() -> void:
	var ring = cop.get_node("PoliceCircle")
	# Deterministic test trigger; normal collisions still use production reporting.
	ring.yellow_remaining = 2.5
	PoliceDispatch.report_collision(cop)
	join_pursuit()
	if PoliceDispatch.pursuing:
		truck.message = "POLICE PURSUIT — follow the blue street arc to escape (reverse works); avoid cop contact."

func join_pursuit() -> void:
	if not PoliceDispatch.pursuing:
		return
	for officer in cops:
		if not officer.disabled:
			officer.get_node("PoliceCircle").pursuing = true
			officer.set_police_lights_enabled(true)

func add_cop() -> void:
	var officer = preload("res://scenes/traffic_car.tscn").instantiate()
	officer.name = "Police%d" % (cops.size() + 1)
	officer.model_scene = preload("res://assets/kenney_city/cars_rigged/police.glb")
	officer.driving_speed = 0.0
	officer.obey_crosswalks = false
	officer.intersection_turn_chance = 0.0
	officer.horns_enabled = false
	officer.lane_center = Vector3(4 + (cops.size() % 3) * 5, 0, -floorf(cops.size() / 3.0) * 8)
	officer.position = officer.lane_center + Vector3.UP * 0.09
	$ProceduralCity/Traffic.add_child(officer)
	cops.append(officer)
	officer.get_node("PoliceCircle").chase_radius_multiplier = 2.8
	join_pursuit()

func cycle_cop() -> void:
	cop = cops[(cops.find(cop) + 1) % cops.size()]
	apply_role()

func can_open_shop(_vehicle: Node) -> bool:
	return false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match event.physical_keycode:
		KEY_TAB:
			police_role = not police_role
			apply_role()
		KEY_R: get_tree().reload_current_scene()
		KEY_P: start_pursuit()
		KEY_O: cop.set_police_lights_enabled(not cop.get_node("VehicleLights").police_enabled)
		KEY_C: add_cop()
		KEY_V: cycle_cop()

func _physics_process(delta: float) -> void:
	if not police_role:
		return
	if Input.is_action_just_pressed("truck_horn"):
		cop.horn_player.stream = cop.short_horn
		cop.horn_player.play()
	var throttle := DrivingControls.action_strength("accelerate") - DrivingControls.action_strength("reverse")
	var braking := DrivingControls.action_strength("brake") > 0.0
	var steer := Input.get_axis("left", "right")
	police_speed = move_toward(police_speed, throttle * 22.0, delta * (22.0 if braking else 10.0))
	if braking:
		police_speed = move_toward(police_speed, 0.0, delta * 40.0)
	cop.rotation.y += steer * police_speed / cop.wheelbase * tan(0.45) * delta
	var movement: Vector3 = cop.global_basis.z * police_speed * delta
	var next: Vector3 = cop.global_position + movement
	if cop.truck_blocks_motion(cop.global_position, next, 0.0):
		PoliceDispatch.police_hit(truck)
		police_speed = 0.0
	else:
		cop.global_position = next
	cop.motion_vector = cop.global_basis.z * police_speed
	cop.current_driving_speed = absf(police_speed)
	cop.steering_angle = steer * 0.45
	cop.update_car_pose(delta)
	cop.get_node("VehicleLights").set_driving_lights(braking, police_speed < -0.1, false, false, false)

func _process(delta: float) -> void:
	if PoliceDispatch.pursuing:
		join_pursuit()
	var target: Node3D = cop if police_role else truck
	if DrivingControls.reverse_view_requested() and not police_role:
		camera.global_position = truck.global_position - truck.global_basis.z * 18.0 + Vector3.UP * 12.0
	elif DrivingControls.gear == -1 and DrivingControls.reverse_forward_override and not police_role:
		camera.global_position = truck.global_position + truck.global_basis.z * 18.0 + Vector3.UP * 12.0
	else:
		camera.global_position = camera.global_position.lerp(target.global_position + Vector3(0, 16, 22), minf(1.0, delta * 5.0))
	camera.look_at(target.global_position + Vector3.UP)
	label.text = "POLICE TEST | Driving: %s | Cops: %d | Selected: %s\nTab: switch truck / police | W/S: drive/reverse | A/D: steer | Space: brake\nC: add cop | V: select next cop | P: trigger pursuit | O: lights | R: reset scene\nPAD: LS up/down gear; RT gas; LT brake; L3 horn; R: automatic rear view; flick RS forward: front view\nYellow bays: J/L or D-pad left/right to pull over\nTruck role: police AI pursues; stop off the road for 2 seconds to surrender.\nPolice role: drive up to the stationary truck during pursuit to test contact.\nPursuit: %s | Infractions: %d | Stop: %.1f/2s | Money: $%d | Truck health: %.0f\n%s" % ["POLICE" if police_role else "TRUCK", cops.size(), cop.name, PoliceDispatch.pursuing, PoliceDispatch.infractions, PoliceDispatch.stopped_time, money, truck.health, truck.message]

	label.text += "\nSelected gear: %s" % ("DRIVE" if DrivingControls.gear == 1 else "REVERSE")
	label.text += "\nIngredients: %d/%d | Boost: %.0f | Shift / R3: boost | Wood +10; metal +20 requires boost" % [ingredients, ingredient_capacity, truck.boost_fuel]

func _exit_tree() -> void:
	if saved_dispatch.size() == 5:
		PoliceDispatch.infractions = saved_dispatch[0]
		PoliceDispatch.prior_infractions = saved_dispatch[1]
		PoliceDispatch.pursuing = saved_dispatch[2]
		PoliceDispatch.stopped_time = saved_dispatch[3]
		PoliceDispatch.hit_cooldown = saved_dispatch[4]
		GameOptions.round_balance = saved_balance
