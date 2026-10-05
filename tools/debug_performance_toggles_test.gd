extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var diagnostics := root.get_node("PerformanceDiagnostics")
	var filters: Node = diagnostics.render_filters
	var world := Node3D.new()
	root.add_child(world)
	var grass := MeshInstance3D.new()
	grass.name = "GrassClumps"
	world.add_child(grass)
	var props := Node3D.new()
	props.name = "StreetSigns"
	world.add_child(props)
	var sign := MeshInstance3D.new()
	props.add_child(sign)
	var lamp := OmniLight3D.new()
	lamp.shadow_enabled = true
	world.add_child(lamp)
	filters.set_disabled("grass", true)
	assert(not grass.visible and sign.visible)
	filters.set_disabled("furniture", true)
	assert(not sign.visible)
	filters.set_disabled("shadows", true)
	assert(not lamp.shadow_enabled)
	filters.set_disabled("lights", true)
	assert(not lamp.visible)
	var late := MeshInstance3D.new()
	props.add_child(late)
	await process_frame
	await process_frame
	assert(not late.visible)
	for key in filters.OPTIONS: filters.set_disabled(key, false)
	assert(grass.visible and sign.visible and late.visible and lamp.visible and lamp.shadow_enabled)
	var body := Node3D.new()
	world.add_child(body)
	var model := MeshInstance3D.new()
	model.mesh = BoxMesh.new()
	body.add_child(model)
	var lod: Node = load("res://building_visual_lod.gd").attach(body, model)
	diagnostics.buildings_as_blocks = true
	assert(not model.visible and lod.proxy.visible and lod.proxy.visibility_range_begin == 0)
	diagnostics.buildings_as_blocks = false
	assert(model.visible and lod.proxy.visibility_range_begin == 96)
	var car: Node = load("res://traffic_car.gd").new()
	car.collision_layer = 7
	car.collision_mask = 11
	car.freeze = false
	diagnostics.traffic_enabled = false
	car.apply_debug_traffic()
	assert(not car.visible and car.freeze and car.collision_layer == 0 and car.process_mode == Node.PROCESS_MODE_DISABLED)
	diagnostics.traffic_enabled = true
	car.apply_debug_traffic()
	assert(car.visible and not car.freeze and car.collision_layer == 7 and car.collision_mask == 11)
	car.set_physics_process(true)
	diagnostics.traffic_logic_enabled = false
	car.apply_debug_traffic_logic()
	assert(car.visible and car.freeze and not car.is_physics_processing())
	assert(car.collision_layer == 7 and car.collision_mask == 11)
	diagnostics.traffic_enabled = false
	car.apply_debug_traffic()
	diagnostics.traffic_logic_enabled = true
	car.apply_debug_traffic_logic()
	assert(not car.visible and car.freeze)
	diagnostics.traffic_enabled = true
	car.apply_debug_traffic()
	assert(car.visible and not car.freeze and car.is_physics_processing())
	# Full-disable first, then logic-disable, then reveal cars while logic stays off.
	diagnostics.traffic_enabled = false
	car.apply_debug_traffic()
	diagnostics.traffic_logic_enabled = false
	car.apply_debug_traffic_logic()
	diagnostics.traffic_enabled = true
	car.apply_debug_traffic()
	assert(car.visible and car.freeze and not car.is_physics_processing())
	diagnostics.traffic_logic_enabled = true
	car.apply_debug_traffic_logic()
	assert(not car.freeze and car.is_physics_processing())
	car.free()
	var pedestrian := CharacterBody3D.new()
	world.add_child(pedestrian)
	pedestrian.add_to_group("patrons")
	pedestrian.process_mode = Node.PROCESS_MODE_PAUSABLE
	diagnostics.pedestrian_logic_enabled = false
	assert(pedestrian.process_mode == Node.PROCESS_MODE_DISABLED and pedestrian.visible)
	# The manager's guards must prevent even direct spawn calls while disabled.
	var manager: Node = load("res://patron_manager.gd").new()
	manager.spawn_patrons(1.0)
	manager._process(1.0)
	manager.free()
	var late_pedestrian := CharacterBody3D.new()
	world.add_child(late_pedestrian)
	late_pedestrian.add_to_group("patrons")
	diagnostics.apply_pedestrian_logic(late_pedestrian)
	assert(late_pedestrian.process_mode == Node.PROCESS_MODE_DISABLED)
	diagnostics.pedestrian_logic_enabled = true
	assert(pedestrian.process_mode == Node.PROCESS_MODE_PAUSABLE)
	assert(late_pedestrian.process_mode == Node.PROCESS_MODE_INHERIT)
	root.get_node("DebugMenu").open_menu()
	assert(root.get_node("DebugMenu").panel.visible)
	var debug := root.get_node("DebugMenu")
	debug.set_comparison(true, "rendering_lod_enabled")
	debug.set_all_baseline(false)
	assert(not diagnostics.traffic_enabled and not diagnostics.traffic_logic_enabled)
	assert(not diagnostics.pedestrian_logic_enabled and diagnostics.buildings_as_blocks)
	assert(diagnostics.render_filters.disabled.grass)
	assert(not diagnostics.rendering_lod_enabled, "Baseline selection must not change comparisons")
	debug.set_all_baseline(true)
	assert(diagnostics.traffic_enabled and diagnostics.traffic_logic_enabled and diagnostics.pedestrian_logic_enabled)
	assert(not diagnostics.buildings_as_blocks and not diagnostics.render_filters.disabled.grass)
	assert(debug.all_baseline.button_pressed)
	debug.set_baseline(false, "grass", true)
	assert(not debug.all_baseline.button_pressed and not debug.baseline_options.grass.checkbox.button_pressed)
	debug.set_baseline(true, "grass", true)
	debug.set_comparison(false, "rendering_lod_enabled")
	world.queue_free()
	print("DEBUG PERFORMANCE TOGGLES PASS: restoration, late props, shadows/lights, building boxes, traffic physics/collisions")
	quit()
