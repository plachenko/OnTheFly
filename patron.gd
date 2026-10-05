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
var wander_axis := Vector3.FORWARD
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
var visual_anim: Node
var active_visual: Node3D
@export var appearance_color_index := -1
@export var height_scale := -1.0
var billboard_visual := true
const CHARACTER_PATHS := ["criminalMaleA", "cyborgFemaleA", "skaterFemaleA", "skaterMaleA"]

func _ready() -> void:
	add_to_group("patrons")
	PerformanceDiagnostics.apply_pedestrian_logic.call_deferred(self)
	choose_wander_target()
	character_variant = randi_range(0, 3) if character_variant < 0 else clampi(character_variant, 0, 3)
	if appearance_color_index < 0: appearance_color_index = randi_range(0, 5)
	if height_scale < 0.0: height_scale = randf_range(0.85, 1.15)
	billboard_visual = not "--patron-3d" in OS.get_cmdline_user_args()
	if billboard_visual:
		active_visual = preload("res://patron_billboard.gd").new()
		$VisualVariants.add_child(active_visual)
		active_visual.configure(character_variant, preload("res://patron_billboard.gd").COLORS[appearance_color_index], height_scale)
		visual_anim = active_visual
	else:
		active_visual = load("res://assets/kenney/%s.glb" % CHARACTER_PATHS[character_variant]).instantiate()
		active_visual.scale = Vector3(.36, .516, .516) * Vector3(1, height_scale, 1)
		$VisualVariants.add_child(active_visual)
		visual_anim = active_visual.get_node("AnimationPlayer")
		for clip in ["Idle", "Walk", "Run"]: visual_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		visual_anim.play("Idle")
	apply_appearance()
	for mesh in $VisualVariants.find_children("*", "GeometryInstance3D", true, false): fade_meshes.append(mesh)

func apply_appearance() -> void:
	height_scale = clampf(height_scale, 0.85, 1.15)
	appearance_color_index = clampi(appearance_color_index, 0, 5)
	if billboard_visual:
		active_visual.set_appearance(preload("res://patron_billboard.gd").COLORS[appearance_color_index], height_scale)
	var shape := $CollisionShape3D.shape.duplicate() as CapsuleShape3D
	shape.height = 1.98 * height_scale
	$CollisionShape3D.shape = shape
	$CollisionShape3D.position.y = shape.height * 0.5
	$Status.position.y = 2.55 * height_scale

func play_visual(clip: String) -> void:
	if visual_anim.current_animation!=clip:
		visual_anim.play(clip,.08 if clip=="Dodge" else .16)

func choose_wander_target() -> void:
	wander_target = home_position + wander_axis * randf_range(-wander_radius, wander_radius)
	wander_timer = 5.0

func can_be_attracted() -> bool:
	return not has_eaten and not departing and age >= 2.0 and interest>=manager.attraction_interest_threshold and budget>0

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
	var target: Vector3=truck.global_transform*Vector3(3.15+float(queue_slot%2)*1.8,0,-1.2+float(int(float(queue_slot)/2.0))*1.8)
	target.y=global_position.y
	return target

var age := 0.0
var departing := false
var departure_elapsed := 0.0
var departure_direction := Vector3.ZERO
var fade_alpha := 1.0
var fade_meshes: Array[GeometryInstance3D] = []

func begin_departure() -> void:
	if departing: return
	cancel_order()
	departing = true
	departure_elapsed = 0.0
	departure_direction = (global_position - manager.level.truck.global_position)
	departure_direction.y = 0.0
	departure_direction = departure_direction.normalized()
	if departure_direction.is_zero_approx(): departure_direction = Vector3.FORWARD
	$Status.text = "Fed!"

func set_fade(alpha: float) -> void:
	fade_alpha = clampf(alpha, 0.0, 1.0)
	if billboard_visual and is_instance_valid(active_visual):
		active_visual.material_override.set_shader_parameter("fade_alpha", fade_alpha)
	else:
		for mesh in fade_meshes:
			if is_instance_valid(mesh): mesh.transparency = 1.0 - fade_alpha
	$Status.modulate.a = fade_alpha

func walk_direction(target: Vector3) -> Vector3:
	var direction := target - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.3 else Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not PerformanceDiagnostics.pedestrian_logic_enabled: return
	if not is_instance_valid(manager) or not manager.level.is_processing() or manager.level.round_finished: return
	var started := Time.get_ticks_usec()
	age += delta
	var direction := Vector3.ZERO
	if departing:
		departure_elapsed += delta
		direction = departure_direction * walk_speed
		if departure_elapsed >= 4.0: set_fade(1.0 - (departure_elapsed - 4.0) / 2.0)
		if departure_elapsed >= 6.0:
			queue_free()
			return
	elif is_instance_valid(pad):
		var target := queue_target()
		direction = walk_direction(target) * walk_speed
		$Status.text = "%d items\n$%d" % [order.quantity, order.total]
		if global_position.distance_to(target) < 0.8:
			direction = Vector3.ZERO
			service_elapsed += delta
			if service_elapsed >= order.quantity * manager.seconds_per_item: manager.complete_order(self)
	else:
		wander_timer = maxf(0.0, wander_timer - delta)
		if wander_timer > 0.0: direction = walk_direction(wander_target) * walk_speed
		$Status.text = "Hungry"
	play_visual("Walk" if direction.length_squared() > 0.04 else "Idle")
	if direction.length_squared() > 0.04: active_visual.rotation.y = atan2(direction.x, direction.z)
	velocity.x = direction.x
	velocity.z = direction.z
	velocity.y = velocity.y - 18.0 * delta if not is_on_floor() else -0.1
	move_and_slide()
	PerformanceDiagnostics.record_section("Patrons", Time.get_ticks_usec() - started)
