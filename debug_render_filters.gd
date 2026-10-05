extends Node

const OPTIONS := {
	"grass": "Grass rendering",
	"furniture": "Street furniture rendering",
	"shadows": "Shadows",
	"lights": "Local lights",
	"pedestrians": "Pedestrian rendering",
	"particles": "Particle rendering",
}
var disabled: Dictionary = {}
var saved: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node):
		if true in disabled.values(): apply_added.call_deferred(node.get_instance_id()))

func apply_added(id: int) -> void:
	if is_instance_id_valid(id): apply_node(instance_from_id(id))

func set_disabled(key: String, value: bool) -> void:
	disabled[key] = value
	for node in get_tree().root.find_children("*", "Node", true, false):
		apply_node(node)

func category(node: Node) -> String:
	var ancestor := node
	while ancestor != null:
		var label := str(ancestor.name)
		if label.contains("Grass") or label.begins_with("CurbFringe"): return "grass"
		if label in ["StreetSigns", "PowerLines", "UtilityPolesAndWires", "SparseBlockFences", "SewerGrate", "GrateRib"] or label.begins_with("StreetLight") or label.begins_with("KenneyStreetLight") or label.begins_with("KnockablePole") or label.begins_with("Manhole"): return "furniture"
		if label == "Patrons" or ancestor.is_in_group("patrons"): return "pedestrians"
		ancestor = ancestor.get_parent()
	return ""

func override_property(node: Node, property: String, active: bool, value: Variant) -> void:
	var id := node.get_instance_id()
	if active:
		if not saved.has(id):
			saved[id] = {"node": weakref(node), "properties": {}}
		if not saved[id].properties.has(property): saved[id].properties[property] = node.get(property)
		node.set(property, value)
	elif saved.has(id) and saved[id].properties.has(property):
		node.set(property, saved[id].properties[property])
		saved[id].properties.erase(property)
		if saved[id].properties.is_empty(): saved.erase(id)

func apply_node(node: Node) -> void:
	if not is_instance_valid(node): return
	if not true in disabled.values() and saved.is_empty(): return
	if node is GeometryInstance3D or node is SpriteBase3D:
		var group := category(node)
		var hide_visual := bool(disabled.get(group, false))
		if node is GPUParticles3D or node is CPUParticles3D:
			hide_visual = hide_visual or bool(disabled.get("particles", false))
		override_property(node, "visible", hide_visual, false)
	if node is Light3D:
		override_property(node, "shadow_enabled", bool(disabled.get("shadows", false)), false)
		var no_light := bool(disabled.get("lights", false)) and not node is DirectionalLight3D
		no_light = no_light or bool(disabled.get(category(node), false))
		override_property(node, "visible", no_light, false)
	# Release references to deleted/streamed-out nodes without retaining scenes.
	for id in saved.keys():
		if saved[id].node.get_ref() == null: saved.erase(id)
