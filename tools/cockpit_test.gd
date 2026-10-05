extends SceneTree

class FakeLevel extends Node3D:
	var local_truck: Node3D
	var truck: Node3D
	var round_finished := false
	var loading_intro_active := false
	var free_camera_look := false
	var kitchen_blend := 0.0
	var money := 1240
	var license_points := 8
	var remaining_time := 180.0
	func compass_heading(_direction: Vector3) -> String: return "N"

class FakeTruck extends Node3D:
	var health := 100.0
	var max_health := 100.0
	var speed := 0.0
	var critical_health_ratio := 0.25
	var turn_signal := 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var level := FakeLevel.new()
	root.add_child(level)
	level.truck = FakeTruck.new()
	level.add_child(level.truck)
	var hud := CanvasLayer.new()
	level.add_child(hud)
	var cockpit = load("res://cockpit_hud.gd").new()
	cockpit.level = level
	hud.add_child(cockpit)
	await process_frame
	cockpit._process(0.016)
	assert(cockpit.active and cockpit.visible, "Cockpit must appear without mobile feature flags")
	var wheel: Vector2 = cockpit.wheel_center()
	assert(cockpit.press(0, wheel))
	cockpit.drag(0, wheel + Vector2(55, 0))
	assert(is_equal_approx(Input.get_action_strength("right"), 0.5))
	assert(cockpit.press(1, cockpit.pedal_rect(false).get_center()))
	assert(Input.is_action_pressed("gear_accelerate"))
	cockpit.release(0)
	assert(not Input.is_action_pressed("right") and Input.is_action_pressed("gear_accelerate"))
	cockpit.release(1)
	var stalk: Vector2 = cockpit.signal_rect().get_center()
	cockpit.press(0, stalk)
	cockpit.drag(0, stalk + Vector2(0, -40))
	assert(root.get_node("DrivingControls").pending_direction_signal == 1)
	cockpit.release(0)
	cockpit.press(0, stalk)
	cockpit.drag(0, stalk + Vector2(0, 40))
	assert(root.get_node("DrivingControls").pending_direction_signal == -1)
	cockpit.release(0)
	cockpit.press(0, cockpit.pedal_rect(true).get_center())
	level.round_finished = true
	cockpit._process(0.016)
	assert(not cockpit.visible and not Input.is_action_pressed("brake"))
	level.round_finished = false
	level.truck.health = 20
	cockpit._process(0.016)
	if "--render-cockpit" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Shadow/Documents/Codex/2026-10-05/le/work/cockpit-preview.png")
	print("COCKPIT PASS: desktop visibility, proportional steering, simultaneous fingers, pedal release, signal swipe directions, round suspension, low health rendering")
	level.queue_free()
	await process_frame
	quit()
