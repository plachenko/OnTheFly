@tool
extends Area3D

@export var kitchen_camera_offset: Vector3 = Vector3(5.3, 2.8, -1.0)
@export var kitchen_focus_offset: Vector3 = Vector3(-0.35, 2.25, 1.0)
@export var camera_transition_speed: float = 2.4
@export_category("Patron Service")
@export var serving_enabled: bool = true
@export var serving_duration: float = 45.0
@export var attraction_radius: float = 18.0
@export_range(1,12) var patron_capacity: int = 4
@export var expired_fee: int = 5
@export var expired_fee_interval: float = 5.0
@export_category("Service Glow")
@export var available_glow_color: Color = Color(0.12, 1.0, 0.46)
@export var expired_glow_color: Color = Color(1.0, 0.16, 0.12)
@export_range(0.0, 2.0, 0.05) var glow_strength: float = 0.8
var service_started: bool = false
var service_remaining: float = 45.0
var expired: bool = false
var patrons: Array = []
var fee_elapsed: float = 0.0
var charged_initial_fee: bool = false

func _ready() -> void:
	if has_node("ServiceSurface"):
		var glow := ShaderMaterial.new()
		glow.shader = preload("res://service_glow.gdshader")
		glow.set_shader_parameter("glow_strength", glow_strength)
		$ServiceSurface.material_override = glow
		glow.set_shader_parameter("glow_color", expired_glow_color if expired else available_glow_color)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_entered)
	body_exited.connect(_exited)
	service_remaining=maxf(.1,serving_duration)
	refresh_service_sign()
	if has_node("WorldMeter"):
		$WorldMeter/WorldBar.texture=$WorldMeter/DisplayViewport.get_texture()

func tick_service(delta: float, shop_open: bool, open_at_pad: bool = false) -> void:
	if not serving_enabled:return
	if shop_open:service_started=true
	if service_started and not expired:
		service_remaining=maxf(0.0,service_remaining-delta)
		if service_remaining<=0.0:expired=true
	if expired and open_at_pad:
		if not charged_initial_fee:
			charged_initial_fee=true
			get_parent().get_parent().charge_expired_pad_fee(self)
		fee_elapsed+=delta
		while fee_elapsed>=maxf(.1,expired_fee_interval):
			fee_elapsed-=maxf(.1,expired_fee_interval)
			get_parent().get_parent().charge_expired_pad_fee(self)
	refresh_service_sign()

func meter_percent() -> float:
	return clampf(service_remaining/maxf(.1,serving_duration)*100.0,0.0,100.0)

func meter_text() -> String:
	return "RED PAD • FEE $%d EVERY %ds"%[expired_fee,ceili(expired_fee_interval)] if expired else "SERVING WINDOW  •  %ds remaining"%ceili(service_remaining)

func refresh_service_sign() -> void:
	if has_node("ServiceSurface"):
		var glow := $ServiceSurface.material_override as ShaderMaterial
		glow.set_shader_parameter("glow_color", expired_glow_color if expired else available_glow_color)
		glow.set_shader_parameter("glow_strength", glow_strength)
	if has_node("ServiceSign"):
		$ServiceSign.text="CLOSED\nMOVE TO GREEN" if expired else ("SERVE HERE\n%d seconds"%ceili(service_remaining) if service_started else "SERVE HERE\nOPEN KITCHEN")
	if has_node("WorldMeter"):
		var display=$WorldMeter/DisplayViewport/Progress
		display.value=meter_percent()
		$WorldMeter/DisplayViewport/Time.text="FEE $%d / %ds"%[expired_fee,ceili(expired_fee_interval)] if expired else "%ds"%ceili(service_remaining)
		display.add_theme_stylebox_override("fill",display.get_meta("red_fill") if expired else display.get_meta("green_fill"))

func release_patron(patron: Node) -> void:
	patrons.erase(patron)

func contains_truck(truck: Node3D) -> bool:
	var local=to_local(truck.global_position)
	var size=$ParkingZone.shape.size
	return absf(local.x)<size.x*.5 and absf(local.z)<size.z*.5

func _entered(body: Node3D) -> void:
	if body.has_method("update_suspension"):
		body.parking_pad = self

func _exited(body: Node3D) -> void:
	if body.has_method("update_suspension") and body.parking_pad == self:
		body.parking_pad = null
