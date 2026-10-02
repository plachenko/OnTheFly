extends Node

func _ready() -> void:
	if "--multiplayer-smoke-test" in OS.get_cmdline_user_args():
		var runner := preload("res://tools/multiplayer_runtime_test.gd").new()
		runner.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(runner)
		return
	get_node("/root/LoadingScreen").load_scene("res://main_menu.tscn")
