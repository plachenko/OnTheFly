extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position.z = 5.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.make_current()
	for height in [-1.0, 1.0]:
		var object := MeshInstance3D.new()
		object.mesh = BoxMesh.new()
		object.position.y = height
		var color := StandardMaterial3D.new()
		color.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		color.albedo_color = Color.BLUE
		object.material_override = color
		scene.add_child(object)
	var fill := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	fill.mesh = quad
	fill.position.z = -1.0
	fill.extra_cull_margin = 16384.0
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://menu_ground_fill.gdshader")
	shader.set_shader_parameter("height_threshold", 0.0)
	shader.set_shader_parameter("fill_color", Color.MAGENTA)
	fill.material_override = shader
	camera.add_child(fill)
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var above := camera.unproject_position(Vector3(0, 1, 0))
	var below := camera.unproject_position(Vector3(0, -1, 0))
	var top := image.get_pixelv(Vector2i(above))
	var bottom := image.get_pixelv(Vector2i(below))
	assert(top.b > .8 and top.r < .2, "Geometry above threshold keeps its original color")
	assert(bottom.r > .8 and bottom.b > .8 and bottom.g < .2, "Geometry below threshold uses solid fill")
	print("MENU GROUND FILL RENDER PASS: above threshold retained, below threshold filled solid")
	quit()
