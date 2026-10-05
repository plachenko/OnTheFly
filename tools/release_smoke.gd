extends Node
func _ready() -> void: run.call_deferred()
func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		get_tree().quit(1)
	return condition
func run() -> void:
	if not check(not OS.is_debug_build(),"Expected release engine"): return
	if not check(Engine.max_fps == 30 and Engine.physics_ticks_per_second == 60,"Expected 30fps / 60Hz"): return
	if not check(not get_tree().root.get_node("ReplayRecorder").capture_requested() and not ResourceLoader.exists("res://debug_replay_recorder.gd"),"Recorder must be absent and disabled"): return
	print("RELEASE POLICY PASS: 30fps/60Hz, recorder excluded despite capture flag")
	var menu = load("res://main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	var started := Time.get_ticks_msec()
	while not menu.menu_ready:
		await get_tree().process_frame
		if Time.get_ticks_msec()-started > 45000:
			for child in menu.get_children():
				if child.has_method("is_loading_ready"): print("WAITING ",child.name," ready=",child.is_loading_ready())
			check(false,"Menu did not become ready within 45 seconds")
			return
	if not check(menu.level.truck.billboard == null and menu.level.truck.model.visible,"Expected 3D truck"): return
	if not check(menu.level.get_node("ProceduralCity/FogBoundary/CityAtmosphere").environment.fog_enabled == false,"Starting city must be clear"): return
	if not check(menu.level.get_node("ProceduralCity/HighwayApproaches").find_children("EdgeWall*", "", false, false).size() == 1,"Expected spline wall"): return
	print("RELEASE SMOKE PASS: saved city, 3D truck, clear starting fog, spline wall, menu")
	get_tree().quit()
