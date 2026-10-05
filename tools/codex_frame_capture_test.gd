extends SceneTree

class DelayedCapture extends "res://codex_frame_capture.gd":
	func read_frame() -> Dictionary:
		await get_tree().process_frame
		return {"path": ProjectSettings.globalize_path("res://.godot/codex_capture_test.png"), "time_us": 1000}

class TestBridge extends Node:
	var initialized := true

class TestDock extends "res://addons/codex_chat/dock.gd":
	var attached: Array = []
	func _ready() -> void: pass
	func set_busy(value: bool) -> void: busy = value
	func scene_context() -> String: return ""
	func line(_speaker: String, _text: String) -> void: pass
	func begin_turn() -> void: attached = queued_images.duplicate()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var image := Image.create(16, 9, false, Image.FORMAT_RGB8)
	image.fill(Color.BLUE)
	image.save_png("res://.godot/codex_capture_test.png")
	var capture := DelayedCapture.new()
	root.add_child(capture)
	capture.begin()
	capture.finish()
	assert(capture.capturing and capture.captures.is_empty(), "Release must wait for in-flight frame")
	await process_frame
	await process_frame
	assert(capture.captures.size() == 1 and capture.captures[0].thumbnail != null)
	assert(capture.attachments()[0].time_us == 1000)
	var dock := TestDock.new()
	dock.bridge = TestBridge.new()
	dock.thread_id = "test"
	dock.send_game_dictation("Inspect this capture", capture.attachments())
	assert(dock.attached.size() == 1)
	assert(dock.queued_contexts[dock.attached[0]].contains('"time_us":1000'))
	assert(dock.queued_prompt.contains("(dictatated)"))
	dock.bridge.free()
	dock.free()
	capture.free()
	print("FRAME CAPTURE PASS: asynchronous release, first thumbnail, attachment and timestamp delivery")
	quit()
