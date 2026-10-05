extends SceneTree
func _initialize() -> void:
	verify.call_deferred()
func verify() -> void:
	assert(ClassDB.class_exists("SpeechToText"))
	var speech := preload("res://addons/codex_chat/dictation.gd").new()
	root.add_child(speech)
	assert(not speech.recording and not speech.working)
	speech.cancel()
	assert(speech.cancelled and not speech.recording)
	if not OS.get_cmdline_user_args().is_empty():
		var wav := AudioStreamWAV.load_from_file(OS.get_cmdline_user_args()[0])
		assert(wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS)
		var frames := PackedVector2Array()
		var channels := 2 if wav.stereo else 1
		var source_count := wav.data.size() / (2 * channels)
		var target_count := int(source_count * AudioServer.get_mix_rate() / wav.mix_rate)
		for index in target_count:
			var source := mini(int(index * wav.mix_rate / AudioServer.get_mix_rate()), source_count - 1)
			var value := wav.data.decode_s16(source * 2 * channels) / 32768.0
			frames.append(Vector2(value, value))
		var result := [""]
		speech.transcribed.connect(func(text): result[0] = text)
		speech.cancelled = false
		speech.working = true
		speech.worker = Thread.new()
		assert(speech.worker.start(speech.transcribe_audio.bind(frames)) == OK)
		while speech.working: await process_frame
		print("LOCAL TRANSCRIPT: ", result[0])
		assert(str(result[0]).to_lower().contains("country"))
	speech.shutdown()
	speech.free()
	print("DICTATION PASS: native model, worker transcription and cleanup")
	quit()
