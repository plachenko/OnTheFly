@tool
extends Node
signal paused
signal followed(path: String, line: int)
var editor: EditorInterface
var enabled := false
var pending_change: Dictionary = {}
var elapsed := 0.0
var grace := 0.0
var last_view: Array = []

static func project_path(path: String) -> String:
	if path.is_empty(): return ""
	var absolute := path.replace("\\", "/")
	if not absolute.begins_with("res://"):
		if not absolute.is_absolute_path(): absolute = ProjectSettings.globalize_path("res://").path_join(absolute)
		absolute = ProjectSettings.localize_path(absolute.simplify_path())
	if not absolute.begins_with("res://") or absolute.contains("../"): return ""
	return absolute

static func changed_line(diff: String) -> int:
	var pattern := RegEx.new()
	pattern.compile("^@@.*\\+([0-9]+)(?:,[0-9]+)? @@")
	var line_number := 1
	var in_hunk := false
	for line in diff.split("\n"):
		var hunk := pattern.search(line)
		if hunk != null:
			line_number = maxi(1, int(hunk.get_string(1)))
			in_hunk = true
		elif in_hunk:
			if line.begins_with("+") or line.begins_with("-"): return line_number
			if line.begins_with(" "): line_number += 1
	return line_number

func set_enabled(value: bool) -> void:
	enabled = value
	pending_change.clear()
	last_view = view_state()
	grace = 0.5

func queue_change(change: Dictionary) -> void:
	if not enabled: return
	var path := project_path(str(change.get("path", "")))
	if path.is_empty(): return
	pending_change = {"path": path, "line": changed_line(str(change.get("diff", "")))}
	elapsed = 0.0

func text_editor() -> TextEdit:
	if editor == null: return null
	var current := editor.get_script_editor().get_current_editor()
	return current.get_base_editor() as TextEdit if current != null else null

func view_state() -> Array:
	if editor == null: return []
	var script := editor.get_script_editor().get_current_script()
	var text := text_editor()
	return [script.resource_path if script != null else "", text.get_caret_line() if text != null else -1, text.scroll_vertical if text != null else 0.0]

func _process(delta: float) -> void:
	if not enabled or editor == null: return
	grace = maxf(0.0, grace - delta)
	var view := view_state()
	if grace <= 0.0 and not last_view.is_empty() and view != last_view:
		enabled = false
		pending_change.clear()
		paused.emit()
		return
	last_view = view
	if pending_change.is_empty(): return
	elapsed += delta
	if elapsed < 0.3: return
	var change := pending_change.duplicate()
	pending_change.clear()
	open_change(change)

func open_change(change: Dictionary, manual: bool = false) -> void:
	if editor == null: return
	var path := project_path(str(change.get("path", "")))
	if path.is_empty() or not FileAccess.file_exists(path): return
	grace = 1.0
	editor.get_resource_filesystem().update_file(path)
	if path.get_extension() in ["tscn", "scn"]:
		editor.open_scene_from_path(path)
	elif path.get_extension() in ["gd", "cs"]:
		var resource := ResourceLoader.load(path)
		if resource is Script:
			editor.edit_script(resource, -1, 0, false)
			editor.set_main_screen_editor("Script")
			await get_tree().process_frame
			if not enabled and not manual: return
			var current_script := editor.get_script_editor().get_current_script()
			if current_script == null or current_script.resource_path != path: return
			var text := text_editor()
			if text != null:
				var line := clampi(int(change.line) - 1, 0, text.get_line_count() - 1)
				editor.get_script_editor().goto_line(line)
				text.select(line, 0, line, text.get_line(line).length())
	else:
		editor.select_file(path)
		if ResourceLoader.exists(path): editor.edit_resource(ResourceLoader.load(path))
		else: OS.shell_open(ProjectSettings.globalize_path(path))
	last_view = view_state()
	followed.emit(path, int(change.line))
