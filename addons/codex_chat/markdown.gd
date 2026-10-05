@tool
extends RefCounted

static func escape(text: String) -> String:
	var result := ""
	for character in text:
		result += "[lb]" if character == "[" else ("[rb]" if character == "]" else character)
	return result

static func inline_text(text: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("`([^`]+)`|\\[([^\\]]+)\\]\\(((?:https?://|godot-file:)[^\\s)]+)\\)|\\*\\*(.+?)\\*\\*|__(.+?)__|\\*([^*]+)\\*|~~(.+?)~~")
	var result := ""
	var offset := 0
	for match_value in pattern.search_all(text):
		result += escape(text.substr(offset, match_value.get_start() - offset))
		if not match_value.get_string(1).is_empty(): result += "[code]" + escape(match_value.get_string(1)) + "[/code]"
		elif not match_value.get_string(2).is_empty():
			var url := match_value.get_string(3)
			if url.contains("[") or url.contains("]"): result += escape(match_value.get_string())
			else: result += "[url=" + url + "]" + escape(match_value.get_string(2)) + "[/url]"
		elif not match_value.get_string(4).is_empty(): result += "[b]" + escape(match_value.get_string(4)) + "[/b]"
		elif not match_value.get_string(5).is_empty(): result += "[b]" + escape(match_value.get_string(5)) + "[/b]"
		elif not match_value.get_string(6).is_empty(): result += "[i]" + escape(match_value.get_string(6)) + "[/i]"
		else: result += "[s]" + escape(match_value.get_string(7)) + "[/s]"
		offset = match_value.get_end()
	return result + escape(text.substr(offset))

static func table_cells(line: String) -> PackedStringArray:
	var text := line.strip_edges()
	if text.begins_with("|"): text = text.substr(1)
	if text.ends_with("|") and not text.ends_with("\\|"): text = text.left(-1)
	var cells := PackedStringArray()
	var cell := ""
	var escaped := false
	var in_code := false
	for character in text:
		if escaped:
			cell += character if character == "|" else "\\" + character
			escaped = false
		elif character == "\\": escaped = true
		elif character == "`":
			in_code = not in_code
			cell += character
		elif character == "|" and not in_code:
			cells.append(cell.strip_edges())
			cell = ""
		else: cell += character
	if escaped: cell += "\\"
	cells.append(cell.strip_edges())
	return cells

static func table_alignment(line: String) -> PackedStringArray:
	var cells := table_cells(line)
	var alignments := PackedStringArray()
	var separator := RegEx.new()
	separator.compile("^:?-{3,}:?$")
	for cell in cells:
		if separator.search(cell) == null: return PackedStringArray()
		alignments.append("center" if cell.begins_with(":") and cell.ends_with(":") else ("right" if cell.ends_with(":") else "left"))
	return alignments

static func table_row(cells: PackedStringArray, alignments: PackedStringArray, header: bool) -> String:
	var result := ""
	for index in alignments.size():
		var content := inline_text(cells[index] if index < cells.size() else "")
		if header: content = "[b]" + content + "[/b]"
		var alignment := alignments[index]
		result += "[cell border=#637083 bg=%s padding=8,5,8,5][%s]%s[/%s][/cell]" % ["#303c4f" if header else "#202936", alignment, content, alignment]
	return result

static func render(markdown: String, zoom: float = 1.0) -> String:
	var result := ""
	var code := false
	var heading := RegEx.new()
	heading.compile("^(#{1,6}) (.*)$")
	var bullet := RegEx.new()
	bullet.compile("^(\\s*)[-*+] (.*)$")
	var lines := markdown.split("\n")
	var index := 0
	while index < lines.size():
		var line := lines[index]
		if not code and index + 1 < lines.size() and line.contains("|"):
			var alignments := table_alignment(lines[index + 1])
			var headers := table_cells(line)
			if not alignments.is_empty() and headers.size() == alignments.size():
				result += "[table=%d]" % alignments.size()
				result += table_row(headers, alignments, true)
				index += 2
				while index < lines.size() and lines[index].contains("|") and not lines[index].strip_edges().is_empty():
					result += table_row(table_cells(lines[index]), alignments, false)
					index += 1
				result += "[/table]\n"
				continue
		index += 1
		if line.strip_edges().begins_with("```"):
			result += "[/code]\n" if code else "[code]"
			code = not code
			continue
		if code:
			result += escape(line) + "\n"
			continue
		var title := heading.search(line)
		var list_item := bullet.search(line)
		if title != null:
			result += "[font_size=%d][b]%s[/b][/font_size]\n" % [roundi(maxi(16, 26 - title.get_string(1).length() * 2) * zoom), inline_text(title.get_string(2))]
		elif list_item != null: result += list_item.get_string(1) + "• " + inline_text(list_item.get_string(2)) + "\n"
		elif line.begins_with("> "): result += "[color=#9eabbc]│ " + inline_text(line.substr(2)) + "[/color]\n"
		elif line.strip_edges() in ["---", "***", "___"]: result += "────────────────────────\n"
		else: result += inline_text(line) + "\n"
	if code: result += "[/code]"
	return result
