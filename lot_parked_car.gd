extends StaticBody3D

@export var model_key := "sedan"
@export var body_color := Color("536b80")
var visual: Node3D
var proxy: Node3D
var card: MeshInstance3D
var jolt_elapsed := 1.0
var hit_count := 0
var cooldown := 0.0

func _ready() -> void:
	add_to_group("lot_parked_cars")
	visual = Node3D.new(); visual.name = "LotCarVisual"; add_child(visual)
	proxy = Node3D.new(); visual.add_child(proxy)
	for part in [[Vector3(2.1,.7,4.5),Vector3(0,.6,0),body_color],[Vector3(1.8,.65,2.4),Vector3(0,1.2,.1),Color("293b47")]]:
		var mesh := MeshInstance3D.new(); mesh.mesh = BoxMesh.new(); mesh.mesh.size = part[0]
		mesh.position = part[1]
		var material := StandardMaterial3D.new(); material.albedo_color = part[2]; mesh.material_override = material
		proxy.add_child(mesh)
	set_process(false)

func set_sprite(material: ShaderMaterial, entry: Dictionary) -> void:
	if card != null: return
	card = MeshInstance3D.new(); card.name = "ParkedCarBillboard"
	var quad := QuadMesh.new()
	quad.size = Vector2(float(entry.world_height)*256.0/192.0,float(entry.world_height))
	card.mesh = quad; card.position = Vector3(entry.center[0],entry.center[1],entry.center[2])
	card.material_override = material; card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var radius := quad.size.length()*.5
	card.custom_aabb = AABB(Vector3.ONE*-radius,Vector3.ONE*radius*2)
	visual.add_child(card); proxy.hide()

func release_sprite() -> void:
	if card != null: card.free(); card = null
	proxy.show()

func receive_lot_contact(strength: float) -> void:
	if strength < 1 or cooldown > 0: return
	hit_count += 1; cooldown = .7; jolt_elapsed = 0
	set_process(true)

func _process(delta: float) -> void:
	jolt_elapsed += delta; cooldown = maxf(0,cooldown-delta)
	var envelope := exp(-jolt_elapsed*7)
	visual.position.x = sin(jolt_elapsed*36)*.18*envelope
	visual.rotation.z = sin(jolt_elapsed*29)*.08*envelope
	if jolt_elapsed >= .8:
		visual.position = Vector3.ZERO; visual.rotation = Vector3.ZERO; set_process(false)
