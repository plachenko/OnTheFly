extends Node

const PROFILE_SCRIPT = preload("res://truck_handling_profile.gd")
const PATH := "user://handling/profiles.json"
# key: [label, minimum, maximum, step, original default]
const FIELDS := {
	"forward_speed": ["Top speed (m/s)",8,40,.5,23],
	"reverse_speed": ["Reverse speed (m/s)",2,15,.5,7],
	"acceleration": ["Acceleration",2,30,.5,12],
	"braking_force": ["Braking force",5,45,.5,22],
	"rolling_drag": ["Rolling drag",.1,6,.1,2.3],
	"steering_low_speed": ["Low-speed steering",.1,.8,.01,.48],
	"steering_high_speed": ["High-speed steering",.05,.5,.01,.23],
	"steering_response": ["Steering response",.5,8,.1,2.5],
	"traction_response": ["Normal grip",2,30,.5,18],
	"drift_traction_response": ["Powered drift grip",.2,12,.1,3.5],
	"drift_turn_multiplier": ["Powered drift turning",1,3,.05,1.65],
	"stationary_drift_turn_speed": ["Donut turning",.5,5,.1,2.5],
	"power_slide_min_speed": ["Slide entry speed (m/s)",1,15,.5,3.5],
	"power_slide_duration": ["Slide duration (s)",.2,3,.05,1.2],
	"power_slide_steering": ["Slide steering",.1,.9,.01,.58],
	"power_slide_turn_multiplier": ["Slide turning force",1,6,.1,4.5],
	"power_slide_traction_response": ["Slide grip",.1,8,.05,.65],
	"power_slide_brake_grip": ["Slide braking grip",.1,1,.01,.32],
	"power_slide_enter_response": ["Slide onset",1,10,.25,5],
	"power_slide_recovery_response": ["Grip recovery",.5,10,.25,2.5],
	"vehicle_mass": ["Mass (kg)",1200,6000,50,2400],
	"center_of_mass_height": ["Centre of mass (m)",.5,2.5,.05,1.45],
	"spring_stiffness": ["Spring stiffness",15000,80000,1000,42000],
	"spring_damping": ["Suspension damping",1000,10000,100,4600],
	"rear_suspension_firmness": ["Rear suspension firmness",.4,1,.05,.78],
	"body_yaw_lag": ["Rear body sway",0,.08,.005,.028],
	"donut_drift_speed": ["Donut drift",0,2,.05,.65],
	"sprite_animation_strength": ["Sprite exaggeration",0,1,.05,1],
	"sprite_animation_time_scale": ["Sprite animation pace",.5,2,.05,1],
	"sprite_lean_delay": ["Kitchen lean delay (s)",.01,.4,.01,.16],
	"sprite_transition_seconds": ["Visual blend time (s)",.08,.6,.01,.22]
}
var profiles: Dictionary = {}
var defaults: Dictionary = {}

func _ready() -> void:
	load_store()

func original() -> Dictionary:
	var result := {}
	for key in FIELDS: result[key] = float(FIELDS[key][4])
	return result

func gentle() -> Dictionary:
	var result := original()
	result.merge({"power_slide_turn_multiplier":2.2,"power_slide_steering":.44,"power_slide_traction_response":1.6,"power_slide_enter_response":3.0,"power_slide_recovery_response":4.0},true)
	return result

func validated(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values:
		if not FIELDS.has(key) or typeof(values[key]) not in [TYPE_INT,TYPE_FLOAT]: continue
		var number := float(values[key])
		if is_finite(number): result[key] = clampf(number,float(FIELDS[key][1]),float(FIELDS[key][2]))
	return result

func snapshot(truck: Node) -> Dictionary:
	var result := {}
	for key in FIELDS: result[key] = float(truck.get(key))
	return result

func apply(truck: Node, values: Dictionary) -> void:
	var safe := validated(values)
	for key in safe: truck.set(key,safe[key])

func apply_startup(truck: Node) -> void:
	if truck.handling_profile != null and truck.handling_profile.get_script() == PROFILE_SCRIPT: apply(truck,truck.handling_profile.values)
	# Local preferences must not diverge between multiplayer peers.
	if not NetworkSession.active and truck.use_saved_handling_default:
		var item_name: String = str(defaults.get(truck.handling_id,""))
		if profiles.has(item_name): apply(truck,profiles[item_name])

func load_store(path: String = PATH) -> void:
	profiles.clear()
	defaults.clear()
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1: return
	if data.get("profiles") is Dictionary:
		for item_name in data.profiles:
			if data.profiles[item_name] is Dictionary: profiles[str(item_name)] = validated(data.profiles[item_name])
	if data.get("defaults") is Dictionary:
		for id in data.defaults:
			if profiles.has(str(data.defaults[id])): defaults[str(id)] = str(data.defaults[id])

func persist(path: String = PATH) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK: return error
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version":1,"profiles":profiles,"defaults":defaults},"\t"))
	error = file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)

func save_profile(item_name: String, values: Dictionary, path: String = PATH) -> Error:
	item_name = item_name.strip_edges()
	if item_name.is_empty() or item_name.length()>64: return ERR_INVALID_PARAMETER
	var old := profiles.duplicate(true)
	profiles[item_name] = validated(values)
	var error := persist(path)
	if error != OK: profiles = old
	return error

func set_default(id: String, item_name: String, path: String = PATH) -> Error:
	if id.strip_edges().is_empty() or not profiles.has(item_name): return ERR_INVALID_PARAMETER
	var old := defaults.duplicate(true)
	defaults[id] = item_name
	var error := persist(path)
	if error != OK: defaults = old
	return error
