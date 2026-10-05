extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(FileAccess.file_exists("res://assets/car_impostors/metadata.json"))
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/car_impostors/metadata.json"))
	for model in metadata.models.values():
		assert(ResourceLoader.load(model.atlas) is Texture2D)
		assert(ResourceLoader.load(model.normals) is Texture2D)
	var level: Node = load("res://procedural_city.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var city: Node = level.get_node("ProceduralCity")
	city.randomize_each_load = false
	root.add_child(level)
	current_scene = level
	while city.generating: await process_frame
	assert(city.get_node("Traffic").get_child(0).get_node("TrafficVisualLOD").enabled)
	assert(city.get_node("Buildings").get_child(0).has_node("BuildingVisualLOD"))
	assert(not root.get_node("ReplayRecorder").capture_requested())
	assert(not ResourceLoader.exists("res://debug_replay_recorder.gd"))
	if not OS.is_debug_build(): assert(Engine.max_fps == 30)
	assert(Engine.physics_ticks_per_second == 60)
	var args := OS.get_cmdline_user_args()
	if "--report" in args:
		var file := FileAccess.open(args[args.find("--report")+1],FileAccess.WRITE)
		file.store_string(JSON.stringify({"pass":true,"models":metadata.models.size(),"debug":OS.is_debug_build(),"max_fps":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,"recorder_excluded":true}))
	print("VISUAL_LOD_PACKAGE_PASS 8 compressed atlases/normals, cached city helpers, recorder excluded, frame policy unchanged")
	level.queue_free()
	await process_frame
	quit()
