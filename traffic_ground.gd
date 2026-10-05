extends RefCounted

# Share static surface samples across traffic; avoid evaluating terrain noise for
# every car, wheel and predicted picture on every frame.
const STEP := 1.0
static func height(city: Node3D, x: float, z: float) -> float:
	if city == null: return 0.0
	var cache: Dictionary = city.get_meta("traffic_ground_samples",{})
	if not city.has_meta("traffic_ground_samples"): city.set_meta("traffic_ground_samples",cache)
	if cache.size() > 32768:
		var keys := cache.keys()
		for index in 1024: cache.erase(keys[index])
	var cell := Vector2(floorf(x/STEP),floorf(z/STEP))
	var fraction := Vector2(x/STEP,z/STEP)-cell
	var heights: Array[float] = []
	for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
		var key: Vector2 = cell+offset
		if not cache.has(key):
			cache[key] = city.road_visual_height_at(key.x*STEP,key.y*STEP) if city.has_method("road_visual_height_at") else city.height_at(key.x*STEP,key.y*STEP)
		heights.append(cache[key])
	return lerpf(lerpf(heights[0],heights[1],fraction.x),lerpf(heights[2],heights[3],fraction.x),fraction.y)

static func sample(city: Node3D, point: Vector3) -> Dictionary:
	var y := height(city,point.x,point.z)
	var dx := (height(city,point.x+.5,point.z)-height(city,point.x-.5,point.z))
	var dz := (height(city,point.x,point.z+.5)-height(city,point.x,point.z-.5))
	return {"position":Vector3(point.x,y+.09,point.z),"normal":Vector3(-dx,1,-dz).normalized()}
