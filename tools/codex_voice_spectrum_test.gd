extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var speech := preload("res://addons/codex_chat/dictation.gd").new()
	speech.bus_name = "CodexSpectrumTest"
	root.add_child(speech)
	assert(speech.setup_audio_bus())
	var bus := AudioServer.get_bus_index(speech.bus_name)
	assert(AudioServer.is_bus_mute(bus), "Microphone monitoring must stay inaudible")
	assert(AudioServer.get_bus_effect_count(bus) == 2)
	assert(speech.setup_audio_bus() and AudioServer.get_bus_effect_count(bus) == 2, "Restart must reuse analyzer")
	assert(speech.frequency_bands().size() == 16)
	var player := AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = AudioServer.get_mix_rate()
	generator.buffer_length = 0.2
	player.stream = generator
	player.bus = speech.bus_name
	root.add_child(player)
	player.play()
	speech.recording = true
	speech.set_process(false)
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	var phase := 0.0
	for iteration in 35:
		var samples := PackedVector2Array()
		for index in playback.get_frames_available():
			var value := sin(phase) * 0.25
			samples.append(Vector2(value, value))
			phase += TAU * 500.0 / generator.mix_rate
		playback.push_buffer(samples)
		await create_timer(0.01).timeout
	var bands := speech.frequency_bands()
	var strongest := 0
	for index in bands.size():
		if bands[index] > bands[strongest]: strongest = index
	assert(bands[strongest] > 0.1, "Muted microphone bus must still produce spectrum data")
	assert(strongest >= 5 and strongest <= 7, "500 Hz tone should occupy its frequency band")
	speech.recording = false
	assert(speech.frequency_bands()[strongest] == 0.0, "Stopped dictation clears reported levels")
	player.stop()
	playback = null
	player.free()
	speech.shutdown()
	assert(AudioServer.get_bus_index(speech.bus_name) == -1)
	speech.free()
	await create_timer(0.1).timeout
	print("VOICE SPECTRUM PASS: muted-bus 500 Hz analysis, reusable analyzer, stop/reset and cleanup")
	quit()
