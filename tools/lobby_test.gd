extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var host := "--mp-host" in OS.get_cmdline_user_args()
	var city := "--city" in OS.get_cmdline_user_args()
	var session: Node = root.get_node("NetworkSession")
	assert((session.start_host(24573, "Host") if host else session.start_join("127.0.0.1", 24573, "Guest")) == OK)
	var sent := false
	var selected := false
	var previous_state := ""
	var timeout := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < timeout:
		await process_frame
		var state := str([session.roster, session.started, is_instance_valid(session.level), session.loaded_players, session.last_snapshot.get("sequence", 0) > 0])
		if state != previous_state:
			print("LOBBY TEST STATE ", state)
			previous_state = state
		if session.roster.size() != 2: continue
		if not session.started:
			if is_instance_valid(session.level): assert(session.level.lobby_world)
			if host:
				if not selected:
					assert(not session.can_start())
					assert(not session.start_session())
					session.choose_level("Hilly City" if city else "Plaza")
					session.send_chat("Good luck!")
					selected = true
				if session.can_start():
					var branch_guest_id: int = session.roster.keys().filter(func(id): return id != 1)[0]
					assert(session.roster[branch_guest_id].color == 4)
					assert(session.chat_history.any(func(entry): return entry[1] == "Let's cook!"))
					assert(session.start_session())
			else:
				assert(not session.start_session())
				if not sent and session.chat_history.any(func(entry): return entry[1] == "Good luck!"):
					session.choose_level("Invalid")
					session.send_chat("Let's cook!")
					session.set_lobby_options(true, 4)
					sent = true
			continue
		if not is_instance_valid(session.level) or root.get_node("LoadingScreen").busy: continue
		var world: Node = session.level
		if world.trucks.size() != 2: continue
		if host and not session.world_ready(): continue
		if not host and session.last_snapshot.is_empty(): continue
		assert(world.has_node("ProceduralCity") == city)
		if city: assert(world.get_node("ProceduralCity").actual_seed == 12054)
		var street_display: Node = world.get_node("HUD/Layout/StreetNavigation")
		await process_frame
		assert(street_display.observed_truck == world.local_truck)
		if city:
			street_display.update_location(Vector2(-4, -50), Vector2.DOWN)
			assert(street_display.current_label.text == "ON  Pizza Avenue")
		var painted := false
		var guest_id: int = session.roster.keys().filter(func(id): return id != 1)[0]
		for mesh in world.trucks[guest_id].get_node("Model").find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				if material is StandardMaterial3D and "teal" in material.resource_name.to_lower():
					assert(material.albedo_color.is_equal_approx(session.COLORS[4]))
					painted = true
		assert(painted)
		print("LOBBY %s PASS: host-only start, ready gate, preset messages, purple truck, %s level, synchronized world" % ["HOST" if host else "CLIENT", session.selected_level])
		await create_timer(2.0 if host else 5.0).timeout
		quit()
		return
	push_error("Lobby test timed out")
	quit(1)
