extends SceneTree

func _initialize() -> void:
	var lighting = load("res://window_lighting.gd").new()
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.4, 0.8))
	var texture := ImageTexture.create_from_image(image)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A continuous glass band turns through all four facade normals.
	var corners := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	for side in 4:
		var a: Vector3 = corners[side]
		var b: Vector3 = corners[(side + 1) % 4]
		for point in [a, b, a + Vector3.UP, b, b + Vector3.UP, a + Vector3.UP]:
			tool.set_uv(Vector2(0.5, 0.5))
			tool.add_vertex(point)
	tool.generate_normals()
	var mesh := tool.commit()
	var detected: Dictionary = lighting.detect(mesh, texture, 0)
	assert(detected.groups.size() == 1)
	assert(detected.groups[0].size() == 8)
	var model := Node3D.new()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	visual.material_override = material
	model.add_child(visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	lighting.apply(model, rng, 1.0, 1.0)
	var colors: PackedColorArray = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for color in colors:
		assert(color.is_equal_approx(colors[0]))
		assert(color.r == 1 and color.g == 1)
	model.free()
	print("WRAPAROUND RGB PASS: four connected facades share one lit RGB band and animation phase")
	quit()
