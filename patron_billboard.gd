extends MeshInstance3D

const CLIPS := ["Idle", "Walk", "Run", "Dodge"]
const COLORS := [Color("d9564d"), Color("4b83c4"), Color("62a467"), Color("d6ad45"), Color("985fa9"), Color("49a7a3")]
static var sheets := {}
static var metadata := {}
var current_animation := "Idle"
var animation_elapsed := 0.0
var variant := 0
var last_frame := -1
var durations: Array

func configure(index: int, color: Color, height: float) -> void:
	variant = index
	if metadata.is_empty():
		metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/patron_sprites/metadata.json"))
	if not sheets.has(index):
		sheets[index] = [load("res://assets/patron_sprites/variant_%d_atlas.png" % index), load("res://assets/patron_sprites/variant_%d_mask.png" % index)]
	durations = metadata.durations[index]
	var quad := QuadMesh.new()
	quad.size = Vector2(2.1, 2.8)
	quad.center_offset = Vector3(0, 1.4, 0)
	mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://patron_billboard.gdshader")
	material.set_shader_parameter("atlas", sheets[index][0])
	material.set_shader_parameter("clothing_mask", sheets[index][1])
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1.7, -0.2, -1.7), Vector3(3.4, 3.6, 3.4))
	set_appearance(color, height)
	update_frame()

func set_appearance(color: Color, height: float) -> void:
	scale = Vector3(1.0, clampf(height, 0.85, 1.15), 1.0)
	material_override.set_shader_parameter("clothing_color", color)

func play(clip: String, _blend: float = 0.0) -> void:
	if clip == current_animation: return
	current_animation = clip if clip in CLIPS else "Idle"
	animation_elapsed = 0.0
	last_frame = -1
	update_frame()

func _process(delta: float) -> void:
	animation_elapsed += delta
	update_frame()

func update_frame() -> void:
	if durations == null: return
	var row := CLIPS.find(current_animation)
	var duration: float = durations[row]
	var fraction := animation_elapsed / duration
	var frame := mini(11, int(fraction * 12.0)) if current_animation == "Dodge" else int(fmod(fraction, 1.0) * 12.0)
	if frame == last_frame: return
	last_frame = frame
	material_override.set_shader_parameter("animation_row", row)
	material_override.set_shader_parameter("animation_frame", frame)
