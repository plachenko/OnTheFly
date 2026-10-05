extends SceneTree

class TestBridge extends Node:
	var initialized := true

class TestDock extends "res://addons/codex_chat/dock.gd":
	var sent := ""
	var displayed := ""
	func _ready() -> void: pass
	func set_busy(value: bool) -> void: busy = value
	func scene_context() -> String: return "\nScene: test"
	func rebuild_attachments() -> void: pass
	func begin_turn() -> void: sent = queued_prompt
	func line(speaker: String, text: String) -> void: displayed = speaker + ": " + text

func _initialize() -> void:
	var dock := TestDock.new()
	dock.bridge = TestBridge.new()
	dock.prompt = TextEdit.new()
	dock.status = Label.new()
	dock.thread_id = "test"
	dock.prompt.text = "typed draft"
	dock.attachment_paths.append("draft.png")
	dock.send_game_dictation("add water")
	assert(dock.sent.begins_with("add water (dictatated)"))
	assert(dock.sent.contains("Speech recognition can mishear"))
	assert(dock.displayed.contains("(dictatated)"))
	assert(dock.prompt.text == "typed draft" and dock.attachment_paths == ["draft.png"])
	dock.busy = false
	dock.add_dictation_to_draft("and bridges")
	dock.send_prompt()
	assert(dock.sent.begins_with("typed draft and bridges (dictatated)"))
	assert(not dock.draft_has_dictation)
	dock.busy = false
	dock.prompt.text = "typed only"
	dock.send_prompt()
	assert(not dock.sent.contains("(dictatated)"))
	assert(dock.sent.contains("typed text"))
	dock.prompt.free()
	dock.status.free()
	dock.bridge.free()
	dock.free()
	print("INPUT SOURCE PASS: voice markers, typed reset and preserved game draft")
	quit()
