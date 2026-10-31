extends SceneTree
## Agent: Codex-faisal2. Actual courtyard/camera, deterministic rune-layer check.
const Isolated = preload("res://tools/tests/isolated.gd")
const Fx = preload("res://scripts/fx.gd")
var game
var output := ""
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("vfx_layer_capture"):
		quit(2)
		return
	output = OS.get_environment("CROWNS_CAPTURE_DIR")
	if output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			quit(2)
			return
		await process_frame
	for i in 12:
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for actor in game.units:
		actor.process_mode = Node.PROCESS_MODE_DISABLED
	var fx = Fx.of(game)
	var start: int = fx.get_child_count()
	seed(7)
	var where: Vector3 = game.player.global_position + Vector3(2.2, 0, 3.0)
	fx._x_rune(where, 2.6, Color(0.7, 0.45, 1.0), 1.2)
	var layers := []
	for index in range(start, fx.get_child_count()):
		if fx.get_child(index) is MeshInstance3D:
			layers.append(fx.get_child(index))
	var expected := 2 if fx.daylight() else 1
	check(layers.size() == expected, "expected layer count")
	var observations := []
	for tick in [0, 6, 12, 24]:
		if tick > 0:
			for i in (6 if tick <= 12 else 12):
				await process_frame
		var delta := 0.0
		if layers.size() == 2:
			delta = absf(wrapf(layers[0].rotation.y - layers[1].rotation.y, -PI, PI))
			check(delta < 0.0001, "rune layers aligned at tick %d (radians %.6f)" % [tick, delta])
			check(layers[0].scale.is_equal_approx(layers[1].scale), "layer scales match")
		observations.append({"tick": tick, "yaw_difference_radians": delta})
		if tick == 12 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("rune-gameplay.png")) == OK, "screenshot saved")
	for i in 100:
		await process_frame
	for layer in layers:
		check(not is_instance_valid(layer), "effect layer retires")
	var report := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"agent": "Codex-faisal2", "daylight": fx.daylight(), "layers": expected, "observations": observations, "failures": failures, "fixture": "actual courtyard and gameplay camera; rune staged at fixed position, not a combat playtest"}, "  "))
	print("VFX_LAYER_DONE failures=", failures)
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1
