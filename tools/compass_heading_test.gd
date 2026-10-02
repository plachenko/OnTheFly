extends SceneTree

func _initialize() -> void:
	var game = load("res://game.gd").new()
	var headings := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	for index in 8:
		var angle := index * PI * 0.25
		assert(game.compass_heading(Vector3(sin(angle), 0, -cos(angle))) == headings[index])
		assert(game.compass_heading(Vector3(sin(angle + 0.1), 0, -cos(angle + 0.1))) == headings[index])
	game.free()
	var hud = load("res://scenes/hud.tscn").instantiate()
	assert(hud.has_node("Layout/HeadingLabel"))
	hud.free()
	print("COMPASS PASS: all eight headings, sector rounding, HUD label")
	quit()
