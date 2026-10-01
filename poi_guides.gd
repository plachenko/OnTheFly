extends Control

## Screen-space compass guides. Only arrows rotate; captions stay readable.
const SERVING_COLOR := Color(0.12, 1.0, 0.46)
const REPAIR_COLOR := Color(1.0, 0.61, 0.16)
var cards: Array[Dictionary] = []
@onready var level = get_parent().get_parent().get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10 # Read the camera after the follow-camera update.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(410, 125)
	size = Vector2(435, 56)
	add_guide("SERVE", SERVING_COLOR, 0.0)
	add_guide("REPAIR / SHOP", REPAIR_COLOR, 225.0)

func add_guide(caption: String, tint: Color, x: float) -> void:
	var panel := Panel.new()
	panel.position = Vector2(x, 0)
	panel.size = Vector2(210, 56)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.1, 0.88)
	style.border_color = tint.darkened(0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var arrow := Polygon2D.new()
	arrow.position = Vector2(28, 28)
	arrow.polygon = PackedVector2Array([Vector2(0, -16), Vector2(12, 12), Vector2(0, 6), Vector2(-12, 12)])
	arrow.color = tint
	panel.add_child(arrow)
	var label := Label.new()
	label.position = Vector2(52, 5)
	label.size = Vector2(154, 46)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", tint)
	panel.add_child(label)
	cards.append({"arrow": arrow, "label": label, "caption": caption})

func serving_destination() -> Area3D:
	var navigator = level.truck.get_node_or_null("FSDNavigator")
	if level.truck.fsd_enabled and navigator != null and available(navigator.destination):
		return navigator.destination
	var closest: Area3D
	var best_distance := INF
	for pad in level.get_node("ParkingPads").get_children():
		if not available(pad):
			continue
		var offset: Vector3 = pad.global_position - level.truck.global_position
		offset.y = 0.0
		if offset.length_squared() < best_distance:
			closest = pad
			best_distance = offset.length_squared()
	return closest

func available(pad: Node) -> bool:
	return is_instance_valid(pad) and pad is Area3D and pad != level.repair_pad and pad.serving_enabled and not pad.expired

static func bearing(offset: Vector3, camera_basis: Basis) -> float:
	# Use horizontal camera heading, rather than perspective projection, so
	# behind-camera destinations and changes in camera pitch remain stable.
	var right := Vector3(camera_basis.x.x, 0, camera_basis.x.z).normalized()
	var forward := Vector3(right.z, 0, -right.x)
	return Vector2(offset.dot(right), -offset.dot(forward)).angle() + PI * 0.5

func _process(_delta: float) -> void:
	visible = not get_tree().paused and not level.round_finished and not level.can_repair()
	if not visible:
		return
	update_guide(cards[0], serving_destination())
	update_guide(cards[1], level.repair_pad)

func update_guide(card: Dictionary, target: Area3D) -> void:
	var arrow: Polygon2D = card.arrow
	var label: Label = card.label
	if not is_instance_valid(target):
		arrow.hide()
		label.text = card.caption + "\nNone available"
		return
	var offset: Vector3 = target.global_position - level.truck.global_position
	var distance := Vector2(offset.x, offset.z).length()
	var arrived: bool = target.contains_truck(level.truck)
	arrow.visible = not arrived
	arrow.rotation = bearing(offset, level.camera.global_basis)
	label.text = "%s\n%s" % [card.caption, "HERE" if arrived else "%d m" % roundi(distance)]
