@tool
extends "res://crosswalk_signal.gd"
var endpoint_a := Vector3.ZERO
var endpoint_b := Vector3.ZERO

func _ready() -> void:
	if Engine.is_editor_hint(): return
	for spec in [["SouthSignal", endpoint_a], ["NorthSignal", endpoint_b]]:
		var post := Node3D.new()
		post.name = spec[0]
		add_child(post)
		post.global_position = spec[1]
		var pole := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.height = 1.3
		cylinder.top_radius = 0.05
		cylinder.bottom_radius = 0.05
		pole.mesh = cylinder
		pole.position.y = 0.65
		post.add_child(pole)
		var status := Label3D.new()
		status.name = "Status"
		status.position.y = 1.6
		status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		status.font_size = 30
		post.add_child(status)
	super._ready()

func refresh_lights() -> void:
	var cycle := maxf(0.1, walk_seconds) + maxf(0.1, wait_seconds)
	var phase := fmod(elapsed, cycle)
	walk_allowed = phase >= maxf(0.1, wait_seconds)
	vehicle_yellow = not walk_allowed and phase >= maxf(0.0, wait_seconds - yellow_seconds)
	for title in ["SouthSignal", "NorthSignal"]:
		var status := get_node_or_null(title + "/Status") as Label3D
		if status:
			status.text = "WALK" if walk_allowed else "WAIT"
			status.modulate = Color("70ff94") if walk_allowed else Color("ffb778")

func wait_point(side: int) -> Vector3:
	return endpoint_a if side < 0 else endpoint_b
