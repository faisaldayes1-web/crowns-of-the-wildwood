extends SceneTree
## Agent: claude-faisal3, 2026-10-29 loading pass (PERF-04 in the desktop
## pass). Starting a match from the title builds it within the same frame
## (seconds, with the static batching); the loading art used to be drawn only
## after all of it, so the clicked title sat frozen. This checks a frame with
## the art is drawn right after _start_match is called, before the build ends.
## Rendered only: tools/tests/isolated.sh --path . --script tools/match_start_art_test.gd

const Isolated = preload("res://tools/tests/isolated.gd")
var failures := 0
var game: Node
var drawn_at := -1   # usec of the first frame drawn after the call
var called_at := -1
var art_drawn := false


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	if not Isolated.ok("tools/match_start_art_test.gd"):
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		print("FAIL the match-start loading art test needs a real display")
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	_run.call_deferred()


func _post_draw() -> void:
	if called_at >= 0 and drawn_at < 0:
		drawn_at = Time.get_ticks_usec()
		art_drawn = is_instance_valid(game.loading_layer)


func _run() -> void:
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and not (game.main_menu != null and not game.menus_warming
			and not game._stream_world and not is_instance_valid(game.loading_layer)):
		await process_frame
	check(game.main_menu != null and not game.playing, "the title is up")
	# (The world builds behind the title: this checks a start once it is
	# done, the in-frame build; tools/loading_progress_test.gd starts early.)
	while not game.world_ready and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 30:
		await process_frame
	RenderingServer.frame_post_draw.connect(_post_draw)
	called_at = Time.get_ticks_usec()
	game._start_match(0)
	var returned_at := Time.get_ticks_usec()
	await process_frame
	await RenderingServer.frame_post_draw
	var build_ms := (returned_at - called_at) / 1000.0
	var art_ms := (drawn_at - called_at) / 1000.0
	print("MATCH_START build_ms=%.0f first_draw_ms=%.0f art=%s" % [build_ms, art_ms, art_drawn])
	check(game.playing, "the match started")
	check(drawn_at >= 0 and drawn_at < returned_at, "a frame is drawn before the match build ends")
	check(art_drawn, "that frame has the loading art up")
	check(art_ms < 500.0, "the art is drawn within 0.5 s of the start (%.0f ms)" % art_ms)
	print("match start art test: %d failure(s)" % failures)
	quit(1 if failures else 0)
