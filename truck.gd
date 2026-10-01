extends CharacterBody3D

var speed: float = 0.0
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
@export var suspension_travel: float = 0.30
@export_range(0.0, 0.5, 0.01) var maximum_slope_tilt: float = 0.32
@export var slope_tilt_response: float = 7.0
@export_category("Driving")
@export var forward_speed: float = 23.0
@export var reverse_speed: float = 7.0
@export var acceleration: float = 12.0
@export var braking_force: float = 22.0
@export var rolling_drag: float = 2.3
@export var cone_push_strength: float = 2.0
@export_category("Hill Jump")
@export_range(5.0, 25.0, 0.5) var hill_jump_min_speed: float = 13.0
@export_range(0.05, 0.5, 0.01) var hill_jump_crest_height: float = 0.20
@export_range(1.0, 5.0, 0.1) var hill_jump_impulse: float = 2.5
@export_range(0.5, 4.0, 0.1) var hill_jump_cooldown_seconds: float = 1.8
var hill_jump_cooldown: float = 0.0
var hill_jump_active: bool = false
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
var front_axle_pivot: Vector3 = Vector3.ZERO
var travel_heading: float = 0.0
var headlights_on: bool = true
var turn_signal: int = 0
var hazards_on: bool = false
var signal_start_heading: float = 0.0
var signal_turn_completed: bool = false

func _ready() -> void:
    model = $Model
    model_rest_rotation = model.quaternion
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

func _physics_process(delta: float) -> void:
    var previous_speed = speed
    update_light_controls()
    impact_cooldown = maxf(0.0, impact_cooldown-delta)
    climb_cooldown = maxf(0.0,climb_cooldown-delta)
    hill_jump_cooldown = maxf(0.0,hill_jump_cooldown-delta)
    message_timer = maxf(0.0, message_timer - delta)
    if not round_over and health > 0.0 and health/max_health < critical_health_ratio:
        health = maxf(0.0,health-critical_health_drain*delta)
    if Input.is_action_just_pressed("reset"):
        reset_truck()
        previous_speed = speed
    var servicing = get_parent().has_method("can_repair") and get_parent().can_repair()
    if Input.is_action_just_pressed("serve") and not servicing:
        if absf(speed) < 0.5:
            deployed = not deployed
        else:
            message = "Stop the truck before opening the kitchen."
            message_timer = 2.5
    var throttle = Input.get_axis("reverse", "accelerate")
    var steering_input = clampf(Input.get_axis("right", "left")*steering_sensitivity,-1.0,1.0)
    if turn_signal != 0:
        if absf(angle_difference(signal_start_heading,rotation.y)) > 0.65:
            signal_turn_completed = true
        if signal_turn_completed and absf(steering_input) < 0.12:
            turn_signal = 0
            signal_turn_completed = false
    var brake_amount = Input.get_action_strength("brake")
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
    boost_active = booster_owned and boost_fuel>0.0 and Input.is_action_pressed("boost") and throttle>0.0 and not braking and can_drive
    if boost_active:
        boost_fuel = maxf(0.0,boost_fuel-boost_consumption*delta)
    var speed_bonus = boost_speed_multiplier if boost_active else 1.0
    var accel_bonus = boost_acceleration_multiplier if boost_active else 1.0
    var drifting = drift_owned and braking and absf(steering_input)>.12 and (absf(speed)>2.0 or absf(throttle)>0.0) and can_drive
    var powered_drift = drifting and absf(throttle)>0.0
    var was_stationary_drifting = stationary_drifting
    stationary_drifting = powered_drift and (stationary_drifting or absf(speed)<.5)
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
        var brake_grip = .18*damage_performance() if powered_drift else (.36 if drifting else 1.0)
        speed = move_toward(speed, 0.0, braking_force * brake_amount * delta * brake_grip)
        if powered_drift:
            var drift_target = forward_speed if throttle>0.0 else -reverse_speed
            speed = move_toward(speed,drift_target*damage_performance(),acceleration*damage_performance()*absf(throttle)*delta*.75)
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
    var steering_limit = lerpf(.48, .23, clampf(absf(speed) / 15.0, 0.0, 1.0))
    steer = move_toward(steer, steering_input * steering_limit, delta * 2.5)
    # Throttle can break rear traction and rotate the truck from a standstill.
    var turn_direction = signf(speed) if absf(speed)>.5 else signf(throttle)
    var turn_speed = turn_direction*maxf(absf(speed),4.0*absf(throttle)) if powered_drift else speed
    if stationary_drifting:
        pivot_about_front_axle(steering_input*signf(throttle)*stationary_drift_turn_speed*delta)
        travel_heading=rotation.y
    else:
        rotation.y += steer * turn_speed / 5.0 * delta * (1.0+drift_blend*.65)
    travel_heading = lerp_angle(travel_heading,rotation.y,1.0-exp(-lerpf(18.0,3.5,drift_blend)*delta))
    var forward = Vector3(-sin(travel_heading),0,-cos(travel_heading))
    velocity.x = forward.x * speed
    velocity.z = forward.z * speed
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
            if car_body.disable_from_impact(car_approach,forward*signf(speed),car_sweep.get_position()):
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
    move_and_slide()
    if hill_jump_active and is_on_floor() and velocity.y <= 0.0:
        hill_jump_active = false
        for i in 4:
            spring_velocity[i] = maxf(-3.0,spring_velocity[i]-clampf(landing_speed*.25,.4,1.4))
    var strongest_impact: float = 0.0
    for i in get_slide_collision_count():
        var hit = get_slide_collision(i)
        var body = hit.get_collider()
        if body.has_method("disable_from_impact"):
            var car_impact: float = absf((forward*speed).dot(hit.get_normal()))
            if body.disable_from_impact(car_impact,forward*signf(speed),hit.get_position()):
                take_damage(car_impact * 0.6)
                speed *= .55
                continue
        var breakable = body.get_node_or_null("BoostBreakable")
        if breakable and (breakable.broken or try_boost_break(body,hit.get_normal(),forward)):
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
    rolling += speed * delta / 0.59
    longitudinal_accel = clampf((speed-previous_speed)/delta, -18.0, 18.0)
    lateral_accel = clampf(steer * speed * speed / 5.0, -10.0, 10.0)
    update_suspension(delta)
    update_slope_tilt(delta)
    $VehicleLights.sync_with_chassis()
    opening = move_toward(opening, 1.0 if deployed else 0.0, delta * 0.65)
    var eased = opening * opening * (3.0 - 2.0 * opening)
    skeleton.set_bone_pose_rotation(awning, Quaternion(Vector3.RIGHT, PI / 2.0 * eased))
    skeleton.set_bone_pose_rotation(counter, Quaternion(Vector3.RIGHT, -PI / 2.0 * eased))

func take_damage(amount: float) -> void:
    health = maxf(0.0,health-maxf(0.0,amount)*(1.0-armor_reduction if armor_owned else 1.0))

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
    if Input.is_action_just_pressed("truck_headlights"):
        headlights_on = not headlights_on
    if Input.is_action_just_pressed("truck_hazard"):
        handle_hazard_press(Time.get_ticks_msec())
    if Input.is_action_just_pressed("truck_signal_left"):
        hazards_on = false
        turn_signal = 0 if turn_signal == -1 else -1
        signal_start_heading = rotation.y
        signal_turn_completed = false
    if Input.is_action_just_pressed("truck_signal_right"):
        hazards_on = false
        turn_signal = 0 if turn_signal == 1 else 1
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
    if crest < hill_jump_crest_height:
        return
    velocity.y = hill_jump_impulse + clampf((absf(speed)-hill_jump_min_speed)*0.12,0.0,1.5) + clampf(crest*1.5,0.0,0.8)
    hill_jump_cooldown = hill_jump_cooldown_seconds
    hill_jump_active = true

func can_drive_on_hill() -> bool:
    return health > 0.0 and not round_over and not deployed and opening < 0.02

func try_climb_obstacle(motion: Vector3) -> bool:
    var climb_limit = effective_climb_height()
    if climb_limit <= 0.0 or not is_on_floor() or motion.length() < .001:
        return false
    var obstruction = KinematicCollision3D.new()
    if not test_move(global_transform,motion,obstruction,.001):
        return false
    if absf(obstruction.get_normal().y) > .5 or obstruction.get_collider() is RigidBody3D:
        return false
    # Sweep the entire collision shape up, forward, then down. This checks
    # headroom and the top surface instead of assuming a ray hit is climbable.
    var lift = climb_limit + .035
    if test_move(global_transform,Vector3.UP*lift,null,.001):
        return false
    var elevated = global_transform.translated(Vector3.UP*lift)
    if test_move(elevated,motion,null,.001):
        return false
    var landing = KinematicCollision3D.new()
    var over_obstacle = elevated.translated(motion)
    if not test_move(over_obstacle,Vector3.DOWN*(lift+.1),landing,.001):
        return false
    if landing.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
        return false
    var rise = lift + landing.get_travel().y
    if rise <= .025 or rise > climb_limit + .005:
        return false
    global_position.y += rise + .002
    velocity.y = 0.0
    if climb_cooldown <= 0.0:
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
    var query := PhysicsRayQueryParameters3D.create(world_point + Vector3.UP * 8.0, world_point + Vector3.DOWN * 12.0)
    query.exclude = [get_rid()]
    var contact := get_world_3d().direct_space_state.intersect_ray(query)
    return contact.position.y if not contact.is_empty() else world_point.y

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
        corner_load[i] = maxf(300.0, baseline + fore_aft * axle_sign + side_transfer * side_sign)
    # Keep total supported weight constant even when an inside tire unloads.
    var total_load = corner_load[0]+corner_load[1]+corner_load[2]+corner_load[3]
    for i in 4:
        corner_load[i] *= vehicle_mass * 9.81 / total_load
        suspension_target[i] = clampf(-(corner_load[i]-baseline)/spring_stiffness, -suspension_travel, suspension_travel)
        # Semi-implicit spring integration in short substeps keeps damping stable.
        var step = delta / 4.0
        for substep in 4:
            var force = spring_stiffness * (suspension_target[i]-spring_height[i]) - spring_damping*spring_velocity[i]
            spring_velocity[i] += force/(vehicle_mass/4.0)*step
            spring_height[i] = clampf(spring_height[i]+spring_velocity[i]*step, -suspension_travel, suspension_travel)
        var rest = skeleton.get_bone_global_rest(suspension_bones[i])
        var wheel_world = skeleton.global_transform * rest.origin
        var query = PhysicsRayQueryParameters3D.create(wheel_world+Vector3.UP*0.8, wheel_world-Vector3.UP*3.0)
        query.exclude = [get_rid()]
        var contact = get_world_3d().direct_space_state.intersect_ray(query)
        var height = 0.0
        if not contact.is_empty():
            height = contact.position.y + .59 - wheel_world.y
        var terrain_reach = maxf(1.6,effective_climb_height()+.15)
        road_height[i] = move_toward(road_height[i], clampf(height,-terrain_reach,terrain_reach),delta*8.0)
    var front = (spring_height[0]+spring_height[1]+road_height[0]+road_height[1])/2.0
    var rear = (spring_height[2]+spring_height[3]+road_height[2]+road_height[3])/2.0
    var left = (spring_height[0]+spring_height[2]+road_height[0]+road_height[2])/2.0
    var right = (spring_height[1]+spring_height[3]+road_height[1]+road_height[3])/2.0
    var body_roll = clampf((left-right)/2.4,-.14,.14)
    var body_pitch = clampf((front-rear)/5.0,-.10,.10)
    var body_rest = skeleton.get_bone_rest(chassis)
    skeleton.set_bone_pose_position(chassis,body_rest.origin+Vector3(0,0,(front+rear)/2.0+(lift_body_raise if lift_owned else 0.0)))
    skeleton.set_bone_pose_rotation(chassis,Quaternion(Vector3.RIGHT,body_roll)*Quaternion(Vector3.UP,body_pitch))
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

func reset_truck() -> void:
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
    opening = 0.0
    rolling = 0.0
    travel_heading = rotation.y
    drift_blend = 0.0
    stationary_drifting = false
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

