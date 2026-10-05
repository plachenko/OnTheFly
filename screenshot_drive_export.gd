extends RefCounted

static func copy_capture(image_path: String, folder: String) -> Dictionary:
	var camera_path := image_path.get_basename() + ".camera.json"
	if not image_path.to_lower().ends_with(".png") or not FileAccess.file_exists(image_path):
		return {"error": "Take a screenshot first."}
	if not FileAccess.file_exists(camera_path):
		return {"error": "The screenshot's camera JSON is missing."}
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		return {"error": "Choose an available Google Drive synced folder."}
	var sources := [image_path, camera_path]
	# Validate both destinations first. Never replace an unrelated file.
	for source in sources:
		var target: String = folder.path_join(source.get_file())
		if FileAccess.file_exists(target) and FileAccess.get_file_as_bytes(target) != FileAccess.get_file_as_bytes(source):
			return {"error": "A different file already exists: " + target.get_file()}
	for source in sources:
		var target: String = folder.path_join(source.get_file())
		if FileAccess.file_exists(target): continue
		var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))
		if error != OK:
			return {"error": "Could not copy %s: %s" % [source.get_file(), error_string(error)]}
	return {"error": "", "image": folder.path_join(image_path.get_file()), "camera": folder.path_join(camera_path.get_file())}
