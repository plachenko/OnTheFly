extends RefCounted

const STATES := ["accelerate","brake","turn_left","turn_right","donut","stop","idle"]
const CHANNELS := ["pitch","roll","yaw","heave"]
var profile: Dictionary = {}
var state := "idle"
var age := 0.0
var previous_speed := 0.0
var preview := false
var preview_state := "brake"
var preview_time := 0.0
var enabled := true
var current_pose := {"pitch":0.0,"roll":0.0,"yaw":0.0,"heave":0.0}

static func default_path(truck_id: String) -> String:
	return "user://truck_exaggeration/%s.json" % truck_id.validate_filename()

static func template(truck_id: String = "food_truck") -> Dictionary:
	var clips := {}
	for name in STATES:
		var peak := {"pitch":0.0,"roll":0.0,"yaw":0.0,"heave":0.0}
		match name:
			"accelerate": peak.pitch = -6.0; peak.heave = -.06
			"brake": peak.pitch = 9.0; peak.heave = -.08
			"turn_left": peak.roll = -7.0; peak.yaw = 2.0
			"turn_right": peak.roll = 7.0; peak.yaw = -2.0
			"donut": peak.roll = 8.0; peak.yaw = 4.0; peak.heave = .06
			"stop": peak.pitch = 4.0; peak.heave = -.04
			"idle": peak.heave = .015
		var frames := []
		for spec in [[0.0,0.0,"Rest"],[.12,-.20,"Anticipation"],[.34,1.0,"Peak"],[.62,-.45,"Rebound"],[1.0,0.0,"Settle"]]:
			var frame := {"time":spec[0],"label":spec[2]}
			for channel in CHANNELS: frame[channel] = peak[channel]*spec[1]
			frames.append(frame)
		clips[name] = {"duration":1.0,"loop":name in ["idle","donut","turn_left","turn_right"],"keys":frames}
	clips.idle = preload("res://truck_idle_motion.gd").idle_profile().clips.idle
	return {"version":1,"truck_id":truck_id,"name":"Expressive truck","strength":1.0,"clips":clips}

static func validated(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") != 1 or not data.get("clips") is Dictionary: return {}
	var strength: Variant = data.get("strength",1.0)
	if not strength is float and not strength is int: return {}
	if not is_finite(float(strength)): return {}
	var result := {"version":1,"truck_id":str(data.get("truck_id","food_truck")),"name":str(data.get("name","Truck exaggeration")),"strength":clampf(float(strength),0,2),"clips":{}}
	for name in STATES:
		var raw: Variant = data.clips.get(name)
		if not raw is Dictionary or not raw.get("keys") is Array: continue
		var duration: Variant = raw.get("duration",1.0)
		if typeof(duration) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(duration)): continue
		var clip := {"duration":clampf(float(duration),.1,5.0),"loop":raw.get("loop",false)==true,"keys":[]}
		for key in raw.keys.slice(0,128):
			if not key is Dictionary: continue
			var safe := {"label":str(key.get("label","Pose")).substr(0,32)}
			var good := true
			for channel in ["time"]+CHANNELS:
				var number: Variant = key.get(channel,0.0)
				if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)):
					good = false
					break
				var limit := .75 if channel == "heave" else 30.0
				safe[channel] = clampf(float(number),0.0,clip.duration) if channel == "time" else clampf(float(number),-limit,limit)
			if good: clip.keys.append(safe)
		clip.keys.sort_custom(func(a,b): return a.time < b.time)
		var unique := []
		for key in clip.keys:
			if not unique.is_empty() and absf(unique[-1].time-key.time) < .0001: unique[-1] = key
			else: unique.append(key)
		clip.keys = unique
		if clip.keys.size() >= 2: result.clips[name] = clip
	return {} if result.clips.is_empty() else result

static func sample(data: Dictionary, name: String, time: float) -> Dictionary:
	var pose := {"pitch":0.0,"roll":0.0,"yaw":0.0,"heave":0.0}
	if not data.get("clips",{}).has(name): return pose
	var clip: Dictionary = data.clips[name]
	var keys: Array = clip.keys
	var at := clampf(time,0,clip.duration)
	var a: Dictionary = keys.front()
	var b: Dictionary = keys.back()
	if at <= a.time: b = a
	elif at >= b.time: a = b
	else:
		for i in range(keys.size()-1):
			if at >= keys[i].time and at <= keys[i+1].time:
				a = keys[i]; b = keys[i+1]; break
	var t := smoothstep(a.time,b.time,at) if b.time > a.time else 0.0
	for channel in CHANNELS: pose[channel] = lerpf(a[channel],b[channel],t)*float(data.get("strength",1.0))
	return pose

func reset_motion() -> void:
	age = 0.0
	previous_speed = 0.0
	state = "idle"
	for channel in CHANNELS: current_pose[channel] = 0.0

func load_profile(path: String) -> Error:
	if not FileAccess.file_exists(path): return ERR_FILE_NOT_FOUND
	var safe := validated(JSON.parse_string(FileAccess.get_file_as_string(path)))
	if safe.is_empty(): return ERR_FILE_CORRUPT
	profile = safe
	reset_motion()
	return OK

static func save_profile(path: String, data: Dictionary) -> Error:
	var safe := validated(data)
	if safe.is_empty(): return ERR_INVALID_DATA
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK: return error
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(safe,"\t")+"\n")
	error = file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)

func step(truck: Node, delta: float) -> Dictionary:
	if not enabled or profile.is_empty():
		for channel in CHANNELS: current_pose[channel] = 0.0
		return current_pose
	if preview:
		current_pose = sample(profile,preview_state,preview_time)
		return current_pose
	var speed: float = absf(truck.speed)
	var wanted := ""
	if truck.stationary_drifting or truck.drift_blend > .6: wanted = "donut"
	elif truck.tire_brake > .3 and speed > 1.0: wanted = "brake"
	elif previous_speed > .6 and speed <= .6: wanted = "stop"
	elif absf(truck.lateral_accel) > 1.5: wanted = "turn_left" if truck.lateral_accel < 0 else "turn_right"
	elif truck.longitudinal_accel*signf(truck.speed) > 2.0: wanted = "accelerate"
	elif speed < .4: wanted = "idle"
	previous_speed = speed
	var clip: Dictionary = profile.clips.get(state,{})
	if not wanted.is_empty() and wanted != state and (age >= clip.get("duration",0.0) or wanted in ["brake","donut","stop"] or state == "idle"):
		state = wanted
		age = 0.0
	age += delta
	clip = profile.clips.get(state,{})
	var target := {"pitch":0.0,"roll":0.0,"yaw":0.0,"heave":0.0}
	if not clip.is_empty():
		if clip.loop and wanted == state: age = fposmod(age,clip.duration)
		if age <= clip.duration: target = sample(profile,state,age)
	if state == "idle":
		var idle_weight := 1.0 - smoothstep(.2, 1.2, speed)
		if truck.get("health") != null and truck.health <= 0: idle_weight = 0.0
		if truck.get("round_over") == true: idle_weight = 0.0
		for channel in CHANNELS: target[channel] *= idle_weight
	for channel in CHANNELS: current_pose[channel] = lerpf(current_pose[channel],target[channel],1.0-exp(-delta*18.0))
	return current_pose

func apply(truck: Node, delta: float) -> void:
	var pose := step(truck,delta)
	var skeleton: Skeleton3D = truck.skeleton
	var chassis: int = truck.chassis
	var base := skeleton.get_bone_pose_rotation(chassis)
	# The imported rig uses Z for height, Y for pitch and X for roll.
	var offset := Quaternion(Vector3.BACK,deg_to_rad(pose.yaw))*Quaternion(Vector3.RIGHT,deg_to_rad(pose.roll))*Quaternion(Vector3.UP,deg_to_rad(pose.pitch))
	skeleton.set_bone_pose_rotation(chassis,base*offset)
	skeleton.set_bone_pose_position(chassis,skeleton.get_bone_pose_position(chassis)+Vector3(0,0,pose.heave))
