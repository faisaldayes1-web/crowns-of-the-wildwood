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
	print("batch cache test: %d failure(s)" % failures)
	quit(1 if failures else 0)
