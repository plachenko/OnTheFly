extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: -- source.res target.res")
		quit(1)
		return
	var data = load(args[0])
	if data == null or data.snapshot == null:
		push_error("Source needs a legacy saved city snapshot")
		quit(1)
		return
	var saved: Node3D = data.snapshot.instantiate()
	var partition := preload("res://city_section_stream.gd").partition(saved)
	saved.free()
	assert(partition.error == OK)
	data.sections.assign(partition.scenes)
	data.section_centers = partition.centers
	data.section_global = partition.global
	data.snapshot = null
	DirAccess.make_dir_recursive_absolute(args[1].get_base_dir())
	var error := ResourceSaver.save(data, args[1], ResourceSaver.FLAG_COMPRESS)
	print("CITY PARTITION sections=", data.sections.size(), " error=", error)
	quit(0 if error == OK else 1)
