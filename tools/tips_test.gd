extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
const Tips = preload("res://scripts/tips.gd")
## First-match tips: they walk the list per local player, follow the device,
## can be skipped, are saved when done and replay when switched on again.
## Run from the project root:
##     tools/tests/isolated.sh --headless --path . --script tools/tips_test.gd
## claude-faisal3, task cf-crowns-onboard-1104x.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	if not Isolated.ok("tools/tips_test.gd"):
		quit(2)
		return
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
	game.prep_left = 0.0
	check(game.tips_on and not game.tips_done, "tips start on and not done")
	check(Tips.current(game, p, 0.1).begins_with("Move"), "the first tip is movement")
	p.global_position += Vector3(6, 0, 0)
	var t := Tips.current(game, p, 0.1)
	check(t.begins_with("Pick a class") or t.begins_with("Attack"), "moving clears the move tip (got '%s')" % t)
	game.pad_active = true
	check(Tips.text_for(game, p, "move").contains("STICK"), "a pad player sees the stick, not keys")
	game.pad_active = false
	check(Tips.text_for(game, p, "goal").length() < 70, "tips are one short line")
	game.game_mode = "tdm"
	check(Tips.text_for(game, p, "goal").contains("kills"), "deathmatch tip names the kill target")
	game.game_mode = "ctf"
	# Ignored tips time out; a finished list is saved and stays away.
	for i in 12:
		Tips.current(game, p, 12.5)
	check(Tips.current(game, p, 0.1) == "", "an ignored list times out")
	check(game.tips_done, "the finished list is remembered")
	var cf := ConfigFile.new()
	cf.load("user://controls.cfg")
	check(cf.get_value("settings", "tips_done", false) == true, "tips_done is saved")
	game.toggle_setting("tips")
	game.toggle_setting("tips")
	check(game.tips_on and not game.tips_done and Tips.current(game, p, 0.1).begins_with("Move"), "switching Tips back on replays them")
	print("tips test: %d failure(s)" % fails)
	quit(fails)
