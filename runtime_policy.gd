extends Node

func _ready() -> void:
	# Autoloads in editor-launched games use the debug engine. Never cap those.
	if not OS.has_feature("editor") and not OS.is_debug_build():
		Engine.max_fps = 30
		Engine.physics_ticks_per_second = 60

