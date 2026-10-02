extends Node

var level: Node
var wave := 0
var remaining := 0.0
var in_service := true
var initialized := false
var rotation: Array = []
var used: Dictionary = {}
var competitive_waves := 0

func start_wave() -> void:
	wave += 1
	in_service = true
	remaining = maxf(0.1, level.service_window_seconds)
	for pad in level.get_node("ParkingPads").get_children():
		if not pad.serving_enabled: continue
		pad.wave_managed = true
		pad.expired = not rotation.has(pad)
		pad.service_started = rotation.has(pad)
		pad.service_remaining = remaining if rotation.has(pad) else 0.0
		pad.fee_elapsed = 0.0
		pad.charged_initial_fee = false
		pad.refresh_service_sign()

func tick(delta: float) -> void:
	if level.loading_intro_active or not level.is_loading_ready(): return
	if not initialized:
		for pad in level.get_node("ParkingPads").get_children():
			if pad.serving_enabled: rotation.append(pad)
		initialized = true
		start_wave()
	remaining = maxf(0.0, remaining - delta)
	for pad in rotation:
		pad.service_remaining = remaining if in_service else 0.0
		pad.serving_duration = maxf(0.1, level.service_window_seconds)
		pad.expired = not in_service
		pad.refresh_service_sign()
	if remaining > 0.0: return
	if in_service:
		in_service = false
		remaining = maxf(0.1, level.service_pause_seconds)
		for pad in rotation:
			pad.expired = true
			pad.refresh_service_sign()
	else:
		var floor_count := maxi(1, level.service_player_count() - 1)
		if rotation.size() > floor_count:
			# Retire at most one used bay per wave so the map dwindles gradually.
			for pad in rotation.duplicate():
				if used.has(pad):
					rotation.erase(pad)
					break
		else:
			competitive_waves += 1
			if competitive_waves > level.service_final_hold_waves and rotation.size() > 1:
				rotation.pop_back()
		used.clear()
		start_wave()

func mark_used(pad: Node) -> void:
	if in_service and rotation.has(pad): used[pad] = true

func text() -> String:
	return "WAVE %d • %ds • %d service bays" % [wave, ceili(remaining), rotation.size()] if in_service else "RESTOCK / REPAIR • Next wave in %ds" % ceili(remaining)
