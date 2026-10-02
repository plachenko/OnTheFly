extends Sprite3D

# Hand-drawn polygon lettering: no fonts or system text.
const GLYPHS := {
	"H": "M3 5 L20 2 L18 29 L39 26 L42 0 L59 4 L54 70 L36 73 L38 44 L17 47 L16 72 L0 68 Z",
	"O": "M10 5 L43 0 L59 14 L55 58 L42 72 L10 68 L0 52 L2 20 Z M20 20 L18 49 L35 52 L39 19 Z",
	"N": "M3 7 L20 0 L39 40 L42 3 L59 6 L55 70 L38 73 L18 34 L17 69 L0 71 Z",
	"K": "M4 2 L21 0 L19 27 L40 2 L60 7 L34 36 L59 65 L40 73 L18 47 L17 70 L0 68 Z",
	"B": "M4 4 L39 0 L56 12 L54 29 L44 35 L58 44 L55 61 L39 72 L0 69 Z M20 16 L19 28 L35 27 L37 16 Z M18 43 L17 55 L36 55 L38 43 Z",
	"M": "M3 4 L19 0 L31 24 L43 2 L59 4 L56 71 L40 69 L41 33 L30 48 L18 34 L17 72 L0 68 Z",
	"!": "M19 1 L40 4 L32 48 L17 46 Z M16 56 L33 58 L30 73 L13 70 Z"
}
static var textures: Dictionary = {}
var elapsed := 0.0
var hold_time := 0.4
var delay := 0.0
var base_position := Vector3.ZERO
var boom := false

static func spawn(parent: Node, at: Vector3, word: String, duration: float, width: float, wait: float = 0.0) -> Sprite3D:
	var burst := load("res://comic_burst.gd").new() as Sprite3D
	burst.texture = lettering(word)
	burst.pixel_size = width / burst.texture.get_width()
	burst.hold_time = duration
	burst.delay = wait
	burst.boom = word == "BOOM!"
	burst.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	burst.no_depth_test = false
	burst.shaded = false
	burst.modulate.a = 0.0
	parent.add_child(burst)
	burst.global_position = at
	burst.base_position = burst.position
	return burst

static func lettering(word: String) -> Texture2D:
	if textures.has(word):
		return textures[word]
	var width := word.length() * 66 + 48
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="140" viewBox="0 0 %d 140">' % [width * 2, width]
	if word == "BOOM!":
		svg += '<path d="M8 70 L40 53 L23 12 L90 30 L130 3 L160 26 L215 8 L235 30 L305 10 L290 48 L365 70 L310 87 L337 130 L262 108 L225 137 L183 114 L117 135 L98 108 L30 125 L43 91 Z" fill="#ff752a" stroke="#21152c" stroke-width="6"/>'
	for i in word.length():
		var path: String = GLYPHS[word[i]]
		var transform := 'translate(%d %d) skewX(-9) rotate(%d 30 35)' % [30 + i * 66, 31 + (i % 2) * 4, -5 if i % 2 == 0 else 4]
		svg += '<g transform="%s"><path d="%s" transform="translate(4 6)" fill="#21152c" stroke="#21152c" stroke-width="9" stroke-linejoin="round"/><path d="%s" fill="#fff16b" fill-rule="evenodd" stroke="#21152c" stroke-width="5" stroke-linejoin="round"/><path d="M9 12 L16 9" stroke="#ffffff" stroke-width="3"/></g>' % [transform, path, path]
	svg += '</svg>'
	var bitmap := Image.new()
	bitmap.load_svg_from_string(svg)
	var result := ImageTexture.create_from_image(bitmap)
	textures[word] = result
	return result

func _process(delta: float) -> void:
	elapsed += delta
	var t := elapsed - delay
	if t < 0.0:
		return
	var fade := clampf((t - hold_time) / 0.22, 0.0, 1.0)
	var pop := clampf(t / 0.09, 0.0, 1.0)
	var size := lerpf(0.35, 1.15, pop) if t < 0.09 else lerpf(1.15, 1.0, clampf((t - 0.09) / 0.1, 0.0, 1.0))
	# A held horn keeps a small vibration until its sound ends.
	if hold_time > 1.0 and t > 0.19:
		size += sin(t * 32.0) * 0.025 * (1.0 - fade)
	scale = Vector3.ONE * size * (1.0 + fade * 0.18)
	position = base_position + Vector3.UP * (t * (0.9 if boom else 0.5) + fade * 0.5)
	modulate.a = clampf(t / 0.025, 0.0, 1.0) * (1.0 - fade)
	if fade >= 1.0:
		queue_free()
