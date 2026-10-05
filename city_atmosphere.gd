extends Node

var city: Node3D
var environment: Environment
var edge_blend := 0.0
const FOG_START_PROGRESS := 0.20
const FOG_END_PROGRESS := 0.95
const FINAL_CLEAR_RADIUS := 0.12

func _ready() -> void:
	var world_environment := city.get_parent().get_node("WorldEnvironment") as WorldEnvironment
	environment = world_environment.environment.duplicate(true)
	world_environment.environment = environment
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_curve = 1.6
	environment.fog_light_color = Color("cbd0d3") if not city.is_night else Color("414b59")
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.12 if not city.is_night else 0.0
	update_position(Vector3.ZERO)

func _process(_delta: float) -> void:
	# Use the truck, so a chase camera trailing across a boundary cannot fog
	# a player who is still safely inside the clear city.
	var truck := city.get_parent().get_node_or_null("FoodTruck") as Node3D
	if truck: update_position(truck.global_position)

func round_progress() -> float:
	var level := city.get_parent()
	if level.has_method("is_loading_ready") and not level.is_loading_ready(): return 0.0
	if level.get("loading_intro_active") == true: return 0.0
	if level.get("level_duration_seconds") == null or level.get("remaining_time") == null: return 0.0
	var duration: float = maxf(1.0, float(level.level_duration_seconds))
	return clampf(1.0 - float(level.remaining_time) / duration, 0.0, 1.0)

func highway_blend(position: Vector3) -> float:
	var haze := 0.0
	var approaches := city.get_node_or_null("HighwayApproaches")
	if approaches == null: return haze
	for road_sign in approaches.get_children():
		if not road_sign.has_meta("highway_axis"): continue
		var axis: int = road_sign.get_meta("highway_axis")
		var lateral := 2 if axis == 0 else 0
		if absf(position[lateral] - road_sign.global_position[lateral]) > 18.0: continue
		var distance: float = (position[axis] - road_sign.global_position[axis]) * float(road_sign.get_meta("highway_side"))
		haze = maxf(haze, smoothstep(0.0, 24.0, distance))
	return haze

func update_position(position: Vector3) -> void:
	var advance := smoothstep(FOG_START_PROGRESS, FOG_END_PROGRESS, round_progress())
	var center := Vector2.ZERO
	var half: Vector2 = Vector2.ONE * city.wrap_edge
	if city.topology.planned:
		center = city.topology.bounds.get_center()
		half = city.topology.bounds.size * .5
	var relative := Vector2(position.x, position.z) - center
	var radius := maxf(absf(relative.x) / maxf(1.0,half.x), absf(relative.y) / maxf(1.0,half.y))
	var clear_radius := lerpf(1.0, FINAL_CLEAR_RADIUS, advance)
	var dense_radius := clear_radius + .18
	# No baseline haze at all early on, including the streets at the boundary.
	var city_haze := smoothstep(clear_radius, dense_radius, radius) if advance > 0.0 else 0.0
	edge_blend = maxf(city_haze, highway_blend(position))
	environment.fog_enabled = edge_blend > 0.001
	environment.fog_depth_begin = lerpf(125.0, 0.0, edge_blend)
	environment.fog_depth_end = lerpf(360.0, 24.0, edge_blend)
	environment.fog_density = edge_blend
	environment.fog_sky_affect = edge_blend

