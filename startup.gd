extends Node

func _ready() -> void:
	if "--release-smoke-test" in OS.get_cmdline_user_args():
		var test := load("res://tools/release_smoke.gd").new() as Node
		get_tree().root.add_child.call_deferred(test)
		return
	if "--runtime-policy-test" in OS.get_cmdline_user_args():
		var test := load("res://tools/runtime_policy_test.gd").new() as Node
		get_tree().root.add_child.call_deferred(test)
		return
	if "--profile-route" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/profiler_route.tscn")
		return
	if "--multiplayer-smoke-test" in OS.get_cmdline_user_args():
		var runner := preload("res://tools/multiplayer_runtime_test.gd").new()
		runner.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(runner)
		return
	get_node("/root/LoadingScreen").load_scene("res://main_menu.tscn")
