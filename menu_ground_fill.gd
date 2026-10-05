extends MeshInstance3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	visible = get_viewport().get_camera_3d() == get_parent()
