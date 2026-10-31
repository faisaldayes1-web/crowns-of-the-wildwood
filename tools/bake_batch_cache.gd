extends SceneTree
## Bakes assets/batch_cache.res (claude-faisal/stutter, 2026-10-30): the
## surface arrays scripts/static_batch.gd would otherwise read back from the
## GPU while the world is batched behind the title, i.e. the unit primitives
## and every imported model surface it merges. One map per run, merged into
## the file (the first run with --reset starts it over):
##   for m in 0 1 2 3 4; do godot --headless --path . --script tools/bake_batch_cache.gd -- --demo --map=$m [--reset]; done
## Re-run after changing or adding a model in the world;
## tools/batch_cache_test.gd fails while the bake is out of date (a stale or
## missing entry is read back in the game, so it never looks wrong).

const StaticBatch = preload("res://scripts/static_batch.gd")
const OUT := "res://assets/batch_cache.res"


func _init() -> void:
	StaticBatch.record = {}
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	_finish.call_deferred(game)


func _finish(game) -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while not game.playing and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 3:
		await process_frame
	var arrays := {}
	if not "--reset" in OS.get_cmdline_user_args() and ResourceLoader.exists(OUT):
		var old = load(OUT)
		if old != null and old.has_meta(&"arrays"):
			arrays = old.get_meta(&"arrays")
	var added := 0
	for k in StaticBatch.record:
		if not arrays.has(k):
			added += 1
		arrays[k] = StaticBatch.record[k]
	var res := Resource.new()
	res.set_meta(&"arrays", arrays)
	var err := ResourceSaver.save(res, OUT, ResourceSaver.FLAG_COMPRESS)
	print("BAKE %d read-backs this map, %d new, %d entries; save %s" % [StaticBatch.record.size(), added, arrays.size(), error_string(err)])
	quit(0 if err == OK and game.playing else 1)
