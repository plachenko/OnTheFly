extends Control

# Draw the actual generated topology, not an illustrative random map.
var plan: RefCounted
var phase := 0
var spawn := Vector2.ZERO
var zoom := 0.0:
	set(value):
		zoom = value
		queue_redraw()

func reset() -> void:
	plan = null
	phase = 0
	zoom = 0.0
	position = Vector2.ZERO
	hide()

func reveal(topology: RefCounted, step: int) -> void:
	plan = topology
	phase = maxi(1,step)
	show()
	queue_redraw()

func point(world: Vector2) -> Vector2:
	var scale_factor: float = minf(size.x * .65 / plan.bounds.size.x, size.y * .50 / plan.bounds.size.y)
	var center: Vector2 = plan.bounds.get_center().lerp(spawn, zoom)
	return Vector2(size.x*.5,size.y*.4) + (world - center) * scale_factor * lerpf(1.0, 12.0, zoom)

func _draw() -> void:
	if plan == null: return
	var boundary := Rect2(point(plan.bounds.position), point(plan.bounds.end) - point(plan.bounds.position))
	draw_rect(boundary, Color("122c31"))
	draw_rect(boundary, Color("a7c9c3"), false, 2.0)
	if phase >= 4:
		var seen := {}
		for cell in plan.blocks:
			var rectangle: Rect2 = plan.blocks[cell]
			if seen.has(rectangle): continue
			seen[rectangle] = true
			var inset := rectangle.grow(-12.0)
			var area := Rect2(point(inset.position), point(inset.end) - point(inset.position))
			var green: bool = plan.plots[cell] != "grey"
			draw_rect(area, Color("426d4c") if green else Color("75858b"))
			if phase >= 5: draw_rect(area.grow(2.0), Color("d4d8bf"), false, 1.5)
	if phase >= 2:
		for vertical in [true, false]:
			for coordinate in (plan.verticals if vertical else plan.horizontals):
				var artery: bool = plan.arteries.has(plan.key(vertical, coordinate))
				if not artery and phase < 3 and not plan.arteries.is_empty(): continue
				for span in plan.segments(vertical, coordinate, 256, 8):
					var a := Vector2(coordinate, span.x) if vertical else Vector2(span.x, coordinate)
					var b := Vector2(coordinate, span.y) if vertical else Vector2(span.y, coordinate)
					a = a.clamp(plan.bounds.position, plan.bounds.end)
					b = b.clamp(plan.bounds.position, plan.bounds.end)
					draw_line(point(a), point(b), Color("f1be65") if artery else Color("91bcb9"), 4.0 if artery else 1.5, true)
	if phase >= 1:
		for exit in plan.exits: draw_circle(point(exit.center), 5.0, Color("ec775a"))
	if phase >= 6:
		for x in plan.verticals:
			for z in plan.horizontals:
				draw_circle(point(Vector2(x,z)), 2.0, Color("ffe4a0"))
	if phase >= 7:
		draw_circle(point(spawn), 8.0, Color("54f5b2"))
		draw_arc(point(spawn), 13.0, 0, TAU, 32, Color("54f5b2"), 2.0, true)
