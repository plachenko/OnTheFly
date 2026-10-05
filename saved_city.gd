extends Resource

@export var format_version: int = 3
@export var original_grid := false
@export var map_size: int = 1
@export var settings_hash: String
# Keep the serialized property name compatible with existing saved cities.
@warning_ignore("shadowed_global_identifier")
@export var seed: int
@export var night: bool
@export var hills: Array[Vector2]
@export var traffic_state: int
@export var snapshot: PackedScene
@export var sections: Array[PackedScene] = []
@export var section_centers: PackedVector3Array
@export var section_global: PackedByteArray
@export var block_cards: Array[Dictionary] = []
