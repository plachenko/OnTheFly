extends Node3D

var camera: Camera3D
var sprites: Array = []
var originals: Array = []
var models_3d := false
var orbit := 0.0
var clip := "Walk"

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("9ab3ba")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(25, 25)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d8d2b4")
	floor_mesh.material_override = material
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 48
	add_child(camera)
	camera.make_current()
	for row in 2:
		for variant in 4:
			var sprite = preload("res://patron_billboard.gd").new()
			add_child(sprite)
			sprite.position = Vector3((variant - 1.5) * 3.5, 0, (row - 0.5) * 4.0)
			sprite.configure(variant, sprite.COLORS[(variant + row * 2) % 6], 0.85 if row == 0 else 1.15)
			sprite.play(clip)
			sprites.append(sprite)
	var hud := CanvasLayer.new()
	add_child(hud)
	var label := Label.new()
	label.position = Vector2(20, 20)
	label.text = "PATRON SPRITE PROTOTYPE\nLeft/Right: orbit camera | 1: Idle  2: Walk  3: Run  4: Dodge\nB: compare original 3D models | Front row: 85% height; rear row: 115%"
	label.add_theme_font_size_override("font_size", 22)
	hud.add_child(label)
	update_camera()

func update_camera() -> void:
	camera.position = Vector3(sin(orbit) * 17.0, 7.0, cos(orbit) * 17.0)
	camera.look_at(Vector3(0, 1, 0))

func _process(delta: float) -> void:
	orbit += Input.get_axis("left", "right") * delta
	update_camera()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		clip = ["Idle", "Walk", "Run", "Dodge"][event.physical_keycode - KEY_1]
		for sprite in sprites: sprite.play(clip)
		for model in originals: model.get_node("AnimationPlayer").play(clip)
	elif event.physical_keycode == KEY_B:
		models_3d = not models_3d
		if originals.is_empty():
			for i in sprites.size():
				var model = load("res://assets/kenney/%s.glb" % preload("res://patron.gd").CHARACTER_PATHS[i % 4]).instantiate()
				model.position = sprites[i].position
				model.scale = Vector3(.36, .516, .516) * Vector3(1, sprites[i].scale.y, 1)
				add_child(model)
				originals.append(model)
		for sprite in sprites: sprite.visible = not models_3d
		for model in originals:
			model.visible = models_3d
			model.process_mode = Node.PROCESS_MODE_INHERIT if models_3d else Node.PROCESS_MODE_DISABLED
			model.get_node("AnimationPlayer").play(clip)
