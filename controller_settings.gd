extends CanvasLayer

@export_range(.02,.4) var stick_deadzone: float = .18
@export_range(.01,.3) var trigger_deadzone: float = .05
@export_range(.5,2.0) var steering_sensitivity: float = 1.0
@export var vibration_enabled: bool = true
@export var truck_path: NodePath = NodePath("../FoodTruck")
@onready var truck = get_node(truck_path)
@onready var panel: Panel = $Layout/ControllerPanel
var upgrade_tab: bool = false
var options_from_pause: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var options=get_node("/root/GameOptions")
	stick_deadzone=options.stick_deadzone
	trigger_deadzone=options.trigger_deadzone
	steering_sensitivity=options.steering_sensitivity
	vibration_enabled=options.vibration_enabled
	panel.visible=false
	$Layout/PausePanel.hide()
	options.bind_video_audio(panel)
	$Layout/StartButton.pressed.connect(toggle_pause)
	$Layout/PausePanel/Resume.pressed.connect(resume_game)
	$Layout/PausePanel/Options.pressed.connect(toggle)
	$Layout/PausePanel/Quit.pressed.connect(func(): get_tree().quit())
	$Layout/ControllerPanel/StickDeadzone.value=stick_deadzone
	$Layout/ControllerPanel/TriggerDeadzone.value=trigger_deadzone
	$Layout/ControllerPanel/SteeringSensitivity.value=steering_sensitivity
	$Layout/ControllerPanel/Vibration.button_pressed=vibration_enabled
	$Layout/ControllerPanel/StickDeadzone.value_changed.connect(func(value): stick_deadzone=value; apply_settings())
	$Layout/ControllerPanel/TriggerDeadzone.value_changed.connect(func(value): trigger_deadzone=value; apply_settings())
	$Layout/ControllerPanel/SteeringSensitivity.value_changed.connect(func(value): steering_sensitivity=value; apply_settings())
	$Layout/ControllerPanel/Vibration.toggled.connect(func(value): vibration_enabled=value; apply_settings())
	$Layout/ControllerPanel/Close.pressed.connect(toggle)
	apply_settings()
	$Layout/RepairPanel/FullFix.pressed.connect(func(): get_parent().buy_repair(0))
	$Layout/RepairPanel/GoodFix.pressed.connect(func(): get_parent().buy_repair(1))
	$Layout/RepairPanel/MidFix.pressed.connect(func(): get_parent().buy_repair(2))
	$Layout/RoundEndPanel/Restart.pressed.connect(restart_round)
	$Layout/RoundEndPanel/MainMenu.pressed.connect(func(): get_node("/root/GameOptions").round_balance=get_parent().money; get_tree().paused=false; get_tree().change_scene_to_file("res://main_menu.tscn"))
	$Layout/RoundEndPanel/Quit.pressed.connect(func(): get_tree().quit())
	$Layout/RepairPanel/RepairsTab.pressed.connect(func(): upgrade_tab=false)
	$Layout/RepairPanel/UpgradesTab.pressed.connect(func(): upgrade_tab=true)
	var upgrade_buttons=[$Layout/RepairPanel/UpgradeList/Booster,$Layout/RepairPanel/UpgradeList/Canister,$Layout/RepairPanel/UpgradeList/Drifting,$Layout/RepairPanel/UpgradeList/LiftKit,$Layout/RepairPanel/UpgradeList/Armor,$Layout/RepairPanel/UpgradeList/FullSelfDriving]
	for i in 6:
		upgrade_buttons[i].pressed.connect(get_parent().buy_upgrade.bind(i))

func apply_settings() -> void:
	var options=get_node("/root/GameOptions")
	options.stick_deadzone=stick_deadzone
	options.trigger_deadzone=trigger_deadzone
	options.steering_sensitivity=steering_sensitivity
	options.vibration_enabled=vibration_enabled
	for action in ["left","right","camera_left","camera_right","camera_up","camera_down"]:
		InputMap.action_set_deadzone(action,stick_deadzone)
	for action in ["accelerate","brake"]:
		InputMap.action_set_deadzone(action,trigger_deadzone)
	truck.steering_sensitivity=steering_sensitivity
	truck.vibration_enabled=vibration_enabled
	$Layout/ControllerPanel/StickDeadzoneLabel.text="Stick deadzone %d%%"%roundi(stick_deadzone*100)
	$Layout/ControllerPanel/TriggerDeadzoneLabel.text="Trigger deadzone %d%%"%roundi(trigger_deadzone*100)
	$Layout/ControllerPanel/SteeringSensitivityLabel.text="Steering sensitivity %.2f"%steering_sensitivity

func toggle() -> void:
	if not panel.visible:
		refresh_options()
		options_from_pause=$Layout/PausePanel.visible
		$Layout/PausePanel.hide()
		panel.show()
		get_tree().paused=true
		$Layout/ControllerPanel/Close.grab_focus()
	else:
		panel.hide()
		if options_from_pause:
			$Layout/PausePanel.show()
			$Layout/PausePanel/Resume.grab_focus()
		else:resume_game()

func refresh_options() -> void:
	var options=get_node("/root/GameOptions")
	stick_deadzone=options.stick_deadzone
	trigger_deadzone=options.trigger_deadzone
	steering_sensitivity=options.steering_sensitivity
	vibration_enabled=options.vibration_enabled
	panel.get_node("StickDeadzone").set_value_no_signal(stick_deadzone)
	panel.get_node("TriggerDeadzone").set_value_no_signal(trigger_deadzone)
	panel.get_node("SteeringSensitivity").set_value_no_signal(steering_sensitivity)
	panel.get_node("Vibration").set_pressed_no_signal(vibration_enabled)
	options.sync_video_audio(panel)
	apply_settings()

func resume_game() -> void:
	panel.hide()
	$Layout/PausePanel.hide()
	get_tree().paused=false
	get_viewport().gui_release_focus()

func toggle_pause() -> void:
	if $Layout/PausePanel.visible:
		resume_game()
	else:
		panel.hide()
		$Layout/PausePanel.show()
		get_tree().paused=true
		$Layout/PausePanel/Resume.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and panel.visible:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_game"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("new_round") and get_parent().round_finished:
		restart_round()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("controller_settings"):
		toggle()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var devices=Input.get_connected_joypads()
	$Layout/ControllerPanel/ControllerName.text="Connected: "+Input.get_joy_name(devices[0]) if not devices.is_empty() else "No joypad detected — connect MCON in gamepad mode"
	var level = get_parent()
	var patron_manager=level.get_node("PatronManager")
	var serving_pad=level.active_serving_pad()
	var displayed_pad=truck.parking_pad
	if is_instance_valid(displayed_pad) and displayed_pad!=level.repair_pad and displayed_pad.serving_enabled and displayed_pad.contains_truck(truck) and truck.deployed and truck.opening>.99 and absf(truck.speed)<.5:
		$Layout/PadMeter.show()
		$Layout/PadMeter/Caption.text=displayed_pad.meter_text()
		$Layout/PadMeter/Caption.modulate=Color("ff806f") if displayed_pad.expired else Color("83e8ad")
		var progress=$Layout/PadMeter/Progress
		progress.value=displayed_pad.meter_percent()
		progress.add_theme_stylebox_override("fill",progress.get_meta("red_fill") if displayed_pad.expired else progress.get_meta("green_fill"))
		$Layout/PadMeter/Fee.text="$%d total fees this round • Close shop or move"%level.total_pad_fees if displayed_pad.expired else "The serving window keeps draining after you open."
	else:$Layout/PadMeter.hide()
	var pad_status="Park on green and open the kitchen."
	if is_instance_valid(truck.parking_pad) and truck.parking_pad!=level.repair_pad:
		pad_status="PAD CLOSED — find another green pad" if truck.parking_pad.expired else ("SERVING %d/%d • %ds left"%[truck.parking_pad.patrons.size(),truck.parking_pad.patron_capacity,ceili(truck.parking_pad.service_remaining)] if serving_pad else "GREEN PAD — open kitchen to serve")
	var menu_items: Array[String]=[]
	for food in level.food_menu:menu_items.append("%s $%d"%[food.food_name,food.price])
	$Layout/PatronPanel/Info.text="PATRONS %d / %d   •   FED %d\n%s\n%s\n%s"%[level.get_node("Patrons").get_child_count(),patron_manager.maximum_patrons,patron_manager.served_orders," / ".join(menu_items),pad_status,patron_manager.last_sale]
	var seconds = ceili(level.remaining_time)
	$Layout/SessionPanel/TimeLabel.text="TIME %d:%02d"%[seconds/60,seconds%60]
	$Layout/SessionPanel/MoneyLabel.text="MONEY $%d"%level.money
	$Layout/SessionPanel/GoalLabel.text="EARNED $%d / $%d — Open kitchen on a serving pad"%[level.money_earned,level.earnings_target]
	$Layout/SessionPanel/LuckLabel.text="Carried from last round" if level.carried_balance else "Starting luck %s$%d"%["+" if level.starting_luck>=0 else "-",absi(level.starting_luck)]
	var show_repair = level.can_repair() and not panel.visible and not $Layout/PausePanel.visible
	var just_arrived = show_repair and not $Layout/RepairPanel.visible
	$Layout/RepairPanel.visible=show_repair
	$Layout/RepairPanel/RepairsTab.modulate=Color("4fcede") if not upgrade_tab else Color.WHITE
	$Layout/RepairPanel/UpgradesTab.modulate=Color("4fcede") if upgrade_tab else Color.WHITE
	$Layout/RepairPanel/UpgradeList.visible=upgrade_tab
	$Layout/RepairPanel/FullFix.visible=not upgrade_tab
	$Layout/RepairPanel/GoodFix.visible=not upgrade_tab
	$Layout/RepairPanel/MidFix.visible=not upgrade_tab
	$Layout/RepairPanel/Hint.visible=not upgrade_tab
	$Layout/RepairPanel/TimeHint.visible=not upgrade_tab
	$Layout/BoostPanel/BoostMeter.value=truck.boost_fuel/truck.boost_capacity*100.0
	$Layout/BoostPanel/BoostLabel.text="BOOST %d%% — HOLD RB / SHIFT"%roundi(truck.boost_fuel/truck.boost_capacity*100.0) if truck.booster_owned else "BOOST — BUY BOOSTER + CANISTERS"
	var upgrades=[$Layout/RepairPanel/UpgradeList/Booster,$Layout/RepairPanel/UpgradeList/Canister,$Layout/RepairPanel/UpgradeList/Drifting,$Layout/RepairPanel/UpgradeList/LiftKit,$Layout/RepairPanel/UpgradeList/Armor,$Layout/RepairPanel/UpgradeList/FullSelfDriving]
	var upgrade_names=["Booster","Boost canister (+50%)","Drifting","Lift kit","Armor","Full Self Driving"]
	for i in 6:
		var quote=level.upgrade_quote(i)
		upgrades[i].text="%s — $%d%s"%[upgrade_names[i],quote.price,"  (Installed)" if i!=1 and not quote.available else ""]
		upgrades[i].disabled=not quote.available or quote.price>level.money
	$Layout/RepairPanel/HealthLabel.text="Health %.1f%%   •   Balance $%d"%[truck.health/truck.max_health*100.0,level.money]
	var repair_buttons=[$Layout/RepairPanel/FullFix,$Layout/RepairPanel/GoodFix,$Layout/RepairPanel/MidFix]
	for i in 3:
		var quote=level.repair_quote(i)
		repair_buttons[i].text="%s — $%d  (+%.1f health)"%[["Full fix","Good fix","Mid fix"][i],quote.price,quote.amount]
		repair_buttons[i].disabled=quote.amount<=.01 or quote.price>level.money
	if just_arrived:
		$Layout/RepairPanel/RepairsTab.grab_focus()
	$Layout/RepairPanel/Hint.text="Truck fully repaired." if truck.health>=truck.max_health-.01 else "Full: all damage • Good: half • Mid: quarter\nFull fix has the best price per health point."
	var end_panel=$Layout/RoundEndPanel
	var just_finished = level.round_finished and not end_panel.visible
	end_panel.visible=level.round_finished and not panel.visible and not $Layout/PausePanel.visible
	if just_finished and end_panel.visible:
		$Layout/RoundEndPanel/Restart.grab_focus()
	$Layout/RoundEndPanel/Title.text="SUCCESS!" if level.round_won else "GAME OVER"
	$Layout/RoundEndPanel/Title.modulate=Color("66dfb4") if level.round_won else Color("f49a76")
	$Layout/RoundEndPanel/Summary.text="%s\nEarned $%d / $%d target\nBalance $%d   •   Time left %d:%02d"%["Money target reached!" if level.round_won else "Time ran out before the money target.",level.money_earned,level.earnings_target,level.money,seconds/60,seconds%60]

func restart_round() -> void:
	get_node("/root/GameOptions").round_balance=get_parent().money
	get_tree().paused=false
	var current_level: String = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file.call_deferred(current_level if not current_level.is_empty() else "res://main.tscn")
