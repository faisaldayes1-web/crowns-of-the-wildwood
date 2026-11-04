extends SceneTree
## Spawn-burst hitch probe (claude-faisal/crowns-spawn 2026-11-04): plays a
## seeded bot match and prints every frame over HITCH_MS with the nodes added
## that frame and the CharacterModel rebuilds (count, ms) that ran in it.
##     godot --path . --script tools/spawn_hitch_probe.gd -- --demo --seed=7 --map=3 --probe-secs=60
## Add --headless for CPU only; without it the real renderer also counts
## first-use shader compiles.

const CharacterModel = preload("res://scripts/character_model.gd")
const HITCH_MS := 25.0

var added := 0
var kinds := {}


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.trim_prefix("--%s=" % name)
	return def


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var secs := float(_arg("probe-secs", "60"))
	node_added.connect(func(n):
		added += 1
		var k: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
		kinds[k] = kinds.get(k, 0) + 1)
	var t0 := Time.get_ticks_msec()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Wait for the match to begin (loading screen gone, units in the tree).
	while game.get("units") == null or game.units.is_empty():
		await process_frame
	# ...and the loading art (and its warm-ups) gone.
	while is_instance_valid(game.get("loading_layer")):
		await process_frame
	for i in 10:
		await process_frame
	print("PROBE match up %d ms" % (Time.get_ticks_msec() - t0))
	CharacterModel.build_log.clear()
	var times: Array = []
	var hitches: Array = []
	var worst_build := 0.0
	var builds := 0
	var start := Time.get_ticks_usec()
	var last := start
	added = 0
	kinds = {}
	while (Time.get_ticks_usec() - start) < secs * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		times.append(ms)
		var b: Array = CharacterModel.build_log.duplicate()
		CharacterModel.build_log.clear()
		builds += b.size()
		var bms := 0.0
		for x in b:
			bms += x
			worst_build = maxf(worst_build, x)
		var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if ms > HITCH_MS:
			var top := kinds.keys()
			top.sort_custom(func(a, c): return kinds[a] > kinds[c])
			hitches.append("  t=%.1fs %.1f ms proc=%.1f phys=%.1f added=%d builds=%d (%.1f ms) [%s]" % [(now - start) / 1e6, ms, proc, phys, added, b.size(), bms,
				", ".join(top.slice(0, 5).map(func(k): return "%s x%d" % [k, kinds[k]]))])
		added = 0
		kinds = {}
	var sorted := times.duplicate()
	sorted.sort()
	print("PROBE frames=%d median %.2f ms p99 %.2f ms worst %.1f ms hitches>%.0fms %d  model builds %d worst build %.1f ms" % [
		times.size(), sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.99)], sorted[-1], HITCH_MS, hitches.size(), builds, worst_build])
	for h in hitches.slice(0, 60):
		print(h)
	quit()
