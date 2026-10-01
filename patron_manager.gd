extends Node
@export var patron_scene: PackedScene
@export_range(0,60) var maximum_patrons: int = 12
@export_range(1,8) var maximum_order_items: int = 3
@export var seconds_per_item: float = 1.2
@export_range(0,1) var attraction_interest_threshold: float = .35
@export_range(0,1) var interest_after_meal: float = .2
@export var fed_cooldown: float = 25.0
var spawn_counts: Dictionary = {}
var spawn_timers: Dictionary = {}
var served_orders: int = 0
var last_sale: String = "No orders yet."
@onready var level=get_parent()

func _process(delta: float) -> void:
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

func spawn_patrons(delta: float) -> void:
    for point in level.get_node("PatronSpawns").get_children():
        if level.get_node("Patrons").get_child_count()>=maximum_patrons:return
        if spawn_counts.get(point,0)>=point.patron_limit:continue
        spawn_timers[point]=spawn_timers.get(point,0.0)-delta
        if spawn_timers[point]>0:continue
        spawn_timers[point]=maxf(.1,point.spawn_interval)
        var patron=patron_scene.instantiate()
        patron.manager=self
        patron.home_position=point.global_position
        patron.wander_radius=point.wander_radius
        var crossings=level.get_node_or_null("ProceduralCity/Crosswalks")
        if crossings and crossings.get_child_count()>0:
            var nearest: Node3D=null
            var nearest_distance=INF
            for crossing in crossings.get_children():
                var gap=Vector2(crossing.global_position.x-point.global_position.x,crossing.global_position.z-point.global_position.z).length_squared()
                if gap<nearest_distance:
                    nearest_distance=gap
                    nearest=crossing
            patron.crosswalk=nearest
        patron.sidewalk_min_z=point.sidewalk_min_z
        patron.sidewalk_max_z=point.sidewalk_max_z
        patron.interest=randf_range(minf(point.minimum_interest,point.maximum_interest),maxf(point.minimum_interest,point.maximum_interest))
        patron.budget=randi_range(mini(point.minimum_budget,point.maximum_budget),maxi(point.minimum_budget,point.maximum_budget))
        level.get_node("Patrons").add_child(patron)
        patron.global_position=point.global_position+Vector3(0,0,randf_range(-1.5,1.5))
        spawn_counts[point]=spawn_counts.get(point,0)+1

func make_order(patron: Node) -> Dictionary:
    var remaining=patron.budget
    var total=0
    var items: Array[String] = []
    var quantity=clampi(ceili(patron.interest*maximum_order_items),1,maximum_order_items)
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
    var total: int=patron.order.total
    level.money+=total
    level.money_earned+=total
    served_orders+=1
    last_sale="Sold %s  +$%d"%[", ".join(patron.order.items),total]
    patron.budget-=total
    patron.interest*=interest_after_meal
    patron.cooldown=fed_cooldown
    patron.has_eaten=true
    patron.cancel_order()
    patron.get_node("Status").text="Fed!"
    return true
