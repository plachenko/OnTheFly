extends Node3D

# Real geometry is already present underneath throughout the card's fade.
const NEAR := 80.0
const FAR := 110.0
var entries: Array[Dictionary] = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func export_for_sections(sections: Array[PackedScene]) -> Array[Dictionary]:
	var known := {}
	for entry in entries:
		var names: Array[String] = []
		for model in entry.models: names.append(str(model.name))
		names.sort()
		known["|".join(names)] = entry
	var result: Array[Dictionary] = []
	for section_index in sections.size():
		var state := sections[section_index].get_state()
		var names: Array[String] = []
		for index in state.get_node_count():
			if state.get_node_name(index) == &"KenneyBuilding":
				names.append(str(state.get_node_path(index)).get_base_dir().get_file())
		if names.is_empty(): continue
		names.sort()
		var key := "|".join(names)
		if not known.has(key): return []
		var entry: Dictionary = known[key]
		result.append({"section": section_index, "center": entry.card.position, "bounds": entry.bounds, "extent": entry.card.mesh.size.x, "texture": entry.material.get_shader_parameter("atlas"), "baked_light": entry.baked_light})
	return result

static func install_loaded(city: Node3D, data: Resource) -> Node3D:
	var existing := city.get_node_or_null("BlockRenderCards")
	if existing != null: return existing
	var cards := preload("res://block_cards.gd").new()
	cards.name = "BlockRenderCards"
	city.add_child(cards)
	for card in data.block_cards:
		cards.add_card(card, data.night)
		var models: Array[Node3D] = []
		var state: SceneState = data.sections[int(card.section)].get_state()
		for index in state.get_node_count():
			if state.get_node_name(index) != &"KenneyBuilding": continue
			var model := city.get_node_or_null(state.get_node_path(index)) as Node3D
			if model != null: models.append(model.get_parent())
		cards.section_loaded(int(card.section), models)
	return cards

static func light_level(ambient: Color, ambient_energy: float, sun: Color, sun_energy: float) -> Vector3:
	# An average facade receives less sun than ambient light. Compare the same
	# estimate for the bake and live scene; do not light the captured image twice.
	return Vector3(ambient.r, ambient.g, ambient.b) * ambient_energy + Vector3(sun.r, sun.g, sun.b) * sun_energy * 0.35

func refresh_lighting() -> void:
	var city := get_parent()
	if city == null or city.get_parent() == null: return
	var level := city.get_parent()
	var sun := level.get_node_or_null("Sun") as DirectionalLight3D
	var world := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if sun == null or world == null or world.environment == null: return
	var environment := world.environment
	var lighting := light_level(environment.ambient_light_color, environment.ambient_light_energy, sun.light_color, sun.light_energy if sun.visible else 0.0)
	for entry in entries:
		var reference: Vector3 = entry.baked_light
		var tint := lighting / reference.max(Vector3.ONE * 0.001)
		entry.material.set_shader_parameter("scene_tint", tint.clamp(Vector3.ZERO, Vector3.ONE * 4.0))

func add_card(data: Dictionary, baked_night: bool = false) -> void:
	var card := MeshInstance3D.new()
	card.name = "BlockRenderCard"
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * float(data.extent)
	card.mesh = mesh
	card.position = data.center
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.extra_cull_margin = float(data.extent)
	var material := ShaderMaterial.new()
	material.shader = preload("res://block_card.gdshader")
	material.set_shader_parameter("atlas", data.texture)
	card.material_override = material
	add_child(card)
	# Older atlases used a white bake sun even at night. Retain that reference
	# so old saves receive the correction without needing another bake.
	var reference: Vector3 = data.get("baked_light", light_level(Color(0.37, 0.45, 0.70) if baked_night else Color.WHITE, 0.28 if baked_night else 0.7, Color.WHITE, 0.15 if baked_night else 0.8))
	entries.append({"section": int(data.section), "bounds": data.bounds, "card": card, "material": material, "models": [], "loaded": false, "handoff": 1.0, "baked_light": reference})
	refresh_lighting()

func section_loaded(index: int, models: Array[Node3D]) -> void:
	for entry in entries:
		if entry.section != index: continue
		entry.loaded = true
		entry.models = models
		for model in models:
			model.set_meta("block_card_managed", true)
			var kenney := model.get_node_or_null("KenneyBuilding")
			if kenney != null: kenney.set_meta("block_card_managed", true)
			for geometry in model.find_children("*", "GeometryInstance3D", true, false):
				geometry.visibility_range_end = 0.0
				geometry.visibility_range_end_margin = 0.0
			var lod := model.get_node_or_null("BuildingVisualLOD")
			if lod != null:
				lod.refresh()
			elif kenney != null:
				preload("res://building_visual_lod.gd").attach(model, kenney)
		update_entry(entry, get_viewport().get_camera_3d())

func _process(delta: float) -> void:
	refresh_lighting()
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for entry in entries:
		if entry.loaded: entry.handoff = move_toward(float(entry.handoff), 0.0, delta / 0.4)
		update_entry(entry, camera)

func update_entry(entry: Dictionary, camera: Camera3D) -> void:
	if PerformanceDiagnostics.buildings_as_blocks:
		entry.card.hide()
		for model in entry.models:
			if is_instance_valid(model): model.show()
		return
	if camera == null: return
	var bounds: AABB = entry.bounds
	var point := to_local(camera.global_position)
	var closest := point.clamp(bounds.position, bounds.end)
	var distance := Vector2(point.x - closest.x, point.z - closest.z).length()
	var diagnostics := get_node_or_null("/root/PerformanceDiagnostics")
	var enabled: bool = diagnostics == null or diagnostics.rendering_lod_enabled
	var opacity := smoothstep(NEAR, FAR, distance) if enabled else 0.0
	var show_detail := opacity < 1.0
	if entry.loaded and enabled: opacity = maxf(opacity, float(entry.handoff))
	# Pending geometry cannot be revealed yet: retain its full silhouette.
	if not entry.loaded: opacity = 1.0
	entry.card.visible = opacity > 0.001
	entry.material.set_shader_parameter("opacity", opacity)
	for model in entry.models:
		if is_instance_valid(model): model.visible = show_detail
