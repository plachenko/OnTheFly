extends RefCounted

static func encode(address: String, port: int) -> String:
	return "onthefly://join?ip=%s&port=%d" % [address.uri_encode(), port]

static func decode(value: String) -> Dictionary:
	if not value.begins_with("onthefly://join?"): return {}
	var fields := {}
	for field in value.trim_prefix("onthefly://join?").split("&"):
		var parts := field.split("=")
		if parts.size() != 2 or fields.has(parts[0]): return {}
		fields[parts[0]] = parts[1].uri_decode()
	var address: String = fields.get("ip", "")
	var port_text: String = fields.get("port", "")
	if not address.is_valid_ip_address() or not port_text.is_valid_int(): return {}
	var port := port_text.to_int()
	if port < 1024 or port > 65535: return {}
	return {"ip": address, "port": port}

static func addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.begins_with("10.") or address.begins_with("192.168.") or (address.begins_with("172.") and address.get_slice(".", 1).to_int() in range(16, 32)):
			if not address in result: result.append(address)
	return result
