extends Node3D

const DISTANCE := 64.0
const MARGIN := 4.0
static var metadata: Dictionary = {}
static var materials := {}
var actor: RigidBody3D
var impostor: MeshInstance3D
var detailed: Array[GeometryInstance3D] = []
var timer := 0.0
var force_detail := false
var enabled := false
var last_policy := -1

func _ready() -> void:
	actor = get_parent()
	if actor.model_scene == null: set_process(false); return
	if metadata.is_empty():
		if not FileAccess.file_exists("res://assets/car_impostors/metadata.json"): set_process(false); return
		metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/car_impostors/metadata.json"))
	var path: String = actor.model_scene.resource_path
	if not metadata.models.has(path): set_process(false); return
	var entry: Dictionary = metadata.models[path]
	var atlas: Texture2D = load(entry.atlas)
	if atlas == null: set_process(false); return
	var key := path
	if not materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = preload("res://car_impostor.gdshader")
		material.set_shader_parameter("atlas",atlas)
		material.set_shader_parameter("normal_atlas",load(entry.normals))
		materials[key] = material
	impostor = MeshInstance3D.new()
	impostor.name = "DistantCarBillboard"
	var quad := QuadMesh.new()
	quad.size = Vector2(float(entry.world_height)*256.0/192.0,float(entry.world_height))*actor.car_scale
	impostor.mesh = quad
	impostor.position = Vector3(entry.center[0],entry.center[1],entry.center[2])*actor.car_scale
	impostor.material_override = materials[key]
	impostor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var radius: float = quad.size.length()*.5
	impostor.custom_aabb = AABB(Vector3.ONE*-radius,Vector3.ONE*radius*2)
	add_child(impostor)
	for node in actor.get_node("Visual").find_children("*","GeometryInstance3D",true,false): detailed.append(node)
	for node in actor.get_node("VehicleLights").find_children("*","GeometryInstance3D",true,false): detailed.append(node)
	PerformanceDiagnostics.rendering_lod_changed.connect(refresh)
	enabled = true
	refresh()

func refresh() -> void:
	if not enabled: return
	force_detail = actor.disabled or actor.exploded or actor.hybrid_pending_strength > 0
	if actor.hybrid != null and actor.hybrid.state != actor.hybrid.State.DRIVING: force_detail = true
	var use_lod: bool = PerformanceDiagnostics.rendering_lod_enabled and not force_detail
	impostor.visible = use_lod and actor.ambient_active
	if last_policy == int(use_lod): return
	last_policy = int(use_lod)
	for mesh in detailed:
		mesh.visibility_range_end = DISTANCE if use_lod else 0.0
		mesh.visibility_range_end_margin = MARGIN if use_lod else 0.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	impostor.visibility_range_begin = DISTANCE
	impostor.visibility_range_begin_margin = MARGIN
	impostor.visibility_range_end = 260

func _process(delta: float) -> void:
	# Predict only the picture between coarse route ticks. Physics remains at the
	# authoritative route position and is restored before entering interaction range.
	position = actor.global_basis.inverse()*actor.motion_vector*actor.distant_elapsed if actor.distant_mode and not force_detail else Vector3.ZERO
	if actor.distant_mode and not force_detail and is_instance_valid(actor.city):
		var picture: Vector3 = actor.global_position+actor.motion_vector*actor.distant_elapsed
		picture.y = preload("res://traffic_ground.gd").height(actor.city,picture.x,picture.z)+.09
		global_position = picture
	timer -= delta
	if timer > 0: return
	timer = .2
	refresh()
