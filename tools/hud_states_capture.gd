extends SceneTree
## Agent: claude-faisallaptop (cf-crowns-pass5-1105n). Real-game HUD states from the pass-4 playtest review: the first-match tip
## with and without a BLESSING! banner, the LEVEL UP strip with a notice scroll, and the kill-streak tag. Staged state, not play.
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1280x720 --script tools/hud_states_capture.gd -- [--map=2] [--tag=after]
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out := ""
var tag := "hud"


func _initialize() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join("%s_%s_%dp.png" % [tag, label, img.get_height()]))
	print("CAPTURE ", label)


func run() -> void:
	if not Isolated.ok("hud_states_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var map := 2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--map="):
			map = int(arg.trim_prefix("--map="))
	out = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	game._start_match(0)
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		await process_frame
	game._begin_battle()
	for i in 90:
		await process_frame
	var p = game.player
	# 1. The tip on its own, then a BLESSING! banner over the same band.
	game.toasts.clear()
	await shot("tip")
	game.toast("A Blessing of Regeneration has appeared near the north bank!", Color(1.0, 0.85, 0.4))
	await shot("tip_with_banner")
	# 2. LEVEL UP strip with a notice scroll and a streak.
	game.toasts.clear()
	p.points = 3
	p.streak = 3
	p.combat_at = -100.0
	for i in 400:
		await process_frame
	game.toast("HOME DEFENSE LOST", Color(0.95, 0.4, 0.3))
	await shot("levelup_toast")
	quit(0)
