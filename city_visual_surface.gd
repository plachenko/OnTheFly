extends RefCounted

const MAX_OFFSET := 0.18
const VISUAL_STEP := 1.5

static func cubic(a: float,b: float,c: float,d: float,t: float) -> float:
	return b + .5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)))

static func height(city: Node3D, point: Vector2, cache: Dictionary) -> float:
	if cache.has(point): return cache[point]
	var step: float = city.terrain_size/maxi(8,roundi(city.terrain_size/city.terrain_step))
	var origin: float = -city.terrain_size*.5
	var grid := (point-Vector2.ONE*origin)/step
	var cell := Vector2(floorf(grid.x),floorf(grid.y))
	var fraction := grid-cell
	var rows: Array[float] = []
	for z in range(-1,3):
		var samples: Array[float] = []
		for x in range(-1,3):
			var at := Vector2.ONE*origin+(cell+Vector2(x,z))*step
			var key := Vector3(at.x,0,at.y)
			if not cache.has(key): cache[key] = city.height_at(at.x,at.y)
			samples.append(cache[key])
		rows.append(cubic(samples[0],samples[1],samples[2],samples[3],fraction.x))
	var smooth := cubic(rows[0],rows[1],rows[2],rows[3],fraction.y)
	var coarse: float = city.terrain_surface_height_at(point.x,point.y)
	var result := coarse+clampf(smooth-coarse,-MAX_OFFSET,MAX_OFFSET)
	cache[point] = result
	return result

static func midpoint(a: Array,b: Array) -> Array:
	return [(a[0]+b[0])*.5,(a[1]+b[1]).normalized(),(a[2]+b[2])*.5,a[3].lerp(b[3],.5)]

static func triangle(city: Node3D, tool: SurfaceTool, a: Array,b: Array,c: Array, transform: Transform3D, cache: Dictionary, uv: bool, colors: bool, depth: int = 0) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	if depth < 8 and maxf(pa.distance_squared_to(pb),maxf(pb.distance_squared_to(pc),pc.distance_squared_to(pa))) > VISUAL_STEP*VISUAL_STEP:
		var ab := midpoint(a,b)
		var bc := midpoint(b,c)
		var ca := midpoint(c,a)
		triangle(city,tool,a,ab,ca,transform,cache,uv,colors,depth+1)
		triangle(city,tool,ab,b,bc,transform,cache,uv,colors,depth+1)
		triangle(city,tool,ca,bc,c,transform,cache,uv,colors,depth+1)
		triangle(city,tool,ab,bc,ca,transform,cache,uv,colors,depth+1)
		return
	for record in [a,b,c]:
		var world: Vector3 = transform*record[0]
		var point := Vector2(world.x,world.z)
		var displacement_key := Vector3(point.x,1,point.y)
		if not cache.has(displacement_key): cache[displacement_key] = height(city,point,cache)-city.terrain_surface_height_at(point.x,point.y)
		world.y += cache[displacement_key]
		var normal: Vector3 = record[1]
		if absf(normal.y) > .5:
			var normal_key := Vector3(point.x,2,point.y)
			if not cache.has(normal_key):
				var dx := (height(city,point+Vector2(.25,0),cache)-height(city,point-Vector2(.25,0),cache))/.5
				var dz := (height(city,point+Vector2(0,.25),cache)-height(city,point-Vector2(0,.25),cache))/.5
				cache[normal_key] = Vector3(-dx,1,-dz).normalized()
			normal = transform.basis.inverse()*cache[normal_key]*signf(normal.y)
		tool.set_normal(normal.normalized())
		if uv: tool.set_uv(record[2])
		if colors: tool.set_color(record[3])
		tool.add_vertex(transform.affine_inverse()*world)

static func smooth_mesh(city: Node3D, source: Mesh, transform: Transform3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	var cache := {}
	for surface in source.get_surface_count():
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0,count,3):
			var records: Array = []
			for j in 3:
				var index: int = indices[i+j] if not indices.is_empty() else i+j
				records.append([vertices[index],normals[index] if not normals.is_empty() else Vector3.UP,uvs[index] if not uvs.is_empty() else Vector2.ZERO,colors[index] if not colors.is_empty() else Color.WHITE])
			triangle(city,tool,records[0],records[1],records[2],transform,cache,not uvs.is_empty(),not colors.is_empty())
		tool.index()
		tool.commit(result)
		result.surface_set_material(result.get_surface_count()-1,source.surface_get_material(surface))
	return result

static func generate(city: Node3D) -> void:
	# Replacing render meshes never rebuilds the existing physics shapes.
	for container in [city.get_node("Roads"),city.get_node("Parks"),city.get_node("Crosswalks"),city.get_node("ParkingSpaces")]:
		for visual in container.find_children("*","MeshInstance3D",true,false):
			if not visual.mesh is ArrayMesh: continue
			# Imported trees, signs and vehicles are not terrain-conforming surfaces.
			if not visual.mesh.resource_path.is_empty(): continue
			await city.loading_checkpoint()
			visual.mesh = await city.loading_job(smooth_mesh.bind(city,visual.mesh,visual.global_transform))
			visual.set_meta("smoothed_visual_surface",true)
