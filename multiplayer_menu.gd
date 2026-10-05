extends ConfirmationDialog

var host_mode := true
var nickname: LineEdit
var address: LineEdit
var port: SpinBox
var message: Label
var scan_button: Button
var paste_button: Button

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(520, 230)
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	var hint := Label.new()
	hint.text = "Up to 4 food trucks • Separate earnings\nLocal / LAN prototype — no Steam account needed"
	layout.add_child(hint)
	nickname = LineEdit.new()
	nickname.placeholder_text = "Driver name"
	nickname.text = "Driver"
	nickname.max_length = 24
	layout.add_child(nickname)
	address = LineEdit.new()
	address.placeholder_text = "Host IP address"
	address.text = "127.0.0.1"
	layout.add_child(address)
	var port_row := HBoxContainer.new()
	layout.add_child(port_row)
	var port_label := Label.new()
	port_label.text = "UDP port"
	port_row.add_child(port_label)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = NetworkSession.PORT
	port_row.add_child(port)
	scan_button = Button.new()
	scan_button.text = "Scan QR"
	scan_button.pressed.connect(scan_qr)
	port_row.add_child(scan_button)
	paste_button = Button.new()
	paste_button.text = "Paste connection code"
	paste_button.pressed.connect(func(): apply_join_code(DisplayServer.clipboard_get()))
	port_row.add_child(paste_button)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = 500
	layout.add_child(message)
	confirmed.connect(connect_session)
	canceled.connect(func():
		if NetworkSession.joining: NetworkSession.close())
	NetworkSession.status_changed.connect(func(text: String):
		message.text = text
		if not NetworkSession.joining: get_ok_button().disabled = false)
	# Keep the connection status visible until the loading screen takes over.
	dialog_hide_on_ok = false

func open(hosting: bool) -> void:
	host_mode = hosting
	title = "Host multiplayer" if hosting else "Join multiplayer"
	ok_button_text = "Host game" if hosting else "Join game"
	address.visible = not hosting
	scan_button.visible = not hosting and OS.get_name() == "Android"
	paste_button.visible = not hosting
	message.text = "Friends on your network join using your computer's LAN IP." if hosting else "Use 127.0.0.1 for two instances on this computer, or the host's LAN IP."
	get_ok_button().disabled = false
	popup_centered(Vector2i(560, 300))
	nickname.grab_focus()

func connect_session() -> void:
	if not host_mode and address.text.strip_edges().is_empty():
		message.text = "Enter the host's IP address."
		return
	get_ok_button().disabled = true
	var error: Error = NetworkSession.start_host(int(port.value), nickname.text) if host_mode else NetworkSession.start_join(address.text, int(port.value), nickname.text)
	if error != OK: get_ok_button().disabled = false

func apply_join_code(value: String) -> void:
	var connection: Dictionary = preload("res://join_code.gd").decode(value.strip_edges())
	if connection.is_empty():
		message.text = "Invalid lobby code. Scan or copy the host's lobby QR."
		return
	fill_connection(connection)

func fill_connection(connection: Dictionary) -> void:
	address.text = connection.ip
	port.value = connection.port
	message.text = "Address and port filled. Tap Join game to connect."
	get_ok_button().grab_focus()

func scan_qr() -> void:
	if not Engine.has_singleton("NativeCameraPlugin") or not Engine.has_singleton("QRPlugin"):
		message.text = "QR scanning requires an Android build with the camera and QR plugins."
		return
	var scanner := preload("res://join_qr_scanner.gd").new()
	add_child(scanner)
	scanner.connection_scanned.connect(fill_connection)
	scanner.popup_centered()
