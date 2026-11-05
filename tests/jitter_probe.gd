extends Node
## `--jitter-probe`: walks the player in a straight line with the frame rate
## uncapped and prints how evenly the hero moves across the SCREEN from one
## rendered frame to the next (a hero that steps at the 60 Hz physics rate
## against a smooth camera shows large spread at 144 Hz). Output:
## "JITTER fps=.. mean=.. std=.. cv=.. stalls=..". Lower cv is smoother.
## Run windowed: godot --path . -- --jitter-probe [--probe-frames=100] (100 frames is a clear straight run)

var game


func _ready() -> void:
	_run()


func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _run() -> void:
	var frames := 100
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-frames="):
			frames = int(a.trim_prefix("--probe-frames="))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var waited := 0
	while (not game.playing or game.player == null or not game.player.is_on_floor()) and waited < 6000:
		await get_tree().process_frame
		waited += 1
	for i in 120:
		await get_tree().process_frame
	var p = game.player
	game.pc_movement = "wasd"
	for u in game.units:
		if u != p:
			u.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(-44, 0.1, 0)
	await get_tree().process_frame
	# Screen-up in WASD is camera forward; walk "left" (A) = along -screen-x.
	_key(KEY_D, true)
	for i in 90:
		await get_tree().process_frame
	var ts: Array = []
	var xs: Array = []
	var cam: Camera3D = game.camera_for(p)
	for i in frames:
		await RenderingServer.frame_pre_draw   # after every _process: what is about to be drawn
		ts.append(Time.get_ticks_usec() / 1000000.0)
		xs.append(p.model.global_position.x)   # where the hero is DRAWN, in metres
		if OS.get_environment("DEBUG_PROBE") != "" and i % 40 == 0:
			print("PROBE i=", i, " x=", xs[-1], " z=", p.model.global_position.z, " y=", p.global_position.y)
	_key(KEY_D, false)
	if OS.get_environment("DEBUG_PROBE") == "2":
		for i in range(1, 40):
			print("PROBE dt=%.4f dx=%.4f gx=%.4f" % [ts[i] - ts[i - 1], xs[i] - xs[i - 1], 0.0])
	# Residual of the drawn position against a straight line over real time: 0
	# for perfectly even motion; a 60 Hz stepped hero shows ~speed*0.0167/sqrt(12).
	var n := xs.size()
	var mt := 0.0
	var mx := 0.0
	for i in n:
		mt += ts[i]
		mx += xs[i]
	mt /= n
	mx /= n
	var sxx := 0.0
	var sxy := 0.0
	for i in n:
		sxx += (ts[i] - mt) * (ts[i] - mt)
		sxy += (ts[i] - mt) * (xs[i] - mx)
	var slope := sxy / maxf(sxx, 0.000001)
	var ss := 0.0
	for i in n:
		var r: float = xs[i] - (mx + slope * (ts[i] - mt))
		ss += r * r
	var rms := sqrt(ss / n)
	# Frames where the hero did not advance at all while walking: the visible stutter.
	var stalls := 0
	var big := 0
	var per_frame: float = absf(slope) * (ts[n - 1] - ts[0]) / (n - 1)
	for i in range(1, n):
		var d: float = absf(xs[i] - xs[i - 1])
		if d < per_frame * 0.25:
			stalls += 1
		elif d > per_frame * 1.75:
			big += 1
	var dt: float = ts[n - 1] - ts[0]
	print("JITTER fps=%.1f speed=%.2f m/s rms_error=%.4f m (%.1f%% of a physics step) stalled_frames=%d double_steps=%d of %d" % [n / dt, slope, rms, 100.0 * rms / maxf(absf(slope) / 60.0, 0.0001), stalls, big, n - 1])
	get_tree().quit()
