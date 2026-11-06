extends SceneTree
## Agent: claude-faisal3 (cf-crowns-play-1106b). Before/after HUD stills at the current window size: a plain match, or --couch=2 for
## split screen. CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/hud_ba_capture.gd -- --play [--couch=2] --tag=after
const Isolated = preload("res://tools/tests/isolated.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if not Isolated.ok("hud_ba_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var out := OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var tag := "shot"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var waited := 0
	while (not game.playing or game.player == null or not game.player.is_on_floor() or (game.loading_layer != null and game.loading_layer.visible)) and waited < 6000:
		await process_frame
		waited += 1
	for i in 240:
		await process_frame
	await RenderingServer.frame_post_draw
	var vp := Vector2(DisplayServer.window_get_size())
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%dx%d.png" % [out, tag, int(vp.x), int(vp.y)])
	print("BA saved ", tag)
	quit(0)
