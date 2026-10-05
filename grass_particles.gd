extends RefCounted

# One reusable clump mesh: short curved ribbons with rounded, blunt tips.
static func blade_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 12:
		var angle := float(blade) * 2.39996
		var rotation := Basis(Vector3.UP, angle)
		var offset := Vector3(cos(angle), 0, sin(angle)) * (0.12 + float(blade % 3) * 0.10)
		var height := 0.24 + float(blade % 4) * 0.035
		for segment in 3:
			var low := float(segment) / 3.0
			var high := float(segment + 1) / 3.0
			for corner in [Vector2(-1, low), Vector2(1, low), Vector2(-1, high), Vector2(1, low), Vector2(1, high), Vector2(-1, high)]:
				var width := lerpf(0.065, 0.022, corner.y)
				tool.set_uv(Vector2((corner.x + 1.0) * 0.5, corner.y))
				tool.set_color(Color.WHITE)
				tool.add_vertex(offset + rotation * Vector3(corner.x * width + corner.y * corner.y * 0.13, corner.y * height, 0))
	tool.generate_normals()
	var mesh := tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://grass_blades.gdshader")
	mesh.surface_set_material(0, material)
	return mesh

# Crossed upright billboard cards give the curb fringe a soft grassy silhouette.
static func fringe_mesh() -> ArrayMesh:
	var image := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for blade in 18:
		var base := 4.0 + blade * 7.0
		var height := 26.0 + float((blade * 13) % 29)
		for y in 64:
			var rise := float(63 - y)
			if rise > height:
				continue
			var curve := sin(float(blade) * 2.4) * 8.0 * pow(rise / height, 2.0)
			var width := lerpf(3.6, 1.2, rise / height)
			for x in 128:
				if absf(float(x) - base - curve) < width:
					image.set_pixel(x, y, Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = preload("res://grass_fringe.gdshader")
	material.set_shader_parameter("silhouette", ImageTexture.create_from_image(image))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI * 0.5]:
		var rotation := Basis(Vector3.UP, angle)
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			tool.set_uv(Vector2(corner.x, 1.0 - corner.y))
			tool.set_color(Color.WHITE)
			tool.add_vertex(rotation * Vector3((corner.x - 0.5) * 0.75, corner.y * 0.38, 0))
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	return mesh

static func add_clumps(city: Node3D, mesh: Mesh, points: PackedVector3Array, random: RandomNumberGenerator, label: String) -> void:
	if points.is_empty():
		return
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = points.size()
	for index in points.size():
		await city.loading_checkpoint()
		var scale := random.randf_range(0.85, 1.3)
		instances.set_instance_transform(index, Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale), points[index]))
		instances.set_instance_color(index, Color(0.19, 0.34, 0.09).lerp(Color(0.38, 0.54, 0.16), random.randf()))
	var patch := MultiMeshInstance3D.new()
	patch.name = label
	patch.multimesh = instances
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.set_meta("grass_positions", points)
	city.get_node("Parks").add_child(patch)

static func available(city: Node3D, point: Vector2, park: bool, occupied: Array[Rect2], margin: float = 0.5) -> bool:
	if city.on_grid_road(point, city.sidewalk_width + margin):
		return false
	if city.distance_to_diagonal_road(point) < city.diagonal_road_width * 0.5 + city.sidewalk_width + margin:
		return false
	if park:
		for center in city.topology.park_cells():
			if absf(point.x - center.x) < 0.9 or absf(point.y - center.y) < 0.9:
				if absf(point.x - center.x) < 21 and absf(point.y - center.y) < 21:
					return false
	for bounds in occupied:
		if bounds.has_point(point):
			return false
	return true

static func generate(city: Node3D, density: float) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = city.actual_seed + 7103
	var occupied: Array[Rect2] = []
	for at in city.lamp_gravel_points:
		await city.loading_checkpoint()
		occupied.append(Rect2(at - Vector2.ONE * 1.25, Vector2.ONE * 2.5))
	for building in city.get_node("Buildings").get_children():
		await city.loading_checkpoint()
		if not building is StaticBody3D:
			continue
		for child in building.get_children():
			await city.loading_checkpoint()
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var half: Vector3 = child.shape.size * 0.5
				var extent: Vector3 = child.global_basis.x.abs() * half.x + child.global_basis.z.abs() * half.z
				var size := Vector2(extent.x, extent.z) + Vector2.ONE * 0.6
				occupied.append(Rect2(Vector2(child.global_position.x, child.global_position.z) - size, size * 2.0))
	var mesh := blade_mesh()
	var fringe: ArrayMesh = await city.loading_job(fringe_mesh)
	var patches: Array = []
	for plot in city.get_node("Parks").get_children():
		await city.loading_checkpoint()
		for visual in plot.get_children():
			await city.loading_checkpoint()
			if visual is MeshInstance3D and str(visual.name) in ["Grass", "ParkGrass"]:
				patches.append(visual)
	for visual in patches:
		await city.loading_checkpoint()
		var island: bool = city.topology.planned or str(visual.get_parent().name).begins_with("DiagonalGrassPlot")
		var bounds: AABB = visual.mesh.get_aabb()
		var count := mini(6000, int(bounds.size.x * bounds.size.z * density * 2.5))
		var points := PackedVector3Array()
		for index in count:
			await city.loading_checkpoint()
			var local := Vector3(random.randf_range(bounds.position.x, bounds.end.x), 0, random.randf_range(bounds.position.z, bounds.end.z))
			var world: Vector3 = visual.to_global(local)
			var point := Vector2(world.x, world.z)
			if not available(city, point, visual.name == "ParkGrass", occupied):
				continue
			world.y = city.terrain_surface_height_at(point.x, point.y) + (city.sidewalk_height + 0.035 if island else 0.065)
			points.append(world)
		await add_clumps(city, mesh, points, random, "GrassClumps_" + str(visual.get_parent().name))
		var edge_points := PackedVector3Array()
		# Sample the grass side of both grid and diagonal sidewalks, never the pavement.
		var x := bounds.position.x
		while x < bounds.end.x:
			await city.loading_checkpoint()
			var z := bounds.position.z
			while z < bounds.end.z:
				await city.loading_checkpoint()
				var world: Vector3 = visual.to_global(Vector3(x, 0, z))
				var point := Vector2(world.x, world.z)
				var near_grid: bool = city.on_grid_road(point, city.sidewalk_width + 0.7)
				var near_diagonal: bool = city.distance_to_diagonal_road(point) < city.diagonal_road_width * 0.5 + city.sidewalk_width + 0.7
				if (near_grid or near_diagonal) and available(city, point, visual.name == "ParkGrass", occupied, 0.08):
					world.y = city.terrain_surface_height_at(point.x, point.y) + (city.sidewalk_height + 0.025 if island else 0.045)
					edge_points.append(world)
				z += 0.45
			x += 0.45
		await add_clumps(city, fringe, edge_points, random, "GrassFringe_" + str(visual.get_parent().name))
