extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Keyboard + mouse movement follows the aim (Faisal 2026-10-15), and the
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
	p.aim_point = p.global_position + Vector3(5, 0, 0)   # the cursor due east
	check(near(p.aim_relative(Vector2(0, -1)), Vector2(1, 0)), "W walks toward the cursor (east)")
	check(near(p.aim_relative(Vector2(0, 1)), Vector2(-1, 0)), "S backs away from it")
	check(near(p.aim_relative(Vector2(1, 0)), Vector2(0, 1)), "D steps to the right of the aim")
	check(near(p.aim_relative(Vector2(-1, 0)), Vector2(0, -1)), "A steps to the left of the aim")
	p.aim_point = p.global_position + Vector3(0.3, 0, 0)
	check(near(p.aim_relative(Vector2(0, -1)), Vector2(0, -1)), "with the cursor on the player, W walks up the screen")
	p.aim_point = p.global_position + Vector3(5, 0, 0)
	game.move_mode = "screen"
	check(near(p.aim_relative(Vector2(0, -1)), Vector2(0, -1)), "UP THE SCREEN keeps W walking up")
	game.move_mode = "aim"
	game.pad_active = true
	check(near(p.aim_relative(Vector2(0, -1)), Vector2(0, -1)), "a gamepad's stick is never turned")
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
	print("KBM MOVE TEST: %d failed" % fails)
	quit(fails)
