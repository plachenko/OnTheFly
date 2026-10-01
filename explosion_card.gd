extends AnimatedSprite3D

const SHEET_PATH := "res://assets/effects/explosion_sheet.png"
const GRID := 4
const FRAME_COUNT := 16

static func spawn(parent: Node, at: Vector3, size: float, label: String = "ExplosionCard") -> AnimatedSprite3D:
	var card := load("res://explosion_card.gd").new() as AnimatedSprite3D
	card.name = label
	card.set_meta("explosion_size", size)
	parent.add_child(card)
	card.global_position = at
	return card

func _ready() -> void:
	var sheet := load(SHEET_PATH) as Texture2D
	var cell := Vector2(sheet.get_width(), sheet.get_height()) / float(GRID)
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", 12.0)
	for index in FRAME_COUNT:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(index % GRID, index / GRID) * cell, cell)
		frame.filter_clip = true
		frames.add_frame("default", frame)
	sprite_frames = frames
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	double_sided = true
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	pixel_size = float(get_meta("explosion_size", 9.0)) / cell.x
	animation_finished.connect(queue_free)
	play("default")

func _process(_delta: float) -> void:
	# Dissolve the last smoke frames rather than popping off at the end.
	modulate.a = 1.0 - clampf((float(frame) + frame_progress - 12.0) / 4.0, 0.0, 1.0)
