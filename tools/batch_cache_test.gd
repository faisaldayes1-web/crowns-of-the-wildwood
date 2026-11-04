extends SceneTree
## claude-faisal/stutter 2026-10-30: assets/batch_cache.res (the batch's
## saved mesh arrays, tools/bake_batch_cache.gd) must match what the GPU
## read-back gives today, and cover every mesh the batch reads. Fails when a
## model changed or was added since the bake: re-bake then.
##   godot --headless --path . --script tools/batch_cache_test.gd -- --demo --map=N

const StaticBatch = preload("res://scripts/static_batch.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	StaticBatch.verify_misses = []
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	_finish.call_deferred(game)


func _finish(game) -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while not game.playing and Time.get_ticks_msec() < deadline:
		await process_frame
	check(game.playing, "the match started (and the world was batched)")
	var misses: Array = StaticBatch.verify_misses
	check(misses.is_empty(), "every baked surface matches its read-back%s" % ("" if misses.is_empty() else ": " + str(misses.slice(0, 8))))
	check(StaticBatch.readbacks == 0, "no surface left to the read-back (%d: %s)" % [StaticBatch.readbacks, StaticBatch.readback_kinds])
	# Agent: Codex-faisal. Retire only this validator-owned match.
	var result: int = 1 if failures else 0
	# Freeze the completed tool scene so footsteps cannot start during drain.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for child in game.find_children("*", "", true, false):
		child.process_mode = Node.PROCESS_MODE_DISABLED
	# Retire this tool's active audio playbacks before freeing their nodes.
	# Audio commands are consumed on the mixer thread, not process frames.
	for player in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	for player in game.find_children("*", "AudioStreamPlayer3D", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.1, true, false, true).timeout
	var retired: WeakRef = weakref(game)
	game.queue_free()
	current_scene = null
	game = null
	for i in 3:
		await process_frame
	var scene_freed: bool = retired.get_ref() == null
	print("CACHE TEST teardown: scene freed=%s" % scene_freed)
	if not scene_freed:
		push_error("CACHE TEST teardown did not release the match scene")
		failures += 1
		result = 1
	print("batch cache test: %d failure(s)" % failures)
	quit(result)
