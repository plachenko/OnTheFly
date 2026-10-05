extends StaticBody3D

@export var reinforced := false
@export var portions := 10
var collected := false
var trigger: Area3D

func _ready() -> void:
	name = "ReinforcedIngredients" if reinforced else "IngredientBox"
	collision_layer = 1 if reinforced else 0
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5)
	var solid := CollisionShape3D.new()
	solid.shape = shape
	solid.position.y = .75
	add_child(solid)
	box(Vector3(1.5,1.5,1.5), Vector3(0,.75,0), Color("687785") if reinforced else Color("b88245"), reinforced)
	for x in [-.65,.65]:
		box(Vector3(.14,1.62,1.62), Vector3(x,.75,0), Color("d4dae0") if reinforced else Color("704724"), reinforced)
	if reinforced:
		for z in [-.77,.77]:
			box(Vector3(1.5,.22,.06), Vector3(0,.35,z), Color("ffb52e"), false)
	var label := Label3D.new()
	label.text = "INGREDIENTS +%d\n%s" % [portions, "METAL • BOOST TO BREAK" if reinforced else "DRIVE INTO BOX"]
	label.position.y = 2.15
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffcc55") if reinforced else Color("aaffaa")
	add_child(label)
	trigger = Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var detection := CollisionShape3D.new()
	var detection_shape := BoxShape3D.new()
	detection_shape.size = Vector3(1.8,1.8,1.8)
	detection.shape = detection_shape
	detection.position.y = .8
	trigger.add_child(detection)
	add_child(trigger)

func box(size: Vector3, at: Vector3, color: Color, metal: bool) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = .8 if metal else 0.0
	material.roughness = .35 if metal else .85
	visual.material_override = material
	add_child(visual)

func _physics_process(_delta: float) -> void:
	for body in trigger.get_overlapping_bodies():
		collect_by_truck(body)

func collect_by_truck(vehicle: Node) -> bool:
	if collected: return true
	if not vehicle is CharacterBody3D or not "boost_active" in vehicle: return false
	if reinforced and not vehicle.boost_active: return false
	var level := vehicle.get_parent()
	if not "ingredients" in level or not "ingredient_capacity" in level: return false
	var amount: int = mini(portions, maxi(0, level.ingredient_capacity - level.ingredients))
	if amount == 0:
		vehicle.message = "Ingredient supply full"
		vehicle.message_timer = 1.5
		return false
	level.ingredients += amount
	collected = true
	collision_layer = 0
	vehicle.message = "+%d ingredients%s" % [amount, " — metal crate smashed!" if reinforced else ""]
	vehicle.message_timer = 2.5
	hide()
	queue_free()
	return true
