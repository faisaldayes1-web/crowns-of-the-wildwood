extends SceneTree
## Screenshots of the title, credits and Options pages for the Steam pass.
## Needs a display and an isolated save:
##     CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1280x720 --script tools/steam_menu_capture.gd
## claude-faisal3 2026-11-04.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out_dir := ""


func _initialize() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	print("CAPTURE ", label)


func run() -> void:
	if not Isolated.ok("steam_menu_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out_dir = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 120000
	if "--play" in OS.get_cmdline_user_args():
		# The paused Options page inside a match (the foot bar takes room).
		while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
			if Time.get_ticks_msec() > deadline:
				quit(1)
				return
			await process_frame
		game.menu_open = true
		game.menu_tab = 5
		await shot("options_in_match")
		quit(0)
		return
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.hero_name = "Player 1"
	game.main_menu.overlay = ""
	await shot("title")
	game.main_menu.overlay = "credits"
	await shot("credits")
	game.main_menu.overlay = ""
	game.menu_open = true
	game.menu_tab = 5
	await shot("options")
	quit(0)
