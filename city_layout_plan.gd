extends RefCounted

const XS := [-96,-32,32,96]
const ZS := [-112,-48,16,80,144]
var xs: Array = XS.duplicate()
var zs: Array = ZS.duplicate()
var verticals: Array = [-128,-64,0,64,128]
var horizontals: Array = [-144,-80,-16,48,112,176]
var bounds := Rect2(-144,-160,288,352)
var street_bounds := Rect2(-128,-144,256,320)
var blocks := {}
var exits: Array[Dictionary] = []
var arteries := {}
var directions := {}
var plots := {}
var artery_types := {}
var segment_cache := {}
var planned := false

func key(vertical: bool, coordinate: float) -> Vector2i:
	return Vector2i(1 if vertical else 0, roundi(coordinate))

func generate(seed_value: int, parks: Array[Vector2i], preference: int = 1, padding_min: float = 14, padding_max: float = 22) -> void:
	planned = true
	blocks.clear(); exits.clear(); arteries.clear(); artery_types.clear(); directions.clear(); plots.clear(); segment_cache.clear()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + 33901
	xs = XS.duplicate() if preference == 1 else [-96,-32,32]
	zs = ZS.duplicate() if preference == 1 else [-112,-48,16,80]
	verticals.clear(); horizontals.clear()
	for x in xs: verticals.append(x - 32)
	verticals.append(xs.back() + 32)
	for z in zs: horizontals.append(z - 32)
	horizontals.append(zs.back() + 32)
	street_bounds = Rect2(Vector2(verticals.front(),horizontals.front()),Vector2(verticals.back()-verticals.front(),horizontals.back()-horizontals.front()))
	var low := maxf(12,padding_min)
	var high := maxf(low,padding_max)
	var margins := Vector4(random.randf_range(low,high),random.randf_range(low,high),random.randf_range(low,high),random.randf_range(low,high))
	bounds = Rect2(street_bounds.position-Vector2(margins.x,margins.y),street_bounds.size+Vector2(margins.x+margins.z,margins.y+margins.w))
	var candidates: Array[Dictionary] = []
	for side in [-1.0,1.0]:
		for x in verticals.slice(1,verticals.size()-1): candidates.append({"center":Vector2(x,bounds.position.y+3 if side<0 else bounds.end.y-3),"vertical":true,"side":side})
		for z in horizontals.slice(1,horizontals.size()-1): candidates.append({"center":Vector2(bounds.position.x+3 if side<0 else bounds.end.x-3,z),"vertical":false,"side":side})
	exits.append(candidates[random.randi_range(0,candidates.size()-1)])
	var wanted := random.randi_range(3,5)
	while exits.size()<wanted:
		var best: Dictionary = {}; var score := -1.0
		for candidate in candidates:
			var distance := INF
			for chosen in exits: distance = minf(distance,candidate.center.distance_to(chosen.center))
			if distance>score: best=candidate; score=distance
		if score < 100 and exits.size() >= 3: break
		exits.append(best)
	for exit in exits: arteries[key(exit.vertical,exit.center.x if exit.vertical else exit.center.y)] = true
	# These transverse streets connect every exit artery and guarantee a shared network.
	arteries[key(true,0)] = true
	arteries[key(false,-16)] = true
	if random.randf()<.35: arteries[key(false,48)] = true
	var cells: Array[Vector2i] = []
	for x in xs:
		for z in zs: cells.append(Vector2i(x,z))
	var order := cells.duplicate()
	for i in range(order.size()-1,0,-1):
		var j := random.randi_range(0,i); var previous: Vector2i = order[i]; order[i]=order[j]; order[j]=previous
	for cell in order:
		if not edge_cell(cell) or blocks.has(cell) or cell in parks or random.randf()>.85: continue
		var step := Vector2i(64,0) if cell.y in [zs.front(),zs.back()] else Vector2i(0,64)
		if random.randf()<.5: step = -step
		var members: Array[Vector2i] = [cell]
		for i in range(1,random.randi_range(2,3)):
			var next: Vector2i = cell+step*i
			var crossing := (Vector2(members.back())+Vector2(next))*.5
			if next not in cells or not edge_cell(next) or next in parks or blocks.has(next) or arteries.has(key(step.x!=0,crossing.x if step.x!=0 else crossing.y)): break
			members.append(next)
		var rectangle := Rect2(Vector2(cell)-Vector2(32,32),Vector2(64,64))
		for member in members: rectangle=rectangle.merge(Rect2(Vector2(member)-Vector2(32,32),Vector2(64,64)))
		for member in members: blocks[member]=rectangle
	for cell in cells:
		if not blocks.has(cell): blocks[cell]=Rect2(Vector2(cell)-Vector2(32,32),Vector2(64,64))
	for vertical in [true,false]:
		for coordinate in (verticals if vertical else horizontals):
			var road := key(vertical,coordinate)
			var ends: Array = verticals if vertical else horizontals
			if coordinate in [ends.front(),ends.back()]: continue
			var chance := .04 if arteries.has(road) else .35
			# Highway approaches must support both departure and arrival.
			if exit_exists(vertical,coordinate,-1) or exit_exists(vertical,coordinate,1): chance = 0
			if random.randf()<chance: directions[road]=-1 if random.randf()<.5 else 1
	# Repair one-way choices until the street graph is strongly connected.
	for road in directions.keys():
		if directed_connected(): break
		directions.erase(road)
	for cell in blocks: plots[cell]="green" if cell in parks or random.randf()<.33 else "grey"
	for cell in blocks:
		if not primary(Vector2(cell)): continue
		for member in blocks:
			if blocks[member]==blocks[cell]: plots[member]=plots[cell]
	var adjacent := {}
	for cell in plots:
		if plots[cell]!="green": continue
		for step in [Vector2i(64,0),Vector2i(-64,0),Vector2i(0,64),Vector2i(0,-64)]:
			if plots.get(cell+step,"grey")=="green": adjacent[cell]=true; adjacent[cell+step]=true
	for cell in plots:
		if adjacent.has(cell) or cell in parks: plots[cell]="park"
	artery_types.clear()
	for road in arteries:
		artery_types[road] = "street_level"
		directions.erase(road)
	var bridge_random := RandomNumberGenerator.new()
	bridge_random.seed = seed_value + 33903
	artery_types[key(true,0) if bridge_random.randf() < .5 else key(false,-16)] = "bridge"

func use_original_grid() -> void:
	# Restore equal rectangular blocks and ground-level streets, before artery planning.
	blocks.clear()
	segment_cache.clear()
	arteries.clear()
	artery_types.clear()
	for x in xs:
		for z in zs:
			blocks[Vector2i(x,z)] = Rect2(Vector2(x-32,z-32),Vector2(64,64))

func use_earlier_islands() -> void:
	use_original_grid()
	directions.clear()
	directions[key(true, -64)] = 1
	if 112 in horizontals: directions[key(false, 112)] = -1

func artery_kind(vertical: bool, coordinate: float) -> String:
	return artery_types.get(key(vertical,coordinate),"inner")

func directed_connected() -> bool:
	var points: Array[Vector2] = []
	for x in verticals:
		for z in horizontals: points.append(Vector2(x,z))
	for reverse in [false,true]:
		var seen := {points[0]:true}; var pending := [points[0]]
		while not pending.is_empty():
			var point: Vector2 = pending.pop_back()
			for delta in [Vector2(64,0),Vector2(-64,0),Vector2(0,64),Vector2(0,-64)]:
				var next: Vector2 = point+delta
				if next not in points or seen.has(next): continue
				var vertical: bool = delta.y!=0
				var middle := (point+next)*.5
				if not road_exists(vertical,point.x if vertical else point.y,middle.y if vertical else middle.x): continue
				var direction := one_way(vertical,point.x if vertical else point.y)
				if direction!=0 and (delta.y if vertical else delta.x)*direction*(-1 if reverse else 1)<0: continue
				seen[next]=true; pending.append(next)
		if seen.size()!=points.size(): return false
	return true

func edge_cell(cell: Vector2i) -> bool: return cell.x in [xs.front(),xs.back()] or cell.y in [zs.front(),zs.back()]
func one_way(vertical: bool, coordinate: float) -> int: return int(directions.get(key(vertical,coordinate),0))
func plot_kind(center: Vector2) -> String: return plots.get(Vector2i(center),"grey")
func park_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in plots:
		if plots[cell]=="park": result.append(cell)
	return result
func bounds_for(center: Vector2) -> Rect2: return blocks.get(Vector2i(center),Rect2(center-Vector2(32,32),Vector2(64,64)))
func primary(center: Vector2) -> bool: return blocks.has(Vector2i(center)) and center.is_equal_approx(bounds_for(center).position+Vector2(32,32))
func exit_exists(vertical: bool, coordinate: float, side: float) -> bool:
	for exit in exits:
		if exit.vertical==vertical and exit.side==side and is_equal_approx(exit.center.x if vertical else exit.center.y,coordinate): return true
	return false
func segments(vertical: bool, coordinate: float, extent: float, half_road: float) -> Array[Vector2]:
	var cache_key := Vector4(1 if vertical else 0,coordinate,extent,half_road)
	if segment_cache.has(cache_key): return segment_cache[cache_key]
	var result: Array[Vector2] = []
	var present := false
	for value in (verticals if vertical else horizontals):
		if is_equal_approx(float(value),coordinate): present = true; break
	if not present: return result
	var low: float = street_bounds.position.y if vertical else street_bounds.position.x
	var high: float = street_bounds.end.y if vertical else street_bounds.end.x
	if exit_exists(vertical,coordinate,-1): low=(bounds.position.y if vertical else bounds.position.x)-40
	if exit_exists(vertical,coordinate,1): high=(bounds.end.y if vertical else bounds.end.x)+40
	result.append(Vector2(low,high))
	var seen := {}
	for rectangle in blocks.values():
		if seen.has(rectangle): continue
		seen[rectangle]=true
		if coordinate<=(rectangle.position.x if vertical else rectangle.position.y) or coordinate>=(rectangle.end.x if vertical else rectangle.end.y): continue
		var cut_low: float = (rectangle.position.y if vertical else rectangle.position.x)+half_road
		var cut_high: float = (rectangle.end.y if vertical else rectangle.end.x)-half_road
		var remaining: Array[Vector2] = []
		for span in result:
			if cut_high<=span.x or cut_low>=span.y: remaining.append(span)
			else:
				if cut_low>span.x: remaining.append(Vector2(span.x,cut_low))
				if cut_high<span.y: remaining.append(Vector2(cut_high,span.y))
		result=remaining
	segment_cache[cache_key]=result
	return result
func road_exists(vertical: bool, coordinate: float, along: float, extent: float = 256, half_road: float = 8) -> bool:
	for span in segments(vertical,coordinate,extent,half_road):
		if along>=span.x and along<=span.y: return true
	return false
