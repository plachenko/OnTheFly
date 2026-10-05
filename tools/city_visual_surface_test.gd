extends SceneTree

class TestCity extends Node3D:
	var terrain_size := 64.0
	var terrain_step := 4.0
	func height_at(x: float,z: float) -> float: return 2.0*sin(x*.2)+cos(z*.15)
	func terrain_surface_height_at(x: float,z: float) -> float:
		var x0 := floorf(x/4)*4
		var z0 := floorf(z/4)*4
		return lerpf(lerpf(height_at(x0,z0),height_at(x0+4,z0),(x-x0)/4),lerpf(height_at(x0,z0+4),height_at(x0+4,z0+4),(x-x0)/4),(z-z0)/4)

func _initialize() -> void:
	var city := TestCity.new()
	root.add_child(city)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(point.x,city.terrain_surface_height_at(point.x,point.y)+.12,point.y))
	var coarse := tool.commit()
	var shape := coarse.create_trimesh_shape()
	var collision_faces := shape.get_faces()
	var smooth = load("res://city_visual_surface.gd").smooth_mesh(city,coarse,Transform3D.IDENTITY)
	var vertices: PackedVector3Array = smooth.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices.size() > 6)
	assert(coarse.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 6)
	assert(shape.get_faces() == collision_faces)
	var displaced := false
	for vertex in vertices:
		var offset: float = vertex.y-city.terrain_surface_height_at(vertex.x,vertex.z)-.12
		assert(absf(offset) <= .181)
		if absf(offset) > .01: displaced = true
	assert(displaced, "Subdivision must curve the visible height, not repeat flat triangles")
	print("VISUAL_SURFACE_PASS: curved subdivision, bounded height offset, original mesh and collision unchanged")
	quit()
