extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var diagnostics := root.get_node("PerformanceDiagnostics")
	await process_frame
	diagnostics.recent_samples.clear()
	diagnostics.recent_samples.append({"time_us": 1000000, "frame_ms": 50.0, "physics_ms": 1.0, "sections_ms": {"Traffic": 30.0}})
	diagnostics.begin_video_tracking()
	var times: Array[int] = [1000000, 1000000, 1066667]
	var path := "res://.godot/performance_recording_test.json"
	assert(diagnostics.save_video_report(path, times, 15) == OK)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.video_frame_time_us.size() == 3)
	assert(report.samples.size() == 1)
	assert(report.hitches[0].likely_cause == "Largest measured section: Traffic")
	assert(not diagnostics.video_tracking)
	assert(is_instance_valid(diagnostics.fps_label))
	DirAccess.remove_absolute(path)
	print("PERFORMANCE RECORDING PASS")
	quit()
