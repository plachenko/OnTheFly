extends Node3D

var text := ""

func _ready() -> void:
	name = "SpeechBubble"
	position = Vector3(0, 5.6, 0)
	# A viewport turns the rounded panel into a real, camera-facing world quad.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.size = Vector2(496, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff2d7")
	style.set_corner_radius_all(24)
	panel.add_theme_stylebox_override("panel", style)
	viewport.add_child(panel)
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", Color("292b32"))
	panel.add_child(caption)
	var tail := Polygon2D.new()
	tail.position = Vector2(120, 102)
	tail.polygon = PackedVector2Array([Vector2(0, 0), Vector2(34, 0), Vector2(5, 22)])
	tail.color = style.bg_color
	viewport.add_child(tail)
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = 0.009
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	add_child(sprite)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", 7.1, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35).set_delay(1.0)
	tween.chain().tween_callback(queue_free)
