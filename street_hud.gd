extends Control

var level: Node3D
var routes: Array[Dictionary] = []
var current_road: Dictionary = {}
var next_street: Dictionary = {}
var past_street: Dictionary = {}
var crossing_street: Dictionary = {}
var current_label: Label
var current_card: PanelContainer
var next_card: PanelContainer
var past_card: PanelContainer
var observed_truck: Node3D
var refresh_timer := 0.0
var reference_direction := Vector2.ZERO
var next_target := Vector2(300, 0)
var past_target := Vector2(-300, 0)
var next_scale := 0.7
var past_scale := 0.7
var swapping := false
var turn_animation: Tween
var backing_up := false
var suppressed_crossing_key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.12
	anchor_right = 0.12
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 4
	offset_right = 156
	offset_top = -80
	offset_bottom = -18
	z_index = 4
	var city := level.get_node_or_null("ProceduralCity")
	if city != null: routes = preload("res://street_navigation.gd").roads(city)
	current_card = make_card("CurrentStreet")
	current_label = current_card.get_child(0)
	current_label.text = "Lobby" if level.get("lobby_world") == true else "Plaza"
	past_card = make_card("PastStreet")
	next_card = make_card("UpcomingStreet")
	past_card.position.x = -300
	next_card.position.x = 300
	past_card.scale = Vector2.ONE * 0.7
	next_card.scale = Vector2.ONE * 0.7
	past_card.hide()
	next_card.hide()

func make_card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = title
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(148, 54)
	card.pivot_offset = Vector2(74, 27)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.10, 0.94)
	style.border_color = Color("bde4c5")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	add_child(card)
	return card

func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer <= 0:
		refresh_timer = 0.1
		var body: Node3D = level.get("local_truck")
		if not is_instance_valid(body): body = level.truck
		if is_instance_valid(body):
			if body != observed_truck:
				observed_truck = body
				current_road = {}
				reference_direction = Vector2.ZERO
			var forward := -body.global_basis.z
			var heading := Vector2(forward.x, forward.z).normalized()
			var motion := Vector2(body.velocity.x, body.velocity.z) if body is CharacterBody3D else Vector2.ZERO
			update_location(Vector2(body.global_position.x, body.global_position.z), heading, motion.dot(heading) < -0.5)
	if not swapping:
		var blend := 1.0 - exp(-8.0 * delta)
		next_card.position = next_card.position.lerp(next_target, blend)
		past_card.position = past_card.position.lerp(past_target, blend)
		next_card.scale = next_card.scale.lerp(Vector2.ONE * next_scale, blend)
		past_card.scale = past_card.scale.lerp(Vector2.ONE * past_scale, blend)

func update_location(point: Vector2, heading: Vector2, reversing: bool = false) -> void:
	if routes.is_empty(): return
	backing_up = reversing
	var navigation := preload("res://street_navigation.gd")
	var selected := navigation.locate(routes, point, heading, current_road.get("id", ""))
	if selected.is_empty():
		current_label.text = "Off street"
		next_card.hide()
		past_card.hide()
		return
	var axis: Vector2 = (selected.end - selected.start).normalized()
	var facing := axis * (1.0 if axis.dot(heading) >= 0 else -1.0)
	var uturn: bool = selected.id == current_road.get("id", "") and reference_direction.dot(facing) < -0.5
	var road_changed: bool = not current_road.is_empty() and selected.id != current_road.id
	if uturn: swap_sides()
	reference_direction = facing
	current_road = selected
	var neighbors := navigation.neighbors(routes, selected, point, facing, 8.0 if not crossing_street.is_empty() else 5.0)
	past_street = neighbors.past
	next_street = neighbors.next
	crossing_street = neighbors.crossing
	if road_changed: suppressed_crossing_key = str(crossing_street.get("key", ""))
	if crossing_street.is_empty(): suppressed_crossing_key = ""
	var crossing_visible: bool = not crossing_street.is_empty() and crossing_street.key != suppressed_crossing_key
	current_label.text = "ON  " + str(crossing_street.name if crossing_visible else selected.name)
	current_card.z_index = 2
	current_card.scale = Vector2.ONE * (1.08 if not crossing_street.is_empty() else 1.0)
	update_side(next_card, next_street, true)
	update_side(past_card, past_street, false)

func update_side(card: PanelContainer, street: Dictionary, upcoming: bool) -> void:
	if street.is_empty():
		card.hide()
		return
	var changed: bool = card.get_meta("street_key", "") != street.key
	card.set_meta("street_key", street.key)
	var label: Label = card.get_child(0)
	label.text = "%s\n%s\n%d m" % ["NEXT" if upcoming else ("BACKING TOWARD" if backing_up else "PAST"), street.name, roundi(street.distance)]
	card.show()
	var approach := 1.0 - clampf((street.distance - 5.0) / 59.0, 0, 1)
	var offset := lerpf(360.0, 245.0, approach)
	var scale_value := lerpf(0.7, 1.03, approach)
	if upcoming:
		next_target = Vector2(offset, 0)
		next_scale = scale_value
	else:
		past_target = Vector2(-offset, 0)
		past_scale = scale_value
	if changed and not swapping:
		if upcoming: card.position.x = get_viewport_rect().size.x * 0.5 + 150
		else: card.position.x = 0.0 # A crossed street leaves the center toward the left.
	card.z_index = 1 if approach > 0.75 else 0

func swap_sides() -> void:
	if turn_animation != null: turn_animation.kill()
	var old_past := past_card
	past_card = next_card
	next_card = old_past
	swapping = true
	turn_animation = create_tween().set_parallel()
	turn_animation.tween_property(next_card, "position", Vector2(0, -45), 0.25).set_trans(Tween.TRANS_CUBIC)
	turn_animation.tween_property(past_card, "position", Vector2(0, 45), 0.25).set_trans(Tween.TRANS_CUBIC)
	turn_animation.tween_property(next_card, "rotation", TAU, 0.55)
	turn_animation.tween_property(past_card, "rotation", -TAU, 0.55)
	turn_animation.chain().tween_callback(finish_swap)

func finish_swap() -> void:
	past_card.rotation = 0
	next_card.rotation = 0
	swapping = false
