extends Node3D

# Route version changes whenever the workload changes. Time is integer physics
# ticks, never wall time or render delta. There are no RNG calls or live actors.
const ROUTE_VERSION := 1
const TICK_RATE := 60
const WARMUP_TICKS := 120
const LAP_TICKS := 3600
const A := Vector3(-30, 0.12, 30)
const B := Vector3(-30, 0.12, -30)
const C := Vector3(30, 0.12, -30)
const D := Vector3(30, 0.12, -18)
const PHASES := ["north to bay A", "serve bay A", "east to bay B", "serve bay B", "reverse south", "reverse stop", "return to start", "start stop"]
const ENDS := [720, 1080, 1800, 2160, 2520, 2640, 3480, 3600]
var tick := 0
var lap := 0
var last_phase := -1
var camera: Camera3D
var label: Label
var physics_samples := 0
var pose_checksum := 0.0
@onready var truck = $FoodTruck

func _ready() -> void:
	if Engine.physics_ticks_per_second != TICK_RATE:
		push_error("Profiler route requires 60 Hz physics; refusing a noncomparable run.")
		get_tree().quit(2)
		return
	truck.set_physics_process(false)
	truck.network_controlled = true
	truck.network_controls = {}
	truck.network_edges = {}
	truck.manual_controls_enabled = false
	truck.set_process_input(false)
	truck.set_process_unhandled_input(false)
	_surface(Vector3(140, 1, 140), Vector3(0, -0.5, 0), Color("485f4b"))
	_surface(Vector3(20, 0.02, 100), Vector3(-30, 0.01, 0), Color("343b45"))
	_surface(Vector3(90, 0.02, 20), Vector3(0, 0.01, -30), Color("343b45"))
	_surface(Vector3(20, 0.02, 85), Vector3(30, 0.01, 0), Color("343b45"))
	_surface(Vector3(90, 0.02, 20), Vector3(0, 0.01, 30), Color("343b45"))
	for z in range(-40, 41, 10):
		_surface(Vector3(0.15, 0.02, 4), Vector3(-30, 0.03, z), Color.WHITE)
	for x in [-55, -5, 55]:
		for z in [-50, 0, 50]:
			var building := preload("res://assets/kenney_city/commercial/building-a.glb").instantiate()
			building.position = Vector3(x, 0, z)
			building.scale = Vector3.ONE * 4.0
			add_child(building)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.shadow_enabled = true
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("8ba7ba")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	camera = Camera3D.new()
	camera.current = true
	camera.far = 250.0
	camera.fov = 70.0
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(20, 20)
	canvas.add_child(label)
	apply_sample(sample(0), 1.0 / TICK_RATE)
	print("PROFILE_ROUTE_READY version=%d warmup_ticks=%d lap_ticks=%d physics_hz=%d max_fps=%d debug=%s renderer=%s viewport=%s replay_requested=%s" % [ROUTE_VERSION, WARMUP_TICKS, LAP_TICKS, Engine.physics_ticks_per_second, Engine.max_fps, OS.is_debug_build(), RenderingServer.get_current_rendering_method(), get_viewport().get_visible_rect().size, ProjectSettings.get_setting("debug/replay_capture/enabled", false) or "--debug-replay-capture" in OS.get_cmdline_user_args()])

func _surface(size: Vector3, at: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	add_child(body)

func sample(route_tick: int) -> Dictionary:
	var t := clampi(route_tick, 0, LAP_TICKS - 1)
	var phase := 0
	while t >= ENDS[phase]: phase += 1
	var start: int = 0 if phase == 0 else ENDS[phase - 1]
	var duration: int = ENDS[phase] - start
	var u := float(t - start) / duration
	# Cubic smoothstep gives repeatable acceleration and full stops at destinations.
	var eased := u * u * (3.0 - 2.0 * u)
	var point := A
	var yaw := 0.0
	var deployed := false
	var reverse := false
	match phase:
		0: point = A.lerp(B, eased)
		1:
			point = B
			deployed = u < 0.65
			yaw = lerp_angle(0.0, -PI / 2.0, smoothstep(0.65, 1.0, u))
		2:
			point = B.lerp(C, eased)
			yaw = -PI / 2.0
		3:
			point = C
			yaw = -PI / 2.0
			deployed = u < 0.65
			yaw = lerp_angle(-PI / 2.0, 0.0, smoothstep(0.65, 1.0, u))
		4:
			point = C.lerp(D, eased)
			reverse = true
		5:
			point = D
			yaw = lerp_angle(0.0, PI, u * u * (3.0 - 2.0 * u))
		6:
			# Fixed quadratic curve returning through the south road.
			var control := Vector3(30, 0.12, 62)
			point = D * (1.0 - eased) * (1.0 - eased) + control * 2.0 * (1.0 - eased) * eased + A * eased * eased
			var tangent := (control - D) * (1.0 - eased) + (A - control) * eased
			yaw = atan2(-tangent.x, -tangent.z)
		7:
			point = A
			yaw = lerp_angle(atan2(60.0, 32.0), 0.0, u * u * (3.0 - 2.0 * u))
	return {"position": point, "yaw": yaw, "deployed": deployed, "reverse": reverse, "phase": phase}

func apply_sample(state: Dictionary, delta: float) -> void:
	var previous: Vector3 = truck.position
	var previous_speed: float = truck.speed
	var movement: Vector3 = state.position - previous
	truck.velocity = movement / delta
	truck.speed = movement.length() / delta * (-1.0 if state.reverse else 1.0)
	# Scripted kinematic route: retain the real truck's ground/suspension, wheel,
	# lights and kitchen workload, but do not benchmark driving AI or random hits.
	truck.move_and_slide()
	truck.position = state.position
	truck.rotation.y = state.yaw
	truck.travel_heading = state.yaw
	truck.deployed = state.deployed
	truck.rolling += truck.speed * delta / 0.59
	truck.longitudinal_accel = clampf((truck.speed - previous_speed) / delta, -18.0, 18.0)
	truck.lateral_accel = 0.0
	truck.update_suspension(delta)
	truck.update_slope_tilt(delta)
	truck.opening = move_toward(truck.opening, 1.0 if truck.deployed else 0.0, delta * 0.65)
	var eased: float = truck.opening * truck.opening * (3.0 - 2.0 * truck.opening)
	truck.skeleton.set_bone_pose_rotation(truck.awning, Quaternion(Vector3.RIGHT, PI / 2.0 * eased))
	truck.skeleton.set_bone_pose_rotation(truck.counter, Quaternion(Vector3.RIGHT, -PI / 2.0 * eased))
	truck.get_node("VehicleLights").set_driving_lights(absf(truck.speed) < 0.1, state.reverse, false, false, truck.deployed)
	truck.get_node("VehicleLights").sync_with_chassis()
	camera.position = truck.position + Vector3(0, 16, 22)
	camera.look_at(truck.position + Vector3.UP * 1.5)

func _physics_process(_delta: float) -> void:
	var fixed_delta := 1.0 / TICK_RATE
	if tick < WARMUP_TICKS:
		apply_sample(sample(0), fixed_delta)
	else:
		var route_tick := (tick - WARMUP_TICKS) % LAP_TICKS
		var state := sample(route_tick)
		if state.phase != last_phase:
			last_phase = state.phase
			print("PROFILE_ROUTE_PHASE lap=%d tick=%d action=%s" % [lap, route_tick, PHASES[state.phase]])
		apply_sample(state, fixed_delta)
		physics_samples += 1
		pose_checksum += truck.position.x * 3.0 + truck.position.z * 7.0 + truck.opening
		if route_tick == LAP_TICKS - 1:
			print("PROFILE_ROUTE_COMPLETE version=%d lap=%d samples=%d pose_checksum=%.9f" % [ROUTE_VERSION, lap, physics_samples, pose_checksum])
			lap += 1
			physics_samples = 0
			pose_checksum = 0.0
			if "--profile-once" in OS.get_cmdline_user_args(): get_tree().quit()
	label.text = "AUTOMATED PROFILER ROUTE v%d | 60 Hz physics | Input disabled\n%s | lap %d | tick %d | replay opt-in only\nFixed layout; no patrons or traffic. Route repeats every 60 seconds." % [ROUTE_VERSION, "Warmup" if tick < WARMUP_TICKS else PHASES[last_phase], lap, tick]
	tick += 1
