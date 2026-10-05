@tool
extends Node
signal status_changed(message: String)
signal transcribed(text: String)
signal state_changed
const MODEL := "res://addons/godot_whisper/models/ggml-tiny.en.bin"
const MAX_SECONDS := 30.0
var recording := false
var working := false
var seconds := 0.0
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var spectrum: AudioEffectSpectrumAnalyzerInstance
var frames := PackedVector2Array()
var worker: Thread
var bus_name := "CodexDictation"
var cancelled := false

func _exit_tree() -> void:
	shutdown()

func start() -> void:
	if working or recording: return
	if not ClassDB.class_exists("SpeechToText"):
		status_changed.emit("Whisper is unavailable. Restart Godot after installing the addon.")
		return
	if not FileAccess.file_exists(MODEL):
		status_changed.emit("Missing local Whisper tiny English model.")
		return
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		status_changed.emit("Microphone input requires restarting Godot after enabling audio input.")
		return
	if OS.get_name() == "Android" and not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
		OS.request_permissions()
		status_changed.emit("Allow microphone access, then click Mic again.")
		return
	if not setup_audio_bus(): return
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = AudioStreamMicrophone.new()
		player.bus = bus_name
		add_child(player)
	frames.clear()
	capture.clear_buffer()
	seconds = 0.0
	cancelled = false
	recording = true
	player.play()
	status_changed.emit("Recording locally… Click Transcribe when finished (30-second limit).")
	state_changed.emit()

func setup_audio_bus() -> bool:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_mute(index, true)
		capture = AudioEffectCapture.new()
		capture.buffer_length = 0.5
		AudioServer.add_bus_effect(index, capture)
	else: capture = AudioServer.get_bus_effect(index, 0) as AudioEffectCapture
	if capture == null: return false
	var spectrum_index := -1
	for effect_index in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect_index) is AudioEffectSpectrumAnalyzer:
			spectrum_index = effect_index
			break
	if spectrum_index < 0:
		var analyzer := AudioEffectSpectrumAnalyzer.new()
		analyzer.buffer_length = 0.2
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		spectrum_index = AudioServer.get_bus_effect_count(index)
		AudioServer.add_bus_effect(index, analyzer)
	spectrum = AudioServer.get_bus_effect_instance(index, spectrum_index) as AudioEffectSpectrumAnalyzerInstance
	return true

func frequency_bands(count: int = 16) -> PackedFloat32Array:
	var bands := PackedFloat32Array()
	bands.resize(count)
	if not recording or spectrum == null: return bands
	for band in count:
		var low := 80.0 * pow(100.0, float(band) / count)
		var high := 80.0 * pow(100.0, float(band + 1) / count)
		var magnitude := spectrum.get_magnitude_for_frequency_range(low, high)
		bands[band] = clampf((linear_to_db(maxf(0.000001, maxf(magnitude.x, magnitude.y))) + 60.0) / 60.0, 0.0, 1.0)
	return bands

func drain() -> void:
	if capture != null:
		frames.append_array(capture.get_buffer(capture.get_frames_available()))

func _process(delta: float) -> void:
	if not recording: return
	drain()
	seconds += delta
	if seconds >= MAX_SECONDS: finish()

func finish() -> void:
	if not recording: return
	drain()
	player.stop()
	recording = false
	if frames.size() < int(AudioServer.get_mix_rate() * 0.3):
		status_changed.emit("No microphone audio captured. Check input device and permissions.")
		state_changed.emit()
		return
	var peak := 0.0
	for frame in frames: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	if peak < 0.001:
		frames.clear()
		status_changed.emit("No speech detected. Check the microphone input device.")
		state_changed.emit()
		return
	working = true
	worker = Thread.new()
	var audio := frames
	frames = PackedVector2Array()
	var error := worker.start(transcribe_audio.bind(audio))
	if error != OK:
		working = false
		worker = null
		status_changed.emit("Could not start local transcription.")
	else: status_changed.emit("Transcribing locally…")
	state_changed.emit()

static func mono_samples(audio: PackedVector2Array, mix_rate: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	if audio.is_empty() or mix_rate <= 0: return samples
	var count := int(audio.size() * 16000.0 / mix_rate)
	samples.resize(count)
	for index in count:
		var begin := int(index * mix_rate / 16000.0)
		var end := mini(audio.size(), maxi(begin + 1, int((index + 1) * mix_rate / 16000.0)))
		var sum := 0.0
		for source in range(begin, end): sum += (audio[source].x + audio[source].y) * 0.5
		samples[index] = sum / (end - begin)
	return samples

func transcribe_audio(audio: PackedVector2Array) -> void:
	var recognizer: Object = ClassDB.instantiate("SpeechToText")
	var model: Object = ClassDB.instantiate("WhisperResource")
	model.set("file", MODEL)
	recognizer.set("language_model", model)
	var samples := mono_samples(audio, AudioServer.get_mix_rate())
	var result: Array = recognizer.call("transcribe", samples, "", 0)
	var text := str(result[0]).strip_edges() if not result.is_empty() else ""
	recognizer.free()
	complete.call_deferred(text)

func complete(text: String) -> void:
	if worker != null:
		worker.wait_to_finish()
		worker = null
	working = false
	if not cancelled:
		if text.is_empty(): status_changed.emit("No speech recognized. Try again.")
		else:
			transcribed.emit(text)
			status_changed.emit("Dictation added to your draft. Review before sending.")
	state_changed.emit()

func cancel() -> void:
	cancelled = true
	if player != null: player.stop()
	recording = false
	frames.clear()
	status_changed.emit("Dictation cancelled.")
	state_changed.emit()

func shutdown() -> void:
	cancel()
	if worker != null:
		worker.wait_to_finish()
		worker = null
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0: AudioServer.remove_bus(index)
	spectrum = null
