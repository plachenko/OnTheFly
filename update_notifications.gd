extends Node

signal update_available(version: String)

const CHECK_SECONDS := 300.0
const PACKAGE := "OnTheFly_Windows.zip"
var repository := ""
var installed_version := ""
var available_version := ""
var notified_version := ""
var request: HTTPRequest
var notice: CanvasLayer
var android_client := false
var download_url := ""
var manual_check := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Editor/test runs do not contact the release service.
	if OS.has_feature("editor") or "--release-smoke-test" in OS.get_cmdline_user_args(): return
	android_client = OS.get_name() == "Android"
	if not android_client and OS.get_name() != "Windows": return
	var folder := OS.get_executable_path().get_base_dir()
	var config: Variant
	var manifest: Variant
	if android_client:
		config = {"repository": ProjectSettings.get_setting("application/config/update_repository", "plachenko/OnTheFly"), "auto_check": true}
		manifest = {"version": ProjectSettings.get_setting("application/config/version", "")}
	else:
		if not FileAccess.file_exists(folder.path_join("Update_Game.ps1")): return
		config = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("updater_config.json")))
		manifest = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("release_manifest.json")))
	if not config is Dictionary or not manifest is Dictionary: return
	if not config.get("auto_check", true): return
	repository = str(config.get("repository", ""))
	repository = repository.strip_edges().trim_prefix("https://github.com/").trim_suffix("/").trim_suffix(".git")
	var pattern := RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*$")
	if pattern.search(repository) == null: return
	installed_version = str(manifest.get("version", ""))
	if version_parts(installed_version).is_empty(): return
	request = HTTPRequest.new()
	request.timeout = 20.0
	request.body_size_limit = 1024 * 1024
	add_child(request)
	request.request_completed.connect(receive_release)
	var timer := Timer.new()
	timer.wait_time = CHECK_SECONDS
	add_child(timer)
	timer.timeout.connect(check_for_updates)
	timer.start()
	check_for_updates()

static func version_parts(value: String) -> PackedInt64Array:
	var pattern := RegEx.create_from_string("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
	var match_result := pattern.search(value)
	if match_result == null: return PackedInt64Array()
	return PackedInt64Array([match_result.get_string(1).to_int(), match_result.get_string(2).to_int(), match_result.get_string(3).to_int()])

static func is_newer(candidate: String, installed: String) -> bool:
	var a := version_parts(candidate)
	var b := version_parts(installed)
	if a.is_empty() or b.is_empty(): return false
	for index in 3:
		if a[index] != b[index]: return a[index] > b[index]
	return false

func release_version(data: Dictionary) -> String:
	if data.get("draft", true) or data.get("prerelease", true): return ""
	var tag := str(data.get("tag_name", ""))
	if not is_newer(tag, installed_version): return ""
	var found := {}
	var package_name := "OnTheFly.apk" if android_client else PACKAGE
	var assets = data.get("assets", [])
	if not assets is Array: return ""
	for asset in assets:
		if not asset is Dictionary: continue
		var asset_name := str(asset.get("name", ""))
		if asset_name not in [package_name, package_name + ".sha256"]: continue
		if found.has(asset_name) or asset.get("state", "") != "uploaded": return ""
		var url := str(asset.get("browser_download_url", ""))
		if not url.begins_with("https://github.com/%s/releases/download/" % repository): return ""
		found[asset_name] = true
	return tag.trim_prefix("v") if found.size() == 2 else ""

func check_for_updates(manual: bool = false) -> void:
	manual_check = manual_check or manual
	if request == null or request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	request.request("https://api.github.com/repos/%s/releases/latest" % repository, PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: OnTheFly-Client", "X-GitHub-Api-Version: 2022-11-28"]))

func receive_release(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# Offline play and API failures remain quiet; the timer retries later.
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if manual_check: show_status("Could not check for updates. Try again when you are online.")
		manual_check = false
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		if manual_check: show_status("The release service returned an invalid response.")
		manual_check = false
		return
	var version := release_version(data)
	if version.is_empty():
		if manual_check: show_status("No newer installable release is available for this device.")
		manual_check = false
		return
	if version == notified_version and not manual_check: return
	manual_check = false
	for asset in data.assets:
		if asset.get("name", "") == "OnTheFly.apk": download_url = str(asset.browser_download_url)
	available_version = version
	notified_version = version
	update_available.emit(version)
	show_notice()

func show_notice() -> void:
	if is_instance_valid(notice): notice.queue_free()
	notice = CanvasLayer.new()
	notice.layer = 100
	add_child(notice)
	var panel := PanelContainer.new()
	notice.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -380
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = 110
	var column := VBoxContainer.new()
	panel.add_child(column)
	var label := Label.new()
	label.text = "OnTheFly %s is available" % available_version
	column.add_child(label)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var update := Button.new()
	update.text = "Download APK" if android_client else "Open updater"
	update.pressed.connect(confirm_update)
	buttons.add_child(update)
	var later := Button.new()
	later.text = "Later"
	later.pressed.connect(func(): notice.queue_free())
	buttons.add_child(later)

func confirm_update() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Game update available"
	if android_client:
		dialog.dialog_text = "Download OnTheFly %s? Open the downloaded APK to install the update. Android may ask you to allow installs from your browser." % available_version
		dialog.ok_button_text = "Download APK"
		add_child(dialog)
		dialog.canceled.connect(dialog.queue_free)
		dialog.confirmed.connect(func():
			var error := OS.shell_open(download_url)
			dialog.queue_free()
			if error != OK: show_status("Could not open the APK download. Try again later."))
		dialog.popup_centered(Vector2i(540, 220))
		return
	dialog.dialog_text = "Close the game and open the launcher to install OnTheFly %s?" % available_version
	dialog.ok_button_text = "Exit and update"
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(func():
		var script_path := OS.get_executable_path().get_base_dir().path_join("Update_Game.ps1")
		var pid := OS.create_process("powershell.exe", PackedStringArray(["-NoProfile", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script_path, "-CheckOnOpen"]))
		if pid > 0: get_tree().quit()
		else:
			dialog.dialog_text = "Could not open the launcher. Open Launch_OnTheFly.cmd in the game folder."
			dialog.popup_centered())
	dialog.popup_centered(Vector2i(540, 180))

func show_status(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Game updates"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540, 180))
