@tool
extends Window
signal attached(original_path: String, painted_path: String, original_context: String, painted_context: String)
var editor: EditorInterface
var canvas: Control
var picker: FileDialog
var status: Label
var original_context: TextEdit
var painted_context: TextEdit
var brush_size: HSlider
var color_picker: ColorPickerButton
var sample_button: Button
func _ready() -> void:
	title = "Screenshot paint-over"
	size = Vector2i(1000, 720)
	min_size = Vector2i(800, 500)
	transient = true
	close_requested.connect(hide)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var toolbar := HBoxContainer.new()
	box.add_child(toolbar)
	add_button(toolbar, "Capture 3D", capture)
	add_button(toolbar, "Open screenshot…", func(): picker.popup_centered(Vector2i(800, 500)))
	add_button(toolbar, "Undo", func(): canvas.undo())
	add_button(toolbar, "Clear", func(): canvas.clear())
	var tools := HBoxContainer.new()
	box.add_child(tools)
	color_picker = ColorPickerButton.new()
	color_picker.color = Color(1.0, 0.15, 0.08)
	color_picker.tooltip_text = "Custom color"
	color_picker.color_changed.connect(choose_color)
	tools.add_child(color_picker)
	var palette := {"White": Color.WHITE, "Black": Color.BLACK, "Red": Color("ff3020"), "Orange": Color("ff921c"), "Yellow": Color("ffea20"), "Green": Color("3bea40"), "Blue": Color("3098ff"), "Purple": Color("b84bff")}
	for name in palette:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(26, 26)
		swatch.tooltip_text = name
		var style := StyleBoxFlat.new()
		style.bg_color = palette[name]
		style.set_border_width_all(1)
		style.border_color = Color("727272")
		swatch.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.set_border_width_all(3)
		hover.border_color = Color.WHITE
		swatch.add_theme_stylebox_override("hover", hover)
		swatch.add_theme_stylebox_override("pressed", hover)
		swatch.pressed.connect(choose_color.bind(palette[name]))
		tools.add_child(swatch)
	sample_button = Button.new()
	sample_button.text = "Sample color"
	sample_button.toggle_mode = true
	sample_button.tooltip_text = "Click a pixel in the image to use its color"
	sample_button.toggled.connect(func(value):
		canvas.sampling = value
		canvas.current = {}
		canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS if value else Control.CURSOR_ARROW
	)
	tools.add_child(sample_button)
	var brush_label := Label.new()
	brush_label.text = "Brush"
	tools.add_child(brush_label)
	brush_size = HSlider.new()
	brush_size.min_value = 2
	brush_size.max_value = 40
	brush_size.step = 1
	brush_size.value = 8
	brush_size.custom_minimum_size.x = 140
	brush_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(brush_size)
	var width_label := Label.new()
	width_label.text = "8 px"
	width_label.custom_minimum_size.x = 45
	brush_size.value_changed.connect(func(value):
		canvas.pen_width = value
		width_label.text = "%d px" % int(value)
	)
	tools.add_child(width_label)
	var original_label := Label.new()
	original_label.text = "Original image context"
	box.add_child(original_label)
	original_context = TextEdit.new()
	original_context.placeholder_text = "What is happening in the original screenshot?"
	original_context.custom_minimum_size.y = 55
	original_context.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(original_context)
	var painted_label := Label.new()
	painted_label.text = "Paint-over context"
	box.add_child(painted_label)
	painted_context = TextEdit.new()
	painted_context.placeholder_text = "What should change? Explain your markings."
	painted_context.custom_minimum_size.y = 55
	painted_context.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(painted_context)
	canvas = preload("res://addons/codex_chat/paint_canvas.gd").new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.color_sampled.connect(choose_color)
	canvas.resized.connect(canvas.queue_redraw)
	box.add_child(canvas)
	status = Label.new()
	status.text = "Open a screenshot or capture the 3D editor viewport, then draw."
	box.add_child(status)
	add_button(box, "Attach paint-over to message", attach_image)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp; Images"])
	picker.file_selected.connect(load_image)
	add_child(picker)
func add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
func choose_color(color: Color) -> void:
	color_picker.color = color
	canvas.pen_color = color
	sample_button.button_pressed = false
func capture() -> void:
	if editor == null:
		status.text = "Capture is available inside the Godot editor. You can open a screenshot instead."
		return
	var viewport := editor.get_editor_viewport_3d(0)
	if viewport == null:
		status.text = "Open a 3D scene first."
		return
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		status.text = "No viewport image is available."
		return
	canvas.set_image(image)
	status.text = "3D viewport captured. Draw your changes, then attach."
func load_image(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		status.text = "Could not open that image. Use PNG, JPEG, or WebP."
		return
	canvas.set_image(image)
	status.text = path.get_file()
func attach_image() -> void:
	var image: Image = canvas.painted_image()
	if image == null:
		status.text = "Open or capture an image first."
		return
	var directory := ProjectSettings.globalize_path("res://.godot/codex_chat/paintovers")
	DirAccess.make_dir_recursive_absolute(directory)
	var id := Crypto.new().generate_random_bytes(8).hex_encode()
	var path := directory.path_join("paintover_%s.png" % id)
	var original_path := directory.path_join("original_%s.png" % id)
	if canvas.base.save_png(original_path) != OK:
		status.text = "Could not save the original image."
		return
	if image.save_png(path) != OK:
		status.text = "Could not save the paint-over."
		return
	attached.emit(original_path, path, original_context.text.strip_edges(), painted_context.text.strip_edges())
	hide()
