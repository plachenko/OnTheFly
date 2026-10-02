@tool
extends Node

const PROFILE := "res://.godot/mcon_ui_actions.cfg"
const Names = preload("res://addons/mcon_viewport/controller_mapping.gd")
var device_provider: Callable
var bindings: Array = []
var target: Dictionary = {}
var menu: PopupMenu
var dialog: ConfirmationDialog
var hint: Label
var sequence_mode := false
var recording := false
var captured: Array = []
var history: Array = []
var held: Dictionary = {}
var last_press := 0.0
var refresh_time := 0.0
var cooldown := 0.0
var connected_device := -1
var hooked: Array[WeakRef] = []
var suspended := false

func _ready() -> void:
	menu = PopupMenu.new()
	menu.name = "ControllerActionMenu"
	add_child(menu)
	menu.id_pressed.connect(menu_selected)
	dialog = ConfirmationDialog.new()
	dialog.title = "Listen for controller action"
	dialog.ok_button_text = "Save binding"
	dialog.add_cancel_button("Cancel")
	add_child(dialog)
	hint = Label.new()
	hint.custom_minimum_size = Vector2(560, 110)
	dialog.add_child(hint)
	dialog.confirmed.connect(save_capture)
	dialog.canceled.connect(cancel_capture)
	dialog.close_requested.connect(cancel_capture)
	dialog.window_input.connect(func(event: InputEvent):
		if event is InputEventJoypadButton and recording:
			dialog.set_input_as_handled())
	dialog.visibility_changed.connect(func():
		if not dialog.visible: recording = false)
	load_profile()
	scan_controls()

func scan_controls() -> void:
	for node in EditorInterface.get_base_control().get_tree().root.find_children("*", "Control", true, false):
		if is_ancestor_of(node) or node.has_meta("mcon_action_hook"):
			continue
		if node is BaseButton or node is Tree or node is ItemList:
			node.set_meta("mcon_action_hook", true)
			node.gui_input.connect(control_input.bind(node))
			hooked.append(weakref(node))
	for popup in EditorInterface.get_base_control().get_tree().root.find_children("*", "PopupMenu", true, false):
		if popup == menu or is_ancestor_of(popup) or popup.has_meta("mcon_action_hook"):
			continue
		popup.set_meta("mcon_action_hook", true)
		popup.window_input.connect(popup_input.bind(popup))
		hooked.append(weakref(popup))

func descriptor(node: Node, kind: String, label: String) -> Dictionary:
	var result := {"path": str(EditorInterface.get_base_control().get_tree().root.get_path_to(node)), "signature": stable_signature(node), "class": node.get_class(), "kind": kind, "label": label}
	if node is BaseButton:
		result["tooltip"] = node.tooltip_text
		result["shortcut"] = node.shortcut.resource_name if node.shortcut != null else ""
		result["text"] = node.text if node is Button else ""
		if label.is_empty():
			result["label"] = result.shortcut if not result.shortcut.is_empty() else node.tooltip_text
	return result

func target_matches(node: Node, selected: Dictionary) -> bool:
	if node.get_class() != selected.get("class", node.get_class()): return false
	if stable_signature(node) != selected.get("signature", stable_signature(node)): return false
	if node is BaseButton:
		if selected.has("shortcut"):
			var shortcut_name: String = node.shortcut.resource_name if node.shortcut != null else ""
			if shortcut_name != selected.shortcut: return false
		if selected.has("tooltip") and node.tooltip_text != selected.tooltip: return false
		if node is Button and node.text != selected.get("text", selected.get("label", "")): return false
	return true

func resolve_target(selected: Dictionary) -> Node:
	var path := NodePath(selected.get("path", ""))
	if path.is_empty(): return null
	var node := get_tree().root.get_node_or_null(path)
	if node != null and target_matches(node, selected): return node
	var matches: Array[Node] = []
	for candidate in get_tree().root.find_children("*", selected.get("class", "Control"), true, false):
		if target_matches(candidate, selected): matches.append(candidate)
	if matches.size() == 1: return matches[0]
	# Migrate old unnamed buttons when only the EditorNode instance ID changed.
	# Their original leaf name disambiguates Run from Pause/Stop before adding
	# the shortcut/tooltip identity used on subsequent editor restarts.
	if not selected.has("shortcut") and path.get_name_count() > 0:
		var legacy_matches: Array[Node] = []
		for candidate in matches:
			if str(candidate.name) == path.get_name(path.get_name_count() - 1): legacy_matches.append(candidate)
		if legacy_matches.size() == 1: return legacy_matches[0]
	return null

func stable_signature(node: Node) -> String:
	var parts := PackedStringArray()
	while node != null:
		var part := str(node.name)
		if part.begins_with("@"):
			part = "@" + part.get_slice("@", 1)
		parts.insert(0, part)
		node = node.get_parent()
	return "/".join(parts)

func control_input(event: InputEvent, control: Control) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var selected: Dictionary = {}
	if control is BaseButton:
		selected = descriptor(control, "button", control.text if control is Button else control.tooltip_text)
	elif control is Tree:
		var item: TreeItem = control.get_item_at_position(event.position)
		if item != null:
			selected = descriptor(control, "tree", item.get_text(0))
			selected["item_path"] = tree_path(item)
	elif control is ItemList:
		var index: int = control.get_item_at_position(event.position, true)
		if index >= 0:
			selected = descriptor(control, "list", control.get_item_text(index))
	if not selected.is_empty():
		show_context.call_deferred(selected, control.get_screen_position() + event.position)

func popup_input(event: InputEvent, popup: PopupMenu) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var index := popup.get_focused_item()
		if index >= 0 and not popup.is_item_separator(index) and popup.get_item_submenu(index).is_empty():
			var selected := descriptor(popup, "menu", popup.get_item_text(index))
			selected["id"] = popup.get_item_id(index)
			show_context.call_deferred(selected, Vector2(popup.position) + event.position)
			popup.set_input_as_handled()

func tree_path(item: TreeItem) -> Array:
	var result: Array = []
	while item != null:
		result.push_front(item.get_text(0))
		item = item.get_parent()
	return result

func show_context(selected: Dictionary, screen_position: Vector2) -> void:
	if recording:
		return
	target = selected
	if not is_instance_valid(menu):
		menu = PopupMenu.new()
		menu.name = "ControllerActionMenu"
		add_child(menu)
		menu.id_pressed.connect(menu_selected)
	# Detach the previous native menu's entry before reusing the recorder menu.
	if menu.get_parent() is PopupMenu:
		var previous: PopupMenu = menu.get_parent()
		for index in range(previous.item_count - 1, -1, -1):
			if previous.get_item_submenu_node(index) == menu: previous.remove_item(index)
		menu.reparent(self)
	# Keep the editor's native context menu; append our submenu when one opened.
	menu.clear()
	menu.add_item("Listen for controller press…", 0)
	menu.add_item("Listen for controller sequence…", 1)
	menu.add_separator()
	menu.add_item("Remove controller binding", 2)
	menu.set_item_disabled(3, binding_index(target) < 0)
	for popup in get_tree().root.find_children("*", "PopupMenu", true, false):
		if popup != menu and popup.visible and target.kind != "menu":
			# A submenu selection doesn't dispatch an unknown action to Godot.
			for index in range(popup.item_count - 1, -1, -1):
				if popup.get_item_text(index) == "Controller binding":
					popup.remove_item(index)
			menu.reparent(popup)
			popup.add_submenu_node_item("Controller binding", menu)
			return
	menu.position = Vector2i(screen_position)
	menu.popup()

func menu_selected(id: int) -> void:
	if id == 2:
		var index := binding_index(target)
		if index >= 0:
			bindings.remove_at(index)
			save_profile()
		return
	begin_capture(id == 1)

func begin_capture(sequence: bool) -> void:
	sequence_mode = sequence
	captured.clear()
	history.clear()
	recording = true
	seed_held(device_provider.call())
	update_hint()
	dialog.popup_centered(Vector2i(600, 180))

func update_hint() -> void:
	var labels := PackedStringArray()
	for button in captured:
		labels.append(Names.PHYSICAL_BUTTON_NAMES[button])
	hint.text = "Invoke: %s\n%s\nRecorded: %s\nRelease held buttons first. Esc cancels." % [target.get("label", "Item"), "Press buttons in order, then click Save (maximum 8; 1 second between presses)." if sequence_mode else "Press one button, then click Save.", " → ".join(labels) if not labels.is_empty() else "Listening…"]
	dialog.get_ok_button().disabled = captured.is_empty()

func cancel_capture() -> void:
	recording = false
	captured.clear()
	history.clear()
	cooldown = 0.35

func save_capture() -> void:
	if captured.is_empty():
		return
	# Replace both the target's old binding and an identical sequence.
	for index in range(bindings.size() - 1, -1, -1):
		if bindings[index].target == target or bindings[index].buttons == captured:
			bindings.remove_at(index)
	bindings.append({"target": target.duplicate(true), "buttons": captured.duplicate()})
	save_profile()
	cancel_capture()

func binding_index(selected: Dictionary) -> int:
	for index in bindings.size():
		if bindings[index].target == selected:
			return index
	return -1

func save_profile(path: String = PROFILE) -> Error:
	var config := ConfigFile.new()
	config.set_value("actions", "bindings", bindings)
	var error := config.save(path)
	if error != OK:
		push_warning("Controller action bindings could not be saved: " + error_string(error))
	return error

func load_profile(path: String = PROFILE) -> void:
	var config := ConfigFile.new()
	bindings.clear()
	if config.load(path) != OK:
		return
	var entries: Variant = config.get_value("actions", "bindings", [])
	if not entries is Array:
		return
	var migrated := false
	for entry in entries:
		if not entry is Dictionary or not entry.get("target") is Dictionary or not entry.get("buttons") is Array:
			continue
		var valid: bool = entry.buttons.size() > 0 and entry.buttons.size() <= 8
		for button in entry.buttons:
			valid = valid and button is int and button >= 0 and button < 21
		if valid:
			if entry.target.get("kind") == "button" and not entry.target.has("shortcut"):
				var node := resolve_target(entry.target)
				if node != null:
					entry.target.merge(descriptor(node, "button", entry.target.get("label", "")), true)
					migrated = true
			bindings.append(entry)
	if migrated: save_profile(path)

func seed_held(device: int) -> void:
	connected_device = device
	held.clear()
	for index in 21:
		held[index] = Input.is_joy_button_pressed(device, index) if device >= 0 else false

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and not EditorInterface.is_playing_scene() and not suspended:
		if recording or cooldown > 0.0 or owns_button(event.button_index):
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	refresh_time -= delta
	cooldown = maxf(0.0, cooldown - delta)
	if refresh_time <= 0.0:
		scan_controls()
		refresh_time = 1.0
	var device: int = device_provider.call()
	var focused := get_tree().root.has_focus()
	for window in get_tree().root.find_children("*", "Window", true, false):
		if window.has_focus(): focused = true
	if not focused or EditorInterface.is_playing_scene() or suspended or not Input.get_connected_joypads().has(device):
		history.clear()
		seed_held(device)
		return
	if device != connected_device:
		seed_held(device)
		return
	for index in 21:
		var pressed := Input.is_joy_button_pressed(device, index)
		var previous: bool = held.get(index, false)
		held[index] = pressed
		if pressed and not previous and cooldown <= 0.0:
			press(index, Time.get_ticks_msec() / 1000.0)
	if not recording and not history.is_empty() and Time.get_ticks_msec() / 1000.0 - last_press > 1.0:
		finish_sequence()

func press(button: int, now: float) -> bool:
	if recording:
		if (sequence_mode or captured.is_empty()) and captured.size() < 8:
			captured.append(button)
			update_hint()
		return true
	if bindings.is_empty() or (history.is_empty() and not owns_button(button)):
		return false
	if now - last_press > 1.0:
		finish_sequence()
	last_press = now
	history.append(button)
	if history.size() > 8: history.pop_front()
	var exact: Dictionary = {}
	var has_longer := false
	for binding in bindings:
		if is_prefix(history, binding.buttons):
			if history.size() == binding.buttons.size(): exact = binding
			else: has_longer = true
	if not exact.is_empty() and not has_longer:
		invoke(exact.target)
		history.clear()
		return true
	if not has_longer and exact.is_empty():
		history = [button] if owns_button(button) else []
		for binding in bindings:
			if binding.buttons == history:
				var longer := false
				for other in bindings:
					if other.buttons.size() > 1 and other.buttons[0] == button: longer = true
				if not longer:
					invoke(binding.target)
					history.clear()
					return true
	return has_longer or not exact.is_empty()

func is_prefix(prefix: Array, sequence: Array) -> bool:
	if prefix.size() > sequence.size(): return false
	for index in prefix.size():
		if prefix[index] != sequence[index]: return false
	return true

func finish_sequence() -> void:
	for binding in bindings:
		if binding.buttons == history:
			invoke(binding.target)
			break
	history.clear()

func owns_button(button: int) -> bool:
	for binding in bindings:
		if button in binding.buttons: return true
	return false

func blocking_builtin(device: int) -> bool:
	if recording or dialog.visible or cooldown > 0.0 or not history.is_empty(): return true
	for button in 21:
		if owns_button(button) and Input.is_joy_button_pressed(device, button): return true
	return false

func invoke(selected: Dictionary) -> bool:
	var node := resolve_target(selected)
	if node == null:
		push_warning("Controller action unavailable: " + str(selected.get("label", "Item")))
		return false
	match selected.get("kind"):
		"button":
			if not node is BaseButton or node.disabled or not node.is_visible_in_tree(): return false
			if node is Button and node.text != selected.get("text", selected.label): return false
			if node is OptionButton:
				node.show_popup()
				return true
			if node is MenuButton:
				var popup: PopupMenu = node.get_popup()
				popup.position = Vector2i(node.get_screen_position() + Vector2(0, node.size.y))
				popup.popup()
				return true
			if node.toggle_mode: node.button_pressed = not node.button_pressed
			node.emit_signal("pressed")
		"menu":
			if not node is PopupMenu: return false
			var index: int = node.get_item_index(selected.id)
			if index < 0 or node.get_item_text(index) != selected.label or node.is_item_disabled(index): return false
			if node.is_item_checkable(index): node.set_item_checked(index, not node.is_item_checked(index))
			node.emit_signal("id_pressed", selected.id)
			node.emit_signal("index_pressed", index)
			node.hide()
		"tree":
			if not node is Tree or not node.is_visible_in_tree(): return false
			var item: TreeItem = find_tree_item(node.get_root(), selected.item_path)
			if item == null: return false
			item.select(0)
			node.scroll_to_item(item)
			node.grab_focus()
			node.emit_signal("item_activated")
		"list":
			if not node is ItemList or not node.is_visible_in_tree(): return false
			for index in node.item_count:
				if node.get_item_text(index) == selected.label and not node.is_item_disabled(index):
					node.select(index)
					node.emit_signal("item_selected", index)
					node.emit_signal("item_activated", index)
					return true
			return false
		_: return false
	return true

func find_tree_item(item: TreeItem, path: Array) -> TreeItem:
	if item == null: return null
	if tree_path(item) == path: return item
	var child := item.get_first_child()
	while child != null:
		var found := find_tree_item(child, path)
		if found != null: return found
		child = child.get_next()
	return null

func _exit_tree() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	for reference in hooked:
		var node: Node = reference.get_ref()
		if node == null: continue
		node.remove_meta("mcon_action_hook")
		if node is PopupMenu:
			var callback := popup_input.bind(node)
			if node.window_input.is_connected(callback): node.window_input.disconnect(callback)
			for index in range(node.item_count - 1, -1, -1):
				if node.get_item_text(index) == "Controller binding": node.remove_item(index)
		else:
			var callback := control_input.bind(node)
			if node.gui_input.is_connected(callback): node.gui_input.disconnect(callback)
