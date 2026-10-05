extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var code = load("res://join_code.gd")
	for address in ["192.168.1.20", "8.8.8.8", "2001:db8::1"]:
		assert(code.decode(code.encode(address, 30000)) == {"ip": address, "port": 30000})
	for value in ["", "https://example.org", "onthefly://join?ip=example.org&port=24567", "onthefly://join?ip=192.168.1.2&port=0", "onthefly://join?ip=192.168.1.2&port=70000", "onthefly://join?ip=192.168.1.2&port=24567&port=30000"]:
		assert(code.decode(value).is_empty())
	var encoder = load("res://addons/qr_share/qr_code.gd").new()
	var texture: ImageTexture = encoder.get_texture(code.encode("192.168.1.20", 30000))
	assert(texture != null)
	texture.get_image().save_png("res://.godot/lobby_qr_test.png")
	encoder.free()
	var menu = load("res://multiplayer_menu.gd").new()
	root.add_child(menu)
	menu.open(false)
	menu.apply_join_code(code.encode("8.8.8.8", 30000))
	assert(menu.address.text == "8.8.8.8" and int(menu.port.value) == 30000)
	menu.hide()
	var share = load("res://share_dialog.gd").new()
	root.add_child(share)
	share.show_release()
	share.hide()
	var lobby = load("res://lobby_share_dialog.gd").new()
	root.add_child(lobby)
	lobby.public_ip = "8.8.8.8"
	lobby.public_toggle.set_pressed_no_signal(true)
	lobby.refresh_code()
	assert(code.decode(lobby.payload) == {"ip": "8.8.8.8", "port": root.get_node("NetworkSession").host_port})
	assert(load("res://join_qr_scanner.gd") != null)
	print("SHARE QR PASS: connection round trips, invalid codes, join fields, release dialogs, public IP toggle")
	quit()
