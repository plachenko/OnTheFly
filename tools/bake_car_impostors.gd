extends SceneTree

const CELL := Vector2i(256,192)
const ANGLES := 16
const ELEVATIONS := [0.0,20.0,40.0,60.0]
const MODELS := ["sedan","sedan-sports","hatchback-sports","taxi","suv","van","police","delivery"]
var materials: Array[ShaderMaterial] = []

func _initialize() -> void: run.call_deferred()

func prepare(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original := node.get_active_material(surface) as StandardMaterial3D
			if original == null: continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://tools/car_impostor_bake.gdshader")
			material.set_shader_parameter("paint_color",original.albedo_color)
			material.set_shader_parameter("has_texture",original.albedo_texture != null)
			material.set_shader_parameter("paint_texture",original.albedo_texture)
			material.set_shader_parameter("vertex_color",original.vertex_color_use_as_albedo)
			node.set_surface_override_material(surface,material)
			materials.append(material)
	for child in node.get_children(): prepare(child)

func bounds(node: Node3D, relative: Transform3D, result: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh: result.append(relative * node.mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D: bounds(child,relative*child.transform,result)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/car_impostors")
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	viewport.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .7
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_energy = .8
	viewport.add_child(sun)
	var metadata := {"version":1,"angles":ANGLES,"elevations":ELEVATIONS,"cell":[CELL.x,CELL.y],"models":{}}
	for name in MODELS:
		var path: String = "res://assets/kenney_city/cars_rigged/"+name+".glb"
		var model: Node3D = load(path).instantiate()
		viewport.add_child(model)
		materials.clear()
		prepare(model)
		var pieces: Array[AABB] = []
		bounds(model,Transform3D.IDENTITY,pieces)
		var box: AABB = pieces[0]
		for piece in pieces: box = box.merge(piece)
		var center := box.get_center()
		var extent := maxf(box.size.length(),.5)*1.1
		camera.size = extent
		var atlas := Image.create(CELL.x*ANGLES,CELL.y*ELEVATIONS.size(),false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		var normals := Image.create(CELL.x*ANGLES,CELL.y*ELEVATIONS.size(),false,Image.FORMAT_RGBA8)
		normals.fill(Color.TRANSPARENT)
		for row in ELEVATIONS.size():
			var elevation := deg_to_rad(ELEVATIONS[row])
			for angle in ANGLES:
				var heading := angle*TAU/ANGLES
				camera.position = center + Vector3(sin(heading)*cos(elevation),sin(elevation),cos(heading)*cos(elevation))*12
				camera.look_at(center)
				for normal_pass in [false,true]:
					for material in materials: material.set_shader_parameter("normal_pass",normal_pass)
					await process_frame
					await RenderingServer.frame_post_draw
					var picture := viewport.get_texture().get_image()
					var destination := Vector2i(angle*CELL.x,row*CELL.y)
					if normal_pass: normals.blit_rect(picture,Rect2i(Vector2i.ZERO,CELL),destination)
					else: atlas.blit_rect(picture,Rect2i(Vector2i.ZERO,CELL),destination)
		var output: String = "res://assets/car_impostors/"+name+".png"
		assert(atlas.save_png(output) == OK)
		var normal_output: String = "res://assets/car_impostors/"+name+"_normals.png"
		assert(normals.save_png(normal_output) == OK)
		metadata.models[path] = {"atlas":output,"normals":normal_output,"world_height":extent,"center":[center.x,center.y,center.z],"bounds":[box.size.x,box.size.y,box.size.z]}
		model.free()
		print("CAR_IMPOSTOR_BAKED ",name," 64 static views")
	var file := FileAccess.open("res://assets/car_impostors/metadata.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t"))
	file.close()
	viewport.queue_free()
	print("CAR_IMPOSTOR_BAKE_PASS")
	quit()
