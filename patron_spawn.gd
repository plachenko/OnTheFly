@tool
extends Marker3D
@export_range(0,30) var patron_limit: int = 4
@export var spawn_interval: float = 1.5
@export var wander_radius: float = 5.0
@export var sidewalk_min_z: float = -11.0
@export var sidewalk_max_z: float = 11.0
@export_range(0,1) var minimum_interest: float = .65
@export_range(0,1) var maximum_interest: float = 1.0
@export var minimum_budget: int = 18
@export var maximum_budget: int = 32
