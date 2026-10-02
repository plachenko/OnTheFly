@tool
extends RefCounted

var mapping := preload("res://addons/mcon_viewport/controller_mapping.gd").new()
var previous_direction: Vector2i = Vector2i.ZERO
var repeat_time: float = 0.0
var held_buttons: Dictionary = {}
var last_dock: EditorDock
var message: String = ""

func focused_window() -> Window:
	var base := EditorInterface.get_base_control()
	for node in base.get_tree().root.find_children("*", "Window", true, false):
		if node is Window and node.has_focus():
			return node
	return base.get_window()

func send_key(key: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		event.shift_pressed = shift
		focused_window().push_input(event)

func context_menu() -> void:
	var window := focused_window()
	var focus := window.gui_get_focus_owner()
	if focus is Tree and focus.get_selected() != null:
		var position: Vector2 = focus.get_item_area_rect(focus.get_selected()).get_center()
		# Invoke the same native handler as a right-click without changing
		# which tree nodes are selected (important for multi-selection).
		focus.emit_signal("item_mouse_selected", position, MOUSE_BUTTON_RIGHT)
		return
	if focus is ItemList and not focus.get_selected_items().is_empty():
		var index: int = focus.get_selected_items()[0]
		focus.emit_signal("item_clicked", index, focus.get_item_rect(index).get_center(), MOUSE_BUTTON_RIGHT)
		return
	if focus is Control:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT
			event.pressed = pressed
			event.position = focus.get_global_rect().get_center()
			event.global_position = event.position
			window.push_input(event)
	else:
		send_key(KEY_F10, true)

func focused_dock() -> EditorDock:
	var focus := focused_window().gui_get_focus_owner()
	var node: Node = focus
	while node:
		if node is EditorDock:
			last_dock = node
			return node
		if node is TabBar and node.get_parent() is TabContainer:
			var current: Control = node.get_parent().get_current_tab_control()
			if current is EditorDock:
				last_dock = current
				return current
		node = node.get_parent()
	return last_dock if is_instance_valid(last_dock) else null

func dock_popup(dock: EditorDock) -> Popup:
	var tabs := dock.get_parent() as TabContainer
	if not tabs:
		return null
	var index := tabs.get_tab_idx_from_control(dock)
	# Use the editor's own menu so its dock manager retains ownership/layout.
	tabs.get_tab_bar().emit_signal("tab_rmb_clicked", index)
	return tabs.get_popup()

func redock(dock: EditorDock) -> void:
	if dock.get_window() != EditorInterface.get_base_control().get_window():
		dock.get_window().emit_signal("close_requested")

func move_dock(direction: Vector2i) -> bool:
	var dock := focused_dock()
	if not dock:
		message = "Focus a dock first (Scene, Inspector, FileSystem...)"
		return false
	if direction.y > 0:
		redock(dock)
		message = "Redocked " + dock.title
		return true
	if direction.y < 0:
		var popup := dock_popup(dock)
		if not popup:
			message = "Panel is already floating"
			return false
		for button in popup.find_children("*", "Button", true, false):
			if button.text == "Make Floating":
				if button.disabled:
					message = button.tooltip_text
					popup.hide()
					return false
				button.emit_signal("pressed")
				message = "Floated " + dock.title
				return true
		popup.hide()
		message = "Floating control unavailable in this editor version"
		return false
	redock(dock)
	var popup := dock_popup(dock)
	if not popup:
		message = "Could not open dock layout controls"
		return false
	if not (dock.available_layouts & EditorDock.DOCK_LAYOUT_VERTICAL):
		popup.hide()
		message = "This panel does not support side docking"
		return false
	for grid in popup.find_children("*", "Control", true, false):
		if grid.has_signal("slot_clicked"):
			var slot := EditorDock.DOCK_SLOT_LEFT_UR if direction.x < 0 else EditorDock.DOCK_SLOT_RIGHT_UL
			grid.emit_signal("slot_clicked", slot)
			popup.hide()
			message = "Moved " + dock.title + (" left" if direction.x < 0 else " right")
			return true
	popup.hide()
	message = "Dock layout controls unavailable in this editor version"
	return false

func process_controller(device: int, delta: float) -> void:
	var window := focused_window()
	var focus := window.gui_get_focus_owner()
	if not focus:
		EditorInterface.get_file_system_dock().make_visible()
		EditorInterface.get_file_system_dock().grab_focus()
	var axis := Vector2(mapping.axis(device, JOY_AXIS_LEFT_X), mapping.axis(device, JOY_AXIS_LEFT_Y))
	axis.x += float(mapping.button(device, JOY_BUTTON_DPAD_RIGHT)) - float(mapping.button(device, JOY_BUTTON_DPAD_LEFT))
	axis.y += float(mapping.button(device, JOY_BUTTON_DPAD_DOWN)) - float(mapping.button(device, JOY_BUTTON_DPAD_UP))
	var direction := Vector2i.ZERO
	if axis.length() > 0.55:
		if absf(axis.x) > absf(axis.y):
			direction.x = int(signf(axis.x))
		else:
			direction.y = int(signf(axis.y))
	repeat_time -= delta
	if direction != Vector2i.ZERO and (direction != previous_direction or repeat_time <= 0.0):
		if mapping.button(device, JOY_BUTTON_BACK) and direction.x != 0:
			cycle_dock(direction.x)
		elif mapping.axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			move_dock(direction)
		else:
			send_key(KEY_LEFT if direction.x < 0 else KEY_RIGHT if direction.x > 0 else KEY_UP if direction.y < 0 else KEY_DOWN)
		repeat_time = 0.4 if direction != previous_direction else 0.15
	previous_direction = direction
	for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var down := mapping.button(device, button)
		if down and not held_buttons.get(button, false):
			if button == JOY_BUTTON_A:
				send_key(KEY_ENTER)
			elif button == JOY_BUTTON_B:
				send_key(KEY_ESCAPE)
			elif button == JOY_BUTTON_X:
				context_menu()
			elif button == JOY_BUTTON_Y:
				var selected := EditorInterface.get_selection().get_selected_nodes()
				if not selected.is_empty():
					EditorInterface.inspect_object(selected[0])
				var inspector: Node = EditorInterface.get_inspector()
				while inspector and not inspector is EditorDock:
					inspector = inspector.get_parent()
				if inspector is EditorDock:
					focus_panel(inspector)
			else:
				send_key(KEY_TAB, button == JOY_BUTTON_LEFT_SHOULDER)
		held_buttons[button] = down

func focus_panel(dock: EditorDock) -> void:
	dock.open()
	dock.make_visible()
	last_dock = dock
	for control in dock.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL:
			control.grab_focus()
			break
	message = "Panel: " + dock.title

func cycle_dock(direction: int) -> void:
	var panels: Array[EditorDock] = []
	for node in EditorInterface.get_base_control().find_children("*", "EditorDock", true, false):
		if node.global:
			panels.append(node)
	if panels.is_empty():
		return
	var current := panels.find(focused_dock())
	focus_panel(panels[posmod(current + direction, panels.size())])
