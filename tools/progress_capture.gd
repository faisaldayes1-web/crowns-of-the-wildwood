extends SceneTree
## Agent: claude-faisallaptop (cf-crowns-pass5-1105n). Screenshots of the PROGRESS page at several account levels.
## Needs a display and an isolated save:
##     CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1280x720 --script tools/progress_capture.gd -- [--tag=after]
const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")
var game
var out_dir := ""
var tag := "progress"


func _initialize() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("%s_%s_%dp.png" % [tag, label, img.get_height()]))
	print("CAPTURE ", label, " ", img.get_size())


func xp_for_level(level: int, into: int) -> int:
	var xp := 0
	for l in range(1, level):
		xp += Stats.account_level_cost(l)
	return xp + into


func run() -> void:
	if not Isolated.ok("progress_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	out_dir = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 120000
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.hero_name = "Faisal"
	for step in [["lv1", 1, 0, 0], ["lv4", 4, 429, 220], ["lv10", 10, 120, 300], ["lv25", 25, 900, 150], ["lv50", 50, 0, 0]]:
		game.account_xp = xp_for_level(step[1], step[2])
		game.last_match_gain = step[3]
		game.main_menu.overlay = "progress"
		await shot(step[0])
	quit(0)
