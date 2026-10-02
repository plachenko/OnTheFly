@tool
extends EditorPlugin
var dock: Control
func _enter_tree() -> void:
	dock = preload("res://addons/codex_chat/dock.gd").new()
	dock.editor = get_editor_interface()
	dock.name = "Codex"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
func _exit_tree() -> void:
	if is_instance_valid(dock):
		dock.shutdown()
		remove_control_from_docks(dock)
		dock.queue_free()
