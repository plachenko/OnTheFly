extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var recorder := root.get_node("ReplayRecorder")
	var requested := "--debug-replay-capture" in OS.get_cmdline_user_args()
	if "--expect-release-pack" in OS.get_cmdline_user_args():
		assert(not ResourceLoader.exists("res://debug_replay_recorder.gd"), "Release pack must omit capture implementation")
	if not OS.is_debug_build() or not requested:
		if not OS.is_debug_build():
			assert(not ResourceLoader.exists("res://debug_replay_recorder.gd"), "Release pack must omit capture implementation")
		assert(not recorder.is_processing())
		assert(not recorder.is_physics_processing())
		assert(not recorder.is_processing_input())
		assert(not recorder.has_method("capture_frame"))
		assert(not recorder.has_method("start_clip"))
		assert(recorder.get_child_count() == 0)
		print("REPLAY GATE PASS: disabled; no capture implementation, processing, input or overlay; debug=", OS.is_debug_build())
	else:
		assert(recorder.has_method("capture_frame"))
		if DisplayServer.get_name() != "headless":
			Engine.max_fps = 30
			await create_timer(0.8).timeout
			assert(not recorder.frames.is_empty(), "30 FPS rendering must still capture")
			recorder.set_process(false)
			while recorder.capture_pending: await process_frame
			recorder.frames.clear()
		var image := Image.create(640, 360, false, Image.FORMAT_RGB8)
		image.fill(Color.GREEN)
		recorder.frames.append(image.save_jpg_to_buffer())
		recorder.start_clip()
		assert(recorder.recording != null and recorder.frame_count == 1)
		recorder.append_frame(recorder.frames[0])
		recorder.finish_clip()
		assert(recorder.recording == null and recorder.frame_count == 2)
		var file := FileAccess.open(recorder.clip_path, FileAccess.READ)
		var data := file.get_buffer(file.get_length())
		assert(data.slice(0, 4).get_string_from_ascii() == "RIFF")
		assert(data.decode_u32(4) == data.size() - 8)
		print("REPLAY GATE PASS: opted-in debug capture writes and finalizes AVI")
	quit()
