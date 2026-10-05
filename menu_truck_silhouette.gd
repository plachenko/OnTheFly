extends Node3D
const DRAW_LAYER := 1 << 19
var copies: Array[MeshInstance3D] = []
var original_layers: Array[int] = []
var viewport: SubViewport
var camera: Camera3D
var source_camera: Camera3D
var source_mask := 0
var screen: CanvasLayer
var left_correction := 0.0
var measured := false
var measurements := 0
var measure_wait := 0
var camera_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	sync()

func set_camera_mode(enabled: bool) -> void:
	if camera_mode == enabled: return
	camera_mode = enabled
	for index in copies.size():
		if is_instance_valid(copies[index]):
			copies[index].layers = original_layers[index] if enabled else DRAW_LAYER
	if is_instance_valid(screen): screen.visible = not enabled
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if enabled else SubViewport.UPDATE_ALWAYS
	if not enabled:
		measured = false
		measurements = 0
		measure_wait = 0
		left_correction = 0.0
func attach(truck: Node3D, main_camera: Camera3D) -> void:
	source_camera=main_camera; source_mask=main_camera.cull_mask
	main_camera.cull_mask &= ~DRAW_LAYER
	for mesh in truck.model.find_children("*","MeshInstance3D",true,false):
		copies.append(mesh); original_layers.append(mesh.layers); mesh.layers=DRAW_LAYER
	viewport=SubViewport.new(); viewport.name="MenuTruckRender"
	viewport.size=get_viewport().get_visible_rect().size
	viewport.transparent_bg=true; viewport.world_3d=truck.get_world_3d()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport)
	camera=Camera3D.new(); camera.cull_mask=DRAW_LAYER; viewport.add_child(camera); camera.make_current()
	var worlds=truck.get_parent().find_children("*","WorldEnvironment",true,false)
	camera.environment=worlds[0].environment.duplicate() if not worlds.is_empty() else Environment.new()
	camera.environment.background_mode=Environment.BG_COLOR
	camera.environment.background_color=Color(0,0,0,0)
	screen=CanvasLayer.new(); screen.layer=0; add_child(screen)
	# Composite the mask first, followed by the actual transparent 3D render.
	var stroke=TextureRect.new(); stroke.name="ComicStroke"; stroke.texture=viewport.get_texture()
	stroke.position=Vector2.ZERO; stroke.size=viewport.size
	stroke.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material=ShaderMaterial.new(); material.shader=preload("res://menu_truck_silhouette.gdshader"); stroke.material=material
	screen.add_child(stroke)
	var render=TextureRect.new(); render.name="Truck3DPass"; render.texture=viewport.get_texture()
	render.size=viewport.size; render.mouse_filter=Control.MOUSE_FILTER_IGNORE; screen.add_child(render)
	sync()
func sync() -> void:
	if not is_instance_valid(camera): return
	# The menu's separate truck pass must not remain fixed over a moving camera.
	set_camera_mode(get_viewport().get_camera_3d() != source_camera)
	if camera_mode: return
	camera.global_transform=source_camera.global_transform
	camera.fov=source_camera.fov; camera.h_offset=source_camera.h_offset; camera.v_offset=source_camera.v_offset
	camera.near=source_camera.near; camera.far=source_camera.far
	camera.keep_aspect=source_camera.keep_aspect
	var size: Vector2i=get_viewport().get_visible_rect().size
	if viewport.size != size:
		viewport.size=size; measured=false; measurements=0; measure_wait=0; left_correction=0.0
		for rect in screen.get_children(): rect.size=size
func measure_margin() -> void:
	if measurements >= 3: return
	measure_wait -= 1
	if measure_wait > 0: return
	var used:=viewport.get_texture().get_image().get_used_rect()
	if used.size.x>0:
		var material: ShaderMaterial = screen.get_node("ComicStroke").material
		material.set_shader_parameter("truck_bounds",Vector4(used.position.x,used.position.y,used.size.x,used.size.y))
		left_correction += 70.0-used.position.x
		measurements += 1
		measure_wait = 10
		measured=true
func remove() -> void:
	set_process(false)
	for index in copies.size():
		if is_instance_valid(copies[index]): copies[index].layers=original_layers[index]
	copies.clear(); original_layers.clear()
	if is_instance_valid(source_camera): source_camera.cull_mask=source_mask
	if is_instance_valid(screen): screen.queue_free()
	if is_instance_valid(viewport): viewport.queue_free()
