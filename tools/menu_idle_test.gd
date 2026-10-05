extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var profile: Dictionary = load("res://menu_stage.gd").idle_profile()
	var player := preload("res://truck_exaggeration.gd")
	assert(not player.validated(profile).is_empty())
	assert(profile.clips.idle.duration == 4.8)
	var stutter := player.sample(profile, "idle", .08)
	assert(absf(stutter.heave) > .005 and absf(stutter.heave) < .035)
	assert(absf(stutter.roll) < .25)
	var stage = load("res://menu_stage.gd")
	var pulse: Dictionary = stage.idle_pose(.06)
	var rebound: Dictionary = stage.idle_pose(.15)
	assert(pulse.heave > .015 and rebound.heave < -.005)
	assert(absf(rebound.heave) < pulse.heave)
	var front_motion: float = pulse.heave + tan(deg_to_rad(pulse.pitch)) * 2.5
	var rear_motion: float = pulse.heave - tan(deg_to_rad(pulse.pitch)) * 2.5
	assert(front_motion > rear_motion * 1.5 and rear_motion > 0.0)
	var reinforces := false
	var counters := false
	var smallest_front := INF
	var largest_front := 0.0
	for index in 20:
		var pose: Dictionary = stage.idle_pose(.06 + index * .24)
		var front: float = pose.heave + tan(deg_to_rad(pose.pitch)) * 2.5
		var rear: float = pose.heave - tan(deg_to_rad(pose.pitch)) * 2.5
		reinforces = reinforces or front * rear > 0
		counters = counters or front * rear < 0
		smallest_front = minf(smallest_front, absf(front))
		largest_front = maxf(largest_front, absf(front))
	assert(reinforces and counters)
	assert(largest_front > smallest_front * 1.8, "Jitter intensity must rise and fall")
	for key in profile.clips.idle.keys:
		assert(absf(key.pitch) < .9 and absf(key.heave) < .04 and is_zero_approx(key.yaw))
		assert(key.label == "Engine stutter")
	var start := player.sample(profile, "idle", 0)
	var end := player.sample(profile, "idle", 4.8)
	for channel in player.CHANNELS: assert(absf(start[channel] - end[channel]) < .0001)
	print("MENU IDLE PASS: jitter rises and falls in waves, softer rear reinforces and counters front, seamless loop without backfire")
	quit()
