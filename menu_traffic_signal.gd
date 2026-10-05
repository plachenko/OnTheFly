extends Node3D
@export var source_path: NodePath
func _process(_delta: float) -> void:
	var source := get_node_or_null(source_path)
	if source == null: return
	for light in ["VehicleRed","VehicleYellow","VehicleGreen"]:
		var bulb := get_node_or_null(light)
		var original := source.get_node_or_null(light)
		if bulb != null and original != null: bulb.visible = original.visible
