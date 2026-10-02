extends RefCounted

var cached_surfaces: Dictionary = {}

func find_root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		index = parents[index]
	return index

func detect(mesh: Mesh, texture: Texture2D, surface: int) -> Dictionary:
	var key := "%d:%d:%d" % [mesh.get_instance_id(), texture.get_instance_id(), surface]
	if cached_surfaces.has(key):
		return cached_surfaces[key]
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index in vertices.size():
			indices.append(index)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var parents: Array[int] = []
	var triangles: Array[int] = []
	var shared: Dictionary = {}
	for triangle in indices.size() / 3:
		var a := indices[triangle * 3]
		var b := indices[triangle * 3 + 1]
		var c := indices[triangle * 3 + 2]
		var normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
		if absf(normal.y) > 0.25 or uvs.is_empty():
			continue
		var uv := (uvs[a] + uvs[b] + uvs[c]) / 3.0
		var color := image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1), clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1))
		if not (color.b > 0.3 and color.b > color.g * 1.15 and color.g > color.r * 1.15):
			continue
		var group := parents.size()
		parents.append(group)
		triangles.append(triangle)
		for vertex in [a, b, c]:
			var point: Vector3 = vertices[vertex]
			# Glass joined at a building corner belongs to the same room/band.
			# Facade normals differ there, but its RGB glow must wrap with it.
			var vertex_key := str(point.snapped(Vector3.ONE * 0.0001))
			if shared.has(vertex_key):
				parents[find_root(parents, group)] = find_root(parents, shared[vertex_key])
			else:
				shared[vertex_key] = group
	var groups: Dictionary = {}
	for index in triangles.size():
		var root := find_root(parents, index)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(triangles[index])
	var result := {"arrays": arrays, "indices": indices, "groups": groups.values()}
	cached_surfaces[key] = result
	return result

func apply(model: Node3D, rng: RandomNumberGenerator, chance: float, streamer_chance: float = 0.025) -> void:
	var rgb_rng := RandomNumberGenerator.new()
	rgb_rng.seed = rng.state ^ 731
	var records: Array[Dictionary] = []
	var window_groups: Array[Dictionary] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var material := node.material_override as StandardMaterial3D
		if not material or not material.albedo_texture or not node.mesh:
			continue
		for surface in node.mesh.get_surface_count():
			var data := detect(node.mesh, material.albedo_texture, surface)
			var record := {"node": node, "surface": surface, "data": data, "lit_triangles": {}}
			records.append(record)
			for group in data.groups:
				window_groups.append({"record": record, "triangles": group, "lit": rng.randf() < chance})
	# Each building with multiple windows gets a visible mixture.
	if window_groups.size() > 1 and chance > 0.0 and chance < 1.0:
		var any_lit := false
		var any_dark := false
		for group in window_groups:
			any_lit = any_lit or group.lit
			any_dark = any_dark or not group.lit
		if not any_lit:
			window_groups[rng.randi_range(0, window_groups.size() - 1)].lit = true
		if not any_dark:
			window_groups[rng.randi_range(0, window_groups.size() - 1)].lit = false
	var lit_count := 0
	var streamer_count := 0
	for group in window_groups:
		if group.lit:
			lit_count += 1
			var streamer := rgb_rng.randf() < streamer_chance
			var phase := rgb_rng.randf()
			streamer_count += int(streamer)
			var window_data := Color(1.0, 1.0 if streamer else 0.0, phase if streamer else 0.0, 1.0)
			for triangle in group.triangles:
				group.record.lit_triangles[triangle] = window_data
	model.set_meta("lit_window_count", lit_count)
	model.set_meta("streamer_window_count", streamer_count)
	model.set_meta("window_count", window_groups.size())
	var meshes: Dictionary = {}
	for record in records:
		var node: MeshInstance3D = record.node
		if not meshes.has(node):
			meshes[node] = ArrayMesh.new()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var arrays: Array = record.data.arrays
		var indices: PackedInt32Array = record.data.indices
		for index in indices.size():
			var vertex := indices[index]
			tool.set_color(record.lit_triangles.get(index / 3, Color.BLACK))
			if arrays[Mesh.ARRAY_NORMAL] != null:
				tool.set_normal(arrays[Mesh.ARRAY_NORMAL][vertex])
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][vertex])
			tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][vertex])
		tool.commit(meshes[node])
	for node in meshes:
		node.mesh = meshes[node]
