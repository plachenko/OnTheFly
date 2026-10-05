extends Node

@export var fee := 25
@export var signal_range := 24.0
var active := false
var bay: Node3D
var elapsed := 0.0
var duration := 0.0
var origin := Vector3.ZERO
var target := Vector3.ZERO
var control_a := Vector3.ZERO
var control_b := Vector3.ZERO
var axis := Vector3.ZERO
var overlays: Dictionary = {}
var refresh := 0.0
var toast: Label
var toast_remaining := 0.0
var last_message := ""
@onready var truck = get_parent()
var city: Node3D

func being_pursued() -> bool:
	if not PoliceDispatch.pursuing: return false
	for cop in get_tree().get_nodes_in_group("traffic_motion"):
		var circle := cop.get_node_or_null("PoliceCircle")
		if circle != null and circle.pursuing and cop.truck == truck: return true
	return false

func eligible(candidate: Node3D) -> bool:
	if candidate.get_meta("occupied", false) and not city.has_node("ParkedCars"): return false
	var reserved: Node = candidate.get_meta("pullover_reserved") if candidate.has_meta("pullover_reserved") else null
	if is_instance_valid(reserved) and reserved != truck: return false
	var pads := truck.get_parent().get_node_or_null("ParkingPads")
	if pads:
		for pad in pads.get_children():
			if Vector2(pad.global_position.x - candidate.global_position.x, pad.global_position.z - candidate.global_position.z).length() < 2.0:
				if not pad.serving_enabled or not pad.expired: return false
	elif candidate.get_meta("serving", false): return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(city.parking_bay_width - 0.2, 2.5, city.parking_bay_length - 0.2)
	query.shape = shape
	var direction: Vector3 = candidate.get_meta("parking_axis", Vector3.FORWARD)
	var center := candidate.global_position
	center.y = city.height_at(center.x, center.z) + 1.8
	query.transform = Transform3D(Basis(Vector3.UP, atan2(direction.x, direction.z)), center)
	query.exclude = [truck.get_rid()]
	query.collision_mask = truck.collision_mask
	return truck.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _process(delta: float) -> void:
	if truck.message != last_message:
		last_message = truck.message
		if last_message.begins_with("PARKED SAFELY") and truck.message_timer > 0.0:
			show_toast(last_message)
	toast_remaining = maxf(0.0, toast_remaining - delta)
	if is_instance_valid(toast): toast.visible = toast_remaining > 0.0
	city = truck.get_parent().get_node_or_null("ProceduralCity")
	if city == null or not city.has_node("ParkingSpaces"): return
	refresh -= delta
	if refresh > 0.0: return
	refresh = 0.2
	var pursued := being_pursued()
	if not pursued:
		for visual in overlays.values():
			if is_instance_valid(visual): visual.hide()
		return
	for candidate in city.get_node("ParkingSpaces").get_children():
		if not overlays.has(candidate):
			var visual := MeshInstance3D.new()
			visual.name = "PulloverGlow_%s" % truck.name
			var plane := PlaneMesh.new()
			plane.size = Vector2(city.parking_bay_width, city.parking_bay_length)
			visual.mesh = plane
			visual.rotation.y = atan2(candidate.get_meta("parking_axis").x, candidate.get_meta("parking_axis").z)
			var material := ShaderMaterial.new()
			material.shader = preload("res://pullover_bay.gdshader")
			visual.material_override = material
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			candidate.add_child(visual)
			city.conform_pad_surface(visual)
			overlays[candidate] = visual
		overlays[candidate].visible = pursued and eligible(candidate)

func choose_bay() -> Node3D:
	if truck.turn_signal == 0 or truck.hazards_on: return null
	var closest: Node3D
	var distance := signal_range
	for candidate in city.get_node("ParkingSpaces").get_children():
		var offset: Vector3 = candidate.global_position - truck.global_position
		offset.y = 0.0
		var side := offset.dot(truck.global_basis.x)
		var forward := offset.dot(-truck.global_basis.z)
		if signf(side) != truck.turn_signal or absf(side) < 0.5 or forward < -4.0: continue
		if offset.length() < distance and eligible(candidate):
			closest = candidate
			distance = offset.length()
	return closest

func begin(candidate: Node3D) -> void:
	bay = candidate
	bay.set_meta("pullover_reserved", truck)
	active = true
	elapsed = 0.0
	origin = truck.global_position
	target = bay.global_position
	target.y = city.height_at(target.x, target.z) + 0.12
	axis = bay.get_meta("parking_axis", -truck.global_basis.z)
	duration = maxf(4.0, origin.distance_to(target) / 2.0)
	control_a = origin - truck.global_basis.z * minf(5.0, origin.distance_to(target) * 0.3)
	control_b = target - axis * minf(4.0, origin.distance_to(target) * 0.3)
	truck.fsd_enabled = false
	truck.deployed = false
	truck.message = "PULLING OVER — automatically parking in the yellow bay."
	truck.message_timer = duration + 1.0

# Called by the real truck's authority physics tick, including multiplayer host.
func drive(delta: float) -> bool:
	city = truck.get_parent().get_node_or_null("ProceduralCity")
	if city == null or not city.has_node("ParkingSpaces"): return false
	if not active:
		if not being_pursued() or truck.opening > 0.02 or truck.health <= 0.0 or truck.round_over: return false
		var selected := choose_bay()
		if selected == null: return false
		begin(selected)
	if not being_pursued() or not is_instance_valid(bay) or not eligible(bay):
		cancel("PULLOVER CANCELLED — bay unavailable.")
		return false
	elapsed = minf(duration, elapsed + delta)
	var u := elapsed / duration
	var t := u * u * (3.0 - 2.0 * u)
	var next := origin * pow(1.0 - t, 3) + control_a * 3.0 * pow(1.0 - t, 2) * t + control_b * 3.0 * (1.0 - t) * t * t + target * t * t * t
	next.y = city.height_at(next.x, next.z) + 0.12
	var movement: Vector3 = next - truck.global_position
	var yaw := atan2(-axis.x, -axis.z)
	var tangent := (control_a - origin) * pow(1.0 - t, 2) + (control_b - control_a) * 2.0 * (1.0 - t) * t + (target - control_b) * t * t
	if tangent.length() > 0.01: yaw = atan2(-tangent.x, -tangent.z)
	truck.rotation.y = lerp_angle(truck.rotation.y, yaw, minf(1.0, delta * 4.0))
	truck.velocity = movement / maxf(delta, 0.001)
	truck.speed = movement.length() / maxf(delta, 0.001)
	truck.move_and_slide()
	if truck.global_position.distance_to(next) > 0.5:
		cancel("PULLOVER BLOCKED — choose another yellow bay.")
		return true
	truck.rolling += truck.speed * delta / 0.59
	truck.update_suspension(delta)
	truck.update_slope_tilt(delta)
	truck.get_node("VehicleLights").set_driving_lights(u > 0.9, false, truck.turn_signal < 0, truck.turn_signal > 0, false)
	truck.get_node("VehicleLights").sync_with_chassis()
	if elapsed >= duration:
		truck.global_position = target
		truck.rotation.y = atan2(-axis.x, -axis.z)
		truck.travel_heading = truck.rotation.y
		var balance: int = truck.get_parent().money
		PoliceDispatch.resolve(truck, true, fee)
		truck.turn_signal = 0
		truck.message = "PARKED SAFELY — pullover fee: $%d" % (balance - truck.get_parent().money)
		truck.message_timer = 5.0
		show_toast(truck.message)
		for cop in get_tree().get_nodes_in_group("traffic_motion"):
			var circle := cop.get_node_or_null("PoliceCircle")
			if circle != null: circle.begin_green_return()
		active = false
		bay.remove_meta("pullover_reserved")
	return true

func show_toast(message: String) -> void:
	if NetworkSession.active and truck.get_meta("player_id", multiplayer.get_unique_id()) != multiplayer.get_unique_id(): return
	last_message = message
	if not is_instance_valid(toast):
		var canvas := CanvasLayer.new()
		canvas.layer = 20
		add_child(canvas)
		toast = Label.new()
		toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		toast.position = Vector2(-240, -90)
		toast.size = Vector2(480, 40)
		toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toast.add_theme_color_override("font_color", Color("ffe44a"))
		toast.add_theme_color_override("font_shadow_color", Color.BLACK)
		toast.add_theme_constant_override("shadow_offset_x", 2)
		toast.add_theme_constant_override("shadow_offset_y", 2)
		canvas.add_child(toast)
	toast.text = message
	toast_remaining = 5.0
	toast.show()

func _exit_tree() -> void:
	if active and is_instance_valid(bay): bay.remove_meta("pullover_reserved")
	for visual in overlays.values():
		if is_instance_valid(visual): visual.queue_free()

func cancel(message: String) -> void:
	if is_instance_valid(bay): bay.remove_meta("pullover_reserved")
	active = false
	truck.speed = 0.0
	truck.velocity = Vector3.ZERO
	truck.turn_signal = 0
	truck.message = message
	truck.message_timer = 4.0
