@tool
extends RefCounted

static func apply(button: Button, color: Color, left: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		if state == "hover": style.bg_color = color.lightened(0.15)
		elif state == "pressed": style.bg_color = color.darkened(0.18)
		elif state == "disabled": style.bg_color = Color(0.20, 0.22, 0.24)
		style.set_corner_radius_all(14)
		if left: style.corner_radius_top_left = 56
		else: style.corner_radius_top_right = 56
		style.corner_detail = 20
		style.content_margin_left = 28
		style.content_margin_right = 28
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	focus.border_color = Color(1, 1, 1, 0.85)
	focus.set_corner_radius_all(14)
	if left: focus.corner_radius_top_left = 56
	else: focus.corner_radius_top_right = 56
	focus.corner_detail = 20
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.55, 0.58))

