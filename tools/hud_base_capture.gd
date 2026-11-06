extends SceneTree
## Agent: claude-faisal3 (cf-crowns-play-1106b). One clean 1080p in-match HUD still (bots live, no card open) for skill-bar mock-ups.
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/hud_base_capture.gd -- --play [--map=N]
const Isolated = preload("res://tools/tests/isolated.gd")
var game


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func run() -> void:
	if not Isolated.ok("hud_base_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var out := OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var waited := 0
	while (not game.playing or game.player == null or not game.player.is_on_floor() or (game.loading_layer != null and game.loading_layer.visible)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(90)
	var p = game.player
	game.prep_left = 0.0
	p.global_position = Vector3(-30, 0.5, 6)
	await _frames(300)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/hud_base.png" % out)
	game.hud.visible = false
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/hud_plate.png" % out)
	print("HUDBASE saved")
	quit(0)
