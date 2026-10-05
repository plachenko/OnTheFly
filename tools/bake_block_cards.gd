extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: -- map.res [map.res ...] (requires a rendering backend)")
		quit(1)
		return
	for path in args:
		var data = load(path)
		assert(data != null and not data.sections.is_empty())
		data.block_cards = await preload("res://block_card_baker.gd").bake(self, data)
		assert(not data.block_cards.is_empty())
		assert(ResourceSaver.save(data, path + ".pending.res", ResourceSaver.FLAG_COMPRESS) == OK)
		assert(DirAccess.rename_absolute(path + ".pending.res", path) == OK)
		print("BLOCK_CARD_BAKE_PASS ", path, " blocks=", data.block_cards.size())
	quit()
