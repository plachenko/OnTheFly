extends CanvasLayer

# City-owned edge bands with a short grey fog-entry sweep.
var panel: ColorRect
var fog_panel: ColorRect
var fog_elapsed := 0.0
const FOG_WIPE_SECONDS := 0.85
var progress := 0.0
var phase := 0 # 0 idle, 1 covering, 2 travelling, 3 revealing, 4 cancelling
var previous := Vector3.ZERO
var initialized := false
var axis := 0
var side := 1.0
var departure_plane := 0.0
var arrival_plane := 0.0

func _ready() -> void:
	layer = 90
	fog_panel = ColorRect.new()
	fog_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_material := ShaderMaterial.new()
	fog_material.shader = preload("res://highway_fog_wipe.gdshader")
	fog_panel.material = fog_material
	add_child(fog_panel)
	fog_panel.hide()
	panel = ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://loading_backdrop.gdshader")
	material.set_shader_parameter("patterns_only", true)
	panel.material = material
	add_child(panel)
	panel.resized.connect(update_panel_size)
	update_panel_size()
	panel.hide()

func update_panel_size() -> void:
	panel.material.set_shader_parameter("panel_size", panel.size)

func update_bands() -> void:
	var eased := progress * progress * (3.0 - 2.0 * progress)
	panel.material.set_shader_parameter("pattern_entry", eased)

func tick(position: Vector3, signs: Node, delta: float) -> void:
	if not initialized:
		previous = position
		initialized = true
	if phase == 0 and signs:
		for road_sign in signs.get_children():
			if not road_sign.has_meta("highway_axis"):
				continue
			var a: int = road_sign.get_meta("highway_axis")
			var s: float = road_sign.get_meta("highway_side")
			var plane: float = road_sign.global_position[a]
			var lateral := 2 if a == 0 else 0
			if (previous[a] - plane) * s <= 0.0 and (position[a] - plane) * s > 0.0 and absf(position[lateral] - road_sign.global_position[lateral]) < 14.0:
				axis = a
				side = s
				departure_plane = plane
				arrival_plane = -plane
				# The tunnel's east sign is offset; use the actual opposite sign.
				for other in signs.get_children():
					if other.has_meta("highway_axis") and int(other.get_meta("highway_axis")) == a and float(other.get_meta("highway_side")) == -s and absf(other.global_position[lateral] - road_sign.global_position[lateral]) < 1.0:
						arrival_plane = other.global_position[a]
				phase = 1
				fog_elapsed = 0.0
				fog_panel.material.set_shader_parameter("progress",0.0)
				fog_panel.show()
				panel.show()
				break
	if phase == 1:
		progress = minf(1.0, progress + delta / 0.24)
		# A driver reversing before reaching the boundary can leave normally.
		if (position[axis] - departure_plane) * side < -2.0:
			phase = 4
	elif phase == 2 and (position[axis] - arrival_plane) * side >= 0.0:
		phase = 3
	if phase == 3 or phase == 4:
		progress = maxf(0.0, progress - delta / 0.45)
		if progress == 0.0:
			phase = 0
			panel.hide()
	update_bands()
	if fog_panel.visible:
		fog_elapsed = minf(FOG_WIPE_SECONDS,fog_elapsed+delta)
		fog_panel.material.set_shader_parameter("progress",fog_elapsed/FOG_WIPE_SECONDS)
		if fog_elapsed >= FOG_WIPE_SECONDS: fog_panel.hide()
	previous = position

func wrapped(position: Vector3) -> void:
	if phase == 1:
		phase = 2
		progress = 1.0
		update_bands()
	previous = position
