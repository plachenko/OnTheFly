extends Node

var traffic_lod_enabled := true
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	last_tick = Time.get_ticks_usec()

func record_section(label: String, microseconds: int) -> void:
	sections[label] = sections.get(label, 0.0) + microseconds / 1000.0

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := (now - last_tick) / 1000.0
	last_tick = now
	frame_ms.append(elapsed)
	if frame_ms.size() > 300: frame_ms.pop_front()
	latest_sections = sections.duplicate()
	sections.clear()
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
