extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var updates = root.get_node("UpdateNotifications")
	updates.repository = "owner/game"
	updates.installed_version = "0.4.13"
	assert(updates.is_newer("v0.4.14", "0.4.13"))
	assert(updates.is_newer("0.10.0", "0.9.9"))
	for invalid in ["v0.4.13", "v0.4.12", "v0.4.14-beta", "garbage"]:
		assert(not updates.is_newer(invalid, "0.4.13"))
	var data := {"draft": false, "prerelease": false, "tag_name": "v0.4.14", "assets": []}
	for asset_name in [updates.PACKAGE, updates.PACKAGE + ".sha256"]:
		data.assets.append({"name": asset_name, "state": "uploaded", "browser_download_url": "https://github.com/owner/game/releases/download/v0.4.14/" + asset_name})
	assert(updates.release_version(data) == "0.4.14")
	data.draft = true
	assert(updates.release_version(data).is_empty())
	data.draft = false
	data.prerelease = true
	assert(updates.release_version(data).is_empty())
	data.prerelease = false
	var checksum = data.assets.pop_back()
	assert(updates.release_version(data).is_empty())
	data.assets.append(checksum)
	data.assets[0].browser_download_url = "https://evil.example/package.zip"
	assert(updates.release_version(data).is_empty())
	data.assets[0].browser_download_url = "https://github.com/owner/game/releases/download/v0.4.14/" + updates.PACKAGE
	updates.receive_release(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(data).to_utf8_buffer())
	assert(updates.available_version == "0.4.14")
	var first_notice = updates.notice
	updates.receive_release(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(data).to_utf8_buffer())
	assert(updates.notice == first_notice, "Same version does not repeatedly notify")
	updates.receive_release(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	assert(updates.notice == first_notice)
	updates.android_client = true
	assert(updates.release_version(data).is_empty(), "Android must ignore Windows-only releases")
	data.assets = []
	for asset_name in ["OnTheFly.apk", "OnTheFly.apk.sha256"]:
		data.assets.append({"name": asset_name, "state": "uploaded", "browser_download_url": "https://github.com/owner/game/releases/download/v0.4.14/" + asset_name})
	assert(updates.release_version(data) == "0.4.14")
	updates.notified_version = ""
	updates.receive_release(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(data).to_utf8_buffer())
	assert(updates.download_url.ends_with("/OnTheFly.apk"))
	assert(updates.notice.get_child(0).get_child(0).get_child(1).get_child(0).text == "Download APK")
	print("UPDATE NOTIFICATIONS PASS: version comparison, stable complete releases, asset URLs, single notice, offline behavior")
	quit()
