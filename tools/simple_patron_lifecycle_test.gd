extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var level: Node = load("res://procedural_city.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	while not level.is_loading_ready(): await process_frame
	var manager: Node = level.get_node("PatronManager")
	manager.set_process(false)
	level.set_process(false)
	manager.configure_building_entrances()
	assert(manager.building_entrances.size() == 3)
	var buildings := {}
	for point in manager.building_entrances:
		assert(point.has_meta("building"))
		buildings[point.get_meta("building")] = true
	assert(buildings.size() == 3)
	for patron in level.get_node("Patrons").get_children(): patron.free()
	manager.building_spawn_elapsed = 0.0
	manager.spawn_patrons(3.9)
	assert(level.get_node("Patrons").get_child_count() == 0)
	manager.spawn_patrons(0.1)
	assert(level.get_node("Patrons").get_child_count() == 1)
	for i in 40: manager.spawn_patrons(4.0)
	assert(level.get_node("Patrons").get_child_count() == 12)
	var patron: Node = level.get_node("Patrons").get_child(0)
	patron.set_physics_process(false)
	patron.has_eaten = true
	patron.begin_departure()
	assert(not patron.can_be_attracted())
	level.set_process(true)
	patron._physics_process(5.0)
	assert(patron.fade_alpha > 0.49 and patron.fade_alpha < 0.51)
	patron._physics_process(1.1)
	assert(patron.is_queued_for_deletion())
	await process_frame
	level.set_process(false)
	manager.spawn_patrons(4.0)
	# Rotate past any entrances that are still full.
	manager.spawn_patrons(4.0)
	manager.spawn_patrons(4.0)
	assert(level.get_node("Patrons").get_child_count() == 12)
	print("SIMPLE PATRON PASS: three distinct buildings, staggered spawning, crowd cap, departure/fade, slot reuse")
	quit()
