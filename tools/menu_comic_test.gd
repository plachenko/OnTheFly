extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var menu = load("res://main_menu.tscn").instantiate()
	root.add_child(menu); current_scene=menu
	while not menu.menu_ready: await process_frame
	for index in 420: await process_frame
	assert(menu.level.truck.billboard == null and menu.level.truck.model.visible)
	var bounds := AABB(); var first:=true
	for mesh in menu.level.truck.model.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "ComicSilhouette" or not mesh.is_visible_in_tree(): continue
		var world: AABB = mesh.global_transform*mesh.get_aabb()
		bounds=world if first else bounds.merge(world); first=false
	var left:=INF
	for index in 8: left=minf(left,menu.get_node("MenuCamera").unproject_position(bounds.get_endpoint(index)).x)
	print("COMIC bounds=",bounds," left=",left," camera=",menu.get_node("MenuCamera").global_position," truck=",menu.level.truck.global_position)
	assert(menu.stage.comic_silhouette.measured)
	assert(menu.stage.comic_silhouette.copies.size()>20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/menu_comic.png")
	var used: Rect2i=menu.stage.comic_silhouette.viewport.get_texture().get_image().get_used_rect()
	print("COMIC PIXEL MARGIN ",used)
	assert(abs(used.position.x-70)<=3)
	assert(used.position.y > 20 and used.end.y < menu.stage.comic_silhouette.viewport.size.y-20)
	assert(used.end.x < menu.stage.comic_silhouette.viewport.size.x-20)
	menu.stage.resume()
	assert(menu.stage.comic_silhouette.copies.is_empty())
	print("MENU COMIC PASS: 3D default, closer shot, tapered pull and speed strokes, 30-pixel left margin, shared live rig, gameplay cleanup")
	quit()
