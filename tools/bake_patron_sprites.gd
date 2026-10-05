extends SceneTree
const PATHS = ["criminalMaleA", "cyborgFemaleA", "skaterFemaleA", "skaterMaleA"]
const CLIPS = ["Idle", "Walk", "Run", "Dodge"]
const CELL = Vector2i(96, 128)
const FRAMES = 12
var viewport: SubViewport
var camera: Camera3D
var materials: Array[ShaderMaterial] = []
func _initialize() -> void: run.call_deferred()
func prepare(node: Node) -> void:
 if node is MeshInstance3D:
  for surface in node.mesh.get_surface_count():
   var original = node.get_active_material(surface) as StandardMaterial3D
   var material := ShaderMaterial.new()
   material.shader = load("res://tools/patron_bake.gdshader")
   material.set_shader_parameter("albedo_texture", original.albedo_texture)
   material.set_shader_parameter("tint", original.albedo_color)
   node.set_surface_override_material(surface, material)
   materials.append(material)
 for child in node.get_children(): prepare(child)
func run() -> void:
 viewport = SubViewport.new()
 viewport.size = CELL
 viewport.own_world_3d = true
 viewport.transparent_bg = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 2.8
 camera.keep_aspect = Camera3D.KEEP_HEIGHT
 viewport.add_child(camera)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(0,0,0,0)
 viewport.add_child(env)
 var metadata := {"frames": FRAMES, "angles": 8, "cell": [96,128], "world_height": 2.8, "clips": CLIPS, "durations": []}
 for variant in 4:
  var model = load("res://assets/kenney/" + PATHS[variant] + ".glb").instantiate()
  model.scale = Vector3(.36,.516,.516)
  viewport.add_child(model)
  materials.clear()
  prepare(model)
  var player: AnimationPlayer = model.get_node("AnimationPlayer")
  player.set_process(false)
  player.set_physics_process(false)
  var durations: Array = []
  for clip in CLIPS: durations.append(player.get_animation(clip).length)
  metadata.durations.append(durations)
  var atlas := Image.create(CELL.x * FRAMES, CELL.y * 4 * 8, false, Image.FORMAT_RGBA8)
  var mask_atlas := Image.create(CELL.x * FRAMES, CELL.y * 4 * 8, false, Image.FORMAT_RGBA8)
  atlas.fill(Color.TRANSPARENT)
  mask_atlas.fill(Color.TRANSPARENT)
  for angle in 8:
   var heading := angle * TAU / 8.0
   var target := Vector3(0,1.53,0)
   camera.position = target + Vector3(sin(heading)*6.0,2.8,cos(heading)*6.0)
   camera.look_at(target)
   for clip_index in 4:
    player.play(CLIPS[clip_index])
    player.pause()
    for frame in FRAMES:
     var time: float = durations[clip_index] * frame / FRAMES
     player.seek(time, true)
     for mask_pass in [false,true]:
      for material in materials: material.set_shader_parameter("mask_pass", mask_pass)
      await process_frame
      await RenderingServer.frame_post_draw
      var picture := viewport.get_texture().get_image()
      var destination := Vector2i(frame*CELL.x,(angle*4+clip_index)*CELL.y)
      if mask_pass: mask_atlas.blit_rect(picture,Rect2i(Vector2i.ZERO,CELL),destination)
      else: atlas.blit_rect(picture,Rect2i(Vector2i.ZERO,CELL),destination)
   atlas.get_region(Rect2i(0,angle*4*CELL.y,CELL.x*FRAMES,CELL.y*4)).save_png("res://assets/patron_sprites/variant_%d_angle_%d.png" % [variant,angle])
   print("PATRON_BAKE variant=",variant," angle=",angle)
  atlas.save_png("res://assets/patron_sprites/variant_%d_atlas.png" % variant)
  mask_atlas.save_png("res://assets/patron_sprites/variant_%d_mask.png" % variant)
  model.free()
 var file := FileAccess.open("res://assets/patron_sprites/metadata.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(metadata,"\t"))
 print("PATRON_BAKE_COMPLETE")
 quit()
