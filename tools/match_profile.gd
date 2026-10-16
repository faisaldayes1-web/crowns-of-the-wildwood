extends SceneTree
## Frame-time profile of a whole bot match with the real renderer, vsync off:
##     godot --path . --resolution 1920x1080 --script tools/match_profile.gd -- --demo --seed=7 --gfx=2 [--map=N] --prof-secs=120
##     godot ... --script tools/match_profile.gd -- --play --couch=2 --seed=7 --gfx=2 --prof-secs=120   (split screen)
## Skips --prof-warm seconds (loading and first-use shaders count separately
## as "warm-up"), then times every frame for --prof-secs. Prints mean fps,
## median / p99 frame time, 1% and 0.1% lows (the mean fps of the slowest 1%
## and 0.1% of frames), the worst frame, draw calls, GPU and CPU render time,
## and every frame over HITCH_MS with what was going on (nodes added that
## frame, match clock). --prof-csv=path writes one line per frame.
## Other heavy programs on the machine skew every number: say so in reports.

const HITCH_MS := 25.0

var added := 0   # nodes entering the tree this frame
var added_kinds := {}   # ...by class or script file


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.trim_prefix("--%s=" % name)
	return def


func _pct(sorted: Array, q: float) -> float:
	return sorted[clampi(int(sorted.size() * q), 0, sorted.size() - 1)]


func _low(sorted_desc_ms: Array, frac: float) -> float:
	## Mean fps of the slowest `frac` of frames.
	var n := maxi(1, int(sorted_desc_ms.size() * frac))
	var s := 0.0
	for i in n:
		s += sorted_desc_ms[i]
	return 1000.0 / (s / n)


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var warm := float(_arg("prof-warm", "8"))
	var secs := float(_arg("prof-secs", "60"))
	var csv_path := _arg("prof-csv", "")
	node_added.connect(func(n):
		added += 1
		var k: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
		added_kinds[k] = added_kinds.get(k, 0) + 1)
	var t0 := Time.get_ticks_msec()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	print("PROF scene ready %d ms" % (Time.get_ticks_msec() - t0))
	var vp_rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	# Warm-up: time it too (first-use shader compiles land here).
	var warm_worst := 0.0
	var last := Time.get_ticks_usec()
	var tw := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tw < warm * 1000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		warm_worst = maxf(warm_worst, (now - last) / 1000.0)
		last = now
	print("PROF warm-up %.0f s, worst frame %.1f ms" % [warm, warm_worst])
	var times: Array = []
	var gpu: Array = []
	var cpu_r: Array = []
	var draws: Array = []
	var hitches: Array = []
	var csv := []
	var start := Time.get_ticks_usec()
	added = 0
	added_kinds = {}
	last = Time.get_ticks_usec()
	while (Time.get_ticks_usec() - start) < secs * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		var g := RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		var c := RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
		var d := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		times.append(ms)
		gpu.append(g)
		cpu_r.append(c)
		draws.append(d)
		var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if csv_path != "":
			csv.append("%.3f,%.2f,%.2f,%.2f,%d,%.2f,%.2f,%d" % [(now - start) / 1e6, ms, g, c, d, proc, phys, added])
		if ms > HITCH_MS:
			var top := added_kinds.keys()
			top.sort_custom(func(a, b): return added_kinds[a] > added_kinds[b])
			var kinds := ", ".join(top.slice(0, 5).map(func(k): return "%s x%d" % [k, added_kinds[k]]))
			hitches.append("  t=%.1fs %.1f ms gpu=%.1f cpu_render=%.1f draws=%d added=%d [%s]" % [
				(now - start) / 1e6, ms, g, c, d, added, kinds])
		added = 0
		added_kinds = {}
	var n := times.size()
	var total := 0.0
	for t in times:
		total += t
	var sorted := times.duplicate()
	sorted.sort()
	var desc := sorted.duplicate()
	desc.reverse()
	var gs := gpu.duplicate()
	gs.sort()
	var cs := cpu_r.duplicate()
	cs.sort()
	var ds := draws.duplicate()
	ds.sort()
	print("PROF args %s" % " ".join(OS.get_cmdline_user_args()))
	print("PROF frames=%d over %.0f s  mean %.1f fps  median %.2f ms  p99 %.2f ms  1%% low %.1f fps  0.1%% low %.1f fps  worst %.1f ms  frames>%.0fms %d  frames>16.7ms %d" % [
		n, total / 1000.0, n / (total / 1000.0), _pct(sorted, 0.5), _pct(sorted, 0.99), _low(desc, 0.01), _low(desc, 0.001), sorted[-1], HITCH_MS, hitches.size(), sorted.filter(func(x): return x > 16.7).size()])
	print("PROF gpu median %.2f ms p99 %.2f  cpu-render median %.2f ms p99 %.2f  draws median %d max %d  objects %d  prims %d  nodes %d  static mem %.0f MB  video mem %.0f MB" % [
		_pct(gs, 0.5), _pct(gs, 0.99), _pct(cs, 0.5), _pct(cs, 0.99), _pct(ds, 0.5), ds[-1],
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("PROF hitches (first 80):")
	for h in hitches.slice(0, 80):
		print(h)
	if csv_path != "":
		var f := FileAccess.open(csv_path, FileAccess.WRITE)
		f.store_line("t,frame_ms,gpu_ms,cpu_render_ms,draws,process_ms,physics_ms,nodes_added")
		for l in csv:
			f.store_line(l)
	quit()
