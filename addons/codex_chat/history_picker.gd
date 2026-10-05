@tool
extends AcceptDialog

signal refresh_requested(cursor: String)
signal history_selected(id: String, resume: bool)
var chats: ItemList
var thread_input: LineEdit
var hint: Label
var next_cursor := ""

func _ready() -> void:
	title = "Project conversation history"
	ok_button_text = "Close"
	var rows := VBoxContainer.new()
	add_child(rows)
	hint = Label.new()
	hint.text = "Select a project chat or paste its thread ID."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)
	chats = ItemList.new()
	chats.custom_minimum_size = Vector2(600, 250)
	rows.add_child(chats)
	chats.item_selected.connect(func(index): thread_input.text = str(chats.get_item_metadata(index)))
	thread_input = LineEdit.new()
	thread_input.placeholder_text = "Existing conversation thread ID"
	rows.add_child(thread_input)
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	for spec in [["Refresh", refresh], ["More", more], ["Import context", import_context], ["Resume chat", resume_chat]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		actions.add_child(button)

func refresh() -> void:
	chats.clear()
	next_cursor = ""
	refresh_requested.emit("")

func more() -> void:
	if not next_cursor.is_empty(): refresh_requested.emit(next_cursor)

func show_results(result: Dictionary) -> void:
	for thread in result.get("data", []):
		var label := str(thread.get("name", ""))
		if label.is_empty(): label = str(thread.get("preview", "Untitled chat")).left(100)
		var index := chats.add_item(label)
		chats.set_item_metadata(index, str(thread.id))
		chats.set_item_tooltip(index, str(thread.get("cwd", "")) + "\n" + str(thread.id))
	next_cursor = str(result.get("nextCursor", "")) if result.get("nextCursor") != null else ""
	hint.text = "%d project chats. Import copies context; Resume continues the selected conversation." % chats.item_count

func import_context() -> void: choose(false)
func resume_chat() -> void: choose(true)
func choose(resume: bool) -> void:
	var id := thread_input.text.strip_edges()
	if id.is_empty():
		hint.text = "Select a conversation first."
		return
	history_selected.emit(id, resume)
