extends SceneTree
## Agent: claude-faisal3 (cf-crowns-next-1106d). Every menu screen at the current window size: title, map, Create Your
## Character (6 tabs), Ready Up, store, progress, Settings (5 tabs), then in a match the pause tabs and the results.
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/menu_screens_capture.gd -- --tag=m
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out := ""
var tag := "m"
var n := 0


func _initialize() -> void:
	call_deferred("run")


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var vp := Vector2(DisplayServer.window_get_size())
	n += 1
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%02d_%s_%dx%d.png" % [out, tag, n, name, int(vp.x), int(vp.y)])
	print("MENU saved ", name)


func run() -> void:
	if not Isolated.ok("menu_screens_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var waited := 0
	while (game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(90)
	var m = game.main_menu
	await _shot("title")
	m.go("map")
	await _frames(40)
	await _shot("map")
	m.go("character")
	for t in 6:
		m.char_tab = t
		await _frames(30)
		await _shot("customize-%d" % t)
	m.go("lobby")
	await _frames(40)
	await _shot("readyup")
	game.couch_players = 2
	game.split_screen = true
	await _frames(30)
	await _shot("readyup-2p")
	game.couch_players = 1
	game.split_screen = false
	m.go("store")
	await _frames(60)
	await _shot("store")
	m.go("title")
	m.overlay = "progress"
	await _frames(30)
	await _shot("progress")
	m.overlay = "credits"
	await _frames(20)
	await _shot("credits")
	m.overlay = ""
	game.menu_open = true
	game.menu_tab = 5
	await _frames(40)
	for t in 5:
		game.options_screen.select_tab(t)
		await _frames(20)
		await _shot("settings-%d" % t)
	game.menu_open = false
	game.menu_tab = 0
	await _frames(20)
	if "--menus-only" in OS.get_cmdline_user_args():
		quit(0)
		return
	m.go("map")
	game._start_match(0)
	waited = 0
	while (not game.playing or game.player == null or not game.player.is_on_floor() or (game.loading_layer != null and game.loading_layer.visible)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(120)
	game.menu_open = true
	for t in [0, 1, 2, 3]:
		game.menu_tab = t
		await _frames(30)
		await _shot("pause-%d" % t)
	game.menu_open = false
	game.menu_tab = 0
	await _frames(10)
	game._finish(game.player_team)
	await _frames(60)
	await _shot("results-early")
	await _frames(500)
	await _shot("results-late")
	if game.summary:
		game.summary.show_board = true
		await _frames(30)
		await _shot("results-board")
	quit(0)
