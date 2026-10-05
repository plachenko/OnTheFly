extends SceneTree
func _initialize() -> void:
	var scene: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = scene.get_node("ProceduralCity")
	city.topology.generate(12054,city.park_block_centers)
	print("PROBE ",city.topology.verticals," ",city.topology.horizontals," ",city.topology.segments(true,0,256,8))
	print("PROBE road=",city.road_segment_exists(true,0,0)," grid=",city.on_grid_road(Vector2(0,0))," grid20=",city.on_grid_road(Vector2(0,20)))
	scene.free()
	quit()
