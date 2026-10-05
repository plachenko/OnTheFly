extends Node3D

static var metadata: Dictionary = {}
var materials: Dictionary = {}
var timer := 0.0
var requests: Dictionary = {}

func _ready() -> void:
	if metadata.is_empty(): metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/car_impostors/metadata.json"))

func _process(delta: float) -> void:
	timer -= delta
	if timer > 0: return
	timer = .25
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var players := get_tree().get_nodes_in_group("food_trucks")
	if players.is_empty():
		var truck := get_parent().get_parent().get_parent().get_parent().get_node_or_null("FoodTruck")
		if truck != null: players.append(truck)
	var used: Dictionary = {}
	for car in get_children():
		if not car is StaticBody3D: continue
		var distance: float = car.global_position.distance_to(camera.global_position)
		var immediate := false
		for player in players:
			if car.global_position.distance_to(player.global_position) < 24: immediate = true; break
		var in_view := camera.is_position_in_frustum(car.global_position+Vector3.UP)
		if not immediate and (distance > 95 or not in_view): car.release_sprite(); continue
		if not immediate and distance > 64 and car.card == null: continue
		var key: String = car.model_key
		used[key] = true
		if not materials.has(key):
			var entry: Dictionary = metadata.models["res://assets/kenney_city/cars_rigged/%s.glb" % key]
			var textures_ready := true
			for path in [entry.atlas,entry.normals]:
				var status := ResourceLoader.load_threaded_get_status(path)
				if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					ResourceLoader.load_threaded_request(path,"Texture2D")
					requests[path] = true
					textures_ready = false
				elif status != ResourceLoader.THREAD_LOAD_LOADED: textures_ready = false
			if not textures_ready: continue
			var material := ShaderMaterial.new(); material.shader = preload("res://car_impostor.gdshader")
			material.set_shader_parameter("atlas",ResourceLoader.load_threaded_get(entry.atlas))
			material.set_shader_parameter("normal_atlas",ResourceLoader.load_threaded_get(entry.normals))
			materials[key] = material
		car.set_sprite(materials[key],metadata.models["res://assets/kenney_city/cars_rigged/%s.glb" % key])
	# Consume completed background requests even if the player has already left.
	for path in requests.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
			requests.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED: requests.erase(path)
	for key in materials.keys():
		if not used.has(key): materials.erase(key)
