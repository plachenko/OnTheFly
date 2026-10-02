@tool
extends EditorPlugin

const GroundGuard = preload("res://addons/mcon_viewport/ground_guard.gd")
var ground_toggle: Button
var safe_height := 0.0
const NodeNavigation = preload("res://addons/mcon_viewport/node_navigation.gd")
var node_direction := Vector2i.ZERO
var node_repeat := 0.0
var navigated_node: Node
var manipulation := preload("res://addons/mcon_viewport/object_manipulation.gd").new()
var manipulate_toggle: Button
var transform_mode: OptionButton
var manipulate_chord_held := false
var context_chord_held := false
var open_selected_scene_held := false
var manipulation_confirm_held := false
var manipulation_cancel_held := false
const Motion = preload("res://addons/mcon_viewport/camera_motion.gd")
var mapping := preload("res://addons/mcon_viewport/controller_mapping.gd").new()
var controller_actions: Node
var mapping_dialog: AcceptDialog
var scene_picker: AcceptDialog
var scenes_held := false
var scene_direction_held := 0
var editor_ui := preload("res://addons/mcon_viewport/editor_ui.gd").new()
var ui_toolbar: HBoxContainer
var ui_toggle: Button
var ui_status: Label
var ui_mode: bool = false
var ui_toggle_held: bool = false
var toolbar: HBoxContainer
var toggle: Button
var devices: OptionButton
var speed: SpinBox
var deadzone: SpinBox
var status: Label
var active_camera: Camera3D
var pose := Transform3D.IDENTITY
var active: bool = false
var active_viewport: int = 0
var menu_held: bool = false
var focus_held: bool = false
var run_chord_held: bool = false
var run_button: Button
var orbit_toggle: Button
var multi_toggle: Button
var select_held := false
var orbit_held := false
var orbit_target: Node3D
const Preview = preload("res://addons/mcon_viewport/selection_preview.gd")
var hover_mesh: MeshInstance3D
var hover_target: Node
var hover_elapsed := 0.0
const Picking = preload("res://addons/mcon_viewport/ray_selection.gd")

func _enter_tree() -> void:
	process_priority = 1000
	mapping.load_profile()
	editor_ui.mapping = mapping
	toolbar = HBoxContainer.new()
	toggle = Button.new()
	toggle.text = "Controller fly"
	toggle.toggle_mode = true
	toggle.tooltip_text = "Left stick: fly · Right stick: look · LB/RB: down/up · LT: slow · RT: fast · Y: focus selection · Menu: toggle. Disable to resume mouse navigation."
	toggle.toggled.connect(set_active)
	toolbar.add_child(toggle)
	run_button = Button.new()
	run_button.text = "Run game"
	run_button.tooltip_text = "Press View + Menu together to run the project, or stop the running game. Menu alone toggles viewport flight."
	run_button.pressed.connect(toggle_game_running)
	toolbar.add_child(run_button)
	var select_button := Button.new()
	select_button.text = "Ray select"
	select_button.pressed.connect(raycast_select)
	toolbar.add_child(select_button)
	multi_toggle = Button.new()
	multi_toggle.text = "Multi select"
	multi_toggle.toggle_mode = true
	multi_toggle.tooltip_text = "Accumulate selections; select again to remove. Hold mapped R3 for temporary multi-select."
	toolbar.add_child(multi_toggle)
	ground_toggle = Button.new()
	ground_toggle.text = "Above ground"
	ground_toggle.toggle_mode = true
	ground_toggle.button_pressed = true
	ground_toggle.tooltip_text = "Keep the controller camera at least 0.8 m above ground surfaces; disable for underground editing."
	toolbar.add_child(ground_toggle)
	manipulate_toggle = Button.new()
	manipulate_toggle.text = "Manipulate"
	manipulate_toggle.toggle_mode = true
	manipulate_toggle.toggled.connect(set_manipulation)
	toolbar.add_child(manipulate_toggle)
	transform_mode = OptionButton.new()
	for label in ["Move", "Rotate", "Scale"]:
		transform_mode.add_item(label)
	transform_mode.item_selected.connect(func(index: int): manipulation.mode = index)
	toolbar.add_child(transform_mode)
	var context_button := Button.new()
	context_button.text = "Context menu"
	context_button.pressed.connect(open_context_menu)
	toolbar.add_child(context_button)
	orbit_toggle = Button.new()
	orbit_toggle.text = "Orbit selected"
	orbit_toggle.toggle_mode = true
	orbit_toggle.toggled.connect(set_orbit)
	toolbar.add_child(orbit_toggle)
	devices = OptionButton.new()
	devices.tooltip_text = "Controller detected by Godot (MCON or another mapped gamepad)"
	toolbar.add_child(devices)
	toolbar.add_child(make_label("Speed"))
	speed = SpinBox.new()
	speed.min_value = 1.0
	speed.max_value = 200.0
	speed.value = 12.0
	toolbar.add_child(speed)
	toolbar.add_child(make_label("Deadzone"))
	deadzone = SpinBox.new()
	deadzone.min_value = 0.05
	deadzone.max_value = 0.5
	deadzone.step = 0.01
	deadzone.value = 0.18
	toolbar.add_child(deadzone)
	status = make_label("")
	toolbar.add_child(status)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	Input.joy_connection_changed.connect(refresh_devices)
	RenderingServer.frame_pre_draw.connect(apply_camera_pose)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	refresh_devices()
	controller_actions = preload("res://addons/mcon_viewport/controller_actions.gd").new()
	controller_actions.device_provider = func(): return devices.get_selected_id()
	add_child(controller_actions)
	set_process(true)
	scene_picker = preload("res://addons/mcon_viewport/scene_picker.gd").new()
	EditorInterface.get_base_control().add_child(scene_picker)
	scene_picker.scene_requested.connect(switch_scene)
	ui_toolbar = HBoxContainer.new()
	var scenes_button := Button.new()
	scenes_button.text = "Scenes…"
	scenes_button.tooltip_text = "Default: View + Y opens scene picker; View + LB/RB switches open scenes"
	scenes_button.pressed.connect(open_scenes)
	ui_toolbar.add_child(scenes_button)
	var open_instance_button := Button.new()
	open_instance_button.text = "Open selected scene"
	open_instance_button.tooltip_text = "View + B: open the source scene of the selected scene instance"
	open_instance_button.pressed.connect(open_selected_scene)
	ui_toolbar.add_child(open_instance_button)
	for direction in [-1, 1]:
		var button := Button.new()
		button.text = "‹" if direction < 0 else "›"
		button.tooltip_text = "Previous open scene" if direction < 0 else "Next open scene"
		button.pressed.connect(cycle_scene.bind(direction))
		ui_toolbar.add_child(button)
	var mapping_button := Button.new()
	mapping_button.text = "Controller mapping…"
	mapping_button.pressed.connect(open_mapping)
	ui_toolbar.add_child(mapping_button)
	ui_toggle = Button.new()
	ui_toggle.text = "Controller UI"
	ui_toggle.toggle_mode = true
	ui_toggle.tooltip_text = "D-pad/left stick: navigate · A: select · B: back · LB/RB: previous/next control · X: context menu · Hold RT + up: float panel, down: redock, left/right: move panel"
	ui_toggle.toggled.connect(set_ui_mode)
	ui_toolbar.add_child(ui_toggle)
	ui_status = make_label("")
	ui_toolbar.add_child(ui_status)
	add_control_to_container(CONTAINER_TOOLBAR, ui_toolbar)
	if "--controller-context-check" in OS.get_cmdline_user_args():
		run_context_check.call_deferred()
	if "--controller-actions-check" in OS.get_cmdline_user_args():
		run_actions_check.call_deferred()
	if "--controller-run-binding-check" in OS.get_cmdline_user_args():
		run_run_binding_check.call_deferred()
	if "--controller-ui-check" in OS.get_cmdline_user_args():
		run_ui_check.call_deferred()
	if "--controller-preview-check" in OS.get_cmdline_user_args():
		run_preview_check.call_deferred()
	if "--controller-scenes-check" in OS.get_cmdline_user_args():
		run_scenes_check.call_deferred()
	if "--controller-mapping-check" in OS.get_cmdline_user_args():
		run_mapping_check.call_deferred()
	if "--controller-plugin-check" in OS.get_cmdline_user_args():
		assert(EditorInterface.get_editor_viewport_3d(0).get_camera_3d() != null)
		print("MCON EDITOR PLUGIN PASS: loaded toolbar and editor viewport camera; connected controllers: ", Input.get_connected_joypads())

func set_manipulation(enabled: bool) -> void:
	if enabled:
		if ui_mode or EditorInterface.is_playing_scene() or not manipulation.begin(EditorInterface.get_selection().get_selected_nodes()):
			manipulate_toggle.set_pressed_no_signal(false)
			status.text = "Select a 3D object first"
			return
		manipulation_confirm_held = true
		manipulation_cancel_held = true
		status.text = "Manipulate · A confirm · B cancel · D-pad mode"
	else:
		manipulation.finish(get_undo_redo())
	manipulate_toggle.set_pressed_no_signal(enabled)

func cancel_manipulation() -> void:
	manipulation.finish(get_undo_redo(), true)
	manipulate_toggle.set_pressed_no_signal(false)

func open_context_menu() -> void:
	if manipulate_toggle.button_pressed:
		set_manipulation(false)
	if not ui_mode and not editor_control_has_focus():
		if EditorInterface.get_selection().get_selected_nodes().is_empty():
			status.text = "Select an object first"
			return
		# The Scene dock provides Godot's native node context menu for the
		# selected viewport item, including multi-selection operations.
		for dock in EditorInterface.get_base_control().find_children("*", "EditorDock", true, false):
			if dock.title == "Scene":
				editor_ui.focus_panel(dock)
				for tree in dock.find_children("*", "Tree", true, false):
					if tree.is_visible_in_tree() and tree.get_selected() != null:
						tree.grab_focus()
						break
				break
	editor_ui.context_menu()

func process_manipulation(device: int, delta: float) -> void:
	var confirm := mapping.button(device, JOY_BUTTON_A)
	var cancel := mapping.button(device, JOY_BUTTON_B)
	if cancel and not manipulation_cancel_held:
		cancel_manipulation()
		return
	if confirm and not manipulation_confirm_held:
		set_manipulation(false)
		select_held = true
		return
	manipulation_confirm_held = confirm
	manipulation_cancel_held = cancel
	if mapping.button(device, JOY_BUTTON_DPAD_LEFT):
		manipulation.mode = 0
	elif mapping.button(device, JOY_BUTTON_DPAD_UP):
		manipulation.mode = 1
	elif mapping.button(device, JOY_BUTTON_DPAD_RIGHT):
		manipulation.mode = 2
	elif mapping.button(device, JOY_BUTTON_DPAD_DOWN):
		set_manipulation(false)
		return
	transform_mode.select(manipulation.mode)
	var movement := Motion.stick(Vector2(mapping.axis(device, JOY_AXIS_LEFT_X), mapping.axis(device, JOY_AXIS_LEFT_Y)), deadzone.value)
	var look := Motion.stick(Vector2(mapping.axis(device, JOY_AXIS_RIGHT_X), mapping.axis(device, JOY_AXIS_RIGHT_Y)), deadzone.value)
	var vertical := float(mapping.button(device, JOY_BUTTON_RIGHT_SHOULDER)) - float(mapping.button(device, JOY_BUTTON_LEFT_SHOULDER))
	var camera := EditorInterface.get_editor_viewport_3d(active_viewport).get_camera_3d()
	var multiplier := lerpf(1.0, 0.2, mapping.axis(device, JOY_AXIS_TRIGGER_LEFT)) * lerpf(1.0, 3.0, mapping.axis(device, JOY_AXIS_TRIGGER_RIGHT))
	manipulation.step(movement, look, vertical, camera.global_basis, speed.value * 0.25 * multiplier, minf(delta, 0.1))

func open_scenes() -> void:
	cancel_manipulation()
	set_active(false)
	set_ui_mode(false)
	scene_picker.show_scenes()

func switch_scene(path: String) -> void:
	cancel_manipulation()
	set_active(false)
	set_orbit(false)
	EditorInterface.open_scene_from_path(path)
	ui_status.text = "Scene: " + path.get_file()

func open_selected_scene() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		ui_status.text = "Select a scene instance first"
		return
	var node: Node = navigated_node if selected.has(navigated_node) else selected.back()
	var path := NodeNavigation.source_scene(node, EditorInterface.get_edited_scene_root())
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		ui_status.text = "Selected node has no source scene"
		return
	switch_scene(path)

func cycle_scene(direction: int) -> void:
	var opened := EditorInterface.get_open_scenes()
	if opened.is_empty():
		open_scenes()
		return
	var root := EditorInterface.get_edited_scene_root()
	var current := opened.find(root.scene_file_path) if root != null else -1
	switch_scene(opened[posmod(current + direction, opened.size())])

func open_mapping() -> void:
	set_active(false)
	set_ui_mode(false)
	if is_instance_valid(mapping_dialog):
		mapping_dialog.queue_free()
	mapping_dialog = mapping.build_dialog(EditorInterface.get_base_control(), mapping_saved, func(): return devices.get_selected_id() if devices.item_count > 0 else -1)
	mapping_dialog.popup_centered(Vector2i(650, 540))

func run_mapping_check() -> void:
	await get_tree().process_frame
	open_mapping()
	assert(mapping_dialog.visible)
	assert(mapping_dialog.find_children("*", "OptionButton", true, false).size() == mapping.BUTTON_NAMES.size() + mapping.AXIS_NAMES.size())
	assert(mapping_dialog.find_children("*", "CheckBox", true, false).size() == mapping.AXIS_NAMES.size())
	assert(editor_ui.mapping == mapping)
	mapping_dialog.hide()
	print("CONTROLLER MAPPING UI PASS: dialog opens, all binding/inversion controls exist, shared UI mapping")

func mapping_saved(error: Error) -> void:
	menu_held = false
	focus_held = false
	select_held = false
	orbit_held = false
	run_chord_held = false
	ui_toggle_held = false
	editor_ui.held_buttons.clear()
	ui_status.text = "Mapping saved" if error == OK else "Could not save mapping: " + error_string(error)

func make_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label

func run_ui_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	set_ui_mode(true)
	var dock := EditorInterface.get_file_system_dock()
	var original_parent := dock.get_parent()
	assert(editor_ui.focused_dock() == dock)
	assert(editor_ui.move_dock(Vector2i.RIGHT))
	assert(dock.get_parent() != original_parent)
	var popup := editor_ui.dock_popup(dock)
	var restored := false
	for grid in popup.find_children("*", "Control", true, false):
		if grid.has_signal("slot_clicked"):
			grid.emit_signal("slot_clicked", dock.default_slot)
			restored = true
			break
	popup.hide()
	assert(restored and dock.get_parent() == original_parent)
	set_ui_mode(false)
	print("MCON UI PASS: focused FileSystem, native dock menu, moved right, restored original slot")

func refresh_devices(_device: int = -1, _connected: bool = false) -> void:
	var previous := devices.get_selected_id() if devices.item_count > 0 else -1
	devices.clear()
	for device in Input.get_connected_joypads():
		devices.add_item(Input.get_joy_name(device), device)
		if device == previous or "mcon" in Input.get_joy_name(device).to_lower():
			devices.select(devices.item_count - 1)
	if devices.item_count == 0:
		devices.add_item("No controller connected", -1)
		set_active(false)
	status.text = ""

func set_active(enabled: bool) -> void:
	active = enabled and Input.get_connected_joypads().has(devices.get_selected_id())
	toggle.set_pressed_no_signal(active)
	if not active:
		hover_mesh = null
		hover_target = null
	update_overlays()
	if active:
		active_camera = EditorInterface.get_editor_viewport_3d(active_viewport).get_camera_3d()
		if is_instance_valid(active_camera):
			pose = active_camera.global_transform
			safe_height = pose.origin.y
	status.text = "LB/RB height · Y focus" if active else ""

func navigation_available() -> bool:
	return not ui_mode and toolbar.is_visible_in_tree() and EditorInterface.get_base_control().get_window().has_focus() and not EditorInterface.is_playing_scene()

func set_ui_mode(enabled: bool) -> void:
	if enabled and is_instance_valid(manipulate_toggle):
		cancel_manipulation()
	ui_mode = enabled
	ui_toggle.set_pressed_no_signal(enabled)
	if enabled:
		set_active(false)
		EditorInterface.get_file_system_dock().make_visible()
		var tree := EditorInterface.get_file_system_dock().find_children("*", "Tree", true, false)
		if not tree.is_empty():
			tree[0].grab_focus()
	ui_status.text = "A select · B back · LB/RB focus · RT+direction dock" if enabled else ""

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseButton and event.pressed:
		for index in 4:
			if EditorInterface.get_editor_viewport_3d(index).get_camera_3d() == camera:
				if active_viewport != index:
					active_viewport = index
					active_camera = camera
					pose = camera.global_transform
					safe_height = pose.origin.y
				break
	return AFTER_GUI_INPUT_PASS

func _process(delta: float) -> void:
	controller_actions.suspended = is_instance_valid(mapping_dialog) and mapping_dialog.visible
	if controller_actions.blocking_builtin(devices.get_selected_id()):
		return
	run_button.text = "Stop game" if EditorInterface.is_playing_scene() else "Run game"
	if not Input.get_connected_joypads().has(devices.get_selected_id()):
		if manipulate_toggle.button_pressed:
			cancel_manipulation()
		menu_held = false
		focus_held = false
		run_chord_held = false
		return
	if is_instance_valid(mapping_dialog) and mapping_dialog.visible:
		return
	var device := devices.get_selected_id()
	if scene_picker.visible:
		if editor_ui.focused_window().has_focus():
			scene_picker.process_controller(device, delta, mapping)
		return
	var view := mapping.button(device, JOY_BUTTON_BACK)
	var manipulate_chord := view and mapping.button(device, JOY_BUTTON_X)
	var context_chord := view and mapping.button(device, JOY_BUTTON_A)
	var open_scene_chord := view and mapping.button(device, JOY_BUTTON_B)
	if not EditorInterface.is_playing_scene() and editor_ui.focused_window().has_focus():
		if manipulate_chord and not manipulate_chord_held:
			set_manipulation(not manipulate_toggle.button_pressed)
		if context_chord and not context_chord_held:
			open_context_menu()
		if open_scene_chord and not open_selected_scene_held:
			open_selected_scene()
	manipulate_chord_held = manipulate_chord
	context_chord_held = context_chord
	open_selected_scene_held = open_scene_chord
	if manipulate_chord or context_chord or open_scene_chord:
		return
	if manipulate_toggle.button_pressed and not EditorInterface.is_playing_scene():
		if editor_ui.focused_window().has_focus():
			process_manipulation(device, delta)
		return
	var scenes_pressed := view and mapping.button(device, JOY_BUTTON_Y)
	var scene_direction := int(mapping.button(device, JOY_BUTTON_RIGHT_SHOULDER)) - int(mapping.button(device, JOY_BUTTON_LEFT_SHOULDER)) if view else 0
	if not EditorInterface.is_playing_scene() and editor_ui.focused_window().has_focus():
		if scenes_pressed and not scenes_held:
			open_scenes()
		elif scene_direction != 0 and scene_direction != scene_direction_held:
			cycle_scene(scene_direction)
	scenes_held = scenes_pressed
	scene_direction_held = scene_direction
	if scenes_pressed or scene_direction != 0:
		return
	var menu := mapping.button(device, JOY_BUTTON_START)
	var run_chord := menu and mapping.button(device, JOY_BUTTON_BACK)
	if run_chord and not run_chord_held and (EditorInterface.is_playing_scene() or EditorInterface.get_base_control().get_window().has_focus()):
		toggle_game_running()
	run_chord_held = run_chord
	var ui_pressed := mapping.button(device, JOY_BUTTON_LEFT_STICK)
	if ui_pressed and not ui_toggle_held and not EditorInterface.is_playing_scene() and editor_ui.focused_window().has_focus():
		set_ui_mode(not ui_mode)
	ui_toggle_held = ui_pressed
	if ui_mode and not run_chord and not EditorInterface.is_playing_scene() and editor_ui.focused_window().has_focus():
		editor_ui.process_controller(device, delta)
		if not editor_ui.message.is_empty():
			ui_status.text = editor_ui.message
		menu_held = menu
		return
	if run_chord or not navigation_available():
		menu_held = menu
		focus_held = false
		return
	if menu and not menu_held:
		set_active(not active)
	menu_held = menu
	# Directional scene selection belongs to active viewport control, not
	# general editor menus or the idle controller.
	if active and not mapping.button(device, JOY_BUTTON_BACK) and not editor_control_has_focus():
		navigate_nodes(device, delta)
	else:
		node_direction = Vector2i.ZERO
	if not active or not is_instance_valid(active_camera):
		return
	var movement := Motion.stick(Vector2(mapping.axis(device, JOY_AXIS_LEFT_X), mapping.axis(device, JOY_AXIS_LEFT_Y)), deadzone.value)
	var look := Motion.stick(Vector2(mapping.axis(device, JOY_AXIS_RIGHT_X), mapping.axis(device, JOY_AXIS_RIGHT_Y)), deadzone.value)
	var vertical := float(mapping.button(device, JOY_BUTTON_RIGHT_SHOULDER)) - float(mapping.button(device, JOY_BUTTON_LEFT_SHOULDER))
	var multiplier := lerpf(1.0, 4.0, maxf(0.0, mapping.axis(device, JOY_AXIS_TRIGGER_RIGHT)))
	multiplier *= lerpf(1.0, 0.2, maxf(0.0, mapping.axis(device, JOY_AXIS_TRIGGER_LEFT)))
	var select_pressed := mapping.button(device, JOY_BUTTON_A)
	if select_pressed and not select_held:
		raycast_select(mapping.button(device, JOY_BUTTON_RIGHT_STICK))
	select_held = select_pressed
	var orbit_pressed := mapping.button(device, JOY_BUTTON_X)
	if orbit_pressed and not orbit_held:
		set_orbit(not orbit_toggle.button_pressed)
	orbit_held = orbit_pressed
	if orbit_toggle.button_pressed and is_instance_valid(orbit_target):
		pose = Motion.orbit(pose, orbit_target.global_position, movement, look, speed.value * multiplier, minf(delta, 0.1))
	else:
		if orbit_toggle.button_pressed:
			set_orbit(false)
		pose = Motion.fly(pose, movement, look, vertical, speed.value * multiplier, minf(delta, 0.1))
	var focus := mapping.button(device, JOY_BUTTON_Y)
	if focus and not focus_held:
		focus_selection()
	focus_held = focus

func raycast_hit() -> MeshInstance3D:
	var camera := EditorInterface.get_editor_viewport_3d(active_viewport).get_camera_3d()
	if not is_instance_valid(camera):
		return null
	if active:
		camera.global_transform = pose
	var center := Vector2(camera.get_viewport().size) * 0.5
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	var candidates: Array = []
	for id in RenderingServer.instances_cull_ray(origin, origin + direction * camera.far, camera.get_world_3d().scenario):
		var node := instance_from_id(id)
		if node is MeshInstance3D and (node == root or root.is_ancestor_of(node)) and node.is_visible_in_tree():
			candidates.append(node)
	return Picking.closest_mesh(candidates, origin, direction, camera.far)

func editable_target(hit: MeshInstance3D) -> Node:
	if not is_instance_valid(hit):
		return null
	var root := EditorInterface.get_edited_scene_root()
	var selected: Node = hit
	while selected != root and selected.owner != root and selected.get_parent() != null:
		selected = selected.get_parent()
	return selected

func raycast_select(additive: bool = false) -> void:
	# Recast on button press so selection always matches the current view.
	var hit := raycast_hit()
	var selected := editable_target(hit)
	if selected == null:
		status.text = "No object at viewport center"
		return
	navigated_node = selected
	var selection_pose := pose
	apply_selection(selected, additive or multi_toggle.button_pressed)
	# Inspector/selection callbacks can update the native editor camera. Keep
	# our controller pose independent of those editor updates.
	if active:
		pose = selection_pose
		keep_above_ground()
		active_camera.global_transform = pose
	status.text = "Selected: %d objects" % EditorInterface.get_selection().get_selected_nodes().size()
	if orbit_toggle.button_pressed:
		set_orbit(true)

func apply_selection(selected: Node, additive: bool) -> void:
	if Picking.update_selection(EditorInterface.get_selection(), selected, additive):
		EditorInterface.inspect_object(selected)

func editor_control_has_focus() -> bool:
	var focus: Node = EditorInterface.get_base_control().get_window().gui_get_focus_owner()
	while focus != null:
		if focus is EditorDock or focus is LineEdit or focus is TextEdit or focus is PopupMenu or focus is Tree:
			return true
		focus = focus.get_parent()
	return false

func navigate_nodes(device: int, delta: float) -> void:
	var direction := Vector2i(
		int(mapping.button(device, JOY_BUTTON_DPAD_RIGHT)) - int(mapping.button(device, JOY_BUTTON_DPAD_LEFT)),
		int(mapping.button(device, JOY_BUTTON_DPAD_DOWN)) - int(mapping.button(device, JOY_BUTTON_DPAD_UP)))
	if direction.y != 0:
		direction.x = 0
	node_repeat -= delta
	if direction != Vector2i.ZERO and (direction != node_direction or node_repeat <= 0.0):
		var selected := EditorInterface.get_selection().get_selected_nodes()
		if not selected.has(navigated_node):
			navigated_node = selected.back() if not selected.is_empty() else null
		var target := NodeNavigation.next_node(EditorInterface.get_edited_scene_root(), navigated_node, direction)
		if target != null:
			# Traversal should retain accumulated selections instead of toggling
			# the object off each time a direction repeats.
			var additive := multi_toggle.button_pressed or mapping.button(device, JOY_BUTTON_RIGHT_STICK)
			if not additive or not EditorInterface.get_selection().get_selected_nodes().has(target):
				apply_selection(target, additive)
			navigated_node = target
			status.text = "Node: " + str(target.name)
			# Let Godot show the correct editor for UI nodes instead of forcing
			# their Inspector/2D selection back into the 3D viewport.
			if target is CanvasItem or target is CanvasLayer:
				set_active(false)
				ui_status.text = "UI node selected: " + str(target.name) + " · use Controller UI to edit controls"
			if active:
				keep_above_ground()
				active_camera.global_transform = pose
		node_repeat = 0.4 if direction != node_direction else 0.15
	node_direction = direction

func _forward_3d_force_draw_over_viewport(overlay: Control) -> void:
	if not active or not navigation_available() or not is_instance_valid(active_camera):
		return
	# Each editor split has its own overlay and SubViewport under the same parent.
	var parent := overlay.get_parent()
	var matched := false
	while parent != null:
		var viewports := parent.find_children("*", "SubViewport", true, false)
		if not viewports.is_empty():
			for viewport in viewports:
				if viewport.get_camera_3d() == active_camera:
					matched = true
			break
		parent = parent.get_parent()
	if not matched:
		return
	var name_preview := str(hover_target.name) if is_instance_valid(hover_target) else ""
	var additive := multi_toggle.button_pressed or (Input.get_connected_joypads().has(devices.get_selected_id()) and mapping.button(devices.get_selected_id(), JOY_BUTTON_RIGHT_STICK))
	if is_instance_valid(hover_target):
		var selected := EditorInterface.get_selection().get_selected_nodes().has(hover_target)
		name_preview += " · Remove" if additive and selected else " · Add" if additive else " · Selected" if selected else ""
	Preview.draw(overlay, active_camera, hover_mesh, name_preview)

func set_orbit(enabled: bool) -> void:
	orbit_target = null
	if enabled:
		for node in EditorInterface.get_selection().get_selected_nodes():
			if node is Node3D:
				orbit_target = node
				break
	orbit_toggle.set_pressed_no_signal(enabled and is_instance_valid(orbit_target))
	if orbit_toggle.button_pressed:
		if not active:
			var camera := EditorInterface.get_editor_viewport_3d(active_viewport).get_camera_3d()
			pose = camera.global_transform
		if pose.origin.distance_to(orbit_target.global_position) < 0.5:
			pose.origin = orbit_target.global_position + pose.basis.z * 12.0
		pose = pose.looking_at(orbit_target.global_position)
		status.text = "Orbit: " + orbit_target.name
	elif enabled:
		status.text = "Select a 3D object first"

func toggle_game_running() -> void:
	if manipulate_toggle.button_pressed:
		set_manipulation(false)
	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()
	else:
		set_active(false)
		EditorInterface.play_main_scene()

func focus_selection() -> void:
	var center := Vector3.ZERO
	var count := 0
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node is Node3D:
			center += node.global_position
			count += 1
	if count == 0:
		return
	center /= count
	pose.origin = center + pose.basis.z * 12.0
	pose = pose.looking_at(center)

func keep_above_ground() -> void:
	if not ground_toggle.button_pressed or not is_instance_valid(active_camera):
		safe_height = pose.origin.y
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var origin := pose.origin
	origin.y = maxf(safe_height, pose.origin.y) + GroundGuard.CLEARANCE
	var candidates: Array = []
	var ids := RenderingServer.instances_cull_ray(origin, origin + Vector3.DOWN * GroundGuard.RANGE, active_camera.get_world_3d().scenario)
	# Include nearby surfaces above us for recovery when enabling below ground.
	ids.append_array(RenderingServer.instances_cull_ray(origin, origin + Vector3.UP * 1000.0, active_camera.get_world_3d().scenario))
	for id in ids:
		var node := instance_from_id(id)
		if node is MeshInstance3D and (node == root or root.is_ancestor_of(node)) and node.is_visible_in_tree() and not candidates.has(node):
			candidates.append(node)
	pose = GroundGuard.protect(pose, safe_height, candidates)
	if orbit_toggle.button_pressed and is_instance_valid(orbit_target) and pose.origin.distance_squared_to(orbit_target.global_position) > 0.01:
		pose = pose.looking_at(orbit_target.global_position)
	safe_height = pose.origin.y

func apply_camera_pose() -> void:
	# The editor updates its camera from its mouse cursor each frame. Apply our
	# view after that update, without touching scene nodes or saved scene cameras.
	if active and navigation_available() and is_instance_valid(active_camera):
		keep_above_ground()
		active_camera.global_transform = pose
		hover_elapsed += get_process_delta_time()
		if hover_elapsed >= 0.1:
			hover_elapsed = 0.0
			hover_mesh = raycast_hit()
			hover_target = editable_target(hover_mesh)
	update_overlays()

func _exit_tree() -> void:
	if is_instance_valid(controller_actions):
		controller_actions.queue_free()
	cancel_manipulation()
	if RenderingServer.frame_pre_draw.is_connected(apply_camera_pose):
		RenderingServer.frame_pre_draw.disconnect(apply_camera_pose)
	if Input.joy_connection_changed.is_connected(refresh_devices):
		Input.joy_connection_changed.disconnect(refresh_devices)
	if is_instance_valid(mapping_dialog):
		mapping_dialog.queue_free()
	if is_instance_valid(scene_picker):
		scene_picker.queue_free()
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	remove_control_from_container(CONTAINER_TOOLBAR, ui_toolbar)
	ui_toolbar.queue_free()
	toolbar.queue_free()

func run_scenes_check() -> void:
	await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	await get_tree().process_frame
	open_scenes()
	assert(scene_picker.visible and scene_picker.list.item_count > 0)
	scene_picker.search.text = "___nonexistent___"
	scene_picker.refresh()
	assert(scene_picker.list.item_count == 0)
	scene_picker.search.text = ""
	scene_picker.refresh()
	assert(scene_picker.list.item_count > 0)
	scene_picker.hide()
	print("CONTROLLER SCENES PASS: project scene discovery, picker, search and empty results")

func run_preview_check() -> void:
	await get_tree().process_frame
	var overlay := Control.new()
	overlay.custom_minimum_size = Vector2(600, 400)
	overlay.size = Vector2(600, 400)
	EditorInterface.get_base_control().add_child(overlay)
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var target := MeshInstance3D.new()
	target.mesh = BoxMesh.new()
	camera.get_viewport().add_child(target)
	target.global_position = camera.global_position - camera.global_basis.z * 5.0
	var drawn := [false]
	overlay.draw.connect(func():
		Preview.draw(overlay, camera, target, "Preview test")
		drawn[0] = true
	)
	overlay.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(drawn[0])
	var selection := EditorSelection.new()
	var second := Node3D.new()
	camera.get_viewport().add_child(second)
	Picking.update_selection(selection, target, false)
	Picking.update_selection(selection, second, true)
	assert(selection.get_selected_nodes().has(target) and selection.get_selected_nodes().has(second))
	Picking.update_selection(selection, target, true)
	assert(not selection.get_selected_nodes().has(target) and selection.get_selected_nodes().has(second))
	selection.clear()
	selection.free()
	second.queue_free()
	target.queue_free()
	overlay.queue_free()
	print("CONTROLLER PREVIEW PASS: reticle, outline, name overlay; multi-selection add/remove preserves other objects")

func run_context_check() -> void:
	await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	set_ui_mode(true)
	var trees := EditorInterface.get_file_system_dock().find_children("*", "Tree", true, false)
	assert(not trees.is_empty())
	var tree: Tree = trees[0]
	if tree.get_root() != null:
		var item := tree.get_root().get_first_child()
		if item != null:
			item.select(0)
	tree.grab_focus()
	open_context_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	var opened := false
	for popup in get_tree().root.find_children("*", "PopupMenu", true, false):
		if popup.visible:
			opened = true
			popup.hide()
	assert(opened)
	set_ui_mode(false)
	print("CONTROLLER CONTEXT PASS: focused editor item opens native right-click menu")

func run_actions_check() -> void:
	await get_tree().process_frame
	var actions := controller_actions
	var saved: Array = actions.bindings.duplicate(true)
	var fixture := Button.new()
	fixture.name = "ControllerActionTest"
	fixture.text = "Test action"
	EditorInterface.get_base_control().add_child(fixture)
	var count := [0]
	fixture.pressed.connect(func(): count[0] += 1)
	var selected: Dictionary = actions.descriptor(fixture, "button", fixture.text)
	actions.bindings = [{"target": selected, "buttons": [0]}, {"target": selected, "buttons": [0, 1]}]
	assert(actions.press(0, 10.0))
	assert(count[0] == 0) # Delay a single press that prefixes a sequence.
	assert(actions.press(1, 10.3))
	assert(count[0] == 1)
	actions.press(0, 12.0)
	actions.finish_sequence()
	assert(count[0] == 2)
	actions.press(0, 14.0)
	actions.press(2, 14.2)
	assert(count[0] == 2)
	assert(actions.history.is_empty())
	fixture.disabled = true
	assert(not actions.invoke(selected))
	fixture.disabled = false
	var config_path := "res://.godot/controller_actions_test.cfg"
	assert(actions.save_profile(config_path) == OK)
	actions.bindings.clear()
	actions.load_profile(config_path)
	assert(actions.bindings.size() == 2)
	DirAccess.remove_absolute(config_path)
	actions.target = selected
	actions.begin_capture(true)
	actions.press(9, 20.0)
	actions.press(0, 20.3)
	assert(actions.captured == [9, 0])
	assert(not actions.dialog.get_ok_button().disabled)
	actions.cancel_capture()
	actions.dialog.hide()
	var popup := PopupMenu.new()
	popup.name = "ControllerMenuTest"
	EditorInterface.get_base_control().add_child(popup)
	popup.add_item("Invoke menu command", 42)
	var menu_count := [0]
	popup.id_pressed.connect(func(id):
		if id == 42: menu_count[0] += 1)
	var menu_target: Dictionary = actions.descriptor(popup, "menu", "Invoke menu command")
	menu_target["id"] = 42
	assert(actions.invoke(menu_target))
	assert(menu_count[0] == 1)
	popup.set_item_disabled(0, true)
	assert(not actions.invoke(menu_target))
	# Test the actual context submenu rather than only the recorder methods.
	popup.set_item_disabled(0, false)
	popup.popup(Rect2i(20, 20, 200, 80))
	actions.show_context(selected, Vector2(30, 30))
	assert(popup.get_item_text(popup.item_count - 1) == "Controller binding")
	assert(popup.get_item_submenu_node(popup.item_count - 1) == actions.menu)
	assert(actions.menu.get_item_text(0) == "Listen for controller press…")
	popup.hide()
	var tree := Tree.new()
	tree.name = "ControllerTreeTest"
	EditorInterface.get_base_control().add_child(tree)
	var tree_root := tree.create_item()
	tree_root.set_text(0, "Root")
	var tree_item := tree.create_item(tree_root)
	tree_item.set_text(0, "Selected node")
	var tree_target: Dictionary = actions.descriptor(tree, "tree", "Selected node")
	tree_target["item_path"] = actions.tree_path(tree_item)
	var activated := [0]
	tree.item_activated.connect(func(): activated[0] += 1)
	assert(actions.invoke(tree_target))
	assert(tree.get_selected() == tree_item and activated[0] == 1)
	tree_item.free()
	assert(not actions.invoke(tree_target))
	tree.queue_free()
	actions.bindings = saved
	fixture.queue_free()
	popup.queue_free()
	print("CONTROLLER ACTIONS PASS: native context submenu, sequence matching, prefix delay, mismatch, capture, persistence, button/menu/tree invocation and disabled/missing actions")
	get_tree().quit()

func run_run_binding_check() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var actions := controller_actions
	var native_run: Button
	for button in get_tree().root.find_children("*", "Button", true, false):
		if button.shortcut != null and button.shortcut.resource_name == "Run Project":
			native_run = button
			break
	assert(native_run != null)
	var selected: Dictionary = actions.descriptor(native_run, "button", "")
	assert(selected.label == "Run Project")
	# Reproduce a saved binding from an earlier editor session, with a dead path.
	selected.path = "@EditorNode@old_session/missing_button"
	assert(actions.resolve_target(selected) == native_run)
	var saved: Array = actions.bindings.duplicate(true)
	actions.bindings = [{"target": selected, "buttons": [6, 4, 0]}]
	actions.suspended = true # Keep the polling loop from clearing injected presses.
	assert(actions.press(6, 10.0))
	assert(actions.press(4, 10.2))
	assert(not EditorInterface.is_playing_scene())
	assert(actions.press(0, 10.4))
	for frame in 120:
		if EditorInterface.is_playing_scene(): break
		await get_tree().process_frame
	assert(EditorInterface.is_playing_scene())
	EditorInterface.stop_playing_scene()
	actions.bindings = saved
	print("CONTROLLER RUN BINDING PASS: unnamed Run button resolves across editor sessions; Menu -> View -> A invokes native Run Project")
	get_tree().quit()
