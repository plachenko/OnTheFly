@tool
extends AcceptDialog

signal scene_requested(path: String)
var search: LineEdit
var list: ItemList
var open_only: CheckBox
var paths := PackedStringArray()
var previous_direction := 0
var repeat_time := 0.0
var held: Dictionary = {}

func _ready() -> void:
	title = "Scenes"
	ok_button_text = "Open / switch"
	add_cancel_button("Cancel")
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(620, 440)
	add_child(layout)
	search = LineEdit.new()
	search.placeholder_text = "Search scenes by name or folder…"
	search.text_changed.connect(func(_text: String): refresh())
	search.text_submitted.connect(func(_text: String): choose())
	layout.add_child(search)
	open_only = CheckBox.new()
	open_only.text = "Open scenes only"
	open_only.toggled.connect(func(_enabled: bool): refresh())
	layout.add_child(open_only)
	list = ItemList.new()
	list.custom_minimum_size.y = 340
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_activated.connect(func(_index: int): choose())
	layout.add_child(list)
	var hint := Label.new()
	hint.text = "D-pad / stick: browse · A: open · B: cancel · X: open scenes only"
	layout.add_child(hint)
	confirmed.connect(choose)

func collect(directory: EditorFileSystemDirectory) -> void:
	if directory == null:
		return
	for index in directory.get_file_count():
		var path := directory.get_file_path(index)
		if path.get_extension().to_lower() in ["tscn", "scn"]:
			paths.append(path)
	for index in directory.get_subdir_count():
		collect(directory.get_subdir(index))

func show_scenes() -> void:
	paths.clear()
	collect(EditorInterface.get_resource_filesystem().get_filesystem())
	paths.sort()
	search.text = ""
	held.clear()
	previous_direction = 0
	repeat_time = 0.0
	refresh()
	popup_centered(Vector2i(650, 530))
	search.grab_focus()

func refresh() -> void:
	list.clear()
	var opened := EditorInterface.get_open_scenes()
	var ordered := PackedStringArray()
	for path in opened:
		ordered.append(path)
	if not open_only.button_pressed:
		for path in paths:
			if not ordered.has(path):
				ordered.append(path)
	for path in ordered:
		if not search.text.is_empty() and not search.text.to_lower() in path.to_lower():
			continue
		var index := list.add_item(("[Open] " if opened.has(path) else "") + path.trim_prefix("res://"))
		list.set_item_metadata(index, path)
	get_ok_button().disabled = list.item_count == 0
	if list.item_count > 0:
		list.select(0)

func choose() -> void:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = list.get_item_metadata(selected[0])
	hide()
	scene_requested.emit(path)

func process_controller(device: int, delta: float, mapping: RefCounted) -> void:
	var axis: float = mapping.axis(device, JOY_AXIS_LEFT_Y)
	axis += float(mapping.button(device, JOY_BUTTON_DPAD_DOWN)) - float(mapping.button(device, JOY_BUTTON_DPAD_UP))
	var direction := int(signf(axis)) if absf(axis) > 0.55 else 0
	repeat_time -= delta
	if direction != 0 and list.item_count > 0 and (direction != previous_direction or repeat_time <= 0):
		var selected := list.get_selected_items()
		var current := selected[0] if not selected.is_empty() else 0
		list.select(posmod(current + direction, list.item_count))
		list.ensure_current_is_visible()
		repeat_time = 0.35 if direction != previous_direction else 0.12
	previous_direction = direction
	for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]:
		var pressed: bool = mapping.button(device, button)
		if pressed and not held.get(button, false):
			if button == JOY_BUTTON_A:
				choose()
			elif button == JOY_BUTTON_B:
				hide()
			else:
				open_only.button_pressed = not open_only.button_pressed
		held[button] = pressed
