extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var model = load("res://assets/truck_with_doors.glb").instantiate()
	stage.add_child(model)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.13, 0.17, 0.21)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.4
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	root.size = Vector2i(1100, 800)
	for view in ["rear", "cab", "kitchen"]:
		if view == "kitchen":
			var rig: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
			rig.set_bone_pose_rotation(rig.find_bone("Awning"), Quaternion(Vector3.RIGHT, PI * 0.5))
			rig.set_bone_pose_rotation(rig.find_bone("Counter"), Quaternion(Vector3.RIGHT, -PI * 0.5))
		camera.position = {"rear": Vector3(8, 5, 8), "cab": Vector3(-8, 4.5, -7), "kitchen": Vector3(2, 3.0, -6)}[view]
		camera.look_at(Vector3(-0.3, 1.8, 0))
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/truck_doors_%s.png" % view)
	quit()
