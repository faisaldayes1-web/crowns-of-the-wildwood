extends SceneTree
## Stall probe (claude-faisal/crowns-spawn 2026-11-04): splits every slow
## frame of a seeded bot match into its phases, so a stall can be put down to
## physics (incl. unit AI in _physics_process), scripts/animation (_process),
## render CPU (draw lists, first-use shader/pipeline compiles), or waiting on
## the GPU / present, plus memory, texture and node deltas that frame.
##     godot --path . --resolution 1920x1080 --script tools/stall_probe.gd -- --demo --seed=7 --gfx=2 --map=3 --probe-secs=60
## --probe-ms=N sets the slow-frame bar (default 25).

var t_start := 0      # frame start (first signal of the frame)
var t_phys := 0       # first physics step this frame
var phys_steps := 0
var t_proc := 0
var t_pre := 0
var t_post := 0
var cur := {}
var rows: Array = []
var recording := false


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.trim_prefix("--%s=" % name)
	return def


func _on_phys() -> void:
	if phys_steps == 0:
		t_phys = Time.get_ticks_usec()
	phys_steps += 1


func _on_proc() -> void:
	t_proc = Time.get_ticks_usec()


func _on_pre() -> void:
	t_pre = Time.get_ticks_usec()


func _on_post() -> void:
	t_post = Time.get_ticks_usec()


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var secs := float(_arg("probe-secs", "60"))
	var bar := float(_arg("probe-ms", "25"))
	physics_frame.connect(_on_phys)
	process_frame.connect(_on_proc)
	RenderingServer.frame_pre_draw.connect(_on_pre)
	RenderingServer.frame_post_draw.connect(_on_post)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	while game.get("units") == null or game.units.is_empty():
		await process_frame
	while is_instance_valid(game.get("loading_layer")):
		await process_frame
	for i in 10:
		await process_frame
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var start := Time.get_ticks_usec()
	var last_proc := t_proc
	var mem := OS.get_static_memory_usage()
	var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var buf := Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var times: Array = []
	var slow: Array = []
	var cats := {}
	phys_steps = 0
	while (Time.get_ticks_usec() - start) < secs * 1e6:
		await process_frame
		# This process_frame ends the previous frame: last_proc .. t_proc.
		var ms := (t_proc - last_proc) / 1000.0
		var proc_ms := (t_pre - last_proc) / 1000.0 if t_pre > last_proc else 0.0
		var render_ms := (t_post - t_pre) / 1000.0 if t_post > t_pre and t_pre > last_proc else 0.0
		var phys_ms := (t_proc - t_phys) / 1000.0 if phys_steps > 0 and t_phys > t_post else 0.0
		var wait_ms := maxf(0.0, ms - proc_ms - render_ms - phys_ms)
		var steps := phys_steps
		phys_steps = 0
		last_proc = t_proc
		times.append(ms)
		var m2 := OS.get_static_memory_usage()
		var tex2 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		var buf2 := Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
		var nodes2 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var objs2 := Performance.get_monitor(Performance.OBJECT_COUNT)
		if ms > bar:
			var parts := {"physics": phys_ms, "process": proc_ms, "render_cpu": render_ms, "gpu_wait": wait_ms}
			var top := "physics"
			for k in parts:
				if parts[k] > parts[top]:
					top = k
			cats[top] = cats.get(top, 0) + 1
			slow.append([ms, "t=%.1fs %.1f ms  phys=%.1f(%d) proc=%.1f render=%.1f wait=%.1f gpu=%.1f  mem%+.1fMB tex%+.1fMB buf%+.1fMB nodes%+d objs%+d  [%s]" % [
				(t_proc - start) / 1e6, ms, phys_ms, steps, proc_ms, render_ms, wait_ms,
				RenderingServer.viewport_get_measured_render_time_gpu(vp),
				(m2 - mem) / 1048576.0, (tex2 - tex) / 1048576.0, (buf2 - buf) / 1048576.0, nodes2 - nodes, objs2 - objs, top]])
		mem = m2
		tex = tex2
		buf = buf2
		nodes = nodes2
		objs = objs2
	var sorted := times.duplicate()
	sorted.sort()
	var desc := sorted.duplicate()
	desc.reverse()
	var n1 := maxi(1, int(desc.size() * 0.01))
	var s1 := 0.0
	for i in n1:
		s1 += desc[i]
	var total := 0.0
	for t in times:
		total += t
	print("STALL args %s" % " ".join(OS.get_cmdline_user_args()))
	print("STALL frames=%d mean %.1f fps 1%% low %.1f fps median %.2f ms worst %.1f ms slow(>%.0fms)=%d by phase %s" % [
		times.size(), times.size() / (total / 1000.0), 1000.0 / (s1 / n1), sorted[sorted.size() / 2], sorted[-1], bar, slow.size(), str(cats)])
	slow.sort_custom(func(a, b): return a[0] > b[0])
	for r in slow.slice(0, 40):
		print("  ", r[1])
	quit()
