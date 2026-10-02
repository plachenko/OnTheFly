@tool
extends Node3D

## Builds a new playable city whenever the scene loads. Tune these properties
## on the ProceduralCity node in the Godot Inspector.
@export_category("Landscape")
@export var randomize_each_load: bool = true
@export var fixed_seed: int = 12054
@export_category("Time of Day")
@export_enum("Random", "Day", "Night") var time_of_day_mode: int = 0
@export_range(0.0, 1.0, 0.05) var night_chance: float = 0.5
@export_range(0.0, 1.0, 0.05) var lit_window_chance: float = 0.38
@export_range(0.0, 0.1, 0.005) var streamer_window_chance: float = 0.025
@export_range(320.0, 1200.0, 8.0) var terrain_size: float = 960.0
@export_range(1.0, 8.0, 1.0) var terrain_step: float = 4.0
@export_range(0.0, 40.0, 0.5) var hill_height: float = 28.0
@export_range(80.0, 400.0, 4.0) var hill_diameter: float = 240.0
@export_range(0.0, 0.15, 0.01) var terrain_roughness: float = 0.05
@export_range(120.0, 260.0, 4.0) var edge_taper_start: float = 160.0
@export_range(280.0, 480.0, 4.0) var edge_taper_end: float = 380.0
@export_category("City")
@export var diagonal_roads_enabled: bool = true
@export_range(8.0, 16.0, 1.0) var diagonal_road_width: float = 12.0
@export var diagonal_road_segments: Array[Vector4] = [Vector4(-128, -96, -64, -32), Vector4(64, -96, 128, -32), Vector4(0, 128, 96, 192)]
@export_range(0, 5, 1) var diagonal_plot_building_limit: int = 2
@export_range(16.0, 20.0, 1.0) var road_width: float = 16.0
@export_range(2.0, 5.0, 0.5) var sidewalk_width: float = 4.0
@export_range(0.2, 0.6, 0.02) var sidewalk_height: float = 0.34
@export_range(2.0, 6.0, 0.5) var block_corner_radius: float = 4.0
@export_range(2.0, 8.0, 0.5) var sidewalk_slab_length: float = 4.0
@export_range(180.0, 208.0, 1.0) var road_visual_extent: float = 192.0
@export_range(11.0, 18.0, 0.5) var crosswalk_setback: float = 14.0
@export_range(16.0, 25.0, 0.5) var stop_line_setback: float = 19.0
@export_range(0.6, 1.0, 0.05) var multi_crosswalk_fraction: float = 0.9
@export_range(0, 260, 1) var building_count: int = 190
@export_range(0, 40, 1) var edge_building_count: int = 26
@export_category("Sparse Block Fences")
@export var sparse_block_fences_enabled: bool = true
@export_range(0, 9, 1) var fence_max_block_buildings: int = 5
@export_range(0.6, 2.0, 0.1) var fence_height: float = 1.2
@export_category("City")
@export_range(5.0, 12.0, 0.5) var building_scale: float = 8.0
@export_range(0.0, 1.0, 0.05) var foundation_overhang: float = 0.4
@export_range(0.02, 0.3, 0.01) var foundation_clearance: float = 0.08
@export_range(0.0, 2.5, 0.1) var building_sidewalk_pull: float = 1.7
@export_range(0.0, 0.3, 0.01) var building_ground_sink: float = 0.12
@export_range(0.2, 0.6, 0.05) var foundation_stair_tread: float = 0.4
@export_range(1.0, 4.0, 0.25) var street_fixture_clearance: float = 2.0
@export var crosswalk_scene: PackedScene = preload("res://scenes/crosswalk_signal.tscn")
@export var traffic_light_model: PackedScene = preload("res://assets/kenney_city/street_furniture/traffic-light.glb")
@export var streetlight_model: PackedScene = preload("res://assets/kenney_city/street_furniture/light-curved.glb")
@export_range(3.0, 10.0, 0.5) var traffic_light_scale: float = 7.2
@export_range(3.0, 12.0, 0.5) var streetlight_scale: float = 9.0
@export_category("Traffic Cars")
@export_range(0, 80, 1) var traffic_car_count: int = 22
@export_range(3.0, 16.0, 0.5) var traffic_speed: float = 8.0
@export_range(0.0, 0.35, 0.01) var traffic_individual_speed_variation: float = 0.12
@export_category("Street Parking")
@export_range(0, 96, 1) var parking_bay_count: int = 60
@export_range(3.0, 4.0, 0.1) var parking_bay_width: float = 3.4
@export_range(10.0, 12.0, 0.2) var parking_bay_length: float = 10.0
@export_range(1.0, 3.0, 0.1) var parking_stop_line_clearance_lengths: float = 1.0
@export_range(0.1, 0.5, 0.05) var parking_marker_gap: float = 0.2
@export_range(0.0, 1.0, 0.05) var parked_car_fraction: float = 0.5
@export_range(0, 20, 1) var city_serving_bay_count: int = 8
@export_range(20.0, 80.0, 1.0) var serving_bay_spacing: float = 42.0
@export_range(1, 8, 1) var patrons_per_city_spawn: int = 3
@export_category("Traffic Cars")
@export var traffic_model_speed_factors: Dictionary = {
	"delivery": 0.72,
	"van": 0.78,
	"suv": 0.88,
	"taxi": 1.02,
	"sedan": 1.0,
	"sedan-sports": 1.28,
	"hatchback-sports": 1.20,
	"police": 1.35,
}
@export var traffic_car_scene: PackedScene = preload("res://scenes/traffic_car.tscn")
@export var traffic_car_models: PackedStringArray = [
	"res://assets/kenney_city/cars_rigged/sedan.glb",
	"res://assets/kenney_city/cars_rigged/sedan-sports.glb",
	"res://assets/kenney_city/cars_rigged/hatchback-sports.glb",
	"res://assets/kenney_city/cars_rigged/taxi.glb",
	"res://assets/kenney_city/cars_rigged/suv.glb",
	"res://assets/kenney_city/cars_rigged/van.glb",
	"res://assets/kenney_city/cars_rigged/police.glb",
	"res://assets/kenney_city/cars_rigged/delivery.glb",
]
@export_category("Fog Boundary")
@export_range(59.0, 220.0, 1.0) var wrap_edge: float = 179.0
@export_range(53.0, 210.0, 1.0) var wrap_arrival: float = 173.0
@export_range(0.05, 0.5, 0.01) var boundary_fog_opacity: float = 0.18
@export_category("Near Skyline")
@export_range(0, 64, 1) var near_skyline_count: int = 32
@export_range(220.0, 280.0, 2.0) var near_skyline_distance: float = 230.0
@export_category("Park Blocks")
@export var park_block_centers: Array[Vector2i] = [Vector2i(-32, 16)]
@export var park_tree_scene: PackedScene = preload("res://scenes/breakable_tree.tscn")

@export_category("Highway Sign")
@export_file("*.glb") var highway_sign_path: String = "res://assets/kenney_city/roads/sign-highway.glb"
@export_file("*.png") var highway_sign_colormap_path: String = "res://assets/kenney_city/roads/Textures/colormap.png"
@export_range(24.0, 40.0, 1.0) var highway_sign_span: float = 30.0
@export_range(8.0, 16.0, 0.5) var highway_sign_height_scale: float = 12.0

@export_category("Building Models")
@export var building_model_paths: PackedStringArray = [
	"res://assets/kenney_city/commercial/building-a.glb",
	"res://assets/kenney_city/commercial/building-b.glb",
	"res://assets/kenney_city/commercial/building-c.glb",
	"res://assets/kenney_city/commercial/building-d.glb",
	"res://assets/kenney_city/commercial/building-e.glb",
	"res://assets/kenney_city/commercial/building-f.glb",
	"res://assets/kenney_city/commercial/building-g.glb",
	"res://assets/kenney_city/commercial/building-h.glb",
	"res://assets/kenney_city/commercial/building-i.glb",
	"res://assets/kenney_city/commercial/building-j.glb",
	"res://assets/kenney_city/commercial/building-k.glb",
	"res://assets/kenney_city/commercial/building-l.glb",
	"res://assets/kenney_city/commercial/building-m.glb",
	"res://assets/kenney_city/commercial/building-n.glb",
	"res://assets/kenney_city/commercial/building-skyscraper-a.glb",
	"res://assets/kenney_city/commercial/building-skyscraper-b.glb",
]
@export_file("*.png") var building_colormap_path: String = "res://assets/kenney_city/commercial/Textures/colormap.png"
@export_file("*.json") var building_outward_manifest_path: String = "res://assets/kenney_city/commercial/outward_faces.json"

var actual_seed: int
var noise: FastNoiseLite
var detail_noise: FastNoiseLite
var rng := RandomNumberGenerator.new()
var lighting_rng := RandomNumberGenerator.new()
var window_lighting := preload("res://window_lighting.gd").new()
var is_night: bool = false
var road_material: StandardMaterial3D
var building_material: StandardMaterial3D
var hill_centers: Array[Vector2] = []
var building_outward_faces: Dictionary = {}
var lamp_gravel_points: Array[Vector2] = []

@export var grass_particles_enabled: bool = true
@export_range(0.0, 3.0, 0.1) var grass_particle_density: float = 1.0

signal generation_finished
var generating := false

func _ready() -> void:
	generate()

func generate() -> void:
	generating = true
	set_meta("surface_height_cache", {})
	for container in [$Terrain, $Roads, $ParkingSpaces, $ParkedCars, $HighwayApproaches, $Buildings, $NearSkyline, $Crosswalks, $StreetSigns, $Parks, $Traffic, $FogBoundary]:
		for child in container.get_children():
			container.remove_child(child)
			child.free()
	for child in get_parent().get_node("ParkingPads").get_children():
		if child.name.begins_with("CityServingPad_"):
			child.get_parent().remove_child(child)
			child.free()
	for child in get_parent().get_node("PatronSpawns").get_children():
		if child.name.begins_with("CityPatronSpawn_"):
			child.get_parent().remove_child(child)
			child.free()
	actual_seed = randi() if randomize_each_load else fixed_seed
	rng.seed = actual_seed
	lighting_rng.seed = actual_seed + 481516
	is_night = time_of_day_mode == 2 or (time_of_day_mode == 0 and lighting_rng.randf() < night_chance)
	configure_time_of_day()
	noise = FastNoiseLite.new()
	noise.seed = actual_seed
	noise.frequency = 0.008
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = actual_seed + 101
	detail_noise.frequency = 0.033
	hill_centers.clear()
	for hill_z in [-120.0,0.0,120.0]:
		for hill_x in [-120.0,0.0,120.0]:
			hill_centers.append(Vector2(hill_x+rng.randf_range(-25.0,25.0),hill_z+rng.randf_range(-25.0,25.0)))
	road_material = make_kit_material(highway_sign_colormap_path)
	building_material = make_kit_material(building_colormap_path)
	var loader := get_node_or_null("/root/LoadingScreen")
	var stages: Array[Callable] = [make_roads, make_terrain, make_parks, make_diagonal_plot_grass, make_sidewalks, make_highway_approaches, make_crosswalks, make_stop_signs, func(): preload("res://city_street_names.gd").generate(self), make_streetlights, make_buildings, make_near_skyline, make_street_parking, make_curb_markings, make_sparse_block_fences, func(): preload("res://city_power_lines.gd").generate(self), make_traffic, make_fog_boundary, align_playable_objects]
	for index in stages.size():
		if loader != null and loader.busy:
			await loader.stage("Building cityâ€¦ %d%%" % int(float(index) / stages.size() * 100))
		stages[index].call()
	if grass_particles_enabled and grass_particle_density > 0.0:
		if loader != null and loader.busy:
			await loader.stage("Planting grassâ€¦")
		preload("res://grass_particles.gd").generate(self, grass_particle_density)
	generating = false
	generation_finished.emit()

func configure_time_of_day() -> void:
	var level := get_parent()
	var world_environment := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := level.get_node_or_null("Sun") as DirectionalLight3D
	if not world_environment or not sun:
		return
	if not is_night:
		sun.light_energy = 0.95
		return
	var night_environment := world_environment.environment.duplicate(true) as Environment
	night_environment.ambient_light_color = Color(0.37, 0.45, 0.70)
	night_environment.ambient_light_energy = 0.28
	var night_sky := night_environment.sky.duplicate(true) as Sky
	var night_material := night_sky.sky_material.duplicate(true) as ShaderMaterial
	night_material.set_shader_parameter("zenith_color", Color(0.025, 0.045, 0.12))
	night_material.set_shader_parameter("horizon_color", Color(0.09, 0.14, 0.25))
	night_material.set_shader_parameter("far_city_color", Color(0.07, 0.10, 0.17))
	night_material.set_shader_parameter("near_city_color", Color(0.035, 0.065, 0.11))
	night_material.set_shader_parameter("cloud_color", Color(0.18, 0.22, 0.32))
	night_material.set_shader_parameter("sun_color", Color(0.0, 0.0, 0.0))
	night_sky.sky_material = night_material
	night_environment.sky = night_sky
	world_environment.environment = night_environment
	sun.light_color = Color(0.40, 0.52, 0.82)
	sun.light_energy = 0.16

func add_building_window_lights(model: Node3D, _source_path: String) -> void:
	if not is_night:
		return
	window_lighting.apply(model, lighting_rng, lit_window_chance, streamer_window_chance)
	apply_emissive_window_material(model)

func apply_emissive_window_material(node: Node) -> void:
	if node is MeshInstance3D:
		var base := node.material_override as StandardMaterial3D
		if base and base.albedo_texture:
			var material := ShaderMaterial.new()
			material.shader = preload("res://building_windows.gdshader")
			material.set_shader_parameter("albedo_texture", base.albedo_texture)
			material.set_shader_parameter("tint", base.albedo_color)
			node.material_override = material
	for child in node.get_children():
		apply_emissive_window_material(child)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var truck := get_parent().get_node_or_null("FoodTruck") as CharacterBody3D
	if not is_instance_valid(truck):
		return
	var moved := false
	var new_position: Vector3 = truck.global_position
	if new_position.x > wrap_edge:
		new_position.x = -wrap_arrival
		moved = true
	elif new_position.x < -wrap_edge:
		new_position.x = wrap_arrival
		moved = true
	if new_position.z > wrap_edge:
		new_position.z = -wrap_arrival
		moved = true
	elif new_position.z < -wrap_edge:
		new_position.z = wrap_arrival
		moved = true
	if moved:
		new_position.y = height_at(new_position.x,new_position.z)+0.2
		truck.global_position = new_position
		truck.velocity.y = 0.0
		var level := get_parent()
		level.camera_follow_focus = new_position+Vector3(0,1.8,0)
		level.camera_started = false

func make_fog_boundary() -> void:
	for layer in range(4):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.69,0.75,0.77,boundary_fog_opacity)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for side in [-1.0,1.0]:
			for vertical in [true,false]:
				var curtain := MeshInstance3D.new()
				curtain.name = ("East" if side > 0.0 else "West") if vertical else ("South" if side > 0.0 else "North")
				curtain.name += "Fog_%d" % layer
				curtain.position = Vector3(side*(167.0+layer*3.0),35.0,0.0) if vertical else Vector3(0.0,35.0,side*(167.0+layer*3.0))
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.1,100.0,370.0) if vertical else Vector3(370.0,100.0,0.1)
				curtain.mesh = mesh
				curtain.material_override = material
				$FogBoundary.add_child(curtain)

func make_near_skyline() -> void:
	if building_model_paths.is_empty() or near_skyline_count <= 0:
		return
	var tones := [Color(0.39, 0.48, 0.54), Color(0.44, 0.52, 0.57), Color(0.34, 0.44, 0.51)]
	var materials: Array[StandardMaterial3D] = []
	for tone in tones:
		var material := StandardMaterial3D.new()
		material.albedo_color = tone
		material.roughness = 1.0
		materials.append(material)
	var slots_per_side := ceili(float(near_skyline_count) / 4.0)
	for i in range(near_skyline_count):
		var side := i % 4
		var slot := i / 4
		var along := -170.0 + (float(slot) + 0.5) * 340.0 / float(slots_per_side) + rng.randf_range(-6.0, 6.0)
		var x := along if side >= 2 else (-near_skyline_distance if side == 0 else near_skyline_distance)
		var z := along if side < 2 else (-near_skyline_distance if side == 2 else near_skyline_distance)
		var path: String = building_model_paths[rng.randi_range(0, building_model_paths.size() - 1)]
		var template: PackedScene = load(path)
		if template == null:
			continue
		var model := template.instantiate() as Node3D
		model.name = "SkylineBuilding_%02d" % (i + 1)
		$NearSkyline.add_child(model)
		var radius := maxf(0.1, building_footprint_radius(model, model))
		model.scale = Vector3.ONE * (rng.randf_range(7.0, 11.0) / radius)
		model.position = Vector3(x, height_at(x, z) - 0.2, z)
		model.rotation.y = rng.randi_range(0, 3) * PI * 0.5
		apply_kit_material(model, materials[i % materials.size()])
		add_building_window_lights(model, path)

func height_at(x: float, z: float) -> float:
	var base_height := base_terrain_height_at(x, z)
	# The eastern ridge leaves a level-width passage for the road at z = 48.
	var east_ramp := smoothstep(124.0, 179.0, x) * 7.0
	var ridge := smoothstep(132.0, 165.0, x) * 11.0
	var passage := smoothstep(9.0, 20.0, absf(z - 48.0))
	var height := base_height + east_ramp + ridge * passage
	if x >= 140.0 and absf(z - 48.0) <= 12.0:
		var exit_grade := base_terrain_height_at(140.0, 48.0) + smoothstep(140.0, 179.0, x) * 8.0
		var passage_blend := 1.0 - smoothstep(7.0, 12.0, absf(z - 48.0))
		height = lerpf(height, maxf(height, exit_grade), passage_blend)
	return height

func base_terrain_height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var radius := hill_diameter * 0.5
	var envelope := 0.0
	for center in hill_centers:
		envelope = maxf(envelope,1.0-smoothstep(0.0,radius,point.distance_to(center)))
	var broad := hill_height * envelope
	var variation := noise.get_noise_2d(x, z) * hill_height * terrain_roughness
	var detail := detail_noise.get_noise_2d(x, z) * hill_height * terrain_roughness * 0.15
	var edge_distance := maxf(absf(x),absf(z))
	var taper := 1.0-smoothstep(edge_taper_start,edge_taper_end,edge_distance)
	return maxf(0.0, broad + (variation + detail) * envelope) * taper

func make_kit_material(texture_path: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path)
	material.metallic = 0.0
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func apply_kit_material(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		apply_kit_material(child, material)

func make_terrain() -> void:
	var segments := maxi(8, roundi(terrain_size / terrain_step))
	var step := terrain_size / float(segments)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in range(segments + 1):
		for xi in range(segments + 1):
			var x := -terrain_size * 0.5 + xi * step
			var z := -terrain_size * 0.5 + zi * step
			var h := height_at(x, z)
			# Excavate the underlying terrain, including cells crossing road edges.
			# The asphalt owns both the visible surface and its collision.
			if on_grid_road(Vector2(x, z), step * 1.5) or distance_to_diagonal_road(Vector2(x, z)) < diagonal_road_width * 0.5 + step * 1.5:
				h -= 1.0
			var color_shift := detail_noise.get_noise_2d(x + 14.0, z - 9.0) * 0.06
			tool.set_color(Color(0.22 + color_shift, 0.24 + color_shift, 0.26 + color_shift + h * 0.001))
			tool.add_vertex(Vector3(x, h, z))
	for zi in range(segments):
		for xi in range(segments):
			var a := zi * (segments + 1) + xi
			var b := a + 1
			var c := a + segments + 1
			var d := c + 1
			for index in [a, b, c, b, d, c]:
				tool.add_index(index)
	tool.generate_normals()
	var terrain_mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	terrain_mesh.surface_set_material(0, material)
	var body := StaticBody3D.new()
	body.name = "HillyGround"
	$Terrain.add_child(body)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "GroundMesh"
	mesh_node.mesh = terrain_mesh
	body.add_child(mesh_node)
	var collider := CollisionShape3D.new()
	collider.name = "GroundCollision"
	collider.shape = terrain_mesh.create_trimesh_shape()
	body.add_child(collider)

func make_roads() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.17, 0.19, 0.21)
	asphalt.roughness = 1.0
	asphalt.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sidewalk := StandardMaterial3D.new()
	sidewalk.albedo_color = Color(0.65, 0.66, 0.62)
	sidewalk.roughness = 1.0
	var sidewalk_crack := StandardMaterial3D.new()
	sidewalk_crack.albedo_color = Color(0.30, 0.32, 0.32)
	sidewalk_crack.roughness = 1.0
	var center_line := StandardMaterial3D.new()
	center_line.albedo_color = Color(0.95,0.82,0.42)
	center_line.roughness = 1.0
	var vertical_streets: Array[int] = []
	var horizontal_streets: Array[int] = []
	for x in range(-128,129,64):
		vertical_streets.append(x)
	for z in range(-144,177,64):
		horizontal_streets.append(z)
	for x in vertical_streets:
		var road := Node3D.new()
		road.name = "Road_V_%d" % x
		road.position.x = x
		$Roads.add_child(road)
		var extra := preload("res://city_road_rules.gd").extra_width(true, x, -1.0)
		preload("res://city_road_rules.gd").paint(self, road, true, x, horizontal_streets, center_line)
	for z in horizontal_streets:
		var road := Node3D.new()
		road.name = "Road_H_%d" % z
		road.position.z = z
		$Roads.add_child(road)
		var extra := preload("res://city_road_rules.gd").extra_width(false, z, 1.0)
		preload("res://city_road_rules.gd").paint(self, road, false, z, vertical_streets, center_line)
	make_road_decals(vertical_streets, horizontal_streets)
	make_diagonal_roads(asphalt, sidewalk, center_line)
	preload("res://city_road_surface.gd").generate(self, asphalt)

func make_sidewalks() -> void:
	var sidewalk := StandardMaterial3D.new()
	sidewalk.albedo_color = Color(0.65, 0.66, 0.62)
	sidewalk.roughness = 1.0
	var crack := StandardMaterial3D.new()
	crack.albedo_color = Color(0.30, 0.32, 0.32)
	var verticals: Array = [-128, -64, 0, 64, 128]
	var horizontals: Array = [-144, -80, -16, 48, 112, 176]
	var rules := preload("res://city_road_rules.gd")
	for x in verticals:
		for side in [-1.0, 1.0]:
			add_sidewalk_sections($Roads.get_node("Road_V_%d" % x), true, side * ((road_width + sidewalk_width) * 0.5 + rules.extra_width(true, x, side)), horizontals, sidewalk_width, sidewalk, crack)
	for z in horizontals:
		for side in [-1.0, 1.0]:
			add_sidewalk_sections($Roads.get_node("Road_H_%d" % z), false, side * ((road_width + sidewalk_width) * 0.5 + rules.extra_width(false, z, side)), verticals, sidewalk_width, sidewalk, crack)
	make_rounded_block_sidewalks(sidewalk)

func distance_to_diagonal_road(point: Vector2) -> float:
	var nearest := INF
	if not diagonal_roads_enabled:
		return nearest
	for segment in diagonal_road_segments:
		var start := Vector2(segment.x, segment.y)
		var finish := Vector2(segment.z, segment.w)
		var direction := finish - start
		if direction.length_squared() < 1.0:
			continue
		var t := clampf((point - start).dot(direction) / direction.length_squared(), 0.0, 1.0)
		nearest = minf(nearest, point.distance_to(start + direction * t))
	return nearest

func on_grid_road(point: Vector2, clearance: float = 0.0) -> bool:
	for x in range(-128, 129, 64):
		if absf(point.x - x) < road_width * 0.5 + preload("res://city_road_rules.gd").extra_width(true, x, signf(point.x - x)) + clearance:
			return true
	for z in range(-144, 177, 64):
		if absf(point.y - z) < road_width * 0.5 + preload("res://city_road_rules.gd").extra_width(false, z, signf(point.y - z)) + clearance:
			return true
	return false

func make_diagonal_roads(asphalt: Material, sidewalk: Material, paint: Material) -> void:
	if not diagonal_roads_enabled:
		return
	for index in diagonal_road_segments.size():
		var segment := diagonal_road_segments[index]
		var start := Vector2(segment.x, segment.y)
		var finish := Vector2(segment.z, segment.w)
		if start.distance_to(finish) < 1.0:
			continue
		var direction := (finish - start).normalized()
		var right := Vector2(-direction.y, direction.x)
		var road := Node3D.new()
		road.name = "DiagonalRoad_%d" % index
		$Roads.add_child(road)
		for side in [-1.0, 1.0]:
			add_diagonal_strip(road, "DoubleYellow", start + right * side * 0.23, finish + right * side * 0.23, 0.17, 0.24, paint, true)

func add_diagonal_strip(parent: Node3D, label: String, start: Vector2, finish: Vector2, width: float, lift: float, material: Material, trim_junctions: bool = false) -> void:
	var direction := (finish - start).normalized()
	var right := Vector2(-direction.y, direction.x)
	var steps := maxi(1, ceili(start.distance_to(finish) / 1.0))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	for step in steps:
		var a := start.lerp(finish, float(step) / steps)
		var b := start.lerp(finish, float(step + 1) / steps)
		if trim_junctions and on_grid_road((a + b) * 0.5, width * 0.5 + 0.5):
			continue
		var corners := [a - right * width * 0.5, a + right * width * 0.5, b - right * width * 0.5, b + right * width * 0.5]
		for corner_index in [0, 1, 2, 1, 3, 2]:
			var point: Vector2 = corners[corner_index]
			var ground := terrain_surface_height_at(point.x, point.y)
			tool.add_vertex(Vector3(point.x, ground + lift, point.y))
		triangles += 2
	if triangles == 0:
		return
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	parent.add_child(visual)
	if label in ["Asphalt", "AsphaltShoulder"]: visual.create_trimesh_collision()

func make_road_decals(vertical_streets: Array[int], horizontal_streets: Array[int]) -> void:
	var stop_paint := StandardMaterial3D.new()
	stop_paint.albedo_color = Color(0.91, 0.91, 0.82)
	stop_paint.roughness = 1.0
	var grate_metal := StandardMaterial3D.new()
	grate_metal.albedo_color = Color(0.13, 0.15, 0.16)
	grate_metal.roughness = 0.8
	var grate_slots := StandardMaterial3D.new()
	grate_slots.albedo_color = Color(0.31, 0.34, 0.35)
	grate_slots.roughness = 0.7
	var rules := preload("res://city_road_rules.gd")
	for x in vertical_streets:
		for z in horizontal_streets:
			var junction := Vector3(x, 0, z)
			var south_distance := rules.stop_boundary(self, Vector3.BACK, junction)
			var north_distance := rules.stop_boundary(self, Vector3.FORWARD, junction)
			var east_distance := rules.stop_boundary(self, Vector3.RIGHT, junction)
			var west_distance := rules.stop_boundary(self, Vector3.LEFT, junction)
			var vertical_direction := rules.one_way(true, x)
			var wide_v := rules.extra_width(true, x, -1)
			if vertical_direction >= 0:
				add_terrain_patch($Roads, "StopLine_Southbound", 7.2 + wide_v + (8.0 if vertical_direction != 0 else 0.0), 0.42, 0.18, stop_paint, Vector2(x - wide_v * 0.5 - (4.0 if vertical_direction == 0 else 0.0), z - south_distance), 0.5, true)
			if vertical_direction <= 0 and z + north_distance < road_visual_extent - 1.0:
				add_terrain_patch($Roads, "StopLine_Northbound", 7.2, 0.42, 0.18, stop_paint, Vector2(x + 4.0, z + north_distance), 0.5, true)
			if z > -144 and z < 176:
				var horizontal_direction := rules.one_way(false, z)
				var wide_h := rules.extra_width(false, z, 1)
				if horizontal_direction >= 0:
					add_terrain_patch($Roads, "StopLine_Eastbound", 0.42, 7.2 + wide_h, 0.18, stop_paint, Vector2(x - east_distance, z + 4.0 + wide_h * 0.5), 0.5, true)
				if horizontal_direction <= 0:
					add_terrain_patch($Roads, "StopLine_Westbound", 0.42, 7.2 + (8.0 if horizontal_direction != 0 else 0.0), 0.18, stop_paint, Vector2(x + west_distance, z - (4.0 if horizontal_direction == 0 else 0.0)), 0.5, true)
	preload("res://city_street_fixtures.gd").generate(self, vertical_streets, horizontal_streets, grate_metal, grate_slots)

func rounded_block_contour(center: Vector2, inset: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_size := 32.0 - road_width * 0.5
	var radius := minf(block_corner_radius, half_size - sidewalk_width)
	var inner_radius := maxf(0.0, radius - inset)
	var rules := preload("res://city_road_rules.gd")
	var left := center.x - half_size + rules.extra_width(true, center.x - 32, 1.0)
	var right := center.x + half_size - rules.extra_width(true, center.x + 32, -1.0)
	var low := center.y - half_size + rules.extra_width(false, center.y - 32, 1.0)
	var high := center.y + half_size - rules.extra_width(false, center.y + 32, -1.0)
	var origins := [Vector2(right - radius, high - radius), Vector2(left + radius, high - radius), Vector2(left + radius, low + radius), Vector2(right - radius, low + radius)]
	for corner in 4:
		var origin: Vector2 = origins[corner]
		for step in 13:
			var angle := (float(corner) + float(step) / 12.0) * PI * 0.5
			points.append(origin + Vector2(cos(angle), sin(angle)) * inner_radius)
		var next_origin: Vector2 = origins[(corner + 1) % 4]
		var normal := Vector2(cos((corner + 1) * PI * 0.5), sin((corner + 1) * PI * 0.5))
		var steps := ceili(origin.distance_to(next_origin))
		for step in range(1, steps):
			points.append(origin.lerp(next_origin, float(step) / steps) + normal * inner_radius)
	return points

func make_rounded_block_sidewalks(material: Material) -> void:
	for x in range(-96, 97, 64):
		for z in range(-112, 145, 64):
			if is_diagonal_plot(Vector2(x, z)):
				preload("res://city_islands.gd").make_block(self, Vector2(x, z), material)
			else:
				add_block_ring($Roads, Vector2(x, z), sidewalk_width, sidewalk_height, material)

func add_block_ring(parent: Node3D, center: Vector2, width: float, lift: float, material: Material, red: Material = null) -> void:
	var layout := preload("res://city_surface_layout.gd")
	var masks := layout.road_masks(self, 0.01)
	var outer := rounded_block_contour(center)
	var inner := rounded_block_contour(center, width)
	var tools_by_color: Array[SurfaceTool] = []
	for index in (2 if red != null else 1):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools_by_color.append(surface)
	var counts := [0, 0]
	for index in outer.size():
		var next := (index + 1) % outer.size()
		var midpoint := (outer[index] + outer[next] + inner[index] + inner[next]) * 0.25
		var pieces := layout.remaining(PackedVector2Array([outer[index], outer[next], inner[next], inner[index]]), masks)
		if pieces.is_empty(): continue
		var restricted := red != null and (absf(midpoint.x - center.x) > 17.0 and absf(midpoint.y - center.y) > 17.0)
		if red != null:
			for bay in $ParkingSpaces.get_children():
				if midpoint.distance_to(Vector2(bay.position.x, bay.position.z)) < 7.5:
					restricted = false
			for pad in get_parent().get_node("ParkingPads").get_children():
				if midpoint.distance_to(Vector2(pad.position.x, pad.position.z)) < 10.0:
					restricted = false
		var color_index := 1 if restricted else 0
		var surface: SurfaceTool = tools_by_color[color_index]
		var vertices: Array[Vector3] = []
		for point in [outer[index], inner[index], outer[next], inner[next]]:
			var ground := terrain_surface_height_at(point.x, point.y)
			vertices.append(Vector3(point.x, ground + lift, point.y))
		for piece in pieces:
			layout.emit_polygon(self, surface, piece, lift, Vector3.ZERO, false)
		counts[color_index] += 6
		if red == null:
			# Raised curb faces share the exact top edge, including every corner.
			for edge in [[0, 2], [3, 1]]:
				var a: Vector3 = vertices[edge[0]]
				var b: Vector3 = vertices[edge[1]]
				if distance_to_diagonal_road(Vector2(a.x, a.z)) < diagonal_road_width * 0.5 + 0.01 or distance_to_diagonal_road(Vector2(b.x, b.z)) < diagonal_road_width * 0.5 + 0.01: continue
				var low_a := a - Vector3.UP * (lift - 0.08)
				var low_b := b - Vector3.UP * (lift - 0.08)
				for vertex in [a, b, low_a, b, low_b, low_a]:
					surface.add_vertex(vertex)
	for index in tools_by_color.size():
		if counts[index] == 0:
			continue
		tools_by_color[index].generate_normals()
		var mesh := tools_by_color[index].commit()
		mesh.surface_set_material(0, red if index == 1 else material)
		var visual := MeshInstance3D.new()
		visual.name = "RoundedSidewalk" if red == null else ("NoParkingRed" if index == 1 else "WhiteCurbLine")
		visual.mesh = mesh
		parent.add_child(visual, true)
		if red == null:
			visual.create_trimesh_collision()
			for child in visual.get_children():
				if child is StaticBody3D:
					child.set_meta("sidewalk", true)

func make_curb_markings() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.9)
	white.roughness = 0.9
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.055, 0.045)
	red.roughness = 0.9
	var markings := Node3D.new()
	markings.name = "CurbMarkings"
	$Roads.add_child(markings)
	for x in range(-96, 97, 64):
		for z in range(-112, 145, 64):
			if is_diagonal_plot(Vector2(x, z)): continue # Closed islands carry their own complete curb outline.
			add_block_ring(markings, Vector2(x, z), 0.28, sidewalk_height + 0.012, white, red)

func add_curb_marking(parent: Node3D, at: Vector2, vertical: bool, restricted: bool, white: Material, red: Material) -> void:
	if distance_to_diagonal_road(at) < diagonal_road_width * 0.5 + 3.0:
		return
	# A designated parking/serving bay always retains a white curb.
	if restricted:
		for bay in $ParkingSpaces.get_children():
			var delta := at - Vector2(bay.position.x, bay.position.z)
			if absf(delta.x) < (3.0 if vertical else 6.5) and absf(delta.y) < (6.5 if vertical else 3.0):
				restricted = false
				break
		for pad in get_parent().get_node("ParkingPads").get_children():
			if at.distance_to(Vector2(pad.position.x, pad.position.z)) < 10.0:
				restricted = false
	var color := red if restricted else white
	add_terrain_patch(parent, "NoParkingRed" if restricted else "WhiteCurbLine", 0.28 if vertical else 5.7, 5.7 if vertical else 0.28, 0.19, color, at, 0.5, true)

func add_sewer_grate(center: Vector2, vertical: bool, metal: Material, slots: Material) -> void:
	add_terrain_patch($Roads, "SewerGrate", 1.15 if vertical else 1.7, 1.7 if vertical else 1.15, 0.17, metal, center, 0.3, true)
	for bar in range(4):
		var shift := (float(bar) - 1.5) * 0.31
		var offset := center + (Vector2(shift, 0.0) if vertical else Vector2(0.0, shift))
		add_terrain_patch($Roads, "GrateRib", 0.075 if vertical else 1.42, 1.42 if vertical else 0.075, 0.18, slots, offset, 0.3, true)

func make_highway_approaches() -> void:
	var shoulder_paint := StandardMaterial3D.new()
	shoulder_paint.albedo_color = Color(0.87,0.88,0.81)
	shoulder_paint.roughness = 1.0
	var sign_scene: PackedScene = load(highway_sign_path) if highway_sign_path != "" else null
	for side in [-1.0,1.0]:
		var approach := Node3D.new()
		approach.name = "NorthHighwayApproach" if side<0.0 else "SouthHighwayApproach"
		approach.position.z = side*164.0
		$HighwayApproaches.add_child(approach)
		for lane_side in [-1.0,1.0]:
			add_terrain_patch(approach,"ShoulderLine",0.22,32.0,0.135,shoulder_paint,Vector2(lane_side*7.2,0.0))
		if sign_scene:
			for road_x in range(-128, 129, 64):
				add_highway_exit_sign(sign_scene, Vector2(road_x, side * 152.0), true, side)
			for road_z in range(-144, 177, 64):
				var sign_x := 138.0 if side > 0.0 and road_z == 48 else 142.0
				add_highway_exit_sign(sign_scene, Vector2(side * sign_x, road_z), false, side)
	make_east_hillside_tunnel()

func add_highway_exit_sign(sign_scene: PackedScene, center: Vector2, vertical: bool, side: float) -> void:
	var group := Node3D.new()
	group.name = "HighwayExitSign_%s_%d_%d" % ["V" if vertical else "H", roundi(center.x), roundi(center.y)]
	group.position = Vector3(center.x, 0.0, center.y)
	$HighwayApproaches.add_child(group)
	var post_offset := highway_sign_span * 0.5
	var post_a := Vector2(center.x - post_offset, center.y) if vertical else Vector2(center.x, center.y - post_offset)
	var post_b := Vector2(center.x + post_offset, center.y) if vertical else Vector2(center.x, center.y + post_offset)
	var sign_base := maxf(height_at(post_a.x, post_a.y), height_at(post_b.x, post_b.y)) + 0.1
	var sign := sign_scene.instantiate() as Node3D
	sign.name = "KenneyHighwaySign"
	sign.position.y = sign_base
	sign.rotation.y = -side * PI * 0.5 if vertical else (0.0 if side > 0.0 else PI)
	sign.scale = Vector3(8.0, highway_sign_height_scale, highway_sign_span)
	apply_kit_material(sign, road_material)
	group.add_child(sign)
	add_visible_highway_panel(group, vertical, side, sign_base)
	for post in [post_a, post_b]:
		make_highway_sign_footing(group, post.x - center.x, post.y - center.y, sign_base)

func add_visible_highway_panel(group: Node3D, vertical: bool, side: float, sign_base: float) -> void:
	var panel := MeshInstance3D.new()
	panel.name = "HighwayPanel"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(14.0, 2.4, 0.24) if vertical else Vector3(0.24, 2.4, 14.0)
	panel.mesh = panel_mesh
	panel.position = Vector3(0.0, sign_base + 6.0, -side * 1.0) if vertical else Vector3(-side * 1.0, sign_base + 6.0, 0.0)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.04, 0.27, 0.19)
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel.material_override = green
	group.add_child(panel)
	var label := Label3D.new()
	label.name = "HighwayText"
	label.text = "HIGHWAY"
	label.font_size = 64
	label.pixel_size = 0.02
	label.modulate = Color(0.98, 0.98, 0.90)
	label.position = Vector3(0.0, sign_base + 6.0, -side * 1.14) if vertical else Vector3(-side * 1.14, sign_base + 6.0, 0.0)
	label.rotation.y = (PI if side > 0.0 else 0.0) if vertical else (-PI * 0.5 if side > 0.0 else PI * 0.5)
	group.add_child(label)

func make_highway_sign_footing(approach: Node3D, local_x: float, local_z: float, sign_base: float) -> void:
	var ground: float = height_at(approach.position.x+local_x,approach.position.z+local_z)
	var depth: float = maxf(0.2,sign_base-ground)
	var footing := StaticBody3D.new()
	footing.name = "SignFooting"
	footing.position = Vector3(local_x,ground+depth*0.5,local_z)
	approach.add_child(footing)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4,depth,1.4)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	footing.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.40,0.43,0.45)
	visual.material_override = concrete
	footing.add_child(visual)

func make_east_hillside_tunnel() -> void:
	var tunnel := Node3D.new()
	tunnel.name = "EastHillsideTunnel"
	$HighwayApproaches.add_child(tunnel)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.28, 0.31, 0.32)
	rock.roughness = 1.0
	var lining := StandardMaterial3D.new()
	lining.albedo_color = Color(0.43, 0.45, 0.44)
	lining.roughness = 1.0
	for road_x in range(140, 177, 4):
		var center_x := float(road_x) + 2.0
		var road_y := height_at(center_x, 48.0)
		var roof_y := road_y + 8.0
		add_tunnel_block(tunnel, "Roof", Vector3(center_x, roof_y + 1.5, 48.0), Vector3(4.2, 3.0, 25.0), rock)
		for side in [-1.0, 1.0]:
			var side_z: float = 48.0 + side * 13.0
			var ground := height_at(center_x, side_z)
			var wall_height := maxf(4.0, roof_y - ground)
			add_tunnel_block(tunnel, "TunnelWall", Vector3(center_x, ground + wall_height * 0.5, side_z), Vector3(4.2, wall_height, 2.0), lining)
	for portal_x in [140.0, 176.0]:
		var portal_y := height_at(portal_x, 48.0)
		add_tunnel_block(tunnel, "PortalLintel", Vector3(portal_x, portal_y + 7.3, 48.0), Vector3(1.5, 1.2, 27.0), lining)

func add_tunnel_block(parent: Node3D, label: String, center: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	parent.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

func near_street(value: float, streets: Array, distance: float) -> bool:
	for street in streets:
		if absf(value - street) < distance:
			return true
	return false

func add_sidewalk_sections(road: Node3D, vertical: bool, side_offset: float, cross_streets: Array, width: float, material: Material, crack_material: Material) -> void:
	# Interior sidewalks are continuous rounded block rings; preserve outer shoulders.
	var across: float = road.position.x + side_offset if vertical else road.position.z + side_offset
	if (vertical and across > -128.0 and across < 128.0) or (not vertical and across > -144.0 and across < 176.0):
		return
	var start := -road_visual_extent
	for cross in cross_streets:
		var finish: float = float(cross) - road_width * 0.5
		if finish > start + 0.1:
			var center := (start + finish) * 0.5
			var length := finish - start
			add_terrain_patch(road, "Sidewalk", width if vertical else length, length if vertical else width, sidewalk_height, material, Vector2(side_offset if vertical else center, center if vertical else side_offset), 1.0, true)
			add_sidewalk_cracks(road, vertical, side_offset, start, finish, width, crack_material)
		start = float(cross) + road_width * 0.5
	if start < road_visual_extent:
		var center := (start + road_visual_extent) * 0.5
		var length := road_visual_extent - start
		add_terrain_patch(road, "Sidewalk", width if vertical else length, length if vertical else width, sidewalk_height, material, Vector2(side_offset if vertical else center, center if vertical else side_offset), 1.0, true)
		add_sidewalk_cracks(road, vertical, side_offset, start, road_visual_extent, width, crack_material)

func add_sidewalk_cracks(road: Node3D, vertical: bool, side_offset: float, start: float, finish: float, width: float, material: Material) -> void:
	var first_joint := ceili((start + 1.0) / sidewalk_slab_length)
	var last_joint := floori((finish - 1.0) / sidewalk_slab_length)
	if first_joint > last_joint:
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for joint in range(first_joint, last_joint + 1):
		var along := float(joint) * sidewalk_slab_length
		var base: int = (joint - first_joint) * 6
		for along_side in [-1.0, 1.0]:
			for across_side in [-1.0, 0.0, 1.0]:
				var local_along: float = along + along_side * 0.035
				var local_across: float = side_offset + across_side * (width * 0.5 - 0.08)
				var x: float = road.position.x + (local_across if vertical else local_along)
				var z: float = road.position.z + (local_along if vertical else local_across)
				var ground := terrain_surface_height_at(x, z)
				tool.add_vertex(Vector3(x - road.position.x, ground + sidewalk_height + 0.01, z - road.position.z))
		for strip in range(2):
			var a: int = base + strip
			var indices := [a, a + 3, a + 1, a + 1, a + 3, a + 4] if vertical else [a, a + 1, a + 3, a + 1, a + 4, a + 3]
			for index in indices:
				tool.add_index(index)
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = "ExpansionJoints"
	visual.mesh = mesh
	road.add_child(visual)

func add_road_edge_taper_sections(road: Node3D, vertical: bool, side: float, cross_streets: Array, material: Material) -> void:
	var start := -road_visual_extent
	for cross in cross_streets:
		var finish := float(cross) - road_width * 0.5
		if finish > start:
			add_road_edge_taper(road, vertical, side, start, finish, material)
		start = float(cross) + road_width * 0.5
	if start < road_visual_extent:
		add_road_edge_taper(road, vertical, side, start, road_visual_extent, material)

func add_road_edge_taper(road: Node3D, vertical: bool, side: float, start: float, finish: float, material: Material) -> void:
	var segments := maxi(1, ceili((finish - start) / terrain_step))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments + 1):
		var along := lerpf(start, finish, float(index) / segments)
		for edge in range(2):
			var coordinate := road.position.x if vertical else road.position.z
			var across := side * (road_width * 0.5 + preload("res://city_road_rules.gd").extra_width(vertical, coordinate, side) + float(edge) * 1.5)
			var x := road.position.x + (across if vertical else along)
			var z := road.position.z + (along if vertical else across)
			var lift := (0.08 if vertical else 0.09) if edge == 0 else 0.015
			tool.add_vertex(Vector3(x - road.position.x, height_at(x, z) + lift, z - road.position.z))
	for index in range(segments):
		var a := index * 2
		for vertex in [a, a + 1, a + 2, a + 1, a + 3, a + 2]:
			tool.add_index(vertex)
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "RoadEdgeTaper"
	instance.mesh = mesh
	road.add_child(instance)

func terrain_surface_height_at(x: float, z: float) -> float:
	var segments := maxi(8, roundi(terrain_size / terrain_step))
	var step := terrain_size / float(segments)
	var grid_x := clampf((x + terrain_size * 0.5) / step, 0.0, float(segments) - 0.0001)
	var grid_z := clampf((z + terrain_size * 0.5) / step, 0.0, float(segments) - 0.0001)
	var cell_x := floori(grid_x)
	var cell_z := floori(grid_z)
	var u := grid_x - cell_x
	var v := grid_z - cell_z
	var x0 := -terrain_size * 0.5 + cell_x * step
	var z0 := -terrain_size * 0.5 + cell_z * step
	var h00 := height_at(x0, z0)
	var h10 := height_at(x0 + step, z0)
	var h01 := height_at(x0, z0 + step)
	var h11 := height_at(x0 + step, z0 + step)
	if u + v <= 1.0:
		return h00 * (1.0 - u - v) + h10 * u + h01 * v
	return h10 * (1.0 - v) + h01 * (1.0 - u) + h11 * (u + v - 1.0)

func add_terrain_patch(parent: Node3D, label: String, width_x: float, width_z: float, lift: float, material: Material, offset: Vector2 = Vector2.ZERO, mesh_step: float = 2.0, follow_surface: bool = false) -> void:
	if label.begins_with("Stripe_") or label.begins_with("StopLine_") or label in ["SewerGrate", "GrateRib"]:
		var projection := preload("res://city_road_surface.gd")
		var layout := preload("res://city_surface_layout.gd")
		var center := Vector2(parent.position.x, parent.position.z) + offset
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		projection.emit_polygon(self, surface, layout.rect_polygon(Rect2(center - Vector2(width_x, width_z) * 0.5, Vector2(width_x, width_z))), lift, parent.position)
		surface.generate_normals()
		var mesh := surface.commit()
		mesh.surface_set_material(0, material)
		var visual := MeshInstance3D.new()
		visual.name = label
		visual.mesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.set_meta("surface_decal", label)
		parent.add_child(visual)
		return
	if label == "Sidewalk":
		var layout := preload("res://city_surface_layout.gd")
		var center := Vector2(parent.position.x, parent.position.z) + offset
		layout.add_patch(self, parent, label, layout.rect_polygon(Rect2(center - Vector2(width_x, width_z) * 0.5, Vector2(width_x, width_z))), lift, material, 0.45)
		return
	if label in ["Grass", "ParkGrass", "ParkPath_X", "ParkPath_Z", "LampGravel"]:
		var layout := preload("res://city_surface_layout.gd")
		var center := Vector2(parent.position.x, parent.position.z) + offset
		layout.add_patch(self, parent, label, layout.rect_polygon(Rect2(center - Vector2(width_x, width_z) * 0.5, Vector2(width_x, width_z))), lift, material, sidewalk_width + 0.05)
		return
	var columns := maxi(1, ceili(width_x / mesh_step))
	var rows := maxi(1, ceili(width_z / mesh_step))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in range(rows + 1):
		for xi in range(columns + 1):
			var x := parent.position.x + offset.x + (float(xi) / columns - 0.5) * width_x
			var z := parent.position.z + offset.y + (float(zi) / rows - 0.5) * width_z
			var ground := terrain_surface_height_at(x, z) if follow_surface else height_at(x, z)
			tool.add_vertex(Vector3(x - parent.position.x, ground + lift, z - parent.position.z))
	for zi in range(rows):
		for xi in range(columns):
			var a := zi * (columns + 1) + xi
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			for index in [a, b, c, b, d, c]:
				tool.add_index(index)
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	parent.add_child(instance)
	if label == "Asphalt": instance.create_trimesh_collision()

func make_crosswalks() -> void:
	preload("res://city_islands.gd").crosswalks(self)
	if crosswalk_scene == null:
		return
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.96, 0.96, 0.89)
	paint.roughness = 1.0
	var crossing_index := 0
	for intersection_x in [-128.0,-64.0,0.0,64.0,128.0]:
		for intersection_z in [-80.0,-16.0,48.0,112.0]:
			crossing_index += 1
			var phase_offset := float(crossing_index % 4) * 2.0
			var crossing := crosswalk_scene.instantiate() as Node3D
			crossing.name = "Crosswalk_%02d" % crossing_index
			crossing.position = Vector3(intersection_x - crosswalk_setback, 0.0, intersection_z)
			crossing.set("crossing_offset",(road_width + sidewalk_width) * 0.5 + preload("res://city_road_rules.gd").extra_width(false, intersection_z, 1))
			crossing.set("intersection_center_x",intersection_x)
			crossing.set("starting_offset",phase_offset)
			$Crosswalks.add_child(crossing)
			for side in [-1, 1]:
				var post := crossing.get_node("SouthSignal" if side < 0 else "NorthSignal") as Node3D
				post.position.z = side * ((road_width + sidewalk_width) * 0.5 + preload("res://city_road_rules.gd").extra_width(false, intersection_z, side))
				post.position.y = height_at(crossing.position.x + post.position.x, intersection_z + post.position.z) + 0.12
				if traffic_light_model:
					post.get_node("Pole").hide()
					post.get_node("Housing").hide()
					post.get_node("Status").position.y = 3.35 * traffic_light_scale / 6.0
					var traffic_light := traffic_light_model.instantiate() as Node3D
					traffic_light.name = "KenneyTrafficLight"
					traffic_light.scale = Vector3.ONE * traffic_light_scale
					traffic_light.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
					apply_kit_material(traffic_light,road_material)
					post.add_child(traffic_light)
					make_traffic_bulb(post,"VehicleRed",Color("ff3438"),2.65)
					make_traffic_bulb(post,"VehicleYellow",Color("ffd149"),2.40)
					make_traffic_bulb(post,"VehicleGreen",Color("50f986"),2.15)
				add_knockable_pole(post, 3.7 * traffic_light_scale / 6.0)
			if streetlight_model:
				var streetlight := streetlight_model.instantiate() as Node3D
				streetlight.name = "KenneyStreetLight"
				var lamp_x: float = intersection_x + (road_width + sidewalk_width) * 0.5
				var lamp_z: float = intersection_z + (road_width + sidewalk_width) * 0.5
				streetlight.position = Vector3(lamp_x - crossing.position.x,height_at(lamp_x,lamp_z)+0.1,lamp_z - crossing.position.z)
				streetlight.scale = Vector3.ONE * streetlight_scale
				streetlight.rotation.y = 0.0
				apply_kit_material(streetlight,road_material)
				crossing.add_child(streetlight)
				add_street_spotlight(streetlight)
				add_knockable_pole(streetlight, 0.6 * streetlight_scale)
			for stripe in range(15 + ceili(preload("res://city_road_rules.gd").extra_width(false, intersection_z, 1))):
				var offset_z := float(stripe - 7)
				add_terrain_patch(crossing,"Stripe_%d" % stripe,3.6,0.5,0.20,paint,Vector2(0.0,offset_z),0.25,true)
			if preload("res://city_road_rules.gd").perpendicular_crosswalk(self, Vector3(intersection_x, 0, intersection_z)):
				make_perpendicular_crosswalk(intersection_x, intersection_z, crossing_index, phase_offset, paint)

func make_perpendicular_crosswalk(intersection_x: float, intersection_z: float, index: int, phase_offset: float, paint: Material) -> void:
	var crossing := crosswalk_scene.instantiate() as Node3D
	crossing.name = "Crosswalk_%02d_Perpendicular" % index
	crossing.position = Vector3(intersection_x, 0.0, intersection_z - crosswalk_setback)
	crossing.set("crossing_offset", (road_width + sidewalk_width) * 0.5 + preload("res://city_road_rules.gd").extra_width(true, intersection_x, -1))
	crossing.set("intersection_center_x", intersection_x)
	crossing.set("crosses_vertical_road", true)
	crossing.set("walk_seconds", 8.0)
	crossing.set("wait_seconds", 12.0)
	crossing.set("starting_offset", fmod(phase_offset + 12.0, 20.0))
	$Crosswalks.add_child(crossing)
	for side in [-1, 1]:
		var post := crossing.get_node("SouthSignal" if side < 0 else "NorthSignal") as Node3D
		post.position = Vector3(side * ((road_width + sidewalk_width) * 0.5 + preload("res://city_road_rules.gd").extra_width(true, intersection_x, side)), 0.0, -2.25)
		post.position.y = height_at(intersection_x + post.position.x, crossing.position.z + post.position.z) + 0.12
		post.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
		if traffic_light_model:
			post.get_node("Pole").hide()
			post.get_node("Housing").hide()
			post.get_node("Status").position.y = 3.35 * traffic_light_scale / 6.0
			var traffic_light := traffic_light_model.instantiate() as Node3D
			traffic_light.name = "KenneyTrafficLight"
			traffic_light.scale = Vector3.ONE * traffic_light_scale
			apply_kit_material(traffic_light, road_material)
			post.add_child(traffic_light)
			make_traffic_bulb(post, "VehicleRed", Color("ff3438"), 2.65)
			make_traffic_bulb(post, "VehicleYellow", Color("ffd149"), 2.40)
			make_traffic_bulb(post, "VehicleGreen", Color("50f986"), 2.15)
		add_knockable_pole(post, 3.7 * traffic_light_scale / 6.0)
	for stripe in range(-ceili(preload("res://city_road_rules.gd").extra_width(true, intersection_x, -1)), 15):
		var offset_x := float(stripe - 7)
		add_terrain_patch(crossing, "Stripe_%d" % stripe, 0.5, 3.6, 0.20, paint, Vector2(offset_x, 0.0), 0.25, true)

func make_streetlights() -> void:
	lamp_gravel_points.clear()
	if not streetlight_model:
		return
	var curb_offset := road_width * 0.5 + sidewalk_width + 0.8
	# Two poles on each side of every block-length street segment.
	for road_x in range(-128, 129, 64):
		for block_z in [-112.0, -48.0, 16.0, 80.0, 144.0]:
			for along in [-12.0, 12.0]:
				for side in [-1.0, 1.0]:
					add_streetlight(Vector2(road_x + side * (curb_offset + preload("res://city_road_rules.gd").extra_width(true, road_x, side)), block_z + along), side * PI * 0.5)
	for road_z in range(-144, 177, 64):
		for block_x in [-96.0, -32.0, 32.0, 96.0]:
			for along in [-12.0, 12.0]:
				for side in [-1.0, 1.0]:
					add_streetlight(Vector2(block_x + along, road_z + side * (curb_offset + preload("res://city_road_rules.gd").extra_width(false, road_z, side))), 0.0 if side > 0.0 else PI)
	var gravel := StandardMaterial3D.new()
	gravel.albedo_color = Color(0.40, 0.38, 0.33)
	gravel.roughness = 1.0
	var polygons: Array[PackedVector2Array] = []
	var layout := preload("res://city_surface_layout.gd")
	for at in lamp_gravel_points:
		polygons.append(layout.rect_polygon(Rect2(at - Vector2.ONE * 0.75, Vector2.ONE * 1.5)))
	layout.add_patches(self, $Parks, "LampGravel", polygons, 0.07, gravel, sidewalk_width + 0.05)

func add_streetlight(at: Vector2, yaw: float) -> void:
	if distance_to_diagonal_road(at) < diagonal_road_width * 0.5 + 1.0:
		return
	for pad in get_parent().get_node("ParkingPads").get_children():
		if Vector2(pad.position.x, pad.position.z).distance_to(at) < 6.0:
			return
	var lamp := streetlight_model.instantiate() as Node3D
	lamp.name = "StreetLight"
	lamp.position = Vector3(at.x, height_at(at.x, at.y) + 0.1, at.y)
	lamp.scale = Vector3.ONE * streetlight_scale
	lamp.rotation.y = yaw
	lamp_gravel_points.append(at)
	apply_kit_material(lamp, road_material)
	$StreetSigns.add_child(lamp)
	add_street_spotlight(lamp)
	add_knockable_pole(lamp, 0.6 * streetlight_scale)

func add_knockable_pole(visual: Node3D, pole_height: float) -> void:
	var body := RigidBody3D.new()
	body.name = "KnockablePole"
	body.set_script(preload("res://knockable_pole.gd"))
	body.freeze = true
	body.mass = 45.0
	body.continuous_cd = true
	body.collision_layer = 1
	body.collision_mask = 1
	visual.add_child(body)
	body.top_level = true
	body.global_transform = Transform3D(Basis(Vector3.UP, visual.global_rotation.y), visual.global_position + Vector3.UP * pole_height * 0.5)
	body.visual = visual
	body.height = pole_height
	body.visual_scale = visual.global_basis.get_scale()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, pole_height, 0.45)
	collider.shape = shape
	body.add_child(collider)

func add_street_spotlight(lamp: Node3D) -> void:
	var light := SpotLight3D.new()
	light.name = "WarmStreetSpotlight"
	lamp.add_child(light)
	# Keep the beam in world units rather than inheriting the pole model's scale.
	light.top_level = true
	light.global_position = lamp.to_global(Vector3(0, 0.56, 0))
	light.rotation.x = -PI * 0.5
	light.light_color = Color("ffe8b1")
	light.light_energy = 2.0
	light.spot_range = 18.0
	light.spot_angle = 65.0
	light.spot_angle_attenuation = 0.7
	light.shadow_enabled = false

func make_stop_signs() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.74, 0.07, 0.07)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.88)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.50, 0.53, 0.53)
	for road_x in range(-128, 129, 64):
		for side in [-1.0, 1.0]:
			var intersection_z := -144.0 if side < 0.0 else 176.0
			if not preload("res://city_road_rules.gd").allows(Vector3(0, 0, side), Vector3(road_x, 0, intersection_z)): continue
			var sign := Node3D.new()
			sign.name = "StopSign_%d_%d" % [road_x, roundi(intersection_z)]
			var sign_x: float = float(road_x) - side * (10.3 + preload("res://city_road_rules.gd").extra_width(true, road_x, -side))
			var sign_z: float = intersection_z - side * preload("res://city_road_rules.gd").stop_boundary(self, Vector3(0, 0, side), Vector3(road_x, 0, intersection_z))
			sign.position = Vector3(sign_x, height_at(sign_x, sign_z), sign_z)
			$StreetSigns.add_child(sign)
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.06
			pole_mesh.bottom_radius = 0.06
			pole_mesh.height = 2.5
			var pole := MeshInstance3D.new()
			pole.name = "Pole"
			pole.mesh = pole_mesh
			pole.position.y = 1.25
			pole.material_override = metal
			sign.add_child(pole)
			var face := Node3D.new()
			face.name = "StopFace"
			face.position.y = 2.4
			face.rotation.y = 0.0 if side < 0.0 else PI
			sign.add_child(face)
			for layer in range(2):
				var plate := MeshInstance3D.new()
				plate.name = "WhiteBorder" if layer == 0 else "RedFace"
				var shape := CylinderMesh.new()
				shape.top_radius = 0.68 if layer == 0 else 0.59
				shape.bottom_radius = shape.top_radius
				shape.height = 0.06
				shape.radial_segments = 8
				plate.mesh = shape
				plate.rotation.x = PI * 0.5
				plate.position.z = float(layer) * 0.04
				plate.material_override = white if layer == 0 else red
				face.add_child(plate)
			var text_label := Label3D.new()
			text_label.name = "STOP"
			text_label.text = "STOP"
			text_label.font_size = 64
			text_label.pixel_size = 0.008
			text_label.modulate = white.albedo_color
			text_label.position.z = 0.09
			face.add_child(text_label)

func make_traffic_bulb(post: Node3D, label: String, color: Color, height: float) -> void:
	var bulb := MeshInstance3D.new()
	bulb.name = label
	var scale_ratio := traffic_light_scale / 6.0
	bulb.position = Vector3(0.0,height,-0.32) * scale_ratio
	bulb.scale = Vector3.ONE * scale_ratio
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	bulb.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	bulb.material_override = material
	post.add_child(bulb)

func parking_center_range(segment_start: float, segment_end: float, travel_direction: float, vertical: bool = true, road_coordinate: float = INF, side: float = -1.0) -> Vector2:
	# Include painted bay/stop-line edges, not just their centre points.
	var half_bay := parking_bay_length * 0.5 + 0.06
	var stop_distance := maxf(stop_line_setback, crosswalk_setback + 4.5)
	var vacancy := parking_bay_length * maxf(1.0, parking_stop_line_clearance_lengths)
	var crossing_clearance := maxf(road_width * 0.5 + 2.0, crosswalk_setback + 1.8)
	if is_finite(road_coordinate):
		var rules := preload("res://city_road_rules.gd")
		var junction := segment_end if travel_direction > 0 else segment_start
		var intersection := Vector3(road_coordinate, 0, junction) if vertical else Vector3(junction, 0, road_coordinate)
		var axis := Vector3(0, 0, travel_direction) if vertical else Vector3(travel_direction, 0, 0)
		var lane_side := side * (-travel_direction if vertical else travel_direction) * 4.0
		if rules.approach_kind(axis, intersection, lane_side) != "unmarked":
			# The rear of the directional arrow sits 26 m before the junction.
			stop_distance = maxf(stop_distance, 26.0)
	if travel_direction > 0:
		return Vector2(segment_start + crossing_clearance + half_bay, segment_end - stop_distance - 0.21 - vacancy - half_bay)
	return Vector2(segment_start + stop_distance + 0.21 + vacancy + half_bay, segment_end - crossing_clearance - half_bay)

func make_street_parking() -> void:
	if parking_bay_count <= 0:
		return
	var candidates: Array[Dictionary] = []
	for road_x in range(-128, 129, 64):
		for segment_z in [-112, -48, 16, 80, 144]:
			for side in [-1.0, 1.0]:
				if preload("res://city_road_rules.gd").extra_width(true, road_x, side) > 0: continue
				var direction := preload("res://city_road_rules.gd").one_way(true, road_x)
				var travel: float = direction if direction != 0 else -side
				var valid_range := parking_center_range(segment_z - 32.0, segment_z + 32.0, travel, true, road_x, side)
				if valid_range.x > valid_range.y: continue
				candidates.append({"center": Vector2(road_x + side * (road_width * 0.5 - parking_bay_width * 0.5 - 0.2), rng.randf_range(valid_range.x, valid_range.y)), "vertical": true, "axis": Vector3(0.0, 0.0, travel), "side": side, "valid_range": valid_range})
	for road_z in range(-144, 177, 64):
		for segment_x in [-96, -32, 32, 96]:
			for side in [-1.0, 1.0]:
				if preload("res://city_road_rules.gd").extra_width(false, road_z, side) > 0: continue
				var direction := preload("res://city_road_rules.gd").one_way(false, road_z)
				var travel: float = direction if direction != 0 else side
				var valid_range := parking_center_range(segment_x - 32.0, segment_x + 32.0, travel, false, road_z, side)
				if valid_range.x > valid_range.y: continue
				candidates.append({"center": Vector2(rng.randf_range(valid_range.x, valid_range.y), road_z + side * (road_width * 0.5 - parking_bay_width * 0.5 - 0.2)), "vertical": false, "axis": Vector3(travel, 0.0, 0.0), "side": side, "valid_range": valid_range})
	for index in range(candidates.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var previous := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = previous
	var available: Array[Dictionary] = []
	for candidate in candidates:
		if not parking_near_gameplay_object(candidate["center"]):
			available.append(candidate)
	# Short blocks cannot fit grouped rows plus the full stop-line vacancy.
	var count := mini(parking_bay_count, available.size())
	var serving_indices: Dictionary = {}
	var serving_centers: Array[Vector2] = []
	for index in range(count):
		if serving_centers.size() >= city_serving_bay_count:
			break
		var candidate: Dictionary = available[index]
		if not candidate["vertical"] or candidate.has("row"):
			continue
		var candidate_center: Vector2 = candidate["center"]
		var well_spaced := true
		for center in serving_centers:
			if center.distance_to(candidate_center) < serving_bay_spacing:
				well_spaced = false
				break
		if well_spaced:
			serving_indices[index] = true
			serving_centers.append(candidate_center)
	var occupied_count := roundi(float(count - serving_indices.size()) * parked_car_fraction)
	var ordinary_index := 0
	var bay_paint := StandardMaterial3D.new()
	bay_paint.albedo_color = Color(0.84, 0.84, 0.76)
	bay_paint.roughness = 1.0
	var bay_asphalt := StandardMaterial3D.new()
	bay_asphalt.albedo_color = Color(0.20, 0.22, 0.23)
	bay_asphalt.roughness = 1.0
	var parked_models: Array[String] = []
	for path in traffic_car_models:
		if path.get_file() != "police.glb":
			parked_models.append(path)
	for index in range(count):
		var bay: Dictionary = available[index]
		var center: Vector2 = bay["center"]
		var vertical: bool = bay["vertical"]
		var bay_node := Node3D.new()
		bay_node.name = "ParkingBay_%02d" % (index + 1)
		bay_node.position = Vector3(center.x, 0.0, center.y)
		var is_serving: bool = serving_indices.has(index)
		bay_node.set_meta("serving", is_serving)
		bay_node.set_meta("parking_axis", bay["axis"])
		bay_node.set_meta("parking_valid_range", bay["valid_range"])
		bay_node.set_meta("parking_row", bay.get("row", 0))
		bay_node.set_meta("parking_side", bay["side"])
		if not is_serving:
			for other_index in range(count):
				if other_index == index or serving_indices.has(other_index): continue
				var other: Dictionary = available[other_index]
				var other_center: Vector2 = other["center"]
				if other["vertical"] != vertical: continue
				var across: float = absf(center.x-other_center.x) if vertical else absf(center.y-other_center.y)
				var along: float = absf(center.y-other_center.y) if vertical else absf(center.x-other_center.x)
				if across < 0.05 and along <= parking_bay_length + parking_marker_gap + 0.1:
					bay_node.set_meta("parking_row", 1)
		bay_node.set_meta("occupied", not is_serving and ordinary_index < occupied_count)
		$ParkingSpaces.add_child(bay_node)
		if is_serving:
			make_city_serving_bay(bay, serving_centers.find(center) + 1)
			continue
		ordinary_index += 1
		if ordinary_index > occupied_count or traffic_car_scene == null or parked_models.is_empty():
			continue
		var car := traffic_car_scene.instantiate() as RigidBody3D
		car.name = "ParkedCar_%02d" % (index + 1)
		car.set("parked", true)
		car.set("travel_axis", bay["axis"])
		car.set("lane_center", Vector3(center.x, 0.0, center.y))
		car.set("progress", 0.0)
		car.set("driving_speed", 0.0)
		car.set("intersection_turn_chance", 0.0)
		car.set("model_scene", load(parked_models[rng.randi_range(0, parked_models.size() - 1)]))
		$ParkedCars.add_child(car)
	# All positions must exist before shared boundaries can be identified.
	for bay_node in $ParkingSpaces.get_children():
		var axis: Vector3 = bay_node.get_meta("parking_axis")
		add_street_parking_markings(bay_node, absf(axis.z) > 0.5, bay_asphalt, bay_paint, parking_bay_width, parking_bay_length)

func make_city_serving_bay(bay: Dictionary, number: int) -> void:
	var level := get_parent()
	var center: Vector2 = bay["center"]
	var template := level.get_node("ParkingPads/ParkingPad_01") as Area3D
	var pad := template.duplicate() as Area3D
	pad.name = "CityServingPad_%02d" % number
	pad.position = Vector3(center.x, 1.5, center.y)
	pad.set_meta("compact_parking", true)
	var zone := BoxShape3D.new()
	zone.size = Vector3(parking_bay_width, 3.0, parking_bay_length)
	pad.get_node("ParkingZone").shape = zone
	var surface := PlaneMesh.new()
	surface.size = Vector2(parking_bay_width, parking_bay_length)
	pad.get_node("ServiceSurface").mesh = surface
	level.get_node("ParkingPads").add_child(pad)
	var spawn := Marker3D.new()
	spawn.name = "CityPatronSpawn_%02d" % number
	spawn.set_script(preload("res://patron_spawn.gd"))
	var sidewalk_x: float = center.x + float(bay["side"]) * 3.2
	spawn.position = Vector3(sidewalk_x, 0.1, center.y)
	spawn.set("patron_limit", patrons_per_city_spawn)
	spawn.set("spawn_interval", 1.1)
	spawn.set("wander_radius", 5.0)
	spawn.set("sidewalk_min_z", center.y - 5.0)
	spawn.set("sidewalk_max_z", center.y + 5.0)
	level.get_node("PatronSpawns").add_child(spawn)

func parking_near_gameplay_object(center: Vector2) -> bool:
	if distance_to_diagonal_road(center) < diagonal_road_width * 0.5 + 5.0:
		return true
	var level := get_parent()
	var truck := level.get_node_or_null("FoodTruck") as Node3D
	if truck and center.distance_to(Vector2(truck.position.x, truck.position.z)) < 11.0:
		return true
	var pads := level.get_node_or_null("ParkingPads")
	if pads:
		for pad in pads.get_children():
			if center.distance_to(Vector2(pad.position.x, pad.position.z)) < 11.0:
				return true
	return false

func add_street_parking_markings(bay: Node3D, vertical: bool, asphalt: Material, paint: Material, bay_width: float = 3.4, bay_length: float = 11.4) -> void:
	bay.set_meta("parking_paint_length", bay_length)
	add_terrain_patch(bay, "ParkingBaySurface", bay_width if vertical else bay_length, bay_length if vertical else bay_width, 0.105, asphalt, Vector2.ZERO, 0.5, true)
	# Retain the footprint for editor/spawn sizing without a filled rectangular tile.
	for child in bay.get_children():
		if child.name.begins_with("ParkingBaySurface"): child.hide()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := Vector2(bay_width, bay_length) * 0.5
	var special: bool = bay.get_meta("serving", false)
	var segments: Array = []
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	if special:
		for i in 4: segments.append([corners[i], corners[(i + 1) % 4]])
	else:
		preload("res://city_parking_paint.gd").emit(self, bay, vertical, surface, bay_width, bay_length)
	for segment in segments:
		var a: Vector2 = segment[0] if vertical else Vector2(segment[0].y, segment[0].x)
		var b: Vector2 = segment[1] if vertical else Vector2(segment[1].y, segment[1].x)
		var right := Vector2(-(b-a).y, (b-a).x).normalized() * 0.065
		var origin := bay.position
		var offset := Vector2(origin.x, origin.z)
		var polygon := PackedVector2Array([a-right+offset, a+right+offset, b+right+offset, b-right+offset])
		preload("res://city_road_surface.gd").emit_polygon(self, surface, polygon, 0.135, origin)
	var mesh := surface.commit()
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, paint)
	var ticks := MeshInstance3D.new()
	ticks.name = "ParkingTicks"
	ticks.mesh = mesh
	ticks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bay.add_child(ticks)

func make_traffic() -> void:
	if traffic_car_scene == null or traffic_car_models.is_empty():
		return
	var routes: Array[Array] = []
	for index in range(6):
		if index < 5:
			var x: float = -128.0+index*64.0
			# Keep each direction on its right-hand lane (US traffic).
			var direction := preload("res://city_road_rules.gd").one_way(true, x)
			if direction >= 0: routes.append([Vector3(0,0,1),Vector3(x-4.0,0,0)])
			if direction <= 0: routes.append([Vector3(0,0,-1),Vector3(x+4.0,0,0)])
			if direction != 0: routes.append([Vector3(0,0,direction),Vector3(x+4.0*direction,0,0)])
			if preload("res://city_road_rules.gd").extra_width(true, x, -1.0) > 0: routes.append([Vector3.BACK, Vector3(x - 8.5, 0, 0)])
		var z: float = -144.0+index*64.0
		var direction := preload("res://city_road_rules.gd").one_way(false, z)
		if direction >= 0: routes.append([Vector3(1,0,0),Vector3(0,0,z+4.0)])
		if direction <= 0: routes.append([Vector3(-1,0,0),Vector3(0,0,z-4.0)])
		if direction != 0: routes.append([Vector3(direction,0,0),Vector3(0,0,z-4.0*direction)])
		if preload("res://city_road_rules.gd").extra_width(false, z, 1.0) > 0: routes.append([Vector3.RIGHT, Vector3(0, 0, z + 8.5)])
	for index in range(traffic_car_count):
		var route: Array = routes[index % routes.size()]
		var model_path: String = traffic_car_models[rng.randi_range(0, traffic_car_models.size() - 1)]
		var model_name := model_path.get_file().get_basename()
		var model_factor: float = float(traffic_model_speed_factors.get(model_name, 1.0))
		var individual_factor := rng.randf_range(1.0 - traffic_individual_speed_variation, 1.0 + traffic_individual_speed_variation)
		var car := traffic_car_scene.instantiate() as RigidBody3D
		car.name = "TrafficCar_%02d" % (index + 1)
		car.set("travel_axis",route[0])
		car.set("lane_center",route[1])
		car.set("progress",rng.randf_range(-170.0,170.0))
		car.set("loop_extent",173.0)
		car.set("driving_speed",clampf(traffic_speed * model_factor * individual_factor, 2.0, 18.0))
		car.set("model_scene",load(model_path))
		$Traffic.add_child(car)

func conform_road(node: Node, center_y: float) -> void:
	if node is MeshInstance3D:
		var source: Mesh = node.mesh
		var shaped := ArrayMesh.new()
		for surface in range(source.get_surface_count()):
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in range(vertices.size()):
				var world: Vector3 = node.to_global(vertices[index])
				world.y = height_at(world.x, world.z) + 0.06 + world.y - center_y
				vertices[index] = node.to_local(world)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			shaped.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		node.mesh = shaped
	for child in node.get_children():
		conform_road(child, center_y)

func align_playable_objects() -> void:
	var level := get_parent()
	var truck := level.get_node_or_null("FoodTruck") as CharacterBody3D
	if truck:
		truck.position.y = height_at(truck.position.x, truck.position.z) + 0.2
		if not Engine.is_editor_hint():
			truck.set("spawn_transform", truck.global_transform)
	var markings := level.get_node_or_null("RoadMarkings") as Node3D
	if markings:
		markings.hide()
	var pads := level.get_node_or_null("ParkingPads")
	if pads:
		for pad in pads.get_children():
			if pad is Node3D:
				pad.position.y = height_at(pad.position.x, pad.position.z) + 1.5
				var surface := pad.get_node_or_null("ServiceSurface") as MeshInstance3D
				if surface:
					conform_pad_surface(surface)
	var spawns := level.get_node_or_null("PatronSpawns")
	if spawns:
		for marker in spawns.get_children():
			if marker is Node3D:
				marker.position.y = height_at(marker.position.x, marker.position.z) + 0.1

func conform_pad_surface(surface: MeshInstance3D) -> void:
	var size := surface.mesh.get_aabb().size
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var polygon := PackedVector2Array()
	for corner in [Vector2(-0.5,-0.5), Vector2(0.5,-0.5), Vector2(0.5,0.5), Vector2(-0.5,0.5)]:
		var point := surface.to_global(Vector3(corner.x * size.x, 0, corner.y * size.z))
		polygon.append(Vector2(point.x, point.z))
	var projector := preload("res://city_road_surface.gd")
	for triangle in projector.cell_triangles(self, projector.bounds(polygon)):
		for piece in Geometry2D.intersect_polygons(polygon, triangle):
			for index in Geometry2D.triangulate_polygon(piece):
				var point: Vector2 = piece[index]
				var local := surface.to_local(Vector3(point.x, projector.sample(self, point) + 0.145, point.y))
				tool.set_uv(Vector2(local.x / size.x + 0.5, local.z / size.z + 0.5))
				tool.add_vertex(local)
	tool.generate_normals()
	surface.mesh = tool.commit()

func make_parks() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.24, 0.50, 0.30)
	grass.roughness = 1.0
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color(0.58, 0.57, 0.52)
	path_material.roughness = 1.0
	for center in park_block_centers:
		var park := Node3D.new()
		park.name = "Park_Block_%d_%d" % [center.x, center.y]
		park.position = Vector3(center.x, 0.0, center.y)
		$Parks.add_child(park)
		add_terrain_patch(park,"ParkGrass",40.0,40.0,0.055,grass)
		add_terrain_patch(park,"ParkPath_X",40.0,1.2,0.075,path_material)
		add_terrain_patch(park,"ParkPath_Z",1.2,40.0,0.08,path_material)
		if park_tree_scene:
			for offset in [Vector2(-14,-14),Vector2(14,-14),Vector2(-14,14),Vector2(14,14)]:
				var tree := park_tree_scene.instantiate() as Node3D
				tree.name = "ParkTree"
				tree.position = Vector3(offset.x,height_at(center.x+offset.x,center.y+offset.y)+0.05,offset.y)
				park.add_child(tree)

func is_diagonal_plot(center: Vector2) -> bool:
	if not diagonal_roads_enabled:
		return false
	var half_size := 32.0 - road_width * 0.5 - sidewalk_width
	var bounds := Rect2(center - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0)
	var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for segment in diagonal_road_segments:
		var start := Vector2(segment.x, segment.y)
		var finish := Vector2(segment.z, segment.w)
		if start.distance_squared_to(finish) < 1.0:
			continue
		if bounds.has_point(start) or bounds.has_point(finish):
			return true
		for edge in 4:
			if Geometry2D.segment_intersects_segment(start, finish, corners[edge], corners[(edge + 1) % 4]) != null:
				return true
	return false

func make_diagonal_plot_grass() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.28, 0.45, 0.25)
	grass.roughness = 1.0
	var width := 64.0 - road_width - sidewalk_width * 2.0
	for x in range(-96, 97, 64):
		for z in range(-112, 145, 64):
			if not is_diagonal_plot(Vector2(x, z)) or Vector2i(x, z) in park_block_centers:
				continue
			var plot := Node3D.new()
			plot.name = "DiagonalGrassPlot_%d_%d" % [x, z]
			plot.position = Vector3(x, 0, z)
			$Parks.add_child(plot)
			# Asphalt and sidewalks sit above this patch, leaving grassy wedges.
			preload("res://city_surface_layout.gd").add_patches(self, plot, "Grass", preload("res://city_islands.gd").inner_pieces(self, Vector2(x, z)), sidewalk_height + 0.02, grass, sidewalk_width + 0.05)

func make_buildings() -> void:
	if building_model_paths.is_empty():
		return
	building_outward_faces = {}
	if FileAccess.file_exists(building_outward_manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(building_outward_manifest_path))
		if parsed is Dictionary:
			building_outward_faces = parsed
	var lots: Array[Vector2i] = []
	var lot_x: Array[int] = []
	var lot_z: Array[int] = []
	for block_x in range(-96,97,64):
		for offset_x in [-12,0,12]:
			lot_x.append(block_x+offset_x)
	for block_z in range(-112,145,64):
		for offset_z in [-12,0,12]:
			lot_z.append(block_z+offset_z)
	for z in lot_z:
		for x in lot_x:
			var lot := Vector2i(x,z)
			if abs(abs(lot.x)-20)<5 and abs(abs(lot.y)-154)<12:
				continue
			var in_park := false
			for park_center in park_block_centers:
				if abs(lot.x-park_center.x)<22 and abs(lot.y-park_center.y)<22:
					in_park = true
					break
			if not in_park:
				lots.append(lot)
	for i in range(lots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous := lots[i]
		lots[i] = lots[j]
		lots[j] = previous
	var edge_lots: Array[Vector2i] = []
	for side in [-1, 1]:
		for edge_z in [-120, -96, -56, -32, 8, 32, 72, 96, 136]:
			edge_lots.append(Vector2i(side * 151, edge_z))
	for edge_x in [-108, -84, -44, -20, 20, 44, 84, 108]:
		edge_lots.append(Vector2i(edge_x, -165))
	for i in range(edge_lots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous := edge_lots[i]
		edge_lots[i] = edge_lots[j]
		edge_lots[j] = previous
	var prioritized_lots: Array[Vector2i] = []
	for i in range(mini(edge_building_count, edge_lots.size())):
		prioritized_lots.append(edge_lots[i])
	prioritized_lots.append_array(lots)
	var diagonal_plot_counts: Dictionary = {}
	for i in range(mini(building_count, prioritized_lots.size())):
		var lot := prioritized_lots[i]
		var plot_center := Vector2i(roundi(float(lot.x - 32) / 64.0) * 64 + 32, roundi(float(lot.y - 16) / 64.0) * 64 + 16)
		var diagonal_plot := is_diagonal_plot(Vector2(plot_center))
		if diagonal_plot and int(diagonal_plot_counts.get(plot_center, 0)) >= diagonal_plot_building_limit:
			continue
		var model_path: String = building_model_paths[rng.randi_range(0, building_model_paths.size() - 1)]
		var template: PackedScene = load(model_path)
		var body := StaticBody3D.new()
		body.name = "Building_%02d" % (i + 1)
		body.position = Vector3(lot.x,0.0,lot.y)
		body.rotation.y = building_outward_rotation(model_path, lot)
		$Buildings.add_child(body)
		var model := template.instantiate() as Node3D
		model.name = "KenneyBuilding"
		body.add_child(model)
		var model_radius: float = maxf(0.1,building_footprint_radius(model,model))
		var sidewalk_outer_edge: float = road_width*0.5+sidewalk_width
		var half_block: float = 32.0
		var safe_half_width: float = minf(5.5,half_block-12.0-sidewalk_outer_edge-0.35)
		var fitted_scale: float = minf(building_scale,(safe_half_width-foundation_overhang)/model_radius)
		model.scale = Vector3.ONE*fitted_scale
		var half_width: float = model_radius*fitted_scale+foundation_overhang
		var block_center := Vector2i(roundi(float(lot.x - 32) / 64.0) * 64 + 32, roundi(float(lot.y - 16) / 64.0) * 64 + 16)
		var block_offset := lot - block_center
		var exterior := building_exterior_direction(lot)
		var perimeter_lot := block_offset.x != 0 or block_offset.y != 0
		var initial_range := foundation_terrain_range(Vector2(lot.x,lot.y),half_width)
		var axis_offset: float = absf(float(block_offset.x)) if absf(exterior.x) > 0.5 else absf(float(block_offset.y))
		var sidewalk_gap: float = 32.0 - axis_offset - half_width - sidewalk_outer_edge
		var pull := 0.0
		if perimeter_lot and initial_range.y - initial_range.x < 1.2 and rng.randf() < 0.6:
			pull = minf(building_sidewalk_pull,maxf(0.0,sidewalk_gap - 1.2))
			body.position.x += exterior.x * pull
			body.position.z += exterior.y * pull
		sidewalk_gap -= pull
		if not building_clears_street_fixtures(body.position,half_width):
			body.position.x = lot.x
			body.position.z = lot.y
			sidewalk_gap += pull
			if not building_clears_street_fixtures(body.position,half_width):
				body.free()
				continue
		var terrain_extremes := foundation_terrain_range(Vector2(body.position.x,body.position.z),half_width)
		body.position.y = terrain_extremes.y + foundation_clearance - building_ground_sink
		make_foundation(body,half_width,terrain_extremes.x)
		if perimeter_lot:
			make_foundation_stairs(body,half_width,exterior,sidewalk_gap)
		apply_kit_material(model, building_material)
		add_building_window_lights(model, model_path)
		make_camera_face_occluder(body,model)
		var collision := CollisionShape3D.new()
		collision.name = "BuildingCollision"
		var shape := BoxShape3D.new()
		shape.size = Vector3(half_width*1.7,fitted_scale*1.15,half_width*1.7)
		collision.shape = shape
		collision.position.y = shape.size.y * 0.5
		body.add_child(collision)
		if diagonal_plot:
			diagonal_plot_counts[plot_center] = int(diagonal_plot_counts.get(plot_center, 0)) + 1

func make_sparse_block_fences() -> void:
	# Keep fences in the existing cleared Buildings container on regeneration.
	if not sparse_block_fences_enabled:
		return
	var buildings := $Buildings.get_children()
	var fences := Node3D.new()
	fences.name = "SparseBlockFences"
	$Buildings.add_child(fences)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.39, 0.27, 0.17)
	wood.roughness = 0.9
	var inset := 32.0 - road_width * 0.5 - sidewalk_width - 1.5
	for bx in range(-160, 161, 64):
		for bz in range(-176, 145, 64):
			if Vector2i(bx, bz) in park_block_centers:
				continue
			var occupancy := 0
			for building in buildings:
				if absf(building.position.x - bx) < 32.0 and absf(building.position.z - bz) < 32.0:
					occupancy += 1
			if occupancy > fence_max_block_buildings:
				continue
			for side in [-1.0, 1.0]:
				for vertical in [false, true]:
					# Open corners and a central gate keep footpaths and lot access clear.
					for along in [-15.0, -9.0, 9.0, 15.0]:
						var center := Vector2(bx + side * inset, bz + along) if vertical else Vector2(bx + along, bz + side * inset)
						var half_size := Vector2(0.3, 3.0) if vertical else Vector2(3.0, 0.3)
						if not fence_segment_clear(center, half_size, buildings):
							continue
						var direction := Vector2(0, 1) if vertical else Vector2(1, 0)
						var a := center - direction * 3.0
						var b := center + direction * 3.0
						var start := Vector3(a.x, terrain_surface_height_at(a.x, a.y), a.y)
						var finish := Vector3(b.x, terrain_surface_height_at(b.x, b.y), b.y)
						for point in [start, finish]:
							add_fence_piece(fences, point + Vector3.UP * fence_height * 0.5, Vector3(0.16, fence_height, 0.16), wood)
						for fraction in [0.35, 0.8]:
							var rail := add_fence_piece(fences, (start + finish) * 0.5 + Vector3.UP * fence_height * fraction, Vector3(start.distance_to(finish), 0.12, 0.1), wood)
							var axis := (finish - start).normalized()
							var normal := axis.cross(Vector3.UP).normalized()
							rail.basis = Basis(axis, normal.cross(axis), normal)

func fence_segment_clear(center: Vector2, half_size: Vector2, buildings: Array[Node]) -> bool:
	if distance_to_diagonal_road(center) < diagonal_road_width * 0.5 + sidewalk_width + half_size.length() + 1.0:
		return false
	# Stay inside the fog wrap and off building foundations/stairs and serving pads.
	if absf(center.x) + half_size.x > wrap_edge - 3.0 or absf(center.y) + half_size.y > wrap_edge - 3.0:
		return false
	for building in buildings:
		var collision := building.get_node_or_null("BuildingCollision") as CollisionShape3D
		if not collision or not collision.shape is BoxShape3D:
			continue
		var radius: float = maxf(collision.shape.size.x, collision.shape.size.z) * 0.6 + 3.0
		if absf(center.x - building.position.x) < half_size.x + radius and absf(center.y - building.position.z) < half_size.y + radius:
			return false
	for pad in get_parent().get_node("ParkingPads").get_children():
		if Vector2(pad.position.x, pad.position.z).distance_to(center) < 14.0:
			return false
	return building_clears_street_fixtures(Vector3(center.x, 0, center.y), 3.0)

func add_fence_piece(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "FencePiece"
	body.position = center
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func building_outward_rotation(model_path: String, lot: Vector2i) -> float:
	var entry: Variant = building_outward_faces.get(model_path.get_file(), {})
	if not entry is Dictionary:
		return rng.randi_range(0, 3) * PI * 0.5
	var normal: Variant = entry.get("outward_normal", [])
	if not normal is Array or normal.size() != 3:
		return rng.randi_range(0, 3) * PI * 0.5
	var target := building_exterior_direction(lot)
	var source := Vector2(float(normal[0]), float(normal[2]))
	if source.length_squared() < 0.5:
		return rng.randi_range(0, 3) * PI * 0.5
	return atan2(target.x, target.y) - atan2(source.x, source.y)

func building_exterior_direction(lot: Vector2i) -> Vector2:
	var block_center := Vector2i(roundi(float(lot.x - 32) / 64.0) * 64 + 32, roundi(float(lot.y - 16) / 64.0) * 64 + 16)
	var offset := lot - block_center
	if absi(offset.x) >= absi(offset.y) and offset.x != 0:
		return Vector2(signf(float(offset.x)), 0.0)
	if offset.y != 0:
		return Vector2(0.0, signf(float(offset.y)))
	return Vector2(0.0, -1.0)

func building_clears_street_fixtures(position: Vector3, half_width: float) -> bool:
	if distance_to_diagonal_road(Vector2(position.x, position.z)) < diagonal_road_width * 0.5 + sidewalk_width + half_width * 1.42 + 1.0:
		return false
	var keepout := half_width + street_fixture_clearance
	for fixture in $StreetSigns.get_children():
		if fixture.name.begins_with("StreetLight") and absf(position.x - fixture.position.x) < keepout and absf(position.z - fixture.position.z) < keepout:
			return false
	for crossing in $Crosswalks.get_children():
		for signal_name in ["SouthSignal", "NorthSignal"]:
			var post_node: Node3D = crossing.get_node(signal_name)
			if absf(position.x - post_node.global_position.x) < keepout and absf(position.z - post_node.global_position.z) < keepout:
				return false
		var streetlight: Node3D = crossing.get_node_or_null("KenneyStreetLight")
		if streetlight and absf(position.x - streetlight.global_position.x) < keepout and absf(position.z - streetlight.global_position.z) < keepout:
			return false
	for approach in $HighwayApproaches.get_children():
		for footing in approach.get_children():
			if footing is StaticBody3D and footing.name.begins_with("SignFooting"):
				if absf(position.x - footing.global_position.x) < keepout and absf(position.z - footing.global_position.z) < keepout:
					return false
	return true

func building_footprint_radius(root: Node3D, node: Node) -> float:
	var radius := 0.0
	if node is MeshInstance3D and node.mesh:
		var bounds: AABB = node.mesh.get_aabb()
		for x_side in [bounds.position.x,bounds.end.x]:
			for y_side in [bounds.position.y,bounds.end.y]:
				for z_side in [bounds.position.z,bounds.end.z]:
					var point: Vector3 = root.to_local(node.to_global(Vector3(x_side,y_side,z_side)))
					radius = maxf(radius,maxf(absf(point.x),absf(point.z)))
	for child in node.get_children():
		radius = maxf(radius,building_footprint_radius(root,child))
	return radius

func make_camera_face_occluder(building: StaticBody3D, model: Node3D) -> void:
	var faces := PackedVector3Array()
	append_camera_faces(building,model,faces)
	append_camera_faces(building,building.get_node("ConcreteFoundation"),faces)
	if faces.is_empty():
		return
	var camera_body := StaticBody3D.new()
	camera_body.name = "CameraFaceOccluder"
	camera_body.collision_layer = 1 << 8
	camera_body.collision_mask = 0
	building.add_child(camera_body)
	var collider := CollisionShape3D.new()
	collider.name = "MeshFaces"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	collider.shape = shape
	camera_body.add_child(collider)

func append_camera_faces(building: Node3D, node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh:
		var mesh: Mesh = node.mesh
		for surface in range(mesh.get_surface_count()):
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for index in range(vertices.size()):
					faces.append(building.to_local(node.to_global(vertices[index])))
			else:
				for index in indices:
					faces.append(building.to_local(node.to_global(vertices[index])))
	for child in node.get_children():
		append_camera_faces(building,child,faces)

func foundation_terrain_range(center: Vector2, half_width: float) -> Vector2:
	var lowest := INF
	var highest := -INF
	var samples := maxi(4,ceili(half_width * 2.0))
	for zi in range(samples + 1):
		for xi in range(samples + 1):
			var x := center.x + (float(xi) / samples * 2.0 - 1.0) * half_width
			var z := center.y + (float(zi) / samples * 2.0 - 1.0) * half_width
			var h := height_at(x,z)
			lowest = minf(lowest,h)
			highest = maxf(highest,h)
	return Vector2(lowest,highest)

func make_foundation(body: StaticBody3D, half_width: float, lowest_ground: float) -> void:
	var top := -0.025
	var bottom := lowest_ground - body.position.y - 0.35
	var corners := [Vector2(-half_width,-half_width),Vector2(half_width,-half_width),Vector2(half_width,half_width),Vector2(-half_width,half_width)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for indices in [[0,1,2],[0,2,3]]:
		for index in indices:
			var corner: Vector2 = corners[index]
			tool.add_vertex(Vector3(corner.x,top,corner.y))
	var segments := maxi(4,ceili(half_width * 2.0))
	for edge in range(4):
		var start: Vector2 = corners[edge]
		var finish: Vector2 = corners[(edge + 1) % 4]
		for step in range(segments):
			var a := start.lerp(finish,float(step) / segments)
			var b := start.lerp(finish,float(step + 1) / segments)
			var bottom_a := bottom
			var bottom_b := bottom
			for vertex in [Vector3(a.x,top,a.y),Vector3(b.x,top,b.y),Vector3(a.x,bottom_a,a.y),Vector3(b.x,top,b.y),Vector3(b.x,bottom_b,b.y),Vector3(a.x,bottom_a,a.y)]:
				tool.add_vertex(vertex)
	tool.generate_normals()
	var mesh := tool.commit()
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.43,0.45,0.46)
	concrete.roughness = 1.0
	concrete.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,concrete)
	var visual := MeshInstance3D.new()
	visual.name = "ConcreteFoundation"
	visual.mesh = mesh
	body.add_child(visual)
	var foundation_collision := CollisionShape3D.new()
	foundation_collision.name = "FoundationCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(half_width * 2.0,maxf(0.1,top-bottom),half_width * 2.0)
	foundation_collision.shape = shape
	foundation_collision.position.y = (top+bottom)*0.5
	body.add_child(foundation_collision)

func make_foundation_stairs(body: StaticBody3D, half_width: float, exterior: Vector2, sidewalk_gap: float) -> void:
	var outward := body.global_transform.basis.inverse() * Vector3(exterior.x,0.0,exterior.y)
	outward = Vector3(roundf(outward.x),0.0,roundf(outward.z)).normalized()
	var available_run := maxf(0.0,sidewalk_gap - 0.3)
	if available_run < foundation_stair_tread * 2.0:
		return
	var front_world := body.global_position + Vector3(exterior.x,0.0,exterior.y) * (half_width + available_run)
	var ground := terrain_surface_height_at(front_world.x,front_world.z)
	var drop := body.position.y - ground
	if drop < 0.45:
		return
	var count := mini(ceili(drop / 0.24),floori(available_run / foundation_stair_tread))
	count = maxi(2,count)
	var tread := minf(foundation_stair_tread,available_run / count)
	var concrete: Material = body.get_node("ConcreteFoundation").mesh.surface_get_material(0)
	var tapered := rng.randf() < 0.5
	if tapered:
		make_stair_retaining_slopes(body,half_width,outward,count*tread,drop,concrete)
	for step_index in range(count):
		var distance := half_width + (float(step_index) + 0.5) * tread
		var local_center := outward * distance
		var world_center := body.global_transform * local_center
		var bottom := terrain_surface_height_at(world_center.x,world_center.z) - body.position.y - 0.2
		var top := -(float(step_index) + 1.0) * drop / count
		if top <= bottom + 0.08:
			continue
		var width := 2.2 + (0.2 * step_index if tapered else 0.0)
		var size := Vector3(tread,top-bottom,width) if absf(outward.x) > 0.5 else Vector3(width,top-bottom,tread)
		var center := local_center + Vector3(0.0,(top+bottom)*0.5,0.0)
		var step_mesh := MeshInstance3D.new()
		step_mesh.name = "FoundationStair_%d" % (step_index + 1)
		var mesh := BoxMesh.new()
		mesh.size = size
		step_mesh.mesh = mesh
		step_mesh.material_override = concrete
		step_mesh.position = center
		body.add_child(step_mesh)
		var step_collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		step_collision.shape = shape
		step_collision.position = center
		body.add_child(step_collision)

func make_stair_retaining_slopes(body: StaticBody3D, half_width: float, outward: Vector3, run: float, drop: float, concrete: Material) -> void:
	var sideways := Vector3(-outward.z,0.0,outward.x)
	for side in [-1.0,1.0]:
		var center_offset: Vector3 = sideways * float(side) * 1.35
		var a: Vector3 = outward * half_width + center_offset + Vector3.UP * -0.025
		var b: Vector3 = outward * half_width + center_offset + Vector3.UP * (-drop - 0.15)
		var c: Vector3 = outward * (half_width + run) + center_offset + Vector3.UP * (-drop - 0.15)
		var thickness := sideways * 0.2
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for triangle in [[a,b,c],[a+thickness,c+thickness,b+thickness],[a,a+thickness,b+thickness],[a,b+thickness,b],[a,c,c+thickness],[a,c+thickness,a+thickness]]:
			for vertex in triangle:
				tool.add_vertex(vertex)
		tool.generate_normals()
		var mesh := tool.commit()
		mesh.surface_set_material(0,concrete)
		var cheek := MeshInstance3D.new()
		cheek.name = "TaperedStairFoundation"
		cheek.mesh = mesh
		body.add_child(cheek)
