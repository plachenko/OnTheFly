extends RefCounted

var directory := "user://codex_notes"

func save(text: String, captures: Array) -> String:
	if text.strip_edges().is_empty() and captures.is_empty(): return ""
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK: return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := directory.path_join("Note_%s_%d.json" % [stamp, Time.get_ticks_usec()])
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return ""
	file.store_string(JSON.stringify({"format": "onthefly.codex_note", "version": 1, "created_at": Time.get_datetime_string_from_system(true), "text": text.strip_edges(), "captures": captures}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return ""
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK: return ""
	return ProjectSettings.globalize_path(path)
