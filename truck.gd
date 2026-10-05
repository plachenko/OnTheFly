extends CharacterBody3D

@export_category("Sprite Animation (Experimental)")
@export var use_driving_billboard := false
@export_range(0.0,1.0,.05) var sprite_animation_strength := 1.0
@export_range(.5,2.0,.05) var sprite_animation_time_scale := 1.0
@export_range(.01,.4,.01) var sprite_lean_delay := .16
@export_range(.08,.6,.01) var sprite_transition_seconds := .22
@export_category("Chassis Exaggeration")
@export_file("*.json") var exaggeration_profile_path := ""
var exaggeration = preload("res://truck_exaggeration.gd").new()
var billboard: Node3D
var speed: float = 0.0
var manual_controls_enabled: bool = true
var network_controlled := false
var network_controls: Dictionary = {}
var network_edges: Dictionary = {}
var test_controls_enabled := false
var test_controls: Dictionary = {}
@export_category("Handling Profile")
@export var handling_id := "food_truck"
@export var handling_profile: Resource
@export var use_saved_handling_default := true

func control_axis(negative: String, positive: String) -> float:
    if test_controls_enabled: return float(test_controls.get(positive,0)) - float(test_controls.get(negative,0))
    if network_controlled:
        return float(network_controls.get(positive, 0.0)) - float(network_controls.get(negative, 0.0))
    return DrivingControls.action_strength(positive) - DrivingControls.action_strength(negative)

func control_strength(action: String) -> float:
    if test_controls_enabled: return float(test_controls.get(action,0))
    return float(network_controls.get(action, 0.0)) if network_controlled else DrivingControls.action_strength(action)

func control_pressed(action: String) -> bool:
    if test_controls_enabled: return control_strength(action)>0.5
    return control_strength(action) > 0.5 if network_controlled else Input.is_action_pressed(action)

func control_just_pressed(action: String) -> bool:
    if test_controls_enabled: return false
    return network_edges.get(action, false) if network_controlled else DrivingControls.direction_signal_just_pressed(action)
var deployed: bool = false
var opening: float = 0.0
var steer: float = 0.0
var rolling: float = 0.0
var model: Node3D
var model_rest_rotation: Quaternion
var skeleton: Skeleton3D
var awning: int = -1
var counter: int = -1
var chassis: int = -1
var suspension_bones: Array[int] = []
var steer_bones: Array[int] = []
var spin_bones: Array[int] = []
var corners: Array[String] = ["Front_L", "Front_R", "Rear_L", "Rear_R"]
var spring_height: Array[float] = [0.0, 0.0, 0.0, 0.0]
var spring_velocity: Array[float] = [0.0, 0.0, 0.0, 0.0]
var corner_load: Array[float] = [5886.0, 5886.0, 5886.0, 5886.0]
var road_height: Array[float] = [0.0, 0.0, 0.0, 0.0]
var suspension_target: Array[float] = [0.0, 0.0, 0.0, 0.0]
var longitudinal_accel: float = 0.0
var lateral_accel: float = 0.0
@export_category("Suspension")
@export var vehicle_mass: float = 2400.0
@export var center_of_mass_height: float = 1.45
@export var spring_stiffness: float = 42000.0
@export var spring_damping: float = 4600.0
@export_range(.4,1.0,.05) var rear_suspension_firmness := .78
@export_range(0.0,.08,.005) var body_yaw_lag := .028
@export_range(0.0,2.0,.05) var donut_drift_speed := .65
var body_yaw_sway := 0.0
var body_yaw_velocity := 0.0
var engine_phase := 0.0
var measured_yaw_rate := 0.0
var donut_drift_velocity := Vector3.ZERO
@export var suspension_travel: float = 0.30
@export_range(0.0, 0.5, 0.01) var maximum_slope_tilt: float = 0.32
@export var slope_tilt_response: float = 7.0
@export_category("Driving")
@export var forward_speed: float = 23.0
@export var reverse_speed: float = 7.0
@export var acceleration: float = 12.0
@export var braking_force: float = 22.0
@export var rolling_drag: float = 2.3
@export var steering_low_speed := .48
@export var steering_high_speed := .23
@export var steering_response := 2.5
@export var traction_response := 18.0
@export var drift_traction_response := 3.5
@export var drift_turn_multiplier := 1.65
@export var cone_push_strength: float = 2.0
@export_category("Parking Power Slide")
@export var power_slide_min_speed: float = 3.5
@export var power_slide_duration: float = 1.2
@export var power_slide_steering := .58
@export var power_slide_turn_multiplier := 4.5
@export var power_slide_traction_response := .65
@export var power_slide_brake_grip := .32
@export var power_slide_enter_response := 5.0
@export var power_slide_recovery_response := 2.5
var power_slide_active: bool = false
var power_slide_blend: float = 0.0
var power_slide_elapsed: float = 0.0
var power_slide_used: bool = false
@export_category("Hill Jump")
@export_range(5.0, 25.0, 0.5) var hill_jump_min_speed: float = 13.0
@export_range(0.05, 0.5, 0.01) var hill_jump_crest_height: float = 0.20
@export_range(1.0, 5.0, 0.1) var hill_jump_impulse: float = 2.5
@export_range(0.5, 4.0, 0.1) var hill_jump_cooldown_seconds: float = 1.8
var hill_jump_cooldown: float = 0.0
var hill_jump_active: bool = false
@export_category("Car Landing Launch")
@export var car_landing_min_speed := 3.0
@export var car_landing_upward_speed := 12.0
@export var car_landing_lateral_speed := 14.0
@export var car_landing_cooldown_seconds := 0.8
var car_landing_cooldown := 0.0
var car_launch_active := false
var car_launch_horizontal := Vector3.ZERO
@export_range(0.5, 4.0, 0.1) var hill_jump_min_upward_momentum: float = 1.5
var uphill_momentum: float = 0.0
var slope_upward_speed: float = 0.0
var spawn_transform: Transform3D
var message: String = ""
var message_timer: float = 0.0
@export_category("Damage")
@export var max_health: float = 100.0
@export var damage_threshold: float = 2.5
@export var impact_damage_scale: float = 1.4
var health: float = 100.0
@export_range(0.0,1.0) var critical_health_ratio: float = .25
@export var critical_health_drain: float = .7
@export_range(.05,1.0) var damaged_speed_floor: float = .30
var round_over: bool = false
var impact_cooldown: float = 0.0
var steering_sensitivity: float = 1.0
var vibration_enabled: bool = true
var parking_pad: Area3D
@export_category("Climbing Obstacles")
@export_range(0.0, 1.2) var max_climb_height: float = 0.65
@export var climb_damage: float = 2.0
@export var climb_damage_cooldown: float = 0.8
var climb_cooldown: float = 0.0
@export_category("Upgrade Effects")
@export var boost_speed_multiplier: float = 1.6
@export var boost_acceleration_multiplier: float = 2.2
@export var boost_capacity: float = 100.0
@export var boost_consumption: float = 25.0
@export var boost_break_max_size: float = 3.0
@export var boost_break_damage: float = 1.5
@export var lifted_climb_height: float = 1.1
@export var lift_body_raise: float = .18
@export var stationary_drift_turn_speed: float = 2.5
@export_range(0.0,.9) var armor_reduction: float = .45
@export_category("Full Self Driving")
@export_range(0.25, 0.8, 0.05) var fsd_double_tap_seconds: float = 0.5
var booster_owned: bool = false
var drift_owned: bool = false
var lift_owned: bool = false
var armor_owned: bool = false
var fsd_owned: bool = false
var fsd_enabled: bool = false
var last_hazard_press_ms: int = -100000
var boost_fuel: float = 0.0
var boost_active: bool = false
var drift_blend: float = 0.0
var stationary_drifting: bool = false
var tire_throttle := 0.0
var tire_brake := 0.0
var front_axle_pivot: Vector3 = Vector3.ZERO
var travel_heading: float = 0.0
var headlights_on: bool = true
var turn_signal: int = 0
var hazards_on: bool = false
var signal_start_heading: float = 0.0
var signal_turn_completed: bool = false
var damage_effects: Node3D
var police_parking: Node
var highway_transit: Node
var horn_player: AudioStreamPlayer3D
var horn_count := 0

func honk() -> void:
    if horn_player == null: return
    horn_count += 1
    horn_player.play()

func _ready() -> void:
    HandlingProfiles.apply_startup(self)
    reload_exaggeration_profile()
    model = $Model
    model_rest_rotation = model.quaternion
    call_deferred("create_driving_billboard")
    var kitchen_cutaway = preload("res://kitchen_cutaway.gd").new()
    kitchen_cutaway.name = "KitchenCutaway"
    add_child(kitchen_cutaway)
    spawn_transform = global_transform
    health = max_health
    travel_heading = rotation.y
    skeleton = find_skeleton(model)
    assert(skeleton != null, "The truck needs its imported armature")
    awning = skeleton.find_bone("Awning")
    counter = skeleton.find_bone("Counter")
    chassis = skeleton.find_bone("Chassis")
    $VehicleLights.attach_to_chassis(skeleton)
    for corner in corners:
        suspension_bones.append(skeleton.find_bone("Suspension_" + corner))
        steer_bones.append(skeleton.find_bone("Steer_" + corner))
        spin_bones.append(skeleton.find_bone("Spin_" + corner))
    var front_center = (skeleton.get_bone_global_rest(suspension_bones[0]).origin+skeleton.get_bone_global_rest(suspension_bones[1]).origin)*.5
    front_axle_pivot=to_local(skeleton.to_global(front_center))
    front_axle_pivot.y=0.0
    damage_effects = preload("res://truck_damage_effects.gd").new()
    damage_effects.name = "DamageEffects"
    add_child(damage_effects)
    horn_player = AudioStreamPlayer3D.new()
    horn_player.name = "TruckHorn"
    horn_player.stream = preload("res://assets/audio/horns/van_short.wav")
    horn_player.max_distance = 65.0
    add_child(horn_player)
    if get_parent().has_node("ProceduralCity"):
        highway_transit = preload("res://highway_transit.gd").new()
        highway_transit.name = "HighwayTransit"
        add_child(highway_transit)
        var tire_effects = preload("res://tire_effects.gd").new()
        tire_effects.name = "TireEffects"
        add_child(tire_effects)
        police_parking = preload("res://police_parking.gd").new()
        police_parking.name = "PoliceParking"
        add_child(police_parking)

func _physics_process(delta: float) -> void:
    if highway_transit != null and highway_transit.drive(delta): return
    var previous_speed = speed
    var previous_yaw := rotation.y
    update_light_controls()
    if control_just_pressed("truck_horn"): honk()
    if police_parking != null and police_parking.drive(delta): return
    impact_cooldown = maxf(0.0, impact_cooldown-delta)
    climb_cooldown = maxf(0.0,climb_cooldown-delta)
    hill_jump_cooldown = maxf(0.0,hill_jump_cooldown-delta)
    car_landing_cooldown = maxf(0.0,car_landing_cooldown-delta)
    if car_launch_active and is_on_floor() and velocity.y <= 0.0:
        car_launch_active = false
        car_launch_horizontal = Vector3.ZERO
    message_timer = maxf(0.0, message_timer - delta)
    if not round_over and health > 0.0 and health/max_health < critical_health_ratio:
        health = maxf(0.0,health-critical_health_drain*delta)
    if control_just_pressed("reset"):
        reset_truck()
        previous_speed = speed
    var servicing = get_parent().has_method("can_repair") and get_parent().can_repair()
    if manual_controls_enabled and control_just_pressed("serve") and not servicing:
        if absf(speed) < 0.5:
            if not deployed and not get_parent().can_open_shop(self):
                message = "Service closed or bay occupied — race to an available green bay."
                message_timer = 3.0
            elif not deployed and not get_parent().has_ingredients():
                message = "Need ingredients to unlock serving — restock at the service station."
                message_timer = 3.0
            else:
                deployed = not deployed
        else:
            message = "Stop the truck before opening the kitchen."
            message_timer = 2.5
    var throttle = control_axis("reverse", "accelerate") if manual_controls_enabled else 0.0
    var steering_input = clampf(control_axis("right", "left")*steering_sensitivity,-1.0,1.0) if manual_controls_enabled else 0.0
    if turn_signal != 0:
        if absf(angle_difference(signal_start_heading,rotation.y)) > 0.65:
            signal_turn_completed = true
        if signal_turn_completed and absf(steering_input) < 0.12:
            turn_signal = 0
            signal_turn_completed = false
    var brake_amount = control_strength("brake") if manual_controls_enabled else 0.0
    var braking = brake_amount > 0.0
    var can_drive = health>0.0 and not round_over and not deployed and opening<.02
    if fsd_enabled:
        if absf(throttle) > 0.15 or absf(steering_input) > 0.15 or brake_amount > 0.15 or not can_drive and not (opening > .02 and health > 0.0 and not round_over):
            stop_fsd("FSD disengaged — manual control")
        elif can_drive:
            var command: Dictionary = $FSDNavigator.driving_command(speed)
            if command.arrived:
                stop_fsd("FSD arrived at " + $FSDNavigator.destination_label())
                throttle = 0.0
                brake_amount = 1.0
                braking = true
            else:
                throttle = command.throttle
                brake_amount = command.brake
                braking = brake_amount > 0.0
                steering_input = command.steer
    boost_active = booster_owned and boost_fuel>0.0 and control_pressed("boost") and throttle>0.0 and not braking and can_drive
    if boost_active:
        boost_fuel = maxf(0.0,boost_fuel-boost_consumption*delta)
    var speed_bonus = boost_speed_multiplier if boost_active else 1.0
    var accel_bonus = boost_acceleration_multiplier if boost_active else 1.0
    update_power_slide(brake_amount, steering_input, throttle, can_drive and manual_controls_enabled and is_on_floor(), delta)
    tire_throttle = throttle
    tire_brake = brake_amount
    var drifting = (drift_owned or absf(throttle)>.15) and not power_slide_active and brake_amount>.25 and absf(steering_input)>.12 and (absf(speed)>2.0 or absf(throttle)>0.0) and can_drive and is_on_floor()
    var powered_drift = drifting and absf(throttle)>0.0
    var was_stationary_drifting = stationary_drifting
    stationary_drifting = powered_drift and brake_amount>.5 and absf(steering_input)>.25 and (stationary_drifting or absf(speed)<3.0)
    if was_stationary_drifting and not stationary_drifting:
        travel_heading=rotation.y
    drift_blend = move_toward(drift_blend,1.0 if drifting else 0.0,delta*3.0)
    if deployed and throttle != 0.0:
        deployed = false
    if deployed or opening > 0.02:
        throttle = 0.0
        braking = true
        brake_amount = 1.0
    if health <= 0.0 or round_over:
        throttle = 0.0
        braking = true
        brake_amount = 1.0
    if stationary_drifting:
        speed=0.0
    elif braking:
        var brake_grip = power_slide_brake_grip if power_slide_active else (.18*damage_performance() if powered_drift else (.36 if drifting else 1.0))
        speed = move_toward(speed, 0.0, braking_force * brake_amount * delta * brake_grip)
        if powered_drift:
            var braking_drift_target = forward_speed if throttle>0.0 else -reverse_speed
            speed = move_toward(speed,braking_drift_target*damage_performance(),acceleration*damage_performance()*absf(throttle)*delta*.75)
    elif throttle != 0.0:
        var accel = acceleration if throttle * speed >= 0.0 else 13.0
        var performance = damage_performance()
        speed = move_toward(speed, forward_speed*performance*speed_bonus if throttle > 0 else -reverse_speed*performance, accel * accel_bonus * performance * absf(throttle) * delta)
    else:
        speed = move_toward(speed, 0.0, rolling_drag * delta)
    if not boost_active and speed>forward_speed*damage_performance():
        speed = move_toward(speed,forward_speed*damage_performance(),rolling_drag*delta*3.0)
    speed = clampf(speed,-reverse_speed*damage_performance(),forward_speed*damage_performance()*speed_bonus)
    var decelerating := previous_speed > 1.0 and (previous_speed-speed)/maxf(delta,0.001) > 4.0
    $VehicleLights.headlights_enabled = headlights_on
    $VehicleLights.set_driving_lights(braking or decelerating or deployed, speed < -0.25, turn_signal < 0, turn_signal > 0, hazards_on)
    var steering_limit = lerpf(steering_low_speed, steering_high_speed, clampf(absf(speed) / 15.0, 0.0, 1.0))
    steer = move_toward(steer, steering_input * lerpf(steering_limit, power_slide_steering, power_slide_blend), delta * steering_response)
    # Throttle can break rear traction and rotate the truck from a standstill.
    var turn_direction = signf(speed) if absf(speed)>.5 else signf(throttle)
    var turn_speed = turn_direction*maxf(absf(speed),4.0*absf(throttle)) if powered_drift else speed
    if stationary_drifting:
        pivot_about_front_axle(steering_input*signf(throttle)*stationary_drift_turn_speed*delta)
        travel_heading=rotation.y
    else:
        rotation.y += steer * turn_speed / 5.0 * delta * lerpf(1.0,drift_turn_multiplier,drift_blend) * lerpf(1.0, power_slide_turn_multiplier, power_slide_blend)
    var grip := lerpf(lerpf(traction_response,drift_traction_response,drift_blend), power_slide_traction_response, power_slide_blend)
    travel_heading = lerp_angle(travel_heading,rotation.y,1.0-exp(-grip*delta))
    var forward = Vector3(-sin(travel_heading),0,-cos(travel_heading))
    velocity.x = forward.x * speed
    velocity.z = forward.z * speed
    var yaw_rate := angle_difference(previous_yaw, rotation.y) / maxf(delta, .001)
    var drift_target := Vector3.ZERO
    if stationary_drifting:
        var weight_scale := clampf(vehicle_mass / 2400.0 * center_of_mass_height / 1.45, .4, 2.0)
        var rear_weight := (corner_load[2] + corner_load[3]) / maxf(1.0, vehicle_mass * 9.81)
        # Tire scrub lets the front-axle pivot migrate; translation still uses the collision solver.
        drift_target = (global_basis.x * signf(yaw_rate) + global_basis.z * .3) * donut_drift_speed * weight_scale * clampf(absf(yaw_rate) / 2.5,0,1.5) * (0.7 + rear_weight)
    donut_drift_velocity = donut_drift_velocity.lerp(drift_target, 1.0 - exp(-delta * (2.0 if stationary_drifting else 5.0)))
    velocity.x += donut_drift_velocity.x
    velocity.z += donut_drift_velocity.z
    if car_launch_active:
        velocity.x = car_launch_horizontal.x
        velocity.z = car_launch_horizontal.z
    update_uphill_momentum(forward, delta)
    if velocity.y > 0.0 and not hill_jump_active and not car_launch_active:
        velocity.y = minf(velocity.y, slope_upward_speed if is_on_floor() else 0.0)
    if not car_launch_active:
        try_hill_jump(forward)
    if not is_on_floor():
        velocity.y -= 20.0 * delta
    elif velocity.y <= 0.0:
        velocity.y = -0.1
    var motion = Vector3(velocity.x,0,velocity.z)*delta
    var car_sweep := KinematicCollision3D.new()
    if test_move(global_transform,motion,car_sweep,.001):
        var car_body: Object = car_sweep.get_collider()
        if car_body.has_method("disable_from_impact"):
            var car_approach: float = maxf(0.0,-motion.normalized().dot(car_sweep.get_normal())*absf(speed))
            var car_contact: bool = car_body.receive_vehicle_contact(forward * speed, -car_sweep.get_normal(), car_sweep.get_position()) if car_body.has_method("receive_vehicle_contact") else car_body.disable_from_impact(car_approach,forward*signf(speed),car_sweep.get_position())
            if car_contact:
                PoliceDispatch.report_collision(car_body)
                record_license_collision(car_body, car_approach)
                take_damage(car_approach*0.6)
                speed *= 0.35
                velocity.x = forward.x*speed
                velocity.z = forward.z*speed
                motion = Vector3(velocity.x,0,velocity.z)*delta
    if boost_active:
        var upcoming = KinematicCollision3D.new()
        if test_move(global_transform,motion,upcoming,.001):
            try_boost_break(upcoming.get_collider(),upcoming.get_normal(),forward)
    try_climb_obstacle(motion)
    var landing_speed := maxf(0.0,-velocity.y)
    var was_grounded := is_on_floor()
    var approved_upward_speed := maxf(0.0, velocity.y)
    var approach_velocity := velocity
    move_and_slide()
    # The solver may redirect horizontal collisions upward. Only terrain
    # momentum at driving speed may turn that into an airborne launch.
    if velocity.y > 0.0:
        if hill_jump_active or car_launch_active:
            velocity.y = minf(velocity.y, approved_upward_speed)
        elif is_on_floor():
            velocity.y = minf(velocity.y, slope_upward_speed)
        elif was_grounded and absf(speed) >= hill_jump_min_speed and uphill_momentum >= hill_jump_min_upward_momentum and not is_on_wall() and can_drive_on_hill():
            velocity.y = minf(velocity.y, uphill_momentum)
            hill_jump_active = true
            hill_jump_cooldown = hill_jump_cooldown_seconds
        else:
            velocity.y = 0.0
    if hill_jump_active and is_on_floor() and velocity.y <= 0.0:
        hill_jump_active = false
        for i in 4:
            spring_velocity[i] = maxf(-3.0,spring_velocity[i]-clampf(landing_speed*.25,.4,1.4))
    var strongest_impact: float = 0.0
    for i in get_slide_collision_count():
        var hit = get_slide_collision(i)
        var body = hit.get_collider()
        if body.has_method("collect_by_truck") and body.collect_by_truck(self):
            continue
        # A curb is ground support, even if the solver reports its vertical
        # edge for a frame. Never turn that contact into crash damage/braking.
        if body.get_meta("sidewalk", false) or body.get_meta("drivable_surface", false):
            continue
        if body.has_method("disable_from_impact"):
            if try_car_landing_launch(body, hit.get_normal(), hit.get_position(), approach_velocity):
                continue
            var car_impact: float = absf((forward*speed).dot(hit.get_normal()))
            var car_contact: bool = body.receive_vehicle_contact(forward * speed, -hit.get_normal(), hit.get_position()) if body.has_method("receive_vehicle_contact") else body.disable_from_impact(car_impact,forward*signf(speed),hit.get_position())
            if car_contact:
                PoliceDispatch.report_collision(body)
                record_license_collision(body, car_impact)
                take_damage(car_impact * 0.6)
                speed *= .55
                continue
        if body.has_method("receive_lot_contact"):
            var lot_impact = absf((forward*speed).dot(hit.get_normal()))
            body.receive_lot_contact(lot_impact)
            record_license_collision(body, lot_impact)
        var breakable = body.get_node_or_null("BoostBreakable")
        if breakable and (breakable.broken or try_boost_break(body,hit.get_normal(),forward)):
            continue
        if body.has_method("impact_knock_down"):
            var pole_impact = maxf(0.0, -(forward * speed).dot(hit.get_normal()))
            if body.impact_knock_down(forward * signf(speed), pole_impact):
                take_damage(2.0)
                speed *= .9
                continue
        if body.has_method("knock_down"):
            if lift_owned and absf(speed)>=3.0 and body.knock_down(forward*signf(speed),absf(speed)):
                take_damage(2.0)
                speed *= .92
                continue
            if body.fallen:
                body.apply_central_impulse(forward*speed*4.0)
                speed *= .97
                continue
        var impact = absf(velocity.dot(hit.get_normal()))
        # move_and_slide adjusts velocity, so reconstruct horizontal approach speed.
        impact = absf((forward*speed).dot(hit.get_normal()))
        if absf(hit.get_normal().y) < .5:
            strongest_impact = maxf(strongest_impact,impact * (.15 if body is RigidBody3D and not body.has_method("knock_down") else 1.0))
        if body.has_method("push_from_truck"):
            if boost_active and body.has_method("boost_bounce"):
                body.boost_bounce(-global_basis.z,absf(speed))
            else:
                body.push_from_truck(forward*signf(speed),absf(speed),hit.get_position())
            speed *= 0.97
        elif body is RigidBody3D and not body.has_method("knock_down"):
            var impulse = -hit.get_normal() * minf(absf(speed) * cone_push_strength, 25.0)
            body.apply_impulse(impulse, hit.get_position() - body.global_position)
            speed *= 0.94
        elif absf(hit.get_normal().y) < 0.5:
            speed *= 0.15
    if strongest_impact > damage_threshold and impact_cooldown <= 0.0:
        take_damage(pow(strongest_impact-damage_threshold,1.25)*impact_damage_scale)
        impact_cooldown = .45
        if vibration_enabled:
            for device in Input.get_connected_joypads():
                Input.start_joy_vibration(device,.3,.6,.18)
    elif strongest_impact > 0.8 and impact_cooldown <= 0.0:
        if get_parent().has_method("trigger_impact_shake"):
            get_parent().trigger_impact_shake(strongest_impact)
        impact_cooldown = 0.15
    rolling += (signf(throttle) * 10.0 if stationary_drifting else speed) * delta / 0.59
    longitudinal_accel = clampf((speed-previous_speed)/delta, -18.0, 18.0)
    measured_yaw_rate = angle_difference(previous_yaw, rotation.y) / maxf(delta, .001)
    # Rear mass travels around the front pivot even when longitudinal speed is zero.
    var rotational_load := signf(measured_yaw_rate) * measured_yaw_rate * measured_yaw_rate * 1.5 if stationary_drifting else 0.0
    lateral_accel = clampf(measured_yaw_rate * speed + rotational_load, -10.0, 10.0)
    update_suspension(delta)
    update_slope_tilt(delta)
    $VehicleLights.sync_with_chassis()
    opening = move_toward(opening, 1.0 if deployed else 0.0, delta * 0.65)
    var eased = opening * opening * (3.0 - 2.0 * opening)
    skeleton.set_bone_pose_rotation(awning, Quaternion(Vector3.RIGHT, PI / 2.0 * eased))
    skeleton.set_bone_pose_rotation(counter, Quaternion(Vector3.RIGHT, -PI / 2.0 * eased))

func record_license_collision(car: Object, strength: float) -> void:
    var level := get_parent()
    if level.has_method("register_car_collision"):
        level.register_car_collision(self, car, strength)

func take_damage(amount: float) -> void:
    if highway_transit != null and highway_transit.active: return
    var previous_health := health
    health = maxf(0.0,health-maxf(0.0,amount)*(1.0-armor_reduction if armor_owned else 1.0))
    if health < previous_health and is_instance_valid(damage_effects):
        damage_effects.damage_taken()
    if amount > 0.0 and get_parent().has_method("trigger_impact_shake"):
        get_parent().trigger_impact_shake(amount)

func effective_climb_height() -> float:
    return maxf(max_climb_height,lifted_climb_height) if lift_owned else max_climb_height

func pivot_about_front_axle(angle: float) -> void:
    # Keep the midpoint of the front wheel bones fixed as the rear swings out.
    var steps=maxi(1,ceili(absf(angle)/.025))
    var step_angle=angle/steps
    for i in steps:
        var pivot_world=global_transform*front_axle_pivot
        var candidate=global_transform
        candidate.basis=Basis(Vector3.UP,step_angle)*candidate.basis
        candidate.origin=pivot_world-candidate.basis*front_axle_pivot
        var collision=KinematicCollision3D.new()
        if test_move(global_transform,candidate.origin-global_position,collision,.001):
            if absf(collision.get_normal().y)<.5:
                return
        if test_move(candidate,Vector3.ZERO,collision,.001,true,4):
            for contact in collision.get_collision_count():
                if absf(collision.get_normal(contact).y)<.5:
                    return
        global_transform=candidate

func try_boost_break(body: Node, normal: Vector3, direction: Vector3) -> bool:
    if not boost_active or not body is PhysicsBody3D:
        return false
    if body.has_method("collect_by_truck"):
        return body.collect_by_truck(self)
    if body.has_method("boost_bounce") and body.boost_bounce(-global_basis.z,absf(speed)):
        message = "Boost rebound!"
        message_timer = 1.0
        return true
    var breakable = body.get_node_or_null("BoostBreakable")
    var approach_speed = maxf(0.0,-(direction*speed).dot(normal))
    if not breakable or not breakable.smash(boost_break_max_size,approach_speed,direction):
        return false
    add_collision_exception_with(body)
    take_damage(boost_break_damage)
    speed *= .92
    message = "Boost smash!"
    message_timer = 1.5
    return true

func damage_performance() -> float:
    return lerpf(damaged_speed_floor,1.0,clampf(health/max_health,0.0,1.0))

func update_light_controls() -> void:
    if control_just_pressed("direction_signal_left"):
        activate_direction_signal(-1)
    if control_just_pressed("direction_signal_right"):
        activate_direction_signal(1)
    if control_just_pressed("truck_headlights"):
        headlights_on = not headlights_on
    if control_just_pressed("truck_hazard"):
        handle_hazard_press(Time.get_ticks_msec())
    if control_just_pressed("truck_signal_left"):
        hazards_on = false
        turn_signal = 0 if turn_signal == -1 else -1
        signal_start_heading = rotation.y
        signal_turn_completed = false
    if control_just_pressed("truck_signal_right"):
        hazards_on = false
        turn_signal = 0 if turn_signal == 1 else 1
        signal_start_heading = rotation.y
        signal_turn_completed = false

func activate_direction_signal(direction: int) -> void:
    hazards_on = false
    turn_signal = direction
    signal_start_heading = rotation.y
    signal_turn_completed = false

func handle_hazard_press(now_ms: int) -> void:
    if now_ms - last_hazard_press_ms <= roundi(fsd_double_tap_seconds * 1000.0):
        last_hazard_press_ms = -100000
        hazards_on = false
        toggle_fsd()
    else:
        last_hazard_press_ms = now_ms
        hazards_on = not hazards_on
        if hazards_on:
            turn_signal = 0

func toggle_fsd() -> void:
    if fsd_enabled:
        stop_fsd("FSD disengaged")
        return
    if not fsd_owned:
        message = "Buy Full Self Driving at the repair pad first."
        message_timer = 2.5
        return
    if health <= 0.0 or round_over:
        return
    if not $FSDNavigator.begin():
        message = "FSD: no available serving destination."
        message_timer = 2.5
        return
    deployed = false
    fsd_enabled = true
    turn_signal = 0
    message = "FSD to " + $FSDNavigator.destination_label() + " — drive controls take over"
    message_timer = 3.0

func stop_fsd(reason: String) -> void:
    fsd_enabled = false
    $FSDNavigator.stop()
    message = reason
    message_timer = 2.5

func update_uphill_momentum(forward: Vector3, delta: float) -> void:
    slope_upward_speed = 0.0
    if is_on_floor() and can_drive_on_hill():
        var terrain_contact := false
        for index in get_slide_collision_count():
            var hit := get_slide_collision(index)
            var body = hit.get_collider()
            if body is StaticBody3D and body.name == "HillyGround" and hit.get_normal().y > 0.5:
                terrain_contact = true
                break
        if terrain_contact:
            var normal := get_floor_normal()
            var travel := forward * signf(speed)
            var grade := maxf(0.0, -normal.dot(travel) / maxf(0.1, normal.y))
            slope_upward_speed = minf(absf(speed) * grade, 6.0)
    if absf(speed) < hill_jump_min_speed or not can_drive_on_hill():
        uphill_momentum = 0.0
    elif slope_upward_speed >= hill_jump_min_upward_momentum:
        uphill_momentum = move_toward(uphill_momentum, slope_upward_speed, delta * 12.0)
    else:
        uphill_momentum = move_toward(uphill_momentum, 0.0, delta * 8.0)

func hill_launch_speed(crest: float, approach_grade: float) -> float:
    if absf(speed) < hill_jump_min_speed or uphill_momentum < hill_jump_min_upward_momentum or approach_grade < 0.06 or crest < hill_jump_crest_height:
        return 0.0
    return minf(uphill_momentum, hill_jump_impulse + clampf((absf(speed) - hill_jump_min_speed) * 0.12, 0.0, 1.5))

func try_hill_jump(forward: Vector3) -> void:
    if hill_jump_cooldown > 0.0 or not is_on_floor() or absf(speed) < hill_jump_min_speed or not can_drive_on_hill():
        return
    var city: Node = get_parent().get_node_or_null("ProceduralCity")
    if city == null or not city.has_method("height_at"):
        return
    var travel := forward * signf(speed)
    var sample_distance := clampf(absf(speed)*0.24,3.0,5.5)
    var center: float = city.height_at(global_position.x,global_position.z)
    var ahead: float = city.height_at(global_position.x+travel.x*sample_distance,global_position.z+travel.z*sample_distance)
    var behind: float = city.height_at(global_position.x-travel.x*sample_distance,global_position.z-travel.z*sample_distance)
    var crest := 2.0*center-ahead-behind
    var launch := hill_launch_speed(crest, (center - behind) / sample_distance)
    if launch <= 0.0:
        return
    velocity.y = launch
    hill_jump_cooldown = hill_jump_cooldown_seconds
    hill_jump_active = true

func can_drive_on_hill() -> bool:
    return health > 0.0 and not round_over and not deployed and opening < 0.02

func try_climb_obstacle(motion: Vector3) -> bool:
    var climb_limit = effective_climb_height()
    if climb_limit <= 0.0 or motion.length() < .001:
        return false
    var obstruction = KinematicCollision3D.new()
    if not test_move(global_transform,motion,obstruction,.001,true,8):
        return false
    var sidewalk := false
    var side_hit := false
    for index in obstruction.get_collision_count():
        var body: Object = obstruction.get_collider(index)
        if absf(obstruction.get_normal(index).y) <= .5 and not body is RigidBody3D:
            side_hit = true
            sidewalk = sidewalk or body.get_meta("sidewalk", false) or body.get_meta("drivable_surface", false)
    if not side_hit:
        return false
    if not is_on_floor():
        # Crossing slab seams can briefly drop the floor flag; stay grounded.
        if not sidewalk or velocity.y > 0.1 or not test_move(global_transform, Vector3.DOWN * 0.35, null, .001):
            return false
    # Sweep the entire collision shape up, forward, then down. This checks
    # headroom and the top surface instead of assuming a ray hit is climbable.
    var lift = climb_limit + .035
    if test_move(global_transform,Vector3.UP*lift,null,.001):
        return false
    var elevated = global_transform.translated(Vector3.UP*lift)
    # A frame's tiny motion can leave the front edge barely over the curb,
    # causing the downward sweep to find the road instead of the sidewalk.
    # Probe far enough onto the top while checking the whole truck for walls.
    var step_motion := motion
    if sidewalk:
        var approach := 1.0
        for index in obstruction.get_collision_count():
            if obstruction.get_collider(index).get_meta("sidewalk", false) and absf(obstruction.get_normal(index).y) <= .5:
                approach = minf(approach, maxf(0.25, -motion.normalized().dot(obstruction.get_normal(index))))
        step_motion = motion.normalized() * maxf(motion.length(), 0.3 / approach)
    if test_move(elevated,step_motion,null,.001):
        return false
    var landing = KinematicCollision3D.new()
    var over_obstacle = elevated.translated(step_motion)
    if not test_move(over_obstacle,Vector3.DOWN*(lift+.1),landing,.001):
        return false
    if landing.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
        return false
    var rise = lift + landing.get_travel().y
    if rise <= .025 or rise > climb_limit + .005:
        return false
    global_position.y += rise + .002
    velocity.y = 0.0
    if sidewalk:
        # Ordinary curbs load the suspension without damage or loss of speed.
        for index in 4:
            spring_velocity[index] = maxf(-2.0, spring_velocity[index] - rise * 1.5)
    elif climb_cooldown <= 0.0:
        var penalty = climb_damage * clampf(rise/climb_limit,.4,1.0) * clampf(absf(speed)/8.0,.5,1.5)
        take_damage(penalty)
        climb_cooldown = climb_damage_cooldown
        message = "Climbed obstacle — minor suspension damage"
        message_timer = 1.8
        if vibration_enabled:
            for device in Input.get_connected_joypads():
                Input.start_joy_vibration(device,.15,.25,.12)
    return true

func find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found = find_skeleton(child)
        if found:
            return found
    return null

func ground_height_at(local_point: Vector3) -> float:
    var world_point: Vector3 = global_transform * local_point
    if highway_transit != null and highway_transit.active:
        return highway_transit.surface_height(world_point)
    var query := PhysicsRayQueryParameters3D.create(world_point + Vector3.UP * 8.0, world_point + Vector3.DOWN * 12.0)
    query.exclude = [get_rid()]
    var contact := get_world_3d().direct_space_state.intersect_ray(query)
    return visual_contact_height(contact.position,contact.collider) if not contact.is_empty() else world_point.y

func visual_contact_height(point: Vector3, body: Node) -> float:
    var city = get_parent().get_node_or_null("ProceduralCity")
    if city != null and city.visual_surfaces_ready and (body.get_meta("drivable_surface",false) or body.get_meta("sidewalk",false)):
        return point.y + city.road_visual_height_at(point.x,point.z) - city.terrain_surface_height_at(point.x,point.z)
    return point.y

func update_slope_tilt(delta: float) -> void:
    # Tilt only the visual model; keeping the CharacterBody upright preserves steering and collision.
    var front_left := ground_height_at(Vector3(-1.2, 0, -2.5))
    var front_right := ground_height_at(Vector3(1.2, 0, -2.5))
    var rear_left := ground_height_at(Vector3(-1.2, 0, 2.5))
    var rear_right := ground_height_at(Vector3(1.2, 0, 2.5))
    var front := (front_left + front_right) * 0.5
    var rear := (rear_left + rear_right) * 0.5
    var left := (front_left + rear_left) * 0.5
    var right := (front_right + rear_right) * 0.5
    var target_pitch := clampf(atan2(front - rear, 5.0), -maximum_slope_tilt, maximum_slope_tilt)
    var target_roll := clampf(atan2(left - right, 2.4), -maximum_slope_tilt, maximum_slope_tilt)
    var blend := 1.0 - exp(-slope_tilt_response * delta)
    # Apply slope in vehicle space before the model's imported 90-degree yaw.
    var slope_rotation := Quaternion(Vector3.RIGHT, target_pitch) * Quaternion(Vector3.FORWARD, target_roll)
    model.quaternion = model.quaternion.slerp(slope_rotation * model_rest_rotation, blend)

func update_suspension(delta: float) -> void:
    # F = m*a*h/wheelbase or track. Split axle/side transfer across two tires.
    var baseline = vehicle_mass * 9.81 / 4.0
    var fore_aft = vehicle_mass * longitudinal_accel * center_of_mass_height / 5.0 / 2.0
    var side_transfer = vehicle_mass * lateral_accel * center_of_mass_height / 2.4 / 2.0
    for i in 4:
        var axle_sign = -1.0 if i < 2 else 1.0
        var side_sign = -1.0 if i % 2 == 0 else 1.0
        corner_load[i] = maxf(300.0, baseline + fore_aft * axle_sign + side_transfer * side_sign * (0.8 if i < 2 else 1.2))
    # Keep total supported weight constant even when an inside tire unloads.
    var total_load = corner_load[0]+corner_load[1]+corner_load[2]+corner_load[3]
    for i in 4:
        corner_load[i] *= vehicle_mass * 9.81 / total_load
        suspension_target[i] = clampf(-(corner_load[i]-baseline)/spring_stiffness, -suspension_travel, suspension_travel)
        # Semi-implicit spring integration in short substeps keeps damping stable.
        var step = delta / 4.0
        for substep in 4:
            var firmness := 1.0 if i < 2 else rear_suspension_firmness
            var force = spring_stiffness * firmness * (suspension_target[i]-spring_height[i]) - spring_damping * sqrt(firmness) * (.8 if i >= 2 else 1.0) * spring_velocity[i]
            spring_velocity[i] += force/(vehicle_mass/4.0)*step
            spring_height[i] = clampf(spring_height[i]+spring_velocity[i]*step, -suspension_travel, suspension_travel)
        var rest = skeleton.get_bone_global_rest(suspension_bones[i])
        var wheel_world = skeleton.global_transform * rest.origin
        var query = PhysicsRayQueryParameters3D.create(wheel_world+Vector3.UP*0.8, wheel_world-Vector3.UP*3.0)
        query.exclude = [get_rid()]
        var contact = get_world_3d().direct_space_state.intersect_ray(query)
        var height = 0.0
        if not contact.is_empty():
            height = visual_contact_height(contact.position,contact.collider) + .59 - wheel_world.y
        if highway_transit != null and highway_transit.active:
            height = highway_transit.surface_height(wheel_world) + .59 - wheel_world.y
        var terrain_reach = maxf(1.6,effective_climb_height()+.15)
        road_height[i] = move_toward(road_height[i], clampf(height,-terrain_reach,terrain_reach),delta*8.0)
    var front = (spring_height[0]+spring_height[1]+road_height[0]+road_height[1])/2.0
    var rear = (spring_height[2]+spring_height[3]+road_height[2]+road_height[3])/2.0
    var left = (spring_height[0]+spring_height[2]+road_height[0]+road_height[2])/2.0
    var right = (spring_height[1]+spring_height[3]+road_height[1]+road_height[3])/2.0
    var body_roll = clampf((left-right)/2.4,-.14,.14)
    var body_pitch = clampf((front-rear)/5.0,-.10,.10)
    var body_rest = skeleton.get_bone_rest(chassis)
    engine_phase = fmod(engine_phase + delta * TAU * 13.0, TAU)
    var idle_vibration := sin(engine_phase) * .003 if health > 0.0 and not round_over else 0.0
    skeleton.set_bone_pose_position(chassis,body_rest.origin+Vector3(0,0,(front+rear)/2.0+(lift_body_raise if lift_owned else 0.0)+idle_vibration))
    var sway_target := clampf(-measured_yaw_rate * body_yaw_lag * center_of_mass_height / 1.45, -.085, .085)
    for substep in 4:
        var sway_step := minf(delta,.1) / 4.0
        body_yaw_velocity += ((sway_target - body_yaw_sway) * 24.0 - body_yaw_velocity * 5.5) * sway_step
        body_yaw_sway = clampf(body_yaw_sway + body_yaw_velocity * sway_step, -.10, .10)
    # Imported chassis Z is vertical: a small inertial yaw lets the rear lag behind turns.
    skeleton.set_bone_pose_rotation(chassis,Quaternion(Vector3.BACK,body_yaw_sway)*Quaternion(Vector3.RIGHT,body_roll)*Quaternion(Vector3.UP,body_pitch))
    exaggeration.apply(self,delta)
    skeleton.force_update_all_bone_transforms()
    # Wheels stay on the road; their suspension bones extend/compress relative
    # to the pitching/rolling chassis instead of dragging tires through the ground.
    var body_pose = skeleton.get_bone_global_pose(chassis)
    for i in 4:
        var rest = skeleton.get_bone_global_rest(suspension_bones[i])
        var wheel_pos = rest.origin+Vector3.UP*road_height[i]
        skeleton.set_bone_pose_position(suspension_bones[i],body_pose.affine_inverse()*wheel_pos)
        skeleton.set_bone_pose_rotation(suspension_bones[i],(body_pose.basis.inverse()*rest.basis).get_rotation_quaternion())
        skeleton.set_bone_pose_rotation(steer_bones[i],Quaternion(Vector3.BACK,steer if i < 2 else 0.0))
        skeleton.set_bone_pose_rotation(spin_bones[i],Quaternion(Vector3.UP,rolling))

func car_landing_direction() -> Vector3:
    if not manual_controls_enabled:
        return Vector3.ZERO
    # Action strengths already include the configured controller deadzones.
    var local := Vector3(control_axis("left", "right"), 0, -control_axis("reverse", "accelerate"))
    local = local.limit_length(1.0)
    var world := Basis(Vector3.UP, rotation.y) * local
    return world

func try_car_landing_launch(body: Node, normal: Vector3, point: Vector3, approach_velocity: Vector3) -> bool:
    if not multiplayer.is_server() or car_landing_cooldown > 0.0 or health <= 0.0 or round_over:
        return false
    if not body.has_method("consume_truck_landing") or not body.has_method("is_roof_landing"):
        return false
    if not body.is_roof_landing(normal, point, approach_velocity, car_landing_min_speed):
        return false
    if not body.consume_truck_landing():
        return false
    car_landing_cooldown = maxf(0.1, car_landing_cooldown_seconds)
    car_launch_active = true
    hill_jump_active = false
    car_launch_horizontal = car_landing_direction() * clampf(car_landing_lateral_speed, 0, 30)
    velocity = car_launch_horizontal + Vector3.UP * clampf(car_landing_upward_speed, 1, 25)
    PoliceDispatch.report_collision(body)
    record_license_collision(body, maxf(0.0, -(approach_velocity - body.motion_vector).y))
    take_damage(maxf(0.0, -(approach_velocity - body.motion_vector).y) * 0.6)
    return true

func reset_truck() -> void:
    exaggeration.reset_motion()
    global_transform = spawn_transform
    model.quaternion = model_rest_rotation
    velocity = Vector3.ZERO
    speed = 0.0
    steer = 0.0
    deployed = false
    impact_cooldown = 0.0
    climb_cooldown = 0.0
    hill_jump_cooldown = 0.0
    hill_jump_active = false
    car_launch_active = false
    car_launch_horizontal = Vector3.ZERO
    car_landing_cooldown = 0.0
    uphill_momentum = 0.0
    slope_upward_speed = 0.0
    opening = 0.0
    rolling = 0.0
    travel_heading = rotation.y
    drift_blend = 0.0
    power_slide_active = false
    power_slide_blend = 0.0
    power_slide_used = false
    power_slide_elapsed = 0.0
    stationary_drifting = false
    donut_drift_velocity = Vector3.ZERO
    measured_yaw_rate = 0.0
    engine_phase = 0.0
    body_yaw_sway = 0.0
    body_yaw_velocity = 0.0
    boost_active = false
    headlights_on = true
    turn_signal = 0
    hazards_on = false
    fsd_enabled = false
    $FSDNavigator.stop()
    signal_turn_completed = false
    for i in 4:
        spring_height[i] = 0.0
        spring_velocity[i] = 0.0
        road_height[i] = 0.0
    if skeleton:
        skeleton.reset_bone_poses()
    if health <= 0.0 and get_parent().has_method("recovery_transform"):
        global_transform = get_parent().recovery_transform()


func update_power_slide(brake: float, steering: float, throttle: float, allowed: bool, delta: float) -> void:
    if brake < 0.2:
        power_slide_used = false
        power_slide_elapsed = 0.0
    if not power_slide_active and not power_slide_used and allowed and brake > 0.5 and absf(steering) > 0.25 and absf(speed) >= power_slide_min_speed and absf(throttle) < 0.15:
        power_slide_active = true
        power_slide_used = true
        power_slide_elapsed = 0.0
        message = "POWER SLIDE — countersteer to line up; release brake to regain grip."
        message_timer = 2.0
    if power_slide_active:
        power_slide_elapsed += delta
        if not allowed or brake < 0.2 or absf(speed) < 0.7 or power_slide_elapsed >= power_slide_duration:
            power_slide_active = false
    power_slide_blend = move_toward(power_slide_blend, 1.0 if power_slide_active else 0.0, delta * (power_slide_enter_response if power_slide_active else power_slide_recovery_response))


func create_driving_billboard() -> void:
    if not use_driving_billboard: return
    billboard = preload("res://truck_billboard.gd").new()
    billboard.name = "TruckBillboard"
    add_child(billboard)

func reload_exaggeration_profile() -> Error:
    var path: String = exaggeration_profile_path if not exaggeration_profile_path.is_empty() else preload("res://truck_exaggeration.gd").default_path(handling_id)
    var error := exaggeration.load_profile(path)
    if error != OK and exaggeration.profile.is_empty():
        exaggeration.profile = preload("res://truck_idle_motion.gd").idle_profile()
        exaggeration.reset_motion()
    return error
