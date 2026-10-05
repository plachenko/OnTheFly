extends Node3D

const META := "res://assets/truck_billboards/metadata.json"
static var metadata: Dictionary = {}
static var shared: Dictionary = {}
static var references: Dictionary = {}
static var pending: Dictionary = {}
var truck: CharacterBody3D
var card: MeshInstance3D
var material: ShaderMaterial
var fade_materials: Array[ShaderMaterial] = []
var surface_records: Array[Dictionary] = []
var using_fade := false
var force_3d := false
var sprite_visibility := 0.0
var state := "idle"
var loaded_state := ""
var previous_state := ""
var requested := ""
var phase := 0.0
var previous_phase := 0.0
var elapsed := 0.0
var mix_time := 0.0
var last_speed := 0.0
var lean := 0.0
var stopping := false
var center := Vector3.ZERO

func _ready() -> void:
	truck = get_parent()
	if not FileAccess.file_exists(META): set_process(false); return
	if metadata.is_empty(): metadata = JSON.parse_string(FileAccess.get_file_as_string(META))
	center = Vector3(metadata.center[0],metadata.center[1],metadata.center[2])
	material = ShaderMaterial.new(); material.shader = preload("res://truck_billboard.gdshader")
	card = MeshInstance3D.new(); card.name = "DrivingTruckBillboard"
	var quad := QuadMesh.new(); quad.size = Vector2(metadata.world_height*4.0/3.0,metadata.world_height)
	card.mesh = quad; card.material_override = material
	card.custom_aabb = AABB(Vector3.ONE*-8,Vector3.ONE*16)
	add_child(card); card.hide()
	# Preserve cutaway shaders; all other materials gain complementary dither fading.
	for mesh in truck.model.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "ComicSilhouette": continue
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			var fade: ShaderMaterial
			if original is ShaderMaterial and original.shader == preload("res://kitchen_cutaway.gdshader"):
				fade = original
			elif original is StandardMaterial3D:
				fade = ShaderMaterial.new(); fade.shader = preload("res://truck_visual_fade.gdshader")
				fade.set_shader_parameter("tint",original.albedo_color)
				fade.set_shader_parameter("textured",original.albedo_texture != null)
				fade.set_shader_parameter("paint",original.albedo_texture)
				fade.set_shader_parameter("vertex_color",original.vertex_color_use_as_albedo)
				fade.set_shader_parameter("metallic_value",original.metallic)
				fade.set_shader_parameter("roughness_value",original.roughness)
				fade.set_shader_parameter("emission_color",original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK)
			if fade != null:
				fade_materials.append(fade)
				surface_records.append({"mesh":mesh,"surface":surface,"original":mesh.get_surface_override_material(surface),"fade":fade})

static func retain(item_name: String) -> void:
	references[item_name] = references.get(item_name,0)+1
	if shared.has(item_name) or pending.has(item_name): return
	var entry: Dictionary = metadata.states[item_name]
	for path in [entry.atlas,entry.normals]: ResourceLoader.load_threaded_request(path,"Texture2D")
	pending[item_name] = true

static func obtain(item_name: String) -> bool:
	if shared.has(item_name): return true
	if not pending.has(item_name): return false
	var entry: Dictionary = metadata.states[item_name]
	for path in [entry.atlas,entry.normals]:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED: return false
	var images: Array = []
	for path in [entry.atlas,entry.normals]: images.append(ResourceLoader.load_threaded_get(path))
	pending.erase(item_name)
	if references.get(item_name,0) > 0: shared[item_name] = images
	return shared.has(item_name)

static func release(item_name: String) -> void:
	if item_name.is_empty(): return
	references[item_name] = maxi(0,references.get(item_name,0)-1)
	if references[item_name] == 0: shared.erase(item_name); references.erase(item_name)

func select_state(delta: float) -> String:
	lean = lerpf(lean,truck.lateral_accel,1.0-exp(-delta/maxf(.01,truck.sprite_lean_delay)))
	if absf(last_speed) > .6 and absf(truck.speed) < .4: stopping = true
	last_speed = truck.speed
	if truck.stationary_drifting or (truck.drift_blend > .6 and absf(truck.measured_yaw_rate) > .8): stopping=false; return "donut"
	if truck.tire_brake > .1 and absf(truck.speed) > .5: stopping=false; return "brake"
	if stopping:
		if state == "stop" and elapsed > metadata.states.stop.duration/truck.sprite_animation_time_scale: stopping=false
		else: return "stop"
	var acceleration: float = truck.longitudinal_accel*signf(truck.speed)
	if acceleration < -2 and absf(truck.speed) > .6: return "brake"
	if acceleration > 2 and absf(truck.speed) > .2: return "accelerate"
	if absf(lean) > 1.2 and absf(truck.speed) > .5: return "lean_left" if lean < 0 else "lean_right"
	return "drive" if absf(truck.speed) > .4 else "idle"

func wants_sprite() -> bool:
	if force_3d or truck.deployed or truck.opening > .001: return false
	var scene := truck.get_parent()
	if scene.get("loading_intro_active") == true or scene.get("free_camera_look") == true: return false
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.name == "MenuCamera": return false
	var view := camera.global_position-truck.global_position
	return absf(rad_to_deg(atan2(view.y,Vector2(view.x,view.z).length()))) < 62

func _process(delta: float) -> void:
	# No ray casts or shape queries: terrain attitude and motion already exist.
	basis = Basis(truck.model.quaternion*truck.model_rest_rotation.inverse())
	var contact_height: float = (truck.road_height[0]+truck.road_height[1]+truck.road_height[2]+truck.road_height[3])*.25
	position = basis*(center+Vector3.UP*contact_height)
	var desired := select_state(delta)
	if desired == state and not requested.is_empty(): release(requested); requested = ""
	if wants_sprite() and requested != desired and desired != state:
		release(requested); requested = desired; retain(requested)
	if requested.is_empty() and loaded_state.is_empty() and wants_sprite(): requested = state; retain(requested)
	if not requested.is_empty() and obtain(requested):
		release(previous_state); previous_state = loaded_state if not loaded_state.is_empty() else requested
		previous_phase = phase
		if previous_state == requested: retain(previous_state)
		state = requested; loaded_state = requested; requested = ""; elapsed = 0; mix_time = 0
		material.set_shader_parameter("atlas",shared[state][0]); material.set_shader_parameter("normals",shared[state][1])
		material.set_shader_parameter("previous_atlas",shared[previous_state][0]); material.set_shader_parameter("previous_normals",shared[previous_state][1])
	elapsed += delta; mix_time += delta
	var duration: float = metadata.states[state].duration/maxf(.1,truck.sprite_animation_time_scale)
	phase = fmod(elapsed/duration,1.0)*8.0 if metadata.states[state].loop else minf(elapsed/duration,1.0)*7.0
	if state.begins_with("lean_"): phase = clampf(absf(lean)/8.0,0,.5)*7.0
	var blend := clampf(mix_time/maxf(.01,truck.sprite_transition_seconds),0,1)
	if blend >= 1 and not previous_state.is_empty():
		material.set_shader_parameter("previous_atlas",shared[state][0]); material.set_shader_parameter("previous_normals",shared[state][1]); release(previous_state); previous_state = ""
	var target := 1.0 if wants_sprite() and not loaded_state.is_empty() else 0.0
	sprite_visibility = move_toward(sprite_visibility,target,delta/maxf(.01,truck.sprite_transition_seconds))
	material.set_shader_parameter("frame",phase); material.set_shader_parameter("previous_frame",previous_phase)
	material.set_shader_parameter("state_mix",blend); material.set_shader_parameter("visibility",sprite_visibility)
	material.set_shader_parameter("animation_strength",truck.sprite_animation_strength)
	var fade_active := sprite_visibility > .001
	if using_fade != fade_active:
		using_fade = fade_active
		for entry in surface_records: entry.mesh.set_surface_override_material(entry.surface,entry.fade if using_fade else entry.original)
	for fade in fade_materials: fade.set_shader_parameter("sprite_visibility",sprite_visibility)
	truck.model.visible = sprite_visibility < .999
	card.visible = sprite_visibility > .001
	if target == 0.0 and sprite_visibility <= .001:
		release(requested); requested = ""
		release(previous_state); previous_state = ""
		release(loaded_state); loaded_state = ""
		for key in ["atlas","normals","previous_atlas","previous_normals"]: material.set_shader_parameter(key,null)
	# Drain finished requests even if a cinematic superseded the driving state.
	for item_name in pending.keys():
		if references.get(item_name,0) == 0: obtain(item_name)

func _exit_tree() -> void:
	release(requested); release(previous_state); release(loaded_state)
