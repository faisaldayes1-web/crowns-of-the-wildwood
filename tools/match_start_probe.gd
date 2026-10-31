extends Node
## Match-start probe (claude-faisal/crowns-perf04, 2026-10-31; PERF-04). Presses
## PLAY (g._start_match(0)) S seconds after the title shows, then records every
## frame until 5 s after the match is on screen: its time, where it went
## (physics, process, draw, the rest), the renderer's CPU/GPU time, node growth
## and the phase (under the loading art or live). Prints PROBE lines and quits.
##
## Desktop (editor binary, a source checkout):
##   tools/tests/isolated.sh --path . --script tools/match_start_run.gd -- --world-behind --probe-press=5
## Release export: added as the last autoload of a probe export only (see
## C:/Games/ORY-Candidates/Crowns/perf04-ab/).
##
## Args: --probe-press=S   seconds after the title to press PLAY (default 5)
##       --probe-live=S    seconds of the live match to record (default 5)
##       --probe-shot=PNG  a screenshot at the end

var t_last := 0
var t_title := -1.0
var press_at := 5.0
var live_s := 5.0
var shot := ""
var t_press := -1.0
var t_visible := -1.0
var t_phys := 0
var t_pre := 0
var t_post := 0
var t_proc := 0
var t_late := 0
var seg := [0.0, 0.0, 0.0, 0.0, -1.0]   # physics, process, draw, rest; and of process, what came after every _process (deferred calls, redraws, deletes)
var last_nodes := 0
var call_ms := 0.0
var rows: Array = []   # [ms since press, frame ms, frame no, phase, phys, proc, draw, rest, render_cpu, gpu, dnodes]
var done := false
var t_world := -1.0   # the world behind the title finished
var title_frames: Array = []   # [s after title, frame ms] until the press
var added := {}   # frame -> names of the nodes added in it (--probe-nodes)
var watch_nodes := "--probe-nodes" in OS.get_cmdline_user_args()


func ms() -> float:
	return Time.get_ticks_usec() / 1000.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-press="):
			press_at = float(arg.trim_prefix("--probe-press="))
		elif arg.begins_with("--probe-live="):
			live_s = float(arg.trim_prefix("--probe-live="))
		elif arg.begins_with("--probe-shot="):
			shot = arg.trim_prefix("--probe-shot=")
	print("PROBE start ms=%.0f press=%.1f gpu=%s %s" % [ms(), press_at,
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	t_last = Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	get_tree().physics_frame.connect(func(): if t_phys == 0: t_phys = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func(): t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func(): t_post = Time.get_ticks_usec())
	get_tree().process_frame.connect(_tick)
	set_process_priority(1000000)
	set_process(true)


func _process(_d: float) -> void:
	t_late = Time.get_ticks_usec()


func _game():
	var g = get_tree().current_scene
	if g == null or not is_instance_valid(g) or not ("world_ready" in g) or not ("main_menu" in g):
		return null
	return g


func _tick() -> void:
	var now := Time.get_ticks_usec()
	var d := (now - t_last) / 1000.0
	if t_proc > 0 and t_pre > t_proc and t_post >= t_pre:
		var phys_start := t_phys if t_phys > t_post else now
		seg = [(now - phys_start) / 1000.0, (t_pre - t_proc) / 1000.0, (t_post - t_pre) / 1000.0, (phys_start - t_post) / 1000.0,
			(t_pre - t_late) / 1000.0 if t_late > t_proc and t_late < t_pre else -1.0]
	else:
		seg = [0.0, d, 0.0, 0.0, -1.0]   # no draw this frame
	t_proc = now
	t_phys = 0
	t_last = now
	var nn := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var dn := nn - last_nodes
	last_nodes = nn
	if ms() > 240000.0:
		print("PROBE timeout")
		get_tree().quit(3)
		return
	var g = _game()
	if g == null or done:
		return
	if t_title < 0.0:
		if g.main_menu != null and not g.menus_warming and not is_instance_valid(g.loading_layer) and g.process_mode != Node.PROCESS_MODE_DISABLED:
			t_title = ms()
			print("PROBE title ms=%.0f world_ready=%s" % [t_title, g.world_ready])
		return
	if t_press < 0.0:
		title_frames.append([(ms() - t_title) / 1000.0, d])
		if t_world < 0.0 and g.world_ready:
			t_world = ms()
			print("PROBE world_ready s_after_title=%.2f" % ((t_world - t_title) / 1000.0))
		if (ms() - t_title) / 1000.0 >= press_at:
			_report_title()
			_press(g)
		return
	var vp := get_viewport().get_viewport_rid()
	var phase := "art" if is_instance_valid(g.loading_layer) else "live"
	if phase == "live" and t_visible < 0.0:
		t_visible = ms()
	rows.append([ms() - t_press, d, Engine.get_process_frames(), phase, seg[0], seg[1], seg[2], seg[3], seg[4],
		RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), dn])
	if t_visible > 0.0 and ms() - t_visible >= live_s * 1000.0:
		done = true
		_report(g)


func _report_title() -> void:
	## The title's frames before the press: while the world builds, and after
	## it is ready (when the match-start models are prebuilt behind it).
	var ready_s := (t_world - t_title) / 1000.0 if t_world > 0.0 else 1e9
	for part in ["building", "after_ready"]:
		var n := 0
		var sum := 0.0
		var worst := 0.0
		var o25 := 0
		var o33 := 0
		for f in title_frames:
			if f[0] < 0.25:
				continue   # (the title's first frames: the screen swap)
			if (part == "building") != (f[0] < ready_s):
				continue
			n += 1
			sum += f[1]
			worst = maxf(worst, f[1])
			o25 += int(f[1] > 25.0)
			o33 += int(f[1] > 33.4)
			if f[1] > 33.4:
				print("PROBE title_long %s s=%.2f ms=%.1f" % [part, f[0], f[1]])
		print("PROBE title %s frames=%d fps=%.1f worst_ms=%.1f over25=%d over33=%d" % [part, n, n / maxf(sum / 1000.0, 0.001), worst, o25, o33])


func _press(g) -> void:
	t_press = ms()
	print("PROBE press s_after_title=%.2f world_ready=%s" % [(t_press - t_title) / 1000.0, g.world_ready])
	var t0 := ms()
	g._start_match(0)   # runs until its first await
	call_ms = ms() - t0
	print("PROBE start_match_call_ms=%.1f" % call_ms)
	if watch_nodes:
		get_tree().node_added.connect(func(n: Node):
			var f := Engine.get_process_frames()
			if not added.has(f):
				added[f] = []
			if added[f].size() < 12:
				added[f].append("%s:%s<%s" % [n.name, n.get_class(), n.get_parent().name if n.get_parent() else ""]))


func _report(g) -> void:
	print("PROBE visible_ms=%.0f playing=%s" % [t_visible - t_press, g.playing])
	for r in rows:
		if r[1] > 25.0:
			print("PROBE frame t=%.0f ms=%.1f frame=%d phase=%s physics/process/draw/rest=%.1f/%.1f/%.1f/%.1f after_process=%.1f render_cpu=%.1f gpu=%.1f dnodes=%d" % r)
			for f in [r[2] - 1, r[2]]:
				if added.has(f):
					print("PROBE   added in frame %d: %s" % [f, ", ".join(added[f])])
	for phase in ["art", "live"]:
		var n := 0
		var worst := 0.0
		var sum := 0.0
		var o25 := 0
		var o33 := 0
		var o50 := 0
		var o100 := 0
		var worst_draw := 0.0
		var worst_proc := 0.0
		for r in rows:
			if r[3] != phase:
				continue
			n += 1
			sum += r[1]
			worst = maxf(worst, r[1])
			worst_draw = maxf(worst_draw, r[6])
			worst_proc = maxf(worst_proc, r[5])
			o25 += int(r[1] > 25.0)
			o33 += int(r[1] > 33.4)
			o50 += int(r[1] > 50.0)
			o100 += int(r[1] > 100.0)
		print("PROBE phase %s frames=%d total_ms=%.0f worst_ms=%.1f worst_process_ms=%.1f worst_draw_ms=%.1f over25=%d over33=%d over50=%d over100=%d fps=%.1f" % [
			phase, n, sum, worst, worst_proc, worst_draw, o25, o33, o50, o100, n / maxf(sum / 1000.0, 0.001)])
	var by_s := {}
	for r in rows:
		if r[3] == "live":
			var s := int((r[0] - (t_visible - t_press)) / 1000.0)
			if not by_s.has(s):
				by_s[s] = [0, 0.0, 0.0]
			by_s[s][0] += 1
			by_s[s][1] += r[1]
			by_s[s][2] = maxf(by_s[s][2], r[1])
	for s in by_s.keys():
		print("PROBE live_s %d fps=%.1f worst_ms=%.1f" % [s, by_s[s][0] / maxf(by_s[s][1] / 1000.0, 0.001), by_s[s][2]])
	print("PROBE summary call_ms=%.0f visible_ms=%.0f art_worst_ms=%.1f live_worst_ms=%.1f" % [call_ms, t_visible - t_press,
		rows.filter(func(r): return r[3] == "art").reduce(func(a, r): return maxf(a, r[1]), 0.0),
		rows.filter(func(r): return r[3] == "live").reduce(func(a, r): return maxf(a, r[1]), 0.0)])
	if shot != "":
		get_viewport().get_texture().get_image().save_png(shot)
		print("PROBE shot %s" % shot)
	get_tree().quit()
