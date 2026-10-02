extends MeshInstance3D

var supports: Array[Node3D] = []

func _process(_delta: float) -> void:
	for support in supports:
		if not is_instance_valid(support):
			queue_free()
			return
		var body := support.get_node_or_null("KnockablePole")
		if body != null and not body.freeze:
			queue_free()
			return
