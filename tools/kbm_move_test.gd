extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Keyboard and stick movement is camera-relative (was: follows the aim, Faisal 2026-10-15; replaced 2026-10-29), and the
## hints follow the device last used. Run from the project root:
##     tools/tests/isolated.sh --headless --path . --script tools/kbm_move_test.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01


func _init() -> void:
	if not Isolated.ok("tools/kbm_move_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	var cfg := "user://controls.cfg"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(5)
	var m = game.main_menu
	m._press("play", null)
	m._press("team_size", 1)
	m._press("to_lobby", null)
	m.start()
	await frames(10)
	var p = game.player
	game.move_mode = "aim"
	game.pad_active = false
	game.touch_active = false
	p.has_mouse = true
	p.aim_mode = "mouse"
	# Directions are camera-relative (Codex-faisal, 2026-10-29, Faisal: forward
	# is screen-up and right is screen-right, whatever the hero faces or the
	# cursor does). The old "W walks toward the cursor" rule is gone.
	var cam: Camera3D = game.camera_for(p)
	var up := Vector2(-cam.global_basis.z.x, -cam.global_basis.z.z).normalized()
	var right := Vector2(cam.global_basis.x.x, cam.global_basis.x.z).normalized()
	for aim in [Vector3(5, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 5), Vector3(0.3, 0, 0)]:
		p.aim_point = p.global_position + aim
		check(near(p.aim_relative(Vector2(0, -1)), up), "W walks up the screen with the cursor at %s" % str(aim))
		check(near(p.aim_relative(Vector2(1, 0)), right), "D walks right on screen with the cursor at %s" % str(aim))
		check(near(p.aim_relative(Vector2(0, 1)), -up), "S walks down the screen with the cursor at %s" % str(aim))
		check(near(p.aim_relative(Vector2(-1, 0)), -right), "A walks left on screen with the cursor at %s" % str(aim))
	game.pad_active = true
	check(near(p.aim_relative(Vector2(0, -1)), up), "a gamepad's stick is camera-relative too")
	# The hints follow the last device: a mouse move after the pad goes back to keys.
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(20, 0)
	mm.position = Vector2(300, 300)
	game.menu_input(mm)
	check(not game.pad_active, "moving the mouse switches the hints back to keys")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	game.menu_input(jb)
	check(game.pad_active, "a pad button switches the hints to the pad")
	game.toggle_setting("move_screen")
	var cf := ConfigFile.new()
	cf.load(cfg)
	check(cf.get_value("settings", "move_mode", "") == "screen", "the movement pick is saved")
	# Retire the fixture's menu/world coroutines and playback before quitting the tree.
	current_scene = null
	game.free()
	await frames(4)
	print("KBM MOVE TEST: %d failed" % fails)
	quit(fails)
