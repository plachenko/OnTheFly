extends AcceptDialog

func _ready() -> void:
	title = "Share OnTheFly"
	ok_button_text = "Close"

func show_codes(codes: Dictionary, explanation: String) -> void:
	for child in get_children():
		if child is VBoxContainer:
			remove_child(child)
			child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var hint := Label.new()
	hint.text = explanation
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 320
	column.add_child(hint)
	var row := HBoxContainer.new()
	column.add_child(row)
	for caption in codes:
		var item := VBoxContainer.new()
		row.add_child(item)
		var label := Label.new()
		label.text = caption
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(label)
		var encoder := preload("res://addons/qr_share/qr_code.gd").new()
		var source: Image = encoder.get_texture(codes[caption]).get_image()
		encoder.free()
		# The encoder supplies one white module; add three for the QR quiet zone.
		var padded := Image.create(source.get_width() + 6, source.get_height() + 6, false, Image.FORMAT_RGBA8)
		padded.fill(Color.WHITE)
		padded.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(3, 3))
		var scale_factor := maxi(1, floori(256.0 / padded.get_width()))
		padded.resize(padded.get_width() * scale_factor, padded.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)
		var qr := TextureRect.new()
		qr.texture = ImageTexture.create_from_image(padded)
		qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		item.add_child(qr)
		var copy := Button.new()
		copy.text = "Copy link"
		copy.pressed.connect(func(): DisplayServer.clipboard_set(codes[caption]))
		item.add_child(copy)
	popup_centered()

func show_release() -> void:
	var repository: String = ProjectSettings.get_setting("application/config/update_repository", "plachenko/OnTheFly")
	var base := "https://github.com/%s/releases/latest" % repository
	var codes := {"Latest release": base, "Android APK": base + "/download/OnTheFly.apk"}
	if OS.get_name() == "Android":
		codes = {"Android APK": base + "/download/OnTheFly.apk", "Latest release": base}
	show_codes(codes, "Scan to download OnTheFly. These links always follow the latest GitHub release.")
