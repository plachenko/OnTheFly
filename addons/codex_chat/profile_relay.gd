@tool
extends Node

const DIRECTORY := "res://.godot/codex_chat/profiling"
var dock: Control
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.5: return
	elapsed = 0
	poll()

func poll() -> void:
	poll_dictation()
	if dock == null or not dock.profile_enabled.button_pressed or dock.busy or not dock.bridge.initialized: return
	var path := DIRECTORY + "/request.json"
	if not FileAccess.file_exists(path): return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return
	if file.get_length() > 2000000:
		file.close()
		dock.line("Profile", "Profile exceeds the 2 MB limit; it was not sent.")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var report: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not report is Dictionary or report.get("format") != "onthefly.profile_context" or not report.get("frames") is Array:
		dock.line("Profile", "Invalid profile request; it was not sent.")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var id := str(report.get("id", ""))
	if id.is_empty(): return
	if id == str(dock.config.get_value("profiling", "last_id", "")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	dock.config.set_value("profiling", "last_id", id)
	dock.save_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	dock.send_profile_report(report)

func poll_dictation() -> void:
	if dock == null or dock.busy or not dock.bridge.initialized: return
	var path := "res://.godot/codex_chat/dictation/request.json"
	if not FileAccess.file_exists(path): return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return
	if file.get_length() > 1048576:
		file.close()
		dock.line("Dictation", "Message exceeds the 1 MB limit; it was not sent.")
		return
	var report: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not report is Dictionary or report.get("format") != "onthefly.dictation_message" or not report.get("text") is String: return
	var id := str(report.get("id", ""))
	if id.is_empty(): return
	if id != str(dock.config.get_value("dictation", "last_id", "")):
		dock.send_game_dictation(report.text, report.get("captures", []))
		dock.config.set_value("dictation", "last_id", id)
		dock.save_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
