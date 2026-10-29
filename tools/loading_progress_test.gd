extends SceneTree
## Agent: Codex-faisal3. Bounded rendered cold-boot and real summary-return
## regression. Run through tools/tests/isolated.sh under Xvfb/OpenGL in CI.
## --loading-baseline records the original non-streaming behavior separately.

const Isolated = preload("res://tools/tests/isolated.gd")
const SaveFile = preload("res://scripts/save_file.gd")
var failures := 0
var baseline := false
var evidence := ""


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	if not Isolated.ok("tools/loading_progress_test.gd"):
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		print("FAIL rendered loading test requires a real display")
		quit(2)
		return
	baseline = "--loading-baseline" in OS.get_cmdline_user_args()
	evidence = OS.get_environment("CROWNS_LOADING_EVIDENCE")
	if evidence.is_empty():
		evidence = OS.get_user_data_dir().path_join("loading-evidence")
	check(DirAccess.make_dir_recursive_absolute(evidence) == OK, "create evidence directory")
	_run.call_deferred()


func capture(name: String) -> void:
	var shot := root.get_texture().get_image()
	check(shot != null and not shot.is_empty() and shot.save_png(evidence.path_join(name + ".png")) == OK,
		"retain screenshot " + name)


func settle(phase: String, began: int, previous_id: int = 0):
	var deadline := Time.get_ticks_msec() + 180000
	var stream_frames := 0
	var first_draw := -1
	var worst_gap := 0
	var last := began
	var loading_shot := false
	while Time.get_ticks_msec() < deadline:
		var stage := "startup-inclusive"
		if first_draw >= 0:
			var before = current_scene
			if before != null and is_instance_valid(before):
				stage = "world" if before._stream_world else ("menus" if before.menus_warming else "other")
				if before.main_menu != null:
					stage += ":" + str(before.main_menu.screen)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_msec()
		if now - last >= 1000:
			print("LOAD_GAP phase=%s stage=%s ms=%d" % [phase, stage, now - last])
		worst_gap = maxi(worst_gap, now - last)
		last = now
		if first_draw < 0:
			first_draw = now - began
		var g = current_scene
		if g == null or not is_instance_valid(g) or g.get_instance_id() == previous_id:
			continue
		if g._stream_world:
			stream_frames += 1
		if not loading_shot and is_instance_valid(g.loading_layer):
			capture(phase + "-loading")
			loading_shot = true
		if g.main_menu != null and not g.menus_warming and not is_instance_valid(g.loading_layer):
			print("LOAD_TIMING phase=%s baseline=%s first_draw_ms=%d ready_ms=%d max_postdraw_gap_ms=%d stream_frames=%d" %
				[phase, baseline, first_draw, now - began, worst_gap, stream_frames])
			check(loading_shot, phase + " loading artwork drew")
			check(stream_frames == 0 if baseline else stream_frames >= 2,
				phase + (" records the original blocking build" if baseline else " draws frames during world construction"))
			check(g.main_menu.screen == "title" and not g.playing and not g._stream_world,
				phase + " lands on an interactive title")
			capture(phase + "-title")
			return g
	check(false, phase + " completes within 180 seconds")
	quit(1)
	return null


func _run() -> void:
	# Seed a real named player to avoid an unrelated first-run name overlay.
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "account_xp", 530)
	cfg.set_value("profile", "account_gold", 600)
	cfg.set_value("profile", "owned_items", [])
	cfg.set_value("settings", "hero_name", "Loading Test")
	cfg.set_value("settings", "sound_volume", 0.3)
	cfg.set_value("settings", "music_volume", 0.25)
	cfg.set_value("profiles", "current", "p1")
	check(DirAccess.make_dir_recursive_absolute("user://profiles") == OK, "create isolated player directory")
	check(SaveFile.write(cfg, "user://controls.cfg") == OK
		and SaveFile.write(SaveFile.profile_of(cfg), "user://profiles/p1.cfg") == OK, "seed isolated player")
	var began := Time.get_ticks_msec()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if "--loading-play-only" in OS.get_cmdline_user_args():
		var play_deadline := Time.get_ticks_msec() + 180000
		var play_stream_frames := 0
		var play_loading_shot := false
		while (not game.playing or is_instance_valid(game.loading_layer)) and Time.get_ticks_msec() < play_deadline:
			await RenderingServer.frame_post_draw
			if game._stream_world and is_instance_valid(game.loading_layer):
				play_stream_frames += 1
				if not play_loading_shot:
					capture("direct-play-loading")
					play_loading_shot = true
		check(play_stream_frames >= 2 and play_loading_shot, "direct --play draws loading frames during construction")
		check(game.playing and game.player != null and not is_instance_valid(game.loading_layer),
			"direct --play reaches the visible match")
		check(not game._stream_world and not game.menus_warming and game.process_mode == Node.PROCESS_MODE_INHERIT,
			"direct --play never remains in the menu construction gate")
		var clock_before: float = game.prep_left + game.time_left
		await create_timer(0.4).timeout
		check(game.prep_left + game.time_left < clock_before, "direct --play simulation advances")
		capture("direct-play")
		game._flush_save()
		game.queue_free()
		current_scene = null
		for i in 4:
			await process_frame
		print("loading progress test: %d failure(s)" % failures)
		quit(1 if failures else 0)
		return
	game = await settle("cold", began)
	if game == null:
		return
	check(game.account_xp == 530 and game.account_gold == 600 and game.profile_id == "p1", "cold boot retains player progress")
	game._start_match(0)
	var deadline := Time.get_ticks_msec() + 180000
	while is_instance_valid(game.loading_layer) and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
	check(not is_instance_valid(game.loading_layer) and game.player != null, "match loading finishes before summary")
	if is_instance_valid(game.loading_layer) or game.player == null:
		quit(1)
		return
	game._finish(0)
	game.summary.skip()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var xp: int = game.account_xp
	var gold: int = game.account_gold
	check(game.summary.done() and game.summary.continue_rect.has_area(), "real finished summary has a continue button")
	capture("summary-before-return")
	var previous_id: int = game.get_instance_id()
	began = Time.get_ticks_msec()
	game.hud._click_end(game.summary.continue_rect.get_center())
	check(not game._preserve_menu_art_on_reload if baseline else game._preserve_menu_art_on_reload,
		"summary uses " + ("original direct reload" if baseline else "cache-preserving reload helper"))
	game = await settle("return", began, previous_id)
	if game == null:
		return
	check(game.account_xp == xp and game.account_gold == gold and game.profile_id == "p1",
		"summary return retains banked progress and selected player")
	check(is_equal_approx(game.sfx.sound_volume, 0.3) and is_equal_approx(game.sfx.music_volume, 0.25),
		"summary return retains both volume settings")
	var mains := 0
	for child in root.get_children():
		if child.scene_file_path == "res://scenes/main.tscn":
			mains += 1
	check(mains == 1, "summary return leaves exactly one game scene")
	game._flush_save()
	game.queue_free()
	current_scene = null
	for i in 4:
		await process_frame
	print("loading progress test: %d failure(s)" % failures)
	quit(1 if failures else 0)
