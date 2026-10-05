extends RefCounted

static func idle_pose(time: float) -> Dictionary:
	var phase := fposmod(time, .24) / .24
	# Quick pulse, a smaller opposite rebound, then a gentle return to rest.
	var engine: float
	if phase < .25:
		engine = lerpf(0.0, 1.0, smoothstep(0.0, .25, phase))
	elif phase < .625:
		engine = lerpf(1.0, -.4, smoothstep(.25, .625, phase))
	else:
		engine = lerpf(-.4, 0.0, smoothstep(.625, 1.0, phase))
	# Engine roughness rises and falls; the softer rear alternates between
	# reinforcing the cab's pulse and moving against it.
	var wave := time * TAU / 4.8
	var roughness := .70 + .25 * sin(wave) + .05 * sin(wave * 2.0)
	var front_shake := engine * .055 * roughness
	var rear_shake := engine * .018 * cos(wave)
	return {"pitch": rad_to_deg(atan2(front_shake - rear_shake, 5.0)), "roll": engine * .10,
		"yaw": 0.0, "heave": (front_shake + rear_shake) * .5}

static func idle_profile() -> Dictionary:
	var keys := []
	for index in 121:
		var time := index * .04
		var pose := idle_pose(time)
		pose.time = time
		pose.label = "Engine stutter"
		keys.append(pose)
	return {"version": 1, "truck_id": "menu", "strength": 1.0, "clips": {
		"idle": {"duration": 4.8, "loop": true, "keys": keys}}}
