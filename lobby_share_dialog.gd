extends AcceptDialog

const Code = preload("res://join_code.gd")
var public_toggle: CheckButton
var address_picker: OptionButton
var caption: Label
var qr: TextureRect
var request: HTTPRequest
var public_ip := ""
var payload := ""

func _ready() -> void:
	title = "Share multiplayer lobby"
	ok_button_text = "Close"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	public_toggle = CheckButton.new()
	public_toggle.text = "Use public IP"
	column.add_child(public_toggle)
	public_toggle.toggled.connect(change_address)
	address_picker = OptionButton.new()
	for address in Code.addresses(): address_picker.add_item(address)
	column.add_child(address_picker)
	address_picker.item_selected.connect(func(_index): refresh_code())
	caption = Label.new()
	caption.custom_minimum_size.x = 340
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	qr = TextureRect.new()
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr.custom_minimum_size = Vector2(280, 280)
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	column.add_child(qr)
	var copy := Button.new()
	copy.text = "Copy connection code"
	copy.pressed.connect(func():
		if not payload.is_empty(): DisplayServer.clipboard_set(payload))
	column.add_child(copy)
	request = HTTPRequest.new()
	request.timeout = 10
	request.body_size_limit = 128
	add_child(request)
	request.request_completed.connect(receive_public_ip)
	refresh_code()

func change_address(use_public: bool) -> void:
	address_picker.disabled = use_public
	if use_public and public_ip.is_empty():
		payload = ""
		qr.texture = null
		caption.text = "Finding public IP…"
		var error := request.request("https://api4.ipify.org")
		if error != OK: caption.text = "Could not find the public IP. Toggle off and try again."
	else: refresh_code()

func receive_public_ip(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var value := body.get_string_from_utf8().strip_edges()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and value.is_valid_ip_address():
		public_ip = value
		refresh_code()
	elif public_toggle.button_pressed:
		caption.text = "Could not find the public IP. Toggle off and try again."

func refresh_code() -> void:
	var address := public_ip if public_toggle.button_pressed else address_picker.get_item_text(address_picker.selected) if address_picker.item_count > 0 else ""
	payload = ""
	qr.texture = null
	if address.is_empty():
		caption.text = "Connect to a local network to share a LAN address."
		return
	payload = Code.encode(address, NetworkSession.host_port)
	var encoder := preload("res://addons/qr_share/qr_code.gd").new()
	var source: Image = encoder.get_texture(payload).get_image()
	encoder.free()
	var padded := Image.create(source.get_width() + 6, source.get_height() + 6, false, Image.FORMAT_RGBA8)
	padded.fill(Color.WHITE)
	padded.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(3, 3))
	padded.resize(padded.get_width() * 6, padded.get_height() * 6, Image.INTERPOLATE_NEAREST)
	qr.texture = ImageTexture.create_from_image(padded)
	caption.text = "%s:%d\nIn Join multiplayer, tap Scan QR to fill the address and port." % [address, NetworkSession.host_port]
	if public_toggle.button_pressed:
		caption.text += "\nInternet guests need UDP port %d forwarded to this host." % NetworkSession.host_port
