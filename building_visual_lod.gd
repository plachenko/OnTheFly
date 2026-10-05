extends Node3D

const DISTANCE := 96.0
const MARGIN := 5.0
static var proxy_material: StandardMaterial3D
var detailed: Array[GeometryInstance3D] = []
var proxy: MeshInstance3D
var source: Node3D
var detail_visibility: Dictionary = {}

static func attach(parent: Node3D, model: Node3D) -> Node3D:
	if parent.has_node("BuildingVisualLOD"): return parent.get_node("BuildingVisualLOD")
	var result := preload("res://building_visual_lod.gd").new()
	result.name = "BuildingVisualLOD"
	result.source = model
	var pieces: Array[AABB] = []
	collect_bounds(model,parent.global_transform.affine_inverse()*model.global_transform,pieces)
	if pieces.is_empty(): result.free(); return null
	var box: AABB = pieces[0]
	for piece in pieces: box = box.merge(piece)
	for geometry in model.find_children("*","GeometryInstance3D",true,false): result.detailed.append(geometry)
	if model is GeometryInstance3D: result.detailed.append(model)
	result.proxy = MeshInstance3D.new()
	result.proxy.name = "DistantBuildingBox"
	var mesh := BoxMesh.new()
	mesh.size = box.size.max(Vector3.ONE*.1)
	result.proxy.mesh = mesh
	result.proxy.position = box.get_center()
	if proxy_material == null:
		proxy_material = StandardMaterial3D.new()
		proxy_material.albedo_color = Color("879398")
		proxy_material.roughness = 1
	result.proxy.material_override = proxy_material
	result.add_child(result.proxy)
	parent.add_child(result)
	PerformanceDiagnostics.rendering_lod_changed.connect(result.refresh)
	result.refresh()
	return result

static func collect_bounds(node: Node3D, relative: Transform3D, pieces: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh: pieces.append(relative*node.mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D: collect_bounds(child,relative*child.transform,pieces)

func refresh() -> void:
	var blocks: bool = PerformanceDiagnostics.buildings_as_blocks
	var managed: bool = is_instance_valid(source) and source.has_meta("block_card_managed")
	var enabled: bool = PerformanceDiagnostics.rendering_lod_enabled and not managed
	for mesh in detailed:
		if blocks:
			if not detail_visibility.has(mesh): detail_visibility[mesh] = mesh.visible
			mesh.hide()
		elif detail_visibility.has(mesh):
			mesh.visible = detail_visibility[mesh]
		mesh.visibility_range_end = DISTANCE if enabled else 0.0
		mesh.visibility_range_end_margin = MARGIN if enabled else 0.0
	if not blocks: detail_visibility.clear()
	proxy.visible = blocks or enabled
	proxy.visibility_range_begin = 0.0 if blocks else DISTANCE
	proxy.visibility_range_begin_margin = 0.0 if blocks else MARGIN

static func configure_city(city: Node3D) -> void:
	if Engine.is_editor_hint(): return
	for body in city.get_node("Buildings").get_children():
		var model: Node3D = body.get_node_or_null("KenneyBuilding")
		if model != null: attach(body,model)
	for model in city.get_node("NearSkyline").get_children():
		if model is Node3D: attach(model,model)
