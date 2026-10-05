extends Node

var experience := 0
var license_points := 0
var save_path := "user://player_progress.cfg"
var dirty := false
var save_delay := 0.0

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	var data := ConfigFile.new()
	if data.load(save_path) != OK: return
	var xp: Variant = data.get_value("driver", "experience", 0)
	var points: Variant = data.get_value("driver", "license_points", 0)
	experience = maxi(0, xp) if xp is int else 0
	license_points = maxi(0, points) if points is int else 0

func update_progress(xp: int, points: int) -> void:
	experience = maxi(0, xp)
	license_points = maxi(0, points)
	dirty = true
	save_delay = .25

func save_progress() -> Error:
	var data := ConfigFile.new()
	data.set_value("driver", "experience", experience)
	data.set_value("driver", "license_points", license_points)
	var error := data.save(save_path)
	if error == OK: dirty = false
	return error

func _process(delta: float) -> void:
	if not dirty: return
	save_delay -= delta
	if save_delay <= 0.0:
		save_progress()
		save_delay = 5.0

func _exit_tree() -> void:
	if dirty: save_progress()
