extends Node
@export var patron_scene: PackedScene
@export_range(0,60) var maximum_patrons: int = 12
@export_range(1,8) var maximum_order_items: int = 3
@export var seconds_per_item: float = 1.2
@export_range(0,1) var attraction_interest_threshold: float = .35
@export_range(0,1) var interest_after_meal: float = .2
@export var fed_cooldown: float = 25.0
@export_range(0, 12) var outside_window_patrons := 3
@export var outside_window_spawn_interval := 8.0
var spawn_counts: Dictionary = {}
var spawn_timers: Dictionary = {}
var served_orders: int = 0
var last_sale: String = "No orders yet."
@onready var level=get_parent()

func _process(delta: float) -> void:
    if not PerformanceDiagnostics.pedestrian_logic_enabled:return
    if not level.is_processing() or level.round_finished:return
    spawn_patrons(delta)
    var active=level.active_serving_pad()
    for pad in level.get_node("ParkingPads").get_children():
        var open_at_pad=level.truck.parking_pad==pad and pad!=level.repair_pad and pad.contains_truck(level.truck) and level.truck.deployed and level.truck.opening>.99 and absf(level.truck.speed)<.5 and level.truck.health>0
        pad.tick_service(delta,pad==active,open_at_pad)
        if pad.has_node("WorldMeter"):
            pad.get_node("WorldMeter").visible=not open_at_pad
    if active and active.expired:active=null
    for patron in level.get_node("Patrons").get_children():
        if patron.pad and (patron.pad!=active or patron.pad.expired):patron.cancel_order()
        if active and not patron.pad and patron.can_be_attracted() and active.patrons.size()<active.patron_capacity:
            if patron.global_position.distance_to(active.global_position)<=active.attraction_radius:
                var order=make_order(patron)
                if order.total>0:patron.accept_order(active,order)

@export var building_spawn_interval := 4.0
var building_entrances: Array[Node3D] = []
var next_entrance := 0
var building_spawn_elapsed := 0.0

func configure_building_entrances() -> void:
    if not building_entrances.is_empty(): return
    var city := level.get_node_or_null("ProceduralCity")
    if city != null and city.generating: return
    var anchors := level.get_node("PatronSpawns").get_children()
    var buildings: Array = city.get_node("Buildings").get_children() if city != null else []
    var used: Array = []
    for index in mini(3, anchors.size()):
        var anchor: Node3D = anchors[index]
        var position := anchor.global_position
        var nearest: Node3D
        var gap := INF
        for building in buildings:
            if building in used: continue
            var collision := building.get_node_or_null("BuildingCollision") as CollisionShape3D
            if collision == null or not collision.shape is BoxShape3D: continue
            var distance: float = building.global_position.distance_squared_to(anchor.global_position)
            if distance < gap:
                gap = distance
                nearest = building
        var marker := preload("res://patron_spawn.gd").new()
        marker.name = "BuildingEntrance_%d" % (index + 1)
        marker.spawn_interval = building_spawn_interval
        marker.wander_radius = 4.0
        marker.patron_limit = 4
        if nearest != null:
            used.append(nearest)
            var collider: CollisionShape3D = nearest.get_node("BuildingCollision")
            var box := collider.shape as BoxShape3D
            var local := collider.to_local(anchor.global_position)
            var half := box.size * 0.5
            if absf(local.x / maxf(half.x, 0.1)) > absf(local.z / maxf(half.z, 0.1)):
                local = Vector3((half.x + 1.5) * (1.0 if local.x >= 0 else -1.0), 0, clampf(local.z, -half.z, half.z))
                marker.set_meta("wander_axis", collider.global_basis.z.normalized())
            else:
                local = Vector3(clampf(local.x, -half.x, half.x), 0, (half.z + 1.5) * (1.0 if local.z >= 0 else -1.0))
                marker.set_meta("wander_axis", collider.global_basis.x.normalized())
            position = collider.to_global(local)
            marker.set_meta("building", str(nearest.name))
        level.get_node("PatronSpawns").add_child(marker)
        if city != null: position.y = city.height_at(position.x, position.z) + 0.1
        marker.global_position = position
        building_entrances.append(marker)

func spawn_patrons(delta: float) -> void:
    if not PerformanceDiagnostics.pedestrian_logic_enabled: return
    configure_building_entrances()
    if building_entrances.size() != 3: return
    # A global cap prevents dense city settings from creating an ever-growing crowd.
    if level.get_node("Patrons").get_child_count() >= mini(maximum_patrons, 12): return
    building_spawn_elapsed += delta
    if building_spawn_elapsed < building_spawn_interval: return
    building_spawn_elapsed = 0.0
    var point := building_entrances[next_entrance]
    next_entrance = (next_entrance + 1) % 3
    if spawn_counts.get(point, 0) >= point.patron_limit: return
    var patron = patron_scene.instantiate()
    patron.manager = self
    patron.set_meta("spawn_point", point)
    patron.home_position = point.global_position
    patron.wander_radius = point.wander_radius
    patron.wander_axis = point.get_meta("wander_axis", Vector3.FORWARD)
    patron.interest = randf_range(0.65, 1.0)
    patron.budget = randi_range(18, 32)
    patron.position = level.get_node("Patrons").to_local(point.global_position)
    spawn_counts[point] = spawn_counts.get(point, 0) + 1
    patron.tree_exiting.connect(release_building_slot.bind(point))
    level.get_node("Patrons").add_child(patron)

func release_building_slot(point: Node3D) -> void:
    spawn_counts[point] = maxi(0, spawn_counts.get(point, 0) - 1)

func make_order(patron: Node) -> Dictionary:
    var remaining=patron.budget
    var total=0
    var items: Array[String] = []
    var quantity=clampi(ceili(patron.interest*maximum_order_items),1,maximum_order_items)
    var available_portions: int = level.ingredients
    for waiting in level.get_node("Patrons").get_children():
        if not waiting.order.is_empty():
            available_portions -= int(waiting.order.get("quantity", 0))
    quantity = mini(quantity, maxi(0, available_portions))
    for i in quantity:
        var affordable: Array = []
        for food in level.food_menu:
            if food and food.price>0 and food.price<=remaining:affordable.append(food)
        if affordable.is_empty():break
        var food=affordable.pick_random()
        items.append(food.food_name)
        total+=food.price
        remaining-=food.price
    return {"items":items,"total":total,"quantity":items.size()}

func complete_order(patron: Node) -> bool:
    if level.round_finished or level.remaining_time<=0 or not patron.pad or patron.pad!=level.active_serving_pad() or patron.pad.expired:return false
    if patron.order.is_empty() or patron.order.total<=0 or patron.order.total>patron.budget:return false
    if patron.service_elapsed<patron.order.quantity*seconds_per_item:return false
    if patron.global_position.distance_to(patron.queue_target())>1.1:return false
    if patron.order.quantity > level.ingredients:return false
    level.ingredients -= patron.order.quantity
    var total: int=patron.order.total
    level.money+=total
    level.money_earned+=total
    level.award_experience(level.order_experience)
    served_orders+=1
    last_sale="Sold %s  +$%d / +%d XP"%[", ".join(patron.order.items),total,level.order_experience]
    patron.budget-=total
    patron.interest*=interest_after_meal
    patron.cooldown=fed_cooldown
    patron.has_eaten=true
    patron.cancel_order()
    patron.begin_departure()
    return true
