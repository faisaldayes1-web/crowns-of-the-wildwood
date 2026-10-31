extends Node
## Title stutter probe (claude-faisal/stutter, 2026-10-30). Measures the title
## while the match world builds behind it: frame times by second after the
## title shows, each build slice's CPU time, the batch's GPU read-backs, and
## (with --probe-press=S) how long a match takes to start when PLAY is pressed
## S seconds after the title appears. Prints PROBE lines and quits.
##
## Desktop (editor binary, a source checkout):
##   tools/tests/isolated.sh --path . --script tools/title_stutter_run.gd -- --world-behind [--probe-press=5] [--probe-shot=x.png]
## Release export: added as the last autoload of a probe export only (see
## C:/Games/ORY-Candidates/Crowns/title-stutter-ab/), then run the exe.
##
## Args: --probe-press=S  start a match S s after the title (default: never)
##       --probe-shot=PNG  a screenshot 4 s into the match
##       --probe-hold=S    after the world is ready, keep measuring S s (default 5)
##       --probe-title-shot=PNG  the title, once the world is built (at the end)
##       --probe-load=MS   busy-wait MS every frame (a slower machine's menus)

const WINDOWS := [1.0, 2.0, 3.0, 5.0, 8.0, 10.0, 15.0, 20.0]   # fps windows: seconds after the title

var t_last := 0
var t_title := -1.0
var t_world := -1.0
var press_at := -1.0
var shot := ""
var hold := 5.0
var load_ms := 0.0
var title_shot := ""
var frames: Array = []   # [s after title, frame ms]
var pressed := false
var quit_at := -1.0
var boot_worst := 0.0
var last_slices := 0
var t_phys := 0
var t_pre := 0
var t_post := 0
var seg := [0, 0, 0, 0, 0]   # last frame: physics, process, draw, rest
var t_proc := 0
var t_late := 0
var dn := 0
var verbose := "--probe-verbose" in OS.get_cmdline_user_args()
var last_nodes := 0
var idle_ms := 0.0   # last frame: from the last _process to drawing (deferred calls, material updates)


func _process(_d: float) -> void:
	if load_ms > 0.0:   # a slower machine's menus: this much more CPU every frame
		var until := Time.get_ticks_usec() + int(load_ms * 1000.0)
		while Time.get_ticks_usec() < until:
			pass
	t_late = Time.get_ticks_usec()
var slice_frames := 0


func ms() -> float:
	return Time.get_ticks_usec() / 1000.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-press="):
			press_at = float(arg.trim_prefix("--probe-press="))
		elif arg.begins_with("--probe-shot="):
			shot = arg.trim_prefix("--probe-shot=")
		elif arg.begins_with("--probe-title-shot="):
			title_shot = arg.trim_prefix("--probe-title-shot=")
		elif arg.begins_with("--probe-load="):
			load_ms = float(arg.trim_prefix("--probe-load="))
		elif arg.begins_with("--probe-hold="):
			hold = float(arg.trim_prefix("--probe-hold="))
	print("PROBE start ms=%.0f press=%.1f gpu=%s %s" % [ms(), press_at,
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	t_last = Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# Where a long frame went: physics, process (the slice and the menus),
	# drawing, and the rest (input, deferred calls, resource updates).
	get_tree().physics_frame.connect(func(): if t_phys == 0: t_phys = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func(): t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func(): t_post = Time.get_ticks_usec())
	get_tree().process_frame.connect(_tick)
	set_process_priority(1000000)   # _process last: what follows it is the deferred and idle work
	set_process(true)


func _game():
	var g = get_tree().current_scene
	if g == null or not is_instance_valid(g) or not ("world_slice_usec" in g):
		return null
	return g


func _tick() -> void:
	var now := Time.get_ticks_usec()
	var d := (now - t_last) / 1000.0
	# segments of the frame that just ended (t_proc..t_pre..t_post..t_phys..now)
	if t_proc > 0 and t_pre > t_proc and t_post >= t_pre:
		var phys_start := t_phys if t_phys > t_post else now
		idle_ms = (t_pre - t_late) / 1000.0
		seg = [(now - phys_start) / 1000.0, (t_pre - t_proc) / 1000.0, (t_post - t_pre) / 1000.0, (phys_start - t_post) / 1000.0]
	t_proc = now
	t_phys = 0
	var nn := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	dn = nn - last_nodes
	last_nodes = nn
	t_last = now
	var g = _game()
	if ms() > 240000.0:
		print("PROBE timeout")
		get_tree().quit(3)
		return
	if g == null:
		return
	if t_title < 0.0:
		boot_worst = maxf(boot_worst, d)
		if g.main_menu != null and not g.menus_warming and not is_instance_valid(g.loading_layer) and g.process_mode != Node.PROCESS_MODE_DISABLED:
			t_title = ms()
			print("PROBE title ms=%.0f world_ready=%s" % [t_title, g.world_ready])
		return
	var since := (ms() - t_title) / 1000.0
	if not pressed:
		frames.append([since, d])
		var sl: PackedInt32Array = g.world_slice_usec
		var n_sl := sl.size()
		if n_sl != last_slices:
			last_slices = n_sl
			slice_frames += 1
		if d > 40.0 or (verbose and since < 4.0):
			var vp := get_viewport().get_viewport_rid()
			print("PROBE long_frame s=%.2f ms=%.1f slices=%d last_slice_ms=%.1f readbacks=%d physics/process/draw/rest_ms=%.1f/%.1f/%.1f/%.1f render_cpu_ms=%.1f gpu_ms=%.1f world_ready=%s idle_ms=%.1f dnodes=%d" % [since, d, n_sl,
				sl[n_sl - 1] / 1000.0 if n_sl > 0 else 0.0, _rb("readbacks", -1), seg[0], seg[1], seg[2], seg[3],
				RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), g.world_ready, idle_ms, dn])
			if seg[2] > 60.0 and verbose:   # a long draw: what the world added just before
				var kids: Array = g.get_children().slice(-12)
				print("PROBE   last added: ", kids.map(func(k): return "%s:%s" % [k.name, k.get_class()] + ("/" + String(k.get_child(0).name) if k.get_child_count() else "")))
	if t_world < 0.0 and g.world_ready:
		t_world = ms()
		var cam := get_viewport().get_camera_3d()
		print("PROBE world_ready s_after_title=%.2f camera=%s match_camera_current=%s" % [(t_world - t_title) / 1000.0,
			cam.get_path() if cam else "none", cam != null and cam == g.camera])
		_report_build(g)
		if press_at < 0.0:
			quit_at = ms() + hold * 1000.0
	if press_at >= 0.0 and not pressed and since >= press_at:
		pressed = true
		_press(g, since)
	if quit_at > 0.0 and ms() >= quit_at:
		quit_at = -1.0
		print("PROBE title_after_build objects=%d draw_calls=%d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
		_report_frames()
		if title_shot != "":
			get_viewport().get_texture().get_image().save_png(title_shot)
			print("PROBE title_shot %s" % title_shot)
		get_tree().quit()


func _press(g, since: float) -> void:
	var t0 := ms()
	var world_was: bool = g.world_ready
	print("PROBE press s_after_title=%.2f world_ready=%s" % [since, world_was])
	g._start_match(0)
	while not g.playing:
		await get_tree().process_frame
	var built := ms() - t0
	while is_instance_valid(g.loading_layer):
		await get_tree().process_frame
	print("PROBE match press_s=%.0f built_ms=%.0f visible_ms=%.0f world_was_ready=%s" % [press_at, built, ms() - t0, world_was])
	_report_frames()
	_fingerprint(g)
	if shot != "":
		for i in 240:   # 4 s at 60
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot)
		print("PROBE shot %s" % shot)
	get_tree().quit()


func _rb(name: String, missing: Variant) -> Variant:
	## static_batch.gd's read-back counters (-1: a build without them).
	var script: Script = load("res://scripts/static_batch.gd")
	var v = script.get(name)
	return missing if v == null else v


func _report_build(g) -> void:
	var sl: PackedInt32Array = g.world_slice_usec
	var edges := [2, 4, 6, 8, 10, 12, 16, 20, 33, 50, 100]
	var hist := []
	hist.resize(edges.size() + 1)
	hist.fill(0)
	var total := 0
	var worst := 0
	for u in sl:
		total += u
		worst = maxi(worst, u)
		var b := edges.size()
		for i in edges.size():
			if u < edges[i] * 1000:
				b = i
				break
		hist[b] += 1
	var parts := PackedStringArray()
	for i in hist.size():
		parts.append("%s:%d" % ["<%d" % edges[i] if i < edges.size() else ">=100", hist[i]])
	print("PROBE slices n=%d avg_ms=%.2f max_ms=%.1f total_ms=%.0f hist_ms %s" % [sl.size(), total / 1000.0 / maxf(sl.size(), 1), worst / 1000.0, total / 1000.0, " ".join(parts)])
	if "_world_rest_usec" in g:
		print("PROBE slice_budget rest_ms=%.1f budget_ms=%.1f" % [g._world_rest_usec / 1000.0, g._world_slice_budget() / 1000.0])
	print("PROBE readbacks n=%d ms=%.0f" % [_rb("readbacks", -1), _rb("readback_usec", 0) / 1000.0])
	var kinds: Dictionary = _rb("readback_kinds", {})
	var ks := kinds.keys()
	ks.sort_custom(func(a, b): return kinds[a] > kinds[b])
	for k in ks:
		print("PROBE readback_kind %s %d" % [k, kinds[k]])


func _report_frames() -> void:
	var lo := 0.0
	for hi in WINDOWS:
		var n := 0
		var sum := 0.0
		var worst := 0.0
		var over25 := 0
		var over33 := 0
		for f in frames:
			if f[0] >= lo and f[0] < hi:
				n += 1
				sum += f[1]
				worst = maxf(worst, f[1])
				over25 += int(f[1] > 25.0)
				over33 += int(f[1] > 33.4)
		if n > 0:
			print("PROBE fps %4.1f-%4.1fs fps=%.1f worst_ms=%.1f over25=%d over33=%d" % [lo, hi, n / (sum / 1000.0), worst, over25, over33])
		lo = hi
	var b25 := 0
	var b33 := 0
	var b50 := 0
	var n_build := 0
	var build_end := (t_world - t_title) / 1000.0 if t_world > 0.0 else 1e9
	for f in frames:
		if f[0] < build_end:
			n_build += 1
			b25 += int(f[1] > 25.0)
			b33 += int(f[1] > 33.4)
			b50 += int(f[1] > 50.0)
	print("PROBE build_frames n=%d over25=%d over33=%d over50=%d boot_worst_ms=%.0f" % [n_build, b25, b33, b50, boot_worst])


func _fingerprint(g) -> void:
	## The batch's output, run-independent: per merged mesh its vertex and
	## index counts, format, material and bounds.
	var holder: Node = g.get_node_or_null("StaticBatch")
	if holder == null:
		print("PROBE batch_fp none")
		return
	var rows := PackedStringArray()
	var verts := 0
	for c in holder.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var m: Mesh = mi.mesh
		var a := m.get_aabb()
		var mat: Material = m.surface_get_material(0)
		var mats := mat.get_class()
		if mat is BaseMaterial3D:
			mats += " %s %s" % [mat.albedo_color, mat.albedo_texture.resource_path if mat.albedo_texture else ""]
		elif mat is ShaderMaterial:
			mats += " " + mat.shader.resource_path
		var nv: int = m.surface_get_array_len(0)
		verts += nv
		rows.append("%d %d %d %s %s %d %d" % [nv, m.surface_get_array_index_len(0), m.surface_get_format(0) & 0xFFFF,
			mats, str(a.position.snapped(Vector3.ONE * 0.01)) + str(a.size.snapped(Vector3.ONE * 0.01)), mi.cast_shadow, mi.layers])
	rows.sort()
	print("PROBE batch_fp meshes=%d verts=%d hash=%s" % [rows.size(), verts, "\n".join(rows).md5_text()])
