@tool
extends "res://procedural_city.gd"

# Flat sandbox using the production city's interface without generating traffic.
func _ready() -> void:
	pass

func height_at(_x: float, _z: float) -> float:
	return 0.0

func terrain_surface_height_at(_x: float, _z: float) -> float:
	return 0.0

func on_grid_road(point: Vector2, clearance: float = 0.0) -> bool:
	for x in [-28.0, 0.0, 28.0]:
		if absf(point.x - x) < 8.0 + clearance:
			return true
	for z in [-40.0, 0.0, 40.0]:
		if absf(point.y - z) < 8.0 + clearance:
			return true
	return false

func escape_streets() -> Array:
	var streets: Array = []
	for x in [-28.0, 0.0, 28.0]:
		streets.append([Vector2(x, 0), Vector2(0, 1)])
	for z in [-40.0, 0.0, 40.0]:
		streets.append([Vector2(0, z), Vector2(1, 0)])
	return streets

func distance_to_diagonal_road(_point: Vector2) -> float:
	return INF
