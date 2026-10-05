extends MeshInstance3D

var supports: Array[Node3D] = []
@export var support_paths: Array[NodePath] = []

func _ready() -> void:
	for path in support_paths:
		var node := get_node_or_null(path) as Node3D
		if node != null: supports.append(node)

func _process(_delta: float) -> void:
	for support in supports:
		if not is_instance_valid(support):
			queue_free()
			return
		var body := support.get_node_or_null("KnockablePole")
		if body != null and not body.freeze:
			queue_free()
			return
