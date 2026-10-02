@tool
extends RefCounted

const IDLE := Color(1.0, 1.0, 1.0, 0.85)
const TARGET := Color(0.25, 1.0, 0.65)
const EDGES := [[0, 1], [0, 2], [0, 4], [1, 3], [1, 5], [2, 3], [2, 6], [3, 7], [4, 5], [4, 6], [5, 7], [6, 7]]

static func corners(bounds: AABB, transform: Transform3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in 8:
		var offset := Vector3(bounds.size.x if index & 1 else 0.0, bounds.size.y if index & 2 else 0.0, bounds.size.z if index & 4 else 0.0)
		result.append(transform * (bounds.position + offset))
	return result

static func draw(overlay: Control, camera: Camera3D, mesh: MeshInstance3D, target_name: String) -> void:
	var center := overlay.size * 0.5
	var color := TARGET if is_instance_valid(mesh) else IDLE
	# A dark backing keeps the reticle legible over bright materials.
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		for side in [-1.0, 1.0]:
			overlay.draw_line(center + axis * side * 5.0, center + axis * side * 14.0, Color(0, 0, 0, 0.8), 4.0)
			overlay.draw_line(center + axis * side * 5.0, center + axis * side * 14.0, color, 2.0)
	overlay.draw_circle(center, 2.0, color)
	if not is_instance_valid(mesh) or mesh.mesh == null:
		return
	var points := corners(mesh.mesh.get_aabb(), mesh.global_transform)
	var scale := overlay.size / Vector2(camera.get_viewport().size)
	for edge in EDGES:
		var from := points[edge[0]]
		var to := points[edge[1]]
		if camera.is_position_behind(from) or camera.is_position_behind(to):
			continue
		var a := camera.unproject_position(from) * scale
		var b := camera.unproject_position(to) * scale
		overlay.draw_line(a, b, Color(0, 0, 0, 0.75), 4.0, true)
		overlay.draw_line(a, b, TARGET, 2.0, true)
	var font := ThemeDB.fallback_font
	var text := target_name + " · Ray select"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var label_pos := center + Vector2(20, 30)
	overlay.draw_style_box(label_box(), Rect2(label_pos - Vector2(6, 20), text_size + Vector2(12, 12)))
	overlay.draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TARGET)

static func label_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.03, 0.85)
	return style
