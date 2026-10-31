extends SceneTree
## Agent: Codex-faisal3. Staged crown-drop regression using the real match.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var failures := 0
var out_dir := OS.get_environment("CROWNS_CROWN_EVIDENCE")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + detail)
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in count:
		await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir.is_empty():
		return
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out_dir.path_join(label + ".png")) == OK, "capture " + label)

func run() -> void:
	if not Isolated.ok("codex3_crown_drop_test"):
		quit(2)
		return
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 180000
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("match loading timeout; run with --play")
			quit(2)
			return
		await process_frame
	# Freeze decision making, then stage the existing drop handler at real floors.
	game.set_process(false)
	game.prep_left = 0.0
	for unit in game.units:
		unit.set_physics_process(false)
	var u = game.player
	var crown = game.monarchs[1 - u.team]
	crown.set_process(false)
	var rampart := Vector3(-game.CASTLE_X, game.WALK_Y, -game.CASTLE_HALF_Z)
	u.global_position = rampart
	game.camera.global_position = rampart + game.CAMERA_OFFSET
	game.cam_pos = game.camera.global_position
	crown.pick_up(u)
	u.carrying = crown
	crown._process(0.0)
	await capture("rampart-carried")
	game.drop_monarch(u)
	crown._process(0.0)
	print("DROP rampart carrier=", u.global_position, " crown=", crown.global_position)
	check(is_equal_approx(crown.global_position.y, rampart.y), "rampart drop stays on carrier's floor")
	await capture("rampart-dropped")
	check_return(crown, "rampart")
	# The cellar is below grade; forcing y=0 makes its crown float overhead.
	var cellar := Vector3(game.CASTLE_X + game.CASTLE_DEPTH + 14.5, game.cellar_floor(1), -4.0)
	u.global_position = cellar
	game.camera.global_position = cellar + game.CAMERA_OFFSET
	crown.pick_up(u)
	u.carrying = crown
	game.drop_monarch(u)
	crown._process(0.0)
	print("DROP cellar carrier=", u.global_position, " crown=", crown.global_position)
	check(is_equal_approx(crown.global_position.y, cellar.y), "cellar drop stays on carrier's floor")
	await capture("cellar-dropped")
	check_return(crown, "cellar")
	# Returning directly above/below home must approach it, not snap by metres.
	crown.drop_at(crown.home + Vector3(0, game.WALK_Y, 0))
	var before: Vector3 = crown.global_position
	crown._process(0.1)
	check(crown.global_position.distance_to(before) <= crown.WALK_HOME_SPEED * 0.1 + 0.001,
		"vertical return respects homing speed")
	check(crown.state == crown.State.DROPPED, "vertical return does not teleport home")
	check_return(crown, "vertical")
	# Preserve the old ground-plane behavior too.
	crown.drop_at(crown.home + Vector3(2, 0, 0))
	check_return(crown, "ground")
	game.queue_free()
	await frames(30)
	print("crown drop test: %d failure(s)" % failures)
	quit(1 if failures else 0)

func check_return(crown, label: String) -> void:
	var before: Vector3 = crown.global_position
	var distance: float = before.distance_to(crown.home)
	crown._process(0.1)
	check(crown.global_position.distance_to(crown.home) < distance, label + " return approaches home")
	check(crown.global_position.distance_to(before) <= crown.WALK_HOME_SPEED * 0.1 + 0.001,
		label + " return respects homing speed")
	# Bounded simulated time: this runs the real dropped-state update, not wall time.
	for i in 2000:
		if crown.state == crown.State.HOME:
			break
		crown._process(0.1)
	check(crown.state == crown.State.HOME and crown.global_position.is_equal_approx(crown.home),
		label + " return reaches exact home")
