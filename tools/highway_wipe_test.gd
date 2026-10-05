extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var signs := Node3D.new()
	root.add_child(signs)
	for axis in [0, 2]:
		for side in [-1.0, 1.0]:
			var road_sign := Node3D.new()
			road_sign.position[axis] = side * 152.0
			road_sign.set_meta("highway_axis", axis)
			road_sign.set_meta("highway_side", side)
			signs.add_child(road_sign)
	for axis in [0, 2]:
		for side in [-1.0, 1.0]:
			var wipe = load("res://highway_wipe.gd").new()
			root.add_child(wipe)
			assert(wipe.panel.material.shader.resource_path == "res://loading_backdrop.gdshader")
			assert(wipe.panel.material.get_shader_parameter("patterns_only"))
			var position := Vector3.ZERO
			position[axis] = side * 151.0
			wipe.tick(position, signs, 1.0 / 60.0)
			assert(wipe.phase == 0)
			position[axis] = side * 153.0
			wipe.tick(position, signs, 1.0 / 60.0)
			assert(wipe.phase == 1)
			assert(wipe.fog_panel.visible)
			assert(wipe.fog_panel.material.shader.resource_path == "res://highway_fog_wipe.gdshader")
			if DisplayServer.get_name() != "headless" and axis == 0 and side == -1.0:
				wipe.fog_panel.material.set_shader_parameter("progress",0.5)
				for frame in 3: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/highway_fog_wipe_preview.png")
			for frame in range(20):
				wipe.tick(position, signs, 1.0 / 60.0)
			assert(wipe.progress == 1.0)
			position[axis] = -side * 173.0
			wipe.wrapped(position)
			wipe.tick(position, signs, 1.0 / 60.0)
			assert(wipe.phase == 2 and wipe.progress == 1.0)
			position[axis] = -side * 151.0
			wipe.tick(position, signs, 1.0 / 60.0)
			assert(wipe.phase == 3)
			for frame in range(60):
				wipe.tick(position, signs, 1.0 / 60.0)
			assert(wipe.phase == 0 and not wipe.panel.visible)
			assert(not wipe.fog_panel.visible)
			wipe.free()
	print("HIGHWAY_BANDS_PASS: shared loading shader, four crossings, wrap and arrival retract")
	signs.free()
	quit()
