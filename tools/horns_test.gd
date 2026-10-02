extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://procedural_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var car = scene.get_node("ProceduralCity/Traffic").get_child(0)
	car.set_physics_process(false)
	assert(car.short_horn.get_length() < 0.6)
	assert(car.held_horn.get_length() > 2.5)
	assert(car.honk())
	assert(not car.honk(), "Normal honks must respect cooldown")
	car.prolonged_impact_horn_chance = 1.0
	assert(car.disable_from_impact(10.0, Vector3.RIGHT, car.global_position))
	assert(car.horn_player.stream == car.held_horn and car.horn_player.playing)
	car.explode()
	assert(not car.horn_player.playing and not car.honk(true))
	for voice in ["compact", "sedan", "van"]:
		for kind in ["short", "held"]:
			var sound = load("res://assets/audio/horns/%s_%s.wav" % [voice, kind])
			assert(sound is AudioStreamWAV and sound.get_length() > 0.3)
	print("HORNS PASS: six sound assets, normal cooldown, prolonged impact honk, explosion stops audio")
	quit()
