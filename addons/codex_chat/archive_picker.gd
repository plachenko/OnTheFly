@tool
extends AcceptDialog
signal continue_requested(snapshot: Dictionary)
signal file_requested(path: String, line: int)
const Archive = preload("res://addons/codex_chat/conversation_archive.gd")
var chats: ItemList
var files: ItemList
var preview: RichTextLabel
var diff: TextEdit
var hint: Label
var records: Array[Dictionary] = []
var selected: Dictionary = {}

func _ready() -> void:
	title = "Local project archive"
	ok_button_text = "Close"
	var rows := VBoxContainer.new()
	add_child(rows)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)
	var columns := HSplitContainer.new()
	rows.add_child(columns)
	chats = ItemList.new()
	chats.custom_minimum_size = Vector2(240, 300)
	columns.add_child(chats)
	preview = RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.selection_enabled = true
	preview.meta_clicked.connect(func(url):
		var target := str(url)
		if not target.begins_with("godot-file:"): return
		var parts := target.trim_prefix("godot-file:").split("#")
		file_requested.emit(parts[0].uri_decode(), maxi(1, int(parts[1])) if parts.size() > 1 else 1))
	preview.custom_minimum_size = Vector2(470, 300)
	columns.add_child(preview)
	chats.item_selected.connect(select_snapshot)
	var changes := HSplitContainer.new()
	rows.add_child(changes)
	files = ItemList.new()
	files.custom_minimum_size = Vector2(240, 160)
	changes.add_child(files)
	diff = TextEdit.new()
	diff.editable = false
	diff.custom_minimum_size = Vector2(470, 160)
	changes.add_child(diff)
	files.item_selected.connect(func(index): diff.text = str(files.get_item_metadata(index).get("diff", "No diff was reported.")))
	files.item_activated.connect(open_selected_file)
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	for spec in [["Refresh", refresh], ["Open changed file", open_file], ["Continue from archive", continue_chat]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		actions.add_child(button)

func refresh() -> void:
	records = Archive.list_snapshots()
	chats.clear()
	files.clear()
	preview.clear()
	diff.text = ""
	selected = {}
	for record in records:
		var timestamp := Time.get_datetime_string_from_unix_time(int(record.get("updated_at", 0)))
		var index := chats.add_item(str(record.get("title", "Untitled")) + "\n" + timestamp + " UTC")
		chats.set_item_tooltip(index, str(record.archive_path))
	hint.text = "%d archived conversations. Select a file to view its reported diff; double-click to open it. Continue imports context into a new chat." % records.size()

func select_snapshot(index: int) -> void:
	selected = records[index]
	var text := str(selected.get("transcript_source", ""))
	var tokens := RegEx.new()
	tokens.compile("<!--godot-command(?:-group)?:[0-9]+-->")
	text = tokens.sub(text, "", true)
	preview.text = preload("res://addons/codex_chat/markdown.gd").render(text)
	for entry in selected.get("commands", {}).values():
		var escape_text := preload("res://addons/codex_chat/markdown.gd")
		preview.text += "\n[b]Command[/b]\n[code]%s\n%s[/code]\n" % [escape_text.escape(str(entry.get("command", ""))), escape_text.escape(str(entry.get("output", "")))]
	files.clear()
	diff.text = ""
	for change in selected.get("file_changes", []):
		if not change is Dictionary: continue
		var row := files.add_item(str(change.get("path", "")))
		files.set_item_metadata(row, change)
	hint.text = "%s · %d file-change entries · %s" % [selected.get("title", "Untitled"), files.item_count, selected.archive_path]

func open_selected_file(index: int) -> void:
	var change: Dictionary = files.get_item_metadata(index)
	file_requested.emit(str(change.get("path", "")), preload("res://addons/codex_chat/auto_drive.gd").changed_line(str(change.get("diff", ""))))

func open_file() -> void:
	var indices := files.get_selected_items()
	if not indices.is_empty(): open_selected_file(indices[0])

func continue_chat() -> void:
	if selected.is_empty():
		hint.text = "Select an archived conversation first."
		return
	continue_requested.emit(selected)
