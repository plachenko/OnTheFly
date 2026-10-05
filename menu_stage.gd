extends RefCounted

var saved_city := false
var source := ""
var poses: Array[Dictionary] = []
var frozen: Array[Dictionary] = []
var hidden: Array[Node3D] = []
var stop := Vector3.ZERO
var elapsed := 0.0
var brake_settled := false
var scenery: Node3D
var signal_node: Node3D
var framing_control: Node3D
var environment_node: WorldEnvironment
var environment_backup: Environment
var sun_backup: Array[Dictionary] = []
var vehicle_backup: Array[Dictionary] = []
var signal_backup: Array[Dictionary] = []
var camera_settle_seconds := 5.5
var map_approach_seconds := 3.0
var framing_distance := 0.0
var previous_camera_position := Vector3.INF
var comic_silhouette: Node3D
var ground_fill: MeshInstance3D
var truck_exaggeration_backup: RefCounted
var menu_idle: RefCounted

static func idle_pose(time: float) -> Dictionary:
	return preload("res://truck_idle_motion.gd").idle_pose(time)

static func idle_profile() -> Dictionary:
	return preload("res://truck_idle_motion.gd").idle_profile()
var sun_direction := Vector3(0,.65,-1).normalized()

func prepare(menu: Node) -> void:
	var candidate: Node = load("res://procedural_city.tscn").instantiate()
	var city: Node = candidate.get_node("ProceduralCity")
	city.map_size = CityStore.preferred_size
	city.original_grid = CityStore.original_grid
	if menu.use_saved_menu_city:
		for path in [CityStore.private_path(city), CityStore.bundled_path(city)]:
			if not CityStore.city_file_available(path): continue
			if ResourceLoader.load_threaded_request(path,"Resource",false) != OK: continue
			while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await menu.get_tree().process_frame
			var data: Resource = ResourceLoader.load_threaded_get(path)
			if data == null or data.get("format_version") != CityStore.FORMAT_VERSION or data.get("settings_hash") != CityStore.settings_hash(city): continue
			source = path
			break
	if not source.is_empty():
		var generate_later := CityStore.generate_next
		CityStore.generate_next = false
		candidate.process_mode = Node.PROCESS_MODE_DISABLED
		candidate.name = "MenuHillCity"
		menu.add_child(candidate)
		while not candidate.is_loading_ready(): await menu.get_tree().process_frame
		CityStore.generate_next = generate_later
		menu.level.queue_free()
		menu.level = candidate
		candidate.process_mode = Node.PROCESS_MODE_INHERIT
		saved_city = true
		choose_stop(city, menu.level.truck)
		for crossing in city.get_node("Crosswalks").get_children():
			if crossing.get("elapsed") == null: continue
			signal_backup.append({"node":crossing,"elapsed":crossing.elapsed})
			crossing.elapsed = crossing.wait_seconds+.1
			crossing.refresh_lights()
		for car in menu.get_tree().get_nodes_in_group("traffic_motion"):
			if not candidate.is_ancestor_of(car): continue
			if Vector2(car.global_position.x,car.global_position.z).distance_to(Vector2(stop.x,stop.z)) > 28: continue
			vehicle_backup.append({"node":car,"visible":car.visible,"layer":car.collision_layer,"mask":car.collision_mask})
			car.hide()
			car.collision_layer = 0
			car.collision_mask = 0
	else:
		candidate.free()
		for node in menu.level.get_children():
			if node is Node3D and node != menu.level.truck and not node is Camera3D and node.visible:
				hidden.append(node)
				node.hide()
		stop = Vector3(0,.16,0)
		menu.level.truck.rotation.y = PI * .5
		make_fallback(menu.level)
	# World service labels should not overlap or disappear into scenery behind menu text.
	for label in menu.level.find_children("*","Label3D",true,false):
		if label.visible: hidden.append(label); label.hide()
	if is_instance_valid(framing_control) and framing_control.has_method("_process"):
		framing_control._process(0)
	if menu.level.truck.billboard != null:
		menu.level.truck.billboard.force_3d = true
		menu.level.truck.billboard.sprite_visibility = 0.0
		menu.level.truck.billboard.card.hide()
		for fade in menu.level.truck.billboard.fade_materials: fade.set_shader_parameter("sprite_visibility",0.0)
	menu.level.truck.model.show()
	freeze_tree(menu.level)
	menu.level.get_node("HUD").hide()
	var truck: CharacterBody3D = menu.level.truck
	truck_exaggeration_backup = truck.exaggeration
	menu_idle = preload("res://truck_exaggeration.gd").new()
	menu_idle.profile = idle_profile()
	menu_idle.preview = true
	menu_idle.preview_state = "idle"
	truck.exaggeration = menu_idle
	truck.parking_pad = null
	truck.global_position = stop + truck.global_basis.z * 6.0
	truck.spawn_transform = Transform3D(truck.global_basis, stop)
	truck.speed = 0
	truck.travel_heading = truck.rotation.y
	for path in ["rear_quarter", "sky_pan", "sky_hold"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/menu_cameras/%s.json" % path))
		var camera_reference := Basis(Vector3.UP,deg_to_rad(data.truck_rotation_degrees[1]))
		var basis := Basis(vector(data.basis_x),vector(data.basis_y),vector(data.basis_z))
		poses.append({"offset":camera_reference.inverse() * (vector(data.position)-vector(data.truck_position)),"basis":camera_reference.inverse()*basis,"fov":data.fov})
	for light in menu.level.find_children("*","DirectionalLight3D",true,false):
		if light.visible:
			sun_direction = light.global_basis.z.normalized()
			break
	comic_silhouette = preload("res://menu_truck_silhouette.gd").new()
	menu.add_child(comic_silhouette)
	comic_silhouette.attach(truck,menu.get_node("MenuCamera"))
	ground_fill = preload("res://menu_ground_fill.gd").new()
	ground_fill.name = "MenuGroundFill"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	ground_fill.mesh = quad
	ground_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_fill.extra_cull_margin = 16384.0
	ground_fill.position.z = -1.0
	var fill := ShaderMaterial.new()
	fill.shader = preload("res://menu_ground_fill.gdshader")
	fill.set_shader_parameter("fill_color", menu.menu_ground_fill_color)
	ground_fill.material_override = fill
	menu.get_node("MenuCamera").add_child(ground_fill)
	menu.elapsed = 0
	menu.get_node("MenuCamera").make_current()
	update(menu,0)

func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func freeze_tree(node: Node) -> void:
	if node.name == &"BlockRenderCards": return
	frozen.append({"node":node,"process":node.is_processing(),"physics":node.is_physics_processing(),"input":node.is_processing_input(),"unhandled":node.is_processing_unhandled_input()})
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child in node.get_children(): freeze_tree(child)

func resume() -> void:
	for state in frozen:
		if is_instance_valid(state.node) and state.node.get("exaggeration") == menu_idle:
			state.node.exaggeration = truck_exaggeration_backup
	if is_instance_valid(ground_fill):
		ground_fill.hide()
		ground_fill.queue_free()
	if is_instance_valid(comic_silhouette): comic_silhouette.remove()
	for state in frozen:
		if is_instance_valid(state.node) and state.node.name == "TruckBillboard": state.node.force_3d = false
	for state in frozen:
		if not is_instance_valid(state.node): continue
		state.node.set_process(state.process)
		state.node.set_physics_process(state.physics)
		state.node.set_process_input(state.input)
		state.node.set_process_unhandled_input(state.unhandled)
	for node in hidden:
		if is_instance_valid(node): node.show()
	if is_instance_valid(scenery): scenery.queue_free()
	if is_instance_valid(environment_node): environment_node.environment = environment_backup
	for state in sun_backup:
		if is_instance_valid(state.light): state.light.light_energy = state.energy
	for state in vehicle_backup:
		if not is_instance_valid(state.node): continue
		state.node.visible = state.visible
		state.node.collision_layer = state.layer
		state.node.collision_mask = state.mask
	for state in signal_backup:
		if is_instance_valid(state.node):
			state.node.elapsed = state.elapsed
			state.node.refresh_lights()

func choose_stop(city: Node, truck: CharacterBody3D) -> void:
	var best := -INF
	for crossing in city.get_node("Crosswalks").get_children():
		if crossing.get("crosses_vertical_road") == null: continue
		var vertical: bool = crossing.crosses_vertical_road
		var lane: float = city.road_width*(.375 if city.topology.artery_kind(vertical,crossing.global_position.x if vertical else crossing.global_position.z) != "inner" else .25)
		var forward := Vector3.BACK if vertical else Vector3.RIGHT
		var junction: Vector3 = crossing.global_position+(Vector3(0,0,city.crosswalk_setback) if vertical else Vector3(city.crosswalk_setback,0,0))
		var rules := preload("res://city_road_rules.gd")
		if not rules.allows(forward,junction,city): continue
		var bumper: float = truck.get_node("TruckCollision").shape.size.z*.5-truck.get_node("TruckCollision").position.z
		var boundary: float = preload("res://city_road_rules.gd").stop_boundary(city,forward,junction)
		var position: Vector3 = junction-forward*(boundary+.21+.4+bumper)+Vector3(-forward.z,0,forward.x)*lane
		if city.get_meta("streaming_city", false):
			var anchor: Vector3 = city.get_meta("stream_anchor")
			if Vector2(position.x - anchor.x, position.z - anchor.z).length() > 96.0: continue
		if not city.topology.street_bounds.grow(-24).has_point(Vector2(position.x,position.z)): continue
		var grade: float = city.height_at(position.x+forward.x*5,position.z+forward.z*5) - city.height_at(position.x-forward.x*5,position.z-forward.z*5)
		for car in city.get_tree().get_nodes_in_group("traffic_motion"):
			if city.is_ancestor_of(car) and Vector2(car.global_position.x,car.global_position.z).distance_to(Vector2(position.x,position.z)) < 14:
				grade -= 20
		if grade > best:
			best = grade
			stop = position
			truck.rotation.y = PI if vertical else -PI*.5
			signal_node = crossing
			framing_control = crossing.get_node("SouthSignal" if vertical else "NorthSignal")
	stop.y = city.height_at(stop.x,stop.z)+.2
	if is_instance_valid(framing_control):
		# Frame the controlling signal at the approach line, rather than the far crosswalk pole.
		var source_camera: Node3D = framing_control
		var near_signal: Node3D = source_camera.duplicate()
		near_signal.name = "MenuApproachSignal"
		near_signal.set_script(preload("res://menu_traffic_signal.gd"))
		signal_node.add_child(near_signal)
		near_signal.source_path = near_signal.get_path_to(source_camera)
		var forward := -truck.global_basis.z
		var right := truck.global_basis.x
		var point: Vector3 = stop+forward*6+right*(city.road_width*.5+city.sidewalk_width*.5-(city.road_width*.375 if city.topology.artery_kind(absf(forward.z)>.5,signal_node.position.x if absf(forward.z)>.5 else signal_node.position.z) != "inner" else city.road_width*.25))
		point.y = city.height_at(point.x,point.z)+.12
		near_signal.global_position = point
		framing_control = near_signal
	if is_instance_valid(signal_node):
		signal_node.elapsed = signal_node.wait_seconds + .1
		signal_node.refresh_lights()

func update(menu: Node, delta: float) -> void:
	delta = minf(delta,.05)
	elapsed += delta
	var truck: CharacterBody3D = menu.level.truck
	var blend := clampf(elapsed/2.4,0,1)
	truck.global_position = stop + truck.global_basis.z * 6.0 * pow(1.0-blend,3)
	var city: Node = menu.level.get_node_or_null("ProceduralCity")
	if city != null: truck.position.y = city.height_at(truck.position.x,truck.position.z)+.2
	truck.longitudinal_accel = -5.0*(1.0-blend) if blend < 1 else 0.0
	truck.lateral_accel = 0
	menu_idle.preview_time = fposmod(maxf(0.0, elapsed - 2.4), 4.8)
	if blend >= 1 and not brake_settled:
		brake_settled = true
		truck.spring_velocity[2] -= .55
		truck.spring_velocity[3] -= .55
	truck.update_suspension(delta)
	truck.update_slope_tilt(delta)
	truck.get_node("VehicleLights").set_driving_lights(true,false,false,false,false)
	truck.get_node("VehicleLights").sync_with_chassis()
	# The menu holds the supplied reference exactly; terrain never moves the camera.
	var camera: Camera3D = menu.get_node("MenuCamera")
	var basis := Basis(
		Vector3(0.930302381515503, 0, -0.366793483495712),
		Vector3(0.101905852556229, 0.960630595684052, 0.258464932441711),
		Vector3(0.352353036403656, -0.277828931808472, 0.893676936626434))
	camera.global_transform = truck.global_transform * Transform3D(basis, Vector3(2.47634124755859, -0.411857604980469, 5.87109565734863))
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 4000.0
	camera.h_offset = 0.0
	camera.v_offset = 0.153865441679955
	var saved: Dictionary = menu.get_node("/root/ScreenshotCapture").startup_camera_state
	if not saved.is_empty():
		preload("res://startup_camera_store.gd").apply_to_menu(camera, truck, saved)
	previous_camera_position = camera.global_position
	if is_instance_valid(ground_fill):
		ground_fill.visible = menu.get_viewport().get_camera_3d() == camera
		ground_fill.material_override.set_shader_parameter("height_threshold", truck.global_position.y + menu.menu_ground_fill_offset)
	if is_instance_valid(comic_silhouette): comic_silhouette.sync()

func place_comic_frame(camera: Camera3D, bounds: AABB, weight: float = 1.0) -> void:
	for attempt in 4:
		var left := INF
		var depth := 1.0
		for index in 8:
			var corner := bounds.get_endpoint(index)
			var pixel := camera.unproject_position(corner).x
			if pixel < left:
				left = pixel
				depth = -camera.to_local(corner).z
		var pixel_scale := 2*tan(deg_to_rad(camera.fov)*.5)*depth/camera.get_viewport().get_visible_rect().size.y
		camera.global_position += camera.global_basis.x*((left-70.0-comic_silhouette.left_correction)*pixel_scale*weight)

func truck_fits(camera: Camera3D, bounds: AABB) -> bool:
	var viewport := camera.get_viewport().get_visible_rect().size
	for index in 8:
		var corner := bounds.get_endpoint(index)
		if camera.is_position_behind(corner): return false
		var pixel := camera.unproject_position(corner)
		if pixel.x < -viewport.x*.03 or pixel.x > viewport.x*.92 or pixel.y < viewport.y*.08 or pixel.y > viewport.y*.90: return false
	return true

func keep_truck_in_frame(camera: Camera3D, bounds: AABB) -> void:
	if truck_fits(camera,bounds): return
	# Truck visibility wins over the optional signal framing and rotation overshoot.
	camera.look_at(bounds.get_center(),Vector3.UP)
	for attempt in 32:
		if truck_fits(camera,bounds): break
		framing_distance += .35
		camera.global_position += camera.global_basis.z*.35


func mesh(parent: Node3D, label: String, size: Vector3, position: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .9
	box.material = material
	node.mesh = box
	node.position = position
	parent.add_child(node)

func make_fallback(level: Node) -> void:
	var environments := level.find_children("*","WorldEnvironment",true,false)
	if not environments.is_empty():
		environment_node = environments[0]
		environment_backup = environment_node.environment
		var environment: Environment = environment_backup.duplicate()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("09121e")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("5d708a")
		environment.ambient_light_energy = .35
		environment_node.environment = environment
	for light in level.find_children("*","DirectionalLight3D",true,false):
		sun_backup.append({"light":light,"energy":light.light_energy})
		light.light_energy = .12
	scenery = Node3D.new()
	scenery.name = "MenuStreetLampStage"
	level.add_child(scenery)
	mesh(scenery,"BasicPlane",Vector3(240,.15,240),Vector3(0,-.08,0),Color("171c23"))
	mesh(scenery,"Sidewalk",Vector3(30,.22,3),Vector3(0,.1,-5.5),Color("9eacb3"))
	mesh(scenery,"LampPost",Vector3(.16,7,.16),Vector3(3,3.5,-5),Color("4d555b"))
	mesh(scenery,"LampArm",Vector3(.16,.16,4),Vector3(3,7,-3),Color("4d555b"))
	mesh(scenery,"LampHousing",Vector3(.8,.25,1.2),Vector3(3,6.9,-1),Color("e4d6a8"))
	var light := SpotLight3D.new()
	light.name = "StreetLampSpotlight"
	light.position = Vector3(3,6.7,-1)
	light.light_color = Color("ffe4b9")
	light.light_energy = 5
	light.spot_range = 25
	light.spot_angle = 50
	light.shadow_enabled = true
	scenery.add_child(light)
	light.look_at(Vector3(0,1,0))
