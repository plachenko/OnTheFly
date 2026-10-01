@tool
extends Node3D

@export_category("Crosswalk Lights")
@export var walk_seconds: float = 12.0
@export var wait_seconds: float = 8.0
@export var yellow_seconds: float = 2.0
@export var starting_offset: float = 0.0
@export var crossing_offset: float = 5.5
@export var intersection_center_x: float = 0.0
@export var crosses_vertical_road: bool = false
var elapsed: float = 0.0
var walk_allowed: bool = false
var vehicle_yellow: bool = false

func _ready() -> void:
	elapsed = starting_offset
	refresh_lights()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	elapsed += delta
	refresh_lights()

func refresh_lights() -> void:
	var cycle := maxf(0.1,walk_seconds) + maxf(0.1,wait_seconds)
	var phase := fmod(elapsed,cycle)
	walk_allowed = phase >= maxf(0.1,wait_seconds)
	vehicle_yellow = not walk_allowed and phase >= maxf(0.0, wait_seconds - yellow_seconds)
	for label in [$SouthSignal/Status, $NorthSignal/Status]:
		label.text = "WALK" if walk_allowed else "WAIT"
		label.modulate = Color("58e78a") if walk_allowed else Color("ff6c5f")
	for post in [$SouthSignal, $NorthSignal]:
		var red_bulb: Node3D = post.get_node_or_null("VehicleRed")
		var green_bulb: Node3D = post.get_node_or_null("VehicleGreen")
		var yellow_bulb: Node3D = post.get_node_or_null("VehicleYellow")
		if red_bulb:
			red_bulb.visible = walk_allowed
		if green_bulb:
			green_bulb.visible = not walk_allowed and not vehicle_yellow
		if yellow_bulb:
			yellow_bulb.visible = vehicle_yellow

func wait_point(side: int) -> Vector3:
	if crosses_vertical_road:
		return Vector3(global_position.x + signi(side) * crossing_offset,global_position.y,global_position.z)
	return Vector3(global_position.x,global_position.y,global_position.z + signi(side) * crossing_offset)
