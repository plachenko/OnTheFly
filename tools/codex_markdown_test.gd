extends SceneTree

func _initialize() -> void:
	verify.call_deferred()

func verify() -> void:
	var markdown := load("res://addons/codex_chat/markdown.gd")
	var result: String = markdown.render("# Title\n**Bold** and *italic* and `a[b]`\n- Item\n> Quote\n[Docs](https://example.com)\n```gdscript\n[img]bad[/img]\n```\n| A | B |\n| --- | --- |\n| 1 | 2 |")
	assert(result.contains("[b]Title[/b]"))
	assert(result.contains("[b]Bold[/b]") and result.contains("[i]italic[/i]"))
	assert(result.contains("[code]a[lb]b[rb][/code]"))
	assert(result.contains("• Item") and result.contains("│ Quote"))
	assert(result.contains("[url=https://example.com]Docs[/url]"))
	assert(not result.contains("[img]"))
	assert(result.contains("[table=2]") and result.contains("[left]2[/left][/cell]"))
	assert(result.contains("[b]A[/b]") and result.contains("border=#637083"))
	var optional: String = markdown.render("Name | Value\n:--- | ---:\nA\\|B | `x|y`\n\nAfter")
	assert(optional.contains("[table=2]") and optional.contains("[right][code]x|y[/code][/right]"))
	assert(optional.contains("A|B") and optional.contains("[/table]\n\nAfter"))
	assert(not markdown.render("ordinary | prose\nmore text").contains("[table="))
	assert(not markdown.render("[Danger](javascript:alert)").contains("[url="))
	assert(markdown.render("```\nunclosed").ends_with("[/code]"))
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	root.add_child(label)
	label.text = result
	assert(label.get_parsed_text().contains("a[b]"))
	assert(not label.get_parsed_text().contains("[code]"))
	assert(label.get_parsed_text().contains("[img]bad[/img]"))
	label.size = Vector2(720, 480)
	label.text = markdown.render("## Performance comparison\nFeature | Enabled | Disabled\n:--- | ---: | ---:\nTraffic logic | 42 FPS | **60 FPS**\nGrass | 55 FPS | 60 FPS\nStreet furniture | 58 FPS | 60 FPS")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/codex_markdown_preview.png")
	label.queue_free()
	print("CODEX MARKDOWN PASS: headings, emphasis, code, lists, quotes, links, tables and literal BBCode")
	quit()
