extends SceneTree
## Windowed shot of each turret build spot at the game's camera angle (claude-faisal3 11-05):
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/spot_capture.gd -- --play [--map=N]
const Isolated = preload("res://tools/tests/isolated.gd")

var game


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func run() -> void:
	if not Isolated.ok("spot_capture") or DisplayServer.get_name() == "headless":
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
	await _frames(60)
	game.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 50
	game.add_child(cam)
	cam.make_current()
	var spots: Array = game.turret_spots(0) + game.turret_spots(1)
	for i in spots.size():
		var s: Vector3 = spots[i]
		cam.global_position = s + Vector3(0, 11.0, 9.0)
		cam.look_at(s, Vector3.UP)
		await _frames(12)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/spot%d.png" % [out, i])
		print("SPOT saved ", i, " ", s)
	quit(0)
