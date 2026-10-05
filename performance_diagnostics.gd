extends Node

var traffic_lod_enabled := true
var pedestrian_logic_enabled := true:
	set(value):
		if pedestrian_logic_enabled == value: return
		pedestrian_logic_enabled = value
		for patron in get_tree().get_nodes_in_group("patrons"):
			apply_pedestrian_logic(patron)
var pedestrian_process_modes: Dictionary = {}

func apply_pedestrian_logic(patron: Node) -> void:
	var id := patron.get_instance_id()
	if not pedestrian_logic_enabled:
		if not pedestrian_process_modes.has(id): pedestrian_process_modes[id] = {"node": weakref(patron), "mode": patron.process_mode}
		patron.process_mode = Node.PROCESS_MODE_DISABLED
	elif pedestrian_process_modes.has(id):
		patron.process_mode = pedestrian_process_modes[id].mode
		pedestrian_process_modes.erase(id)
	for key in pedestrian_process_modes.keys():
		if pedestrian_process_modes[key].node.get_ref() == null: pedestrian_process_modes.erase(key)

signal traffic_enabled_changed
signal traffic_logic_changed
var traffic_logic_enabled := true:
	set(value):
		if traffic_logic_enabled == value: return
		traffic_logic_enabled = value
		traffic_logic_changed.emit()
var traffic_enabled := true:
	set(value):
		if traffic_enabled == value: return
		traffic_enabled = value
		traffic_enabled_changed.emit()
signal rendering_lod_changed
var buildings_as_blocks := false:
	set(value):
		if buildings_as_blocks == value: return
		buildings_as_blocks = value
		rendering_lod_changed.emit()
var rendering_lod_enabled := true:
	set(value):
		if rendering_lod_enabled == value: return
		rendering_lod_enabled = value
		rendering_lod_changed.emit()
var optimized_snapshots := true
var frame_ms: Array[float] = []
var sections: Dictionary = {}
var latest_sections: Dictionary = {}
var snapshot_bytes := 0
var snapshot_parts := 0
var stage := ""
var capture: FileAccess
var capture_remaining := 0.0
var capture_path := ""
var last_tick := 0
var traffic_active := 0
var traffic_distant := 0
var section_peaks: Dictionary = {}
var displayed_peaks: Dictionary = {}
var section_window := 1.0
var fps_label: Label
var recent_samples: Array[Dictionary] = []
var recent_physics_samples: Array[Dictionary] = []
var physics_sections: Dictionary = {}
var physics_section_calls: Dictionary = {}
var recorded_physics_tick := -1
var last_physics_sample_us := 0
var video_samples: Array[Dictionary] = []
var video_tracking := false
var render_filters: Node
var profile_shortcut: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	process_physics_priority = 10000
	last_tick = Time.get_ticks_usec()
	render_filters = preload("res://debug_render_filters.gd").new()
	add_child(render_filters)
	profile_shortcut = preload("res://profile_shortcut.gd").new()
	add_child(profile_shortcut)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	fps_label = Label.new()
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_font_size_override("font_size", 18)
	fps_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	fps_label.add_theme_constant_override("shadow_offset_x", 1)
	fps_label.add_theme_constant_override("shadow_offset_y", 1)
	overlay.add_child(fps_label)

func record_section(label: String, microseconds: int) -> void:
	sections[label] = sections.get(label, 0.0) + microseconds / 1000.0
	if profile_shortcut != null and profile_shortcut.enabled and Engine.is_in_physics_frame():
		var tick := Engine.get_physics_frames()
		if recorded_physics_tick != tick:
			physics_sections.clear()
			physics_section_calls.clear()
			recorded_physics_tick = tick
		physics_sections[label] = physics_sections.get(label, 0.0) + microseconds / 1000.0
		physics_section_calls[label] = physics_section_calls.get(label, 0) + 1

func _physics_process(delta: float) -> void:
	# Run after gameplay callbacks. These are instrumented section costs, not solver time.
	if profile_shortcut == null or not profile_shortcut.enabled:
		recent_physics_samples.clear()
		last_physics_sample_us = 0
		return
	var now := Time.get_ticks_usec()
	var tick := Engine.get_physics_frames()
	var sample := {"time_us": now, "physics_tick": tick, "process_frame": Engine.get_process_frames(), "step_ms": delta * 1000.0, "tick_interval_ms": (now - last_physics_sample_us) / 1000.0 if last_physics_sample_us > 0 else 0.0, "sections_ms": physics_sections.duplicate() if recorded_physics_tick == tick else {}, "section_calls": physics_section_calls.duplicate() if recorded_physics_tick == tick else {}, "patron_count": get_tree().get_nodes_in_group("patrons").size(), "traffic_enabled": traffic_enabled, "traffic_logic_enabled": traffic_logic_enabled, "pedestrian_logic_enabled": pedestrian_logic_enabled, "traffic_lod_enabled": traffic_lod_enabled, "rendering_lod_enabled": rendering_lod_enabled, "loading_stage": stage}
	last_physics_sample_us = now
	recent_physics_samples.append(sample)
	while not recent_physics_samples.is_empty() and now - int(recent_physics_samples[0].time_us) > int(profile_shortcut.seconds * 1000000):
		recent_physics_samples.pop_front()
	profile_shortcut.record_sample(sample, true)

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := (now - last_tick) / 1000.0
	last_tick = now
	frame_ms.append(elapsed)
	if frame_ms.size() > 300: frame_ms.pop_front()
	latest_sections = sections.duplicate()
	sections.clear()
	var target := float(Engine.max_fps) if Engine.max_fps > 0 else 60.0
	var fps := minf(float(Engine.get_frames_per_second()), 1000.0 / maxf(elapsed, 0.01))
	fps_label.text = "%.0f FPS  •  %.1f ms" % [fps, elapsed]
	fps_label.position = Vector2(maxf(8, get_viewport().get_visible_rect().size.x - 220), 8)
	fps_label.add_theme_color_override("font_color", Color(1, 0.15, 0.12).lerp(Color(0.4, 1, 0.5), clampf((fps / target - 0.5) / 0.5, 0, 1)))
	var sample := {"time_us": now, "frame_ms": elapsed, "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "sections_ms": latest_sections.duplicate(), "loading_stage": stage, "snapshot_bytes": snapshot_bytes}
	sample["traffic_enabled"] = traffic_enabled
	sample["traffic_logic_enabled"] = traffic_logic_enabled
	sample["pedestrian_logic_enabled"] = pedestrian_logic_enabled
	sample["patron_count"] = get_tree().get_nodes_in_group("patrons").size()
	sample["buildings_as_blocks"] = buildings_as_blocks
	sample["render_disabled"] = render_filters.disabled.duplicate()
	sample["traffic_lod_enabled"] = traffic_lod_enabled
	sample["rendering_lod_enabled"] = rendering_lod_enabled
	sample["optimized_snapshots"] = optimized_snapshots
	recent_samples.append(sample)
	while not recent_samples.is_empty() and now - int(recent_samples[0].time_us) > int(maxf(6, profile_shortcut.seconds if profile_shortcut.enabled else 6) * 1000000):
		recent_samples.pop_front()
	if video_tracking: video_samples.append(sample)
	profile_shortcut.record_sample(sample)
	for key in latest_sections: section_peaks[key] = maxf(section_peaks.get(key, 0), latest_sections[key])
	section_window -= delta
	if section_window <= 0.0:
		section_window = 1.0
		refresh_traffic_counts()
		displayed_peaks = section_peaks.duplicate()
		section_peaks.clear()
	if capture != null:
		capture.store_csv_line(PackedStringArray([str(now), str(elapsed), str(Performance.get_monitor(Performance.TIME_PROCESS) * 1000), str(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000), str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), str(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), str(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), str(traffic_active), str(traffic_distant), str(snapshot_bytes), str(snapshot_parts), str(latest_sections.get("Traffic", 0)), str(latest_sections.get("Snapshot build", 0)), str(latest_sections.get("Snapshot compress", 0)), str(latest_sections.get("Snapshot receive", 0)), str(latest_sections.get("Item load", 0)), str(latest_sections.get("Item spawn", 0)), str(latest_sections.get("Item clear", 0)), stage]))
		capture_remaining -= delta
		if capture_remaining <= 0.0: stop_capture()

func start_capture(seconds: float = 20.0, directory: String = "user://performance") -> String:
	stop_capture()
	DirAccess.make_dir_recursive_absolute(directory)
	capture_path = directory.path_join("frames_%s.csv" % str(Time.get_unix_time_from_system()).replace(".", "_"))
	capture = FileAccess.open(capture_path, FileAccess.WRITE)
	if capture == null: return "Could not save performance capture."
	capture.store_csv_line(PackedStringArray(["time_us", "frame_ms", "engine_process_ms", "physics_ms", "draw_calls", "primitives", "active_physics_bodies", "near_cars", "distant_cars", "snapshot_bytes", "snapshot_packets", "traffic_script_ms", "snapshot_build_ms", "snapshot_compress_ms", "snapshot_receive_ms", "item_load_ms", "item_spawn_ms", "item_clear_ms", "loading_stage"]))
	capture_remaining = seconds
	return ProjectSettings.globalize_path(capture_path)

func stop_capture() -> void:
	if capture != null:
		capture.flush()
		capture.close()
		capture = null

func summary() -> String:
	if frame_ms.is_empty(): return "Collecting frame timings…"
	var ordered := frame_ms.duplicate()
	ordered.sort()
	var average := 0.0
	for value in ordered: average += value
	average /= ordered.size()
	var p95: float = ordered[mini(ordered.size() - 1, ceili(ordered.size() * 0.95) - 1)]
	var slow := 0
	for value in ordered:
		if value > 33.3: slow += 1
	return "FRAME %.1f ms • %.0f FPS • p95 %.1f ms • worst %.1f ms\nFrames >33 ms: %d / %d • 60 FPS budget: 16.7 ms\nEngine process %.2f ms • physics %.2f ms (CPU; not GPU time)\nDraw calls %d • primitives %d • active physics bodies %d\nTraffic: %d near / %d distant • script peak %.2f ms\nSnapshot: %d bytes / %d packets • build %.2f / compress %.2f ms\nClient receive/apply %.2f ms • peaks cover the last second\nLoading: %s%s" % [average, 1000.0 / maxf(average, 0.01), p95, ordered.back(), slow, ordered.size(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), traffic_active, traffic_distant, displayed_peaks.get("Traffic", 0), snapshot_bytes, snapshot_parts, displayed_peaks.get("Snapshot build", 0), displayed_peaks.get("Snapshot compress", 0), displayed_peaks.get("Snapshot receive", 0), stage, "\nRecording CSV: %.0fs left" % capture_remaining if capture != null else ""]

func refresh_traffic_counts() -> void:
	traffic_active = 0
	traffic_distant = 0
	for car in get_tree().get_nodes_in_group("traffic_motion"):
		if car.distant_mode: traffic_distant += 1
		else: traffic_active += 1

func begin_video_tracking() -> void:
	video_samples = recent_samples.duplicate(true)
	video_tracking = true

func save_video_report(path: String, frame_times: Array[int], video_fps: int) -> Error:
	video_tracking = false
	var samples: Array[Dictionary] = []
	var hitches: Array[Dictionary] = []
	var origin := frame_times[0] if not frame_times.is_empty() else 0
	for sample in video_samples:
		if int(sample.time_us) < origin: continue
		var entry: Dictionary = sample.duplicate(true)
		entry["seconds_from_capture_start"] = (int(sample.time_us) - origin) / 1000000.0
		samples.append(entry)
		if float(sample.frame_ms) >= 33.33:
			var suspect := "Unattributed: GPU, frame pacing, OS scheduling or uninstrumented work; CPU monitors may lag a frame"
			var largest := 0.0
			for key in sample.sections_ms:
				if float(sample.sections_ms[key]) > largest:
					largest = float(sample.sections_ms[key])
					suspect = "Largest measured section: " + str(key)
			if largest < 2.0 and float(sample.physics_ms) > 8.0: suspect = "Elevated physics CPU time"
			hitches.append({"time_us": sample.time_us, "frame_ms": sample.frame_ms, "likely_cause": suspect, "measured_section_ms": largest})
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"format": "onthefly.performance_recording", "version": 1, "video_fps": video_fps, "video_frame_time_us": frame_times, "capture_start_us": origin, "samples": samples, "hitches": hitches, "note": "Video frame index / video_fps gives playback time; frame timestamps map it to real capture time. Repeated frames represent capture gaps. Causes are correlations, not proof; GPU time is not measured.", "os": OS.get_name(), "engine": Engine.get_version_info()}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	video_samples.clear()
	return error
