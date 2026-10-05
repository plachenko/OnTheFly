extends Node3D

@export_range(6,120,6) var crowd_size := 36
var round_finished := false
var remaining_time := 3600.0
var ingredients := 1000
var money := 500
var money_earned := 0
var order_experience := 10
var service_waves: Node
var repair_pad: Node
var food_menu: Array = []
var attraction := true
var avoidance := true
var contacts := 0
var contact_pairs: Dictionary = {}
var camera: Camera3D
var stats: Label
var serving_pad: Area3D
@onready var truck = $FoodTruck
@onready var manager = $PatronManager

func _ready() -> void:
	var food = preload("res://food_menu_item.gd").new()
	food.food_name = "Test taco"
	food.price = 6
	food_menu.append(food)
	surface(Vector3(90,1,110),Vector3(0,-.5,0),Color("37434d"),true)
	for x in [-12,12]: surface(Vector3(5,.18,100),Vector3(x,.03,0),Color("aab5b9"),true)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("8ba7ba")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	add_child(sun)
	serving_pad = Area3D.new()
	serving_pad.name = "CrowdServiceBay"
	serving_pad.set_script(preload("res://parking_pad.gd"))
	serving_pad.serving_duration = 3600
	serving_pad.attraction_radius = 28
	serving_pad.patron_capacity = 12
	serving_pad.position = Vector3(0,0,-22)
	var zone := CollisionShape3D.new()
	zone.name = "ParkingZone"
	zone.shape = BoxShape3D.new()
	zone.shape.size = Vector3(10,4,12)
	serving_pad.add_child(zone)
	$ParkingPads.add_child(serving_pad)
	surface(Vector3(10,.02,12),Vector3(0,.02,-22),Color("1e9f66"),false)
	camera = Camera3D.new()
	camera.fov = 65
	add_child(camera)
	camera.make_current()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,16)
	panel.custom_minimum_size = Vector2(330,0)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	stats = Label.new()
	column.add_child(stats)
	var count := HSlider.new()
	count.min_value = 6; count.max_value = 120; count.step = 6; count.value = crowd_size
	count.custom_minimum_size.x = 300
	column.add_child(count)
	count.value_changed.connect(func(value): crowd_size = int(value); reset_crowd())
	var attract := CheckButton.new()
	attract.text = "Attraction enabled"; attract.button_pressed = true
	column.add_child(attract)
	attract.toggled.connect(set_attraction)
	var dodge := CheckButton.new()
	dodge.text = "Patrons dodge approaching truck"; dodge.button_pressed = true
	column.add_child(dodge)
	dodge.toggled.connect(func(value): avoidance = value)
	var threshold_label := Label.new()
	threshold_label.text = "Minimum interest for attraction"
	column.add_child(threshold_label)
	var threshold := HSlider.new()
	threshold.min_value = 0; threshold.max_value = 1; threshold.step = .05; threshold.value = manager.attraction_interest_threshold
	column.add_child(threshold)
	threshold.value_changed.connect(func(value): manager.attraction_interest_threshold = value)
	for spec in [["Reset crowd + truck",reset_crowd],["Park truck + open kitchen",park_and_open],["Return to menu",func(): LoadingScreen.load_scene("res://main_menu.tscn")]]:
		var button := Button.new(); button.text = spec[0]; button.pressed.connect(spec[1]); column.add_child(button)
	reset_crowd()

func surface(size: Vector3, at: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new(); mesh.mesh = BoxMesh.new(); mesh.mesh.size = size
	var material := StandardMaterial3D.new(); material.albedo_color = color; mesh.material_override = material
	if solid:
		var body := StaticBody3D.new(); body.position = at
		var shape := CollisionShape3D.new(); shape.shape = BoxShape3D.new(); shape.shape.size = size
		body.add_child(shape); body.add_child(mesh); add_child(body)
	else: mesh.position = at; add_child(mesh)

func reset_crowd() -> void:
	for patron in $Patrons.get_children(): patron.cancel_order(); patron.free()
	seed(41027)
	contacts = 0; contact_pairs.clear(); manager.served_orders = 0
	ingredients = 1000; money = 500; money_earned = 0
	serving_pad.expired = false; serving_pad.service_started = false; serving_pad.service_remaining = 3600
	truck.spawn_transform = Transform3D(Basis.IDENTITY,Vector3(0,.2,18))
	truck.reset_truck(); truck.parking_pad = null
	for i in crowd_size:
		var patron = preload("res://scenes/hungry_patron.tscn").instantiate()
		patron.manager = manager
		patron.home_position = Vector3((i%6-2.5)*1.65,.2,-7-floorf(float(i)/6.0)*2.1)
		patron.wander_radius = 4; patron.sidewalk_min_z = -45; patron.sidewalk_max_z = 8
		patron.character_variant = i%4; patron.appearance_color_index = i%6
		patron.interest = .15+float(i%6)*.16; patron.budget = 36
		$Patrons.add_child(patron); patron.global_position = patron.home_position

func park_and_open() -> void:
	truck.spawn_transform = Transform3D(Basis.IDENTITY,Vector3(0,.2,-22))
	truck.reset_truck(); truck.parking_pad = serving_pad
	truck.deployed = true; truck.opening = 1

func set_attraction(value: bool) -> void:
	attraction = value
	if not value: cancel_orders()

func cancel_orders() -> void:
	for patron in $Patrons.get_children(): patron.cancel_order()

func active_serving_pad() -> Node3D:
	return serving_pad if attraction and truck.deployed and truck.opening > .99 and absf(truck.speed) < .5 and serving_pad.contains_truck(truck) else null
func has_ingredients() -> bool: return ingredients > 0
func can_open_shop(body: Node) -> bool: return serving_pad.contains_truck(body)
func can_repair() -> bool: return false
func award_experience(_amount: int) -> void: pass
func charge_expired_pad_fee(_pad: Node) -> void: pass

func _physics_process(_delta: float) -> void:
	if not avoidance:
		for patron in $Patrons.get_children(): patron.dodge_cooldown = .5
	var touching: Dictionary = {}
	for i in truck.get_slide_collision_count():
		var body = truck.get_slide_collision(i).get_collider()
		if body.is_in_group("patrons"):
			touching[body.get_instance_id()] = true
			if not contact_pairs.has(body.get_instance_id()): contacts += 1
	contact_pairs = touching

func _process(delta: float) -> void:
	var desired: Vector3 = truck.global_position+truck.global_basis.z*19+Vector3.UP*13
	camera.global_position = camera.global_position.lerp(desired,1-exp(-delta*6))
	camera.look_at(truck.global_position+Vector3(0,1.5,-3))
	var dodges := 0; var queued := 0
	for patron in $Patrons.get_children():
		dodges += patron.dodge_count
		if not patron.order.is_empty(): queued += 1
	stats.text = "PATRON CROWD TEST | %d patrons\nContacts %d | Dodges %d | Queued %d\nServed %d | Truck damage %.0f%%\nInterest threshold %.0f%%\nDrive through crowd or park on green.\nNormal driving controls | E: kitchen" % [crowd_size,contacts,dodges,queued,manager.served_orders,100*(1-truck.health/truck.max_health),manager.attraction_interest_threshold*100]
