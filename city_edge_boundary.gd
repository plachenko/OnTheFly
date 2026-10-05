extends RefCounted

const CORNER_RADIUS := 24.0
const SAMPLE_SPACING := 3.0
const WALL_THICKNESS := 2.0

static func refresh_saved(city: Node3D) -> void:
	if city.earlier_style: return
	for park in city.get_node("Parks").get_children():
		for tree in park.find_children("ParkTree*", "", true, false):
			tree.get_parent().remove_child(tree)
			tree.free()
	await generate(city)

static func perimeter(bounds: Rect2) -> Curve3D:
	# Expand outward before rounding so corners never cut into playable plots.
	var rect := bounds.grow(CORNER_RADIUS)
	var a := rect.position
	var b := rect.end
	var r := CORNER_RADIUS
	var k := r * .55228475
	var curve := Curve3D.new()
	curve.bake_interval = SAMPLE_SPACING
	var points := [Vector2(a.x+r,a.y),Vector2(b.x-r,a.y),Vector2(b.x,a.y+r),Vector2(b.x,b.y-r),Vector2(b.x-r,b.y),Vector2(a.x+r,b.y),Vector2(a.x,b.y-r),Vector2(a.x,a.y+r)]
	var incoming := [Vector2(-k,0),Vector2.ZERO,Vector2(0,-k),Vector2.ZERO,Vector2(k,0),Vector2.ZERO,Vector2(0,k),Vector2.ZERO]
	var outgoing := [Vector2.ZERO,Vector2(k,0),Vector2.ZERO,Vector2(0,k),Vector2.ZERO,Vector2(-k,0),Vector2.ZERO,Vector2(0,-k)]
	for i in 9:
		var n := i % 8
		curve.add_point(Vector3(points[n].x,0,points[n].y),Vector3(incoming[n].x,0,incoming[n].y),Vector3(outgoing[n].x,0,outgoing[n].y))
	return curve

static func exit_opening(city: Node3D, point: Vector3) -> bool:
	for exit in city.topology.exits:
		var lateral: float = point.x if exit.vertical else point.z
		var center: float = exit.center.x if exit.vertical else exit.center.y
		var outward: float = (point.z-exit.center.y if exit.vertical else point.x-exit.center.x)*exit.side
		if absf(lateral-center) < 25.0 and outward > -4.0: return true
	return false

static func smooth_height(city: Node3D, curve: Curve3D, distance: float) -> float:
	var height := 0.0
	var length := curve.get_baked_length()
	for offset in [-16.0,-8.0,0.0,8.0,16.0]:
		var point := curve.sample_baked(fposmod(distance+offset,length),true)
		height += city.height_at(point.x,point.z)
	return height / 5.0

static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a,b,c,a,c,d]: tool.add_vertex(point)

static func generate(city: Node3D) -> void:
	var container := city.get_node("HighwayApproaches")
	for old in container.get_children():
		if old.has_meta("city_boundary") or str(old.name).begins_with("EdgeForest") or str(old.name).begins_with("EdgeCliff"):
			container.remove_child(old)
			old.free()
	if city.earlier_style: return
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("999da1")
	concrete.roughness = 1.0
	concrete.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := StaticBody3D.new()
	body.name = "EdgeWall"
	body.set_meta("city_boundary",true)
	container.add_child(body,true)
	var curve := perimeter(city.topology.bounds)
	var length := curve.get_baked_length()
	var count := ceili(length / SAMPLE_SPACING)
	var positions: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var heights: Array[float] = []
	for i in count+1:
		if i % 32 == 0: await city.loading_checkpoint()
		var distance := length * float(i) / count
		positions.append(curve.sample_baked(distance,true))
		var tangent := (curve.sample_baked(fposmod(distance+.5,length),true)-curve.sample_baked(fposmod(distance-.5,length),true)).normalized()
		normals.append(Vector3(-tangent.z,0,tangent.x)*WALL_THICKNESS*.5)
		heights.append(smooth_height(city,curve,distance))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 0
	for i in count:
		var a := positions[i]
		var b := positions[i+1]
		if exit_opening(city,a) or exit_opening(city,b) or exit_opening(city,(a+b)*.5): continue
		var bottom_a := Vector3(0,minf(heights[i],city.height_at(a.x,a.z))-6.0,0)
		var bottom_b := Vector3(0,minf(heights[i+1],city.height_at(b.x,b.z))-6.0,0)
		var top_a := Vector3(0,heights[i]+18.0,0)
		var top_b := Vector3(0,heights[i+1]+18.0,0)
		var na := normals[i]
		var nb := normals[i+1]
		quad(tool,a+na+bottom_a,b+nb+bottom_b,b+nb+top_b,a+na+top_a)
		quad(tool,b-nb+bottom_b,a-na+bottom_a,a-na+top_a,b-nb+top_b)
		quad(tool,a+na+top_a,b+nb+top_b,b-nb+top_b,a-na+top_a)
		if i == 0 or exit_opening(city,positions[i-1]): quad(tool,a-na+bottom_a,a+na+bottom_a,a+na+top_a,a-na+top_a)
		if i == count-1 or exit_opening(city,positions[i+2]): quad(tool,b+nb+bottom_b,b-nb+bottom_b,b-nb+top_b,b+nb+top_b)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var low := minf(bottom_a.y,bottom_b.y)
		var high := maxf(top_a.y,top_b.y)
		shape.size = Vector3(WALL_THICKNESS+.3,high-low,a.distance_to(b)+.3)
		collision.shape = shape
		collision.position = (a+b)*.5+Vector3(0,(low+high)*.5,0)
		collision.rotation.y = atan2(b.x-a.x,b.z-a.z)
		body.add_child(collision)
		segments += 1
	tool.index()
	tool.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = "SplineWallVisual"
	visual.mesh = tool.commit()
	visual.material_override = concrete
	body.add_child(visual)
	body.set_meta("wall_segments",segments)
