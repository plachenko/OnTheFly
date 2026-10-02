extends CharacterBody3D
@export var walk_speed: float = 1.7
@export var run_speed: float = 2.7
@export var dodge_speed: float = 8.0
@export var jump_speed: float = 2.4
@export var escape_run_speed: float = 6.4
@export_range(0, 1) var dodge_hop_chance: float = 0.10
@export_range(0, 1) var destination_dodge_chance: float = 0.60
@export_enum("Random", "Jump aside", "Run aside") var avoidance_style: int = 0
@export_range(0.5, 1.5, 0.05) var personal_space_radius: float = 0.75
var jumps_aside: bool = true
@export_range(0,1) var interest: float = .8
@export var budget: int = 24
@export var wander_radius: float = 5.0
var sidewalk_min_z: float = -11.0
var sidewalk_max_z: float = 11.0
var crosswalk: Node3D
var home_side: int = -1
var on_other_street: bool = false
var crossing_phase: int = 0 # 0 wandering, 1 approaching, 2 waiting, 3 crossing
var crossing_cooldown: float = 7.0
@export var interest_recovery: float = .003
@export_range(-1,3) var character_variant: int = -1
var manager: Node
var home_position: Vector3
var wander_target: Vector3
var wander_timer: float = 0.0
var pad: Node3D
var order: Dictionary = {}
var queue_slot: int = 0
var service_elapsed: float = 0.0
var cooldown: float = 0.0
var dodge_timer: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var dodge_count: int = 0
var has_eaten: bool = false
var visual_anim: AnimationPlayer
var active_visual: Node3D

func _ready() -> void:
    add_to_group("patrons")
    personal_space_radius *= randf_range(0.9, 1.1)
    if is_instance_valid(crosswalk):
        if crosswalk.has_meta("island"):
            home_side = -1 if home_position.distance_to(crosswalk.wait_point(-1)) < home_position.distance_to(crosswalk.wait_point(1)) else 1
        elif crosswalk.crosses_vertical_road:
            home_side=-1 if home_position.x<crosswalk.global_position.x else 1
        else:
            home_side=-1 if home_position.z<crosswalk.global_position.z else 1
    crossing_cooldown=randf_range(4.0,9.0)
    choose_wander_target()
    var characters=$VisualVariants.get_children()
    var index=randi_range(0,characters.size()-1) if character_variant<0 else clampi(character_variant,0,characters.size()-1)
    for i in characters.size():characters[i].visible=i==index
    active_visual=characters[index]
    visual_anim=active_visual.get_node("AnimationPlayer")
    for clip in ["Idle","Walk","Run"]:visual_anim.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
    visual_anim.play("Idle")

func play_visual(clip: String) -> void:
    if visual_anim.current_animation!=clip:
        visual_anim.play(clip,.08 if clip=="Dodge" else .16)

func choose_wander_target() -> void:
    if on_other_street and is_instance_valid(crosswalk):
        if crosswalk.has_meta("island"):
            wander_target = crosswalk.wait_point(-home_side)
        elif crosswalk.crosses_vertical_road:
            wander_target=Vector3(crosswalk.global_position.x-home_side*crosswalk.crossing_offset,home_position.y,crosswalk.global_position.z+randf_range(-0.8,0.8))
        else:
            wander_target=Vector3(crosswalk.global_position.x+randf_range(-0.8,0.8),home_position.y,crosswalk.global_position.z-home_side*crosswalk.crossing_offset)
    else:
        # Idle patrons remain on the serving street's sidewalk.
        wander_target=home_position+Vector3(0,0,randf_range(-wander_radius,wander_radius))
        wander_target.z=clampf(wander_target.z,sidewalk_min_z,sidewalk_max_z)
    wander_timer=randf_range(3,6)

func crossing_target(side: int) -> Vector3:
    var target: Vector3=crosswalk.wait_point(side)
    target.y=global_position.y
    return target

func can_be_attracted() -> bool:
    return cooldown<=0 and dodge_timer<=0 and interest>=manager.attraction_interest_threshold and budget>0

func accept_order(target_pad: Node3D, selected_order: Dictionary) -> void:
    crossing_phase=0
    pad=target_pad; order=selected_order; service_elapsed=0
    var used: Array=[]
    for patron in pad.patrons:used.append(patron.queue_slot)
    queue_slot=0
    while queue_slot in used:queue_slot+=1
    pad.patrons.append(self)

func cancel_order() -> void:
    if is_instance_valid(pad):pad.release_patron(self)
    pad=null; order={}; service_elapsed=0
    crossing_phase=0
    choose_wander_target()

func queue_target() -> Vector3:
    var truck=manager.level.truck
    if manager.has_method("truck_for_patron"):
        truck=manager.truck_for_patron(self)
    var target: Vector3=truck.global_transform*Vector3(3.15+float(queue_slot%2)*1.8,0,-1.2+float(queue_slot/2)*1.8)
    target.y=global_position.y
    return target

func check_dodge() -> void:
    if dodge_cooldown>0:return
    var truck=manager.level.truck
    if manager.has_method("closest_truck"):
        truck=manager.closest_truck(self)
    var motion=Vector3(truck.velocity.x,0,truck.velocity.z)
    if motion.length()<2:return
    var heading=motion.normalized()
    var offset=global_position-truck.global_position; offset.y=0
    var ahead=offset.dot(heading)
    var sideways=heading.cross(Vector3.UP)
    var lateral=offset.dot(sideways)
    if ahead<0 or ahead>4.5+motion.length()*1.0 or absf(lateral)>2.8:return
    # Capture the intended destination before cancelling an order/crossing.
    var destination := wander_target
    if is_instance_valid(pad): destination = queue_target()
    elif crossing_phase > 0 and is_instance_valid(crosswalk):
        var origin_side: int = -home_side if on_other_street else home_side
        destination = crossing_target(-origin_side if crossing_phase == 3 else origin_side)
    var escape := choose_dodge_direction(sideways, lateral, destination)
    if escape == Vector3.ZERO: return
    cancel_order()
    crossing_cooldown=randf_range(5.0,9.0)
    dodge_direction=escape
    jumps_aside = randf() < dodge_hop_chance if avoidance_style == 0 else avoidance_style == 1
    velocity.y=jump_speed if jumps_aside else minf(0.0, velocity.y)
    dodge_timer=randf_range(.60,.80); dodge_cooldown=1.5; cooldown=maxf(cooldown,2.0); dodge_count+=1
    play_visual("Dodge" if jumps_aside else "Run")

func choose_dodge_direction(sideways: Vector3, lateral: float, destination: Vector3) -> Vector3:
    var sign_out := (1.0 if lateral >= 0 else -1.0) if absf(lateral) > 0.4 else (-1.0 if randf() < 0.5 else 1.0)
    var outward := sideways * sign_out
    var toward := destination - global_position
    toward.y = 0
    toward = toward.normalized()
    var prefer_destination := randf() < destination_dodge_chance
    var best := Vector3.ZERO
    var best_score := -INF
    # All candidates clear the truck laterally; variation adds forward/backward
    # diagonals without choosing a route through the approaching vehicle.
    for i in range(7):
        var angle := randf_range(-0.65, 0.65) if i > 0 else 0.0
        var candidate := outward.rotated(Vector3.UP, angle)
        var origin := global_position + Vector3.UP * 0.7
        var query := PhysicsRayQueryParameters3D.create(origin, origin + candidate * 2.5, 1, [get_rid()])
        if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
        var score := randf() * 0.6 + (candidate.dot(toward) * 1.5 if prefer_destination else 0.0)
        if score > best_score:
            best_score = score
            best = candidate
    return best

func walk_direction(target: Vector3) -> Vector3:
    var direction=target-global_position; direction.y=0
    if direction.length()<.3:return Vector3.ZERO
    direction=direction.normalized()
    for angle in [0.0,.7,-.7,1.4,-1.4]:
        var candidate=direction.rotated(Vector3.UP,angle)
        var query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.6,global_position+Vector3.UP*.6+candidate*1.0,1,[get_rid()])
        if get_world_3d().direct_space_state.intersect_ray(query).is_empty():return candidate
    return Vector3.ZERO

func _physics_process(delta: float) -> void:
    if not is_instance_valid(manager) or not manager.level.is_processing() or manager.level.round_finished:return
    cooldown=maxf(0,cooldown-delta); dodge_cooldown=maxf(0,dodge_cooldown-delta)
    if cooldown<=0:interest=minf(1,interest+interest_recovery*delta)
    check_dodge()
    var direction=Vector3.ZERO
    if dodge_timer>0:
        dodge_timer=maxf(0,dodge_timer-delta); direction=dodge_direction*(dodge_speed if jumps_aside else escape_run_speed)
        $Status.text="Whoa!" if jumps_aside else "Coming through!"
    elif is_instance_valid(pad):
        var target=queue_target()
        direction=walk_direction(target)*run_speed
        $Status.text="%d items\n$%d"%[order.quantity,order.total]
        if global_position.distance_to(target)<.8:
            direction=Vector3.ZERO; service_elapsed+=delta
            if service_elapsed>=order.quantity*manager.seconds_per_item:manager.complete_order(self)
    elif crossing_phase>0 and is_instance_valid(crosswalk):
        var origin_side: int=-home_side if on_other_street else home_side
        if crossing_phase==1:
            var approach=crossing_target(origin_side)
            direction=walk_direction(approach)*walk_speed
            $Status.text="Crosswalk"
            if global_position.distance_to(approach)<.7:
                crossing_phase=2
                direction=Vector3.ZERO
        elif crossing_phase==2:
            $Status.text="WAIT"
            if crosswalk.walk_allowed:
                crossing_phase=3
        else:
            var destination=crossing_target(-origin_side)
            direction=walk_direction(destination)*run_speed
            $Status.text="WALK"
            if global_position.distance_to(destination)<.8:
                on_other_street=not on_other_street
                crossing_phase=0
                crossing_cooldown=randf_range(8.0,15.0)
                choose_wander_target()
                direction=Vector3.ZERO
    else:
        crossing_cooldown-=delta
        if crossing_cooldown<=0 and is_instance_valid(crosswalk):
            crossing_phase=1
        wander_timer-=delta
        if wander_timer<=0 or global_position.distance_to(wander_target)<.6:choose_wander_target()
        direction=walk_direction(wander_target)*walk_speed*.65
        if not on_other_street:
            direction.x=clampf((home_position.x-global_position.x)*2.0,-walk_speed,walk_speed)
        $Status.text="Fed" if cooldown>0 and has_eaten else "Interest\n%d%%"%roundi(interest*100)
    var space_push := personal_space_velocity()
    if dodge_timer<=0 and space_push.length_squared() > 0.001:
        var combined: Vector3 = direction + space_push
        var allowed_direction := walk_direction(global_position + combined)
        direction = allowed_direction * minf(combined.length(), maxf(direction.length(), 2.0))
    if dodge_timer<=0:
        var motion_clip="Idle"
        if direction.length_squared()>.04:motion_clip="Run" if is_instance_valid(pad) else "Walk"
        play_visual(motion_clip)
    if direction.length_squared()>.04:
        active_visual.rotation.y=atan2(direction.x,direction.z)
    velocity.x=direction.x; velocity.z=direction.z
    if not is_on_floor():velocity.y-=18*delta
    elif dodge_timer<=0:velocity.y=-.1
    move_and_slide()

func personal_space_velocity() -> Vector3:
    var push := Vector3.ZERO
    for other in get_tree().get_nodes_in_group("patrons"):
        if other == self:
            continue
        var offset: Vector3 = global_position - other.global_position
        if absf(offset.y) > 2.0:
            continue
        offset.y = 0.0
        var distance := offset.length()
        var radius: float = personal_space_radius + other.personal_space_radius
        if distance >= radius:
            continue
        # Coincident patrons choose opposite directions, avoiding a zero-vector deadlock.
        var away := offset / distance if distance > 0.001 else Vector3.RIGHT * (1.0 if get_instance_id() > other.get_instance_id() else -1.0)
        push += away * (1.0 - distance / radius) * 3.0
    return push.limit_length(2.5)
