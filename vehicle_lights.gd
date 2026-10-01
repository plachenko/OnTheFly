extends Node3D

## Add this scene to a Kenney car or the truck. All dimensions and light states
## remain editable on this node in the Godot Inspector.
@export_enum("Truck", "Kenney Car") var vehicle_kind: int = 1
@export_range(1.5, 3.5, 0.05) var body_width: float = 2.4
@export_range(3.0, 9.0, 0.05) var body_length: float = 4.1
@export_range(0.3, 2.0, 0.05) var front_lamp_height: float = 0.8
@export_range(0.3, 2.5, 0.05) var rear_lamp_height: float = 0.9
@export var front_is_negative_z: bool = false
@export var headlight_beams: bool = false
@export var headlights_enabled: bool = true
@export_range(0.2, 1.5, 0.05) var indicator_period: float = 0.7

var brake_enabled: bool = false
var reverse_enabled: bool = false
var left_enabled: bool = false
var right_enabled: bool = false
var hazard_enabled: bool = false
var police_available: bool = false
var police_enabled: bool = false
var blink_clock: float = 0.0
var lamps: Dictionary = {}
var lamp_state: Dictionary = {}
var beams: Array[SpotLight3D] = []
var police_spots: Array[OmniLight3D] = []
var chassis_skeleton: Skeleton3D
var chassis_bone: int = -1
var rest_transform_in_skeleton: Transform3D

func _ready() -> void:
	build_lights()
	refresh_lights()

func _process(delta: float) -> void:
	blink_clock += delta
	refresh_lights()

func configure_kenney_car(is_police: bool) -> void:
	police_available = is_police
	refresh_lights()

func attach_to_chassis(target_skeleton: Skeleton3D) -> void:
	chassis_skeleton = target_skeleton
	chassis_bone = target_skeleton.find_bone("Chassis") if target_skeleton else -1
	if chassis_bone >= 0:
		rest_transform_in_skeleton = target_skeleton.global_transform.affine_inverse() * global_transform

func sync_with_chassis() -> void:
	if not is_instance_valid(chassis_skeleton) or chassis_bone < 0:
		return
	chassis_skeleton.force_update_all_bone_transforms()
	global_transform = chassis_skeleton.global_transform * chassis_skeleton.get_bone_global_pose(chassis_bone) * chassis_skeleton.get_bone_global_rest(chassis_bone).affine_inverse() * rest_transform_in_skeleton

func set_driving_lights(braking: bool, reversing: bool, left: bool, right: bool, hazards: bool) -> void:
	brake_enabled = braking
	reverse_enabled = reversing
	left_enabled = left
	right_enabled = right
	hazard_enabled = hazards
	refresh_lights()

func set_police_enabled(enabled: bool) -> void:
	police_enabled = enabled and police_available
	refresh_lights()

func build_lights() -> void:
	var front_sign := -1.0 if front_is_negative_z else 1.0
	var front_z := front_sign * body_length * 0.48
	var rear_z := -front_z
	var outer_x := body_width * 0.43
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side == front_sign else "Right"
		make_lamp("Headlight" + suffix, Vector3(side * outer_x, front_lamp_height, front_z), Color(0.96, 0.96, 0.78), Vector3(0.27, 0.16, 0.08))
		make_lamp("Brake" + suffix, Vector3(side * outer_x * 0.72, rear_lamp_height, rear_z), Color(1.0, 0.08, 0.06), Vector3(0.27, 0.16, 0.08))
		make_lamp("Reverse" + suffix, Vector3(side * outer_x * 0.36, rear_lamp_height, rear_z), Color(0.94, 0.98, 1.0), Vector3(0.17, 0.13, 0.08))
		make_lamp("FrontIndicator" + suffix, Vector3(side * outer_x, front_lamp_height, front_z - front_sign * 0.10), Color(1.0, 0.48, 0.04), Vector3(0.17, 0.12, 0.08))
		make_lamp("RearIndicator" + suffix, Vector3(side * outer_x, rear_lamp_height, rear_z), Color(1.0, 0.48, 0.04), Vector3(0.17, 0.12, 0.08))
		if headlight_beams:
			var beam := SpotLight3D.new()
			beam.name = "HeadlightBeam" + suffix
			beam.position = Vector3(side * outer_x, front_lamp_height, front_z)
			beam.rotation.y = 0.0 if front_sign < 0.0 else PI
			beam.light_color = Color(1.0, 0.96, 0.82)
			beam.light_energy = 0.7 if vehicle_kind == 1 else 1.4
			beam.spot_range = 14.0 if vehicle_kind == 1 else 26.0
			beam.spot_angle = 40.0
			beam.shadow_enabled = false
			add_child(beam)
			beams.append(beam)
	if vehicle_kind == 1:
		for suffix in ["Left", "Right"]:
			var side := front_sign if suffix == "Left" else -front_sign
			var color := Color(0.98, 0.06, 0.06) if suffix == "Left" else Color(0.06, 0.30, 1.0)
			var at := Vector3(side * 0.42, 2.05, 0.0)
			make_lamp("Police" + suffix, at, color, Vector3(0.65, 0.22, 0.30))
			var spot := OmniLight3D.new()
			spot.name = "PoliceGlow" + suffix
			spot.position = at
			spot.light_color = color
			spot.light_energy = 0.7
			spot.omni_range = 6.0
			spot.shadow_enabled = false
			add_child(spot)
			police_spots.append(spot)

func make_lamp(label: String, at: Vector3, color: Color, size: Vector3) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.position = at
	var lens := BoxMesh.new()
	lens.size = size
	visual.mesh = lens
	add_child(visual)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = color
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.emission_enabled = true
	lit.emission = color
	lit.emission_energy_multiplier = 2.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = color.darkened(0.82)
	dark.roughness = 0.75
	var tail := StandardMaterial3D.new()
	tail.albedo_color = color.darkened(0.35)
	tail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail.emission_enabled = true
	tail.emission = color
	tail.emission_energy_multiplier = 0.45
	lamps[label] = {"visual": visual, "lit": lit, "tail": tail, "dark": dark}

func refresh_lights() -> void:
	if lamps.is_empty():
		return
	var blinking := fmod(blink_clock, maxf(0.2, indicator_period)) < indicator_period * 0.5
	var left_flash := blinking and (left_enabled or hazard_enabled)
	var right_flash := blinking and (right_enabled or hazard_enabled)
	for suffix in ["Left", "Right"]:
		var signal_on := left_flash if suffix == "Left" else right_flash
		set_lamp("Headlight" + suffix, headlights_enabled)
		set_rear_red_lamp("Brake" + suffix)
		set_lamp("Reverse" + suffix, reverse_enabled)
		set_lamp("FrontIndicator" + suffix, signal_on)
		set_lamp("RearIndicator" + suffix, signal_on)
	for beam in beams:
		beam.visible = headlights_enabled
	var police_phase := fmod(blink_clock, 0.36) < 0.18
	set_lamp("PoliceLeft", police_available and police_enabled and police_phase)
	set_lamp("PoliceRight", police_available and police_enabled and not police_phase)
	for suffix in ["Left", "Right"]:
		if lamps.has("Police" + suffix):
			var entry: Dictionary = lamps["Police" + suffix]
			(entry["visual"] as MeshInstance3D).visible = police_available
	for index in range(police_spots.size()):
		police_spots[index].visible = police_available and police_enabled and (police_phase if index == 0 else not police_phase)

func set_lamp(label: String, enabled: bool) -> void:
	if not lamps.has(label):
		return
	if lamp_state.get(label, null) == enabled:
		return
	lamp_state[label] = enabled
	var entry: Dictionary = lamps[label]
	var visual := entry["visual"] as MeshInstance3D
	visual.material_override = entry["lit"] if enabled else entry["dark"]

func set_rear_red_lamp(label: String) -> void:
	var brightness := 2 if brake_enabled else (1 if headlights_enabled else 0)
	if lamp_state.get(label, -1) == brightness:
		return
	lamp_state[label] = brightness
	var entry: Dictionary = lamps[label]
	var visual := entry["visual"] as MeshInstance3D
	visual.material_override = entry["lit"] if brightness == 2 else (entry["tail"] if brightness == 1 else entry["dark"])
