extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	var city = scene.get_node("ProceduralCity")
	city.randomize_each_load = false
	city.time_of_day_mode = 2
	root.add_child(scene)
	await process_frame
	var meshes: Array[Node] = city.get_node("Buildings").find_children("*", "MeshInstance3D", true, false)
	var emissive := 0
	var mixed_buildings := 0
	var lit_windows := 0
	var total_windows := 0
	var streamer_windows := 0
	for node in city.get_node("Buildings").find_children("*", "Node3D", true, false):
		if node.has_meta("window_count"):
			var count: int = node.get_meta("window_count")
			var lit: int = node.get_meta("lit_window_count")
			lit_windows += lit
			streamer_windows += int(node.get_meta("streamer_window_count", 0))
			total_windows += count
			if count > 1:
				assert(lit > 0 and lit < count)
				mixed_buildings += 1
	for mesh in meshes:
		assert(not str(mesh.name).begins_with("WindowLight_"))
		if mesh.material_override is ShaderMaterial:
			assert(mesh.material_override.shader == load("res://building_windows.gdshader"))
			emissive += 1
	assert(emissive > 0)
	assert(mixed_buildings > 0 and lit_windows > 0 and total_windows > lit_windows)
	assert(streamer_windows > 0 and streamer_windows < lit_windows * 0.08)
	assert(city.get_node("Buildings").find_children("WindowLights", "Node3D", true, false).is_empty())
	print("WINDOW EMISSION PASS: ", mixed_buildings, " mixed buildings, ", lit_windows, "/", total_windows, " lit windows, ", streamer_windows, " rare RGB rooms, no floating geometry")
	quit()
