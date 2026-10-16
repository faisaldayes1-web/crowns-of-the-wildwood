extends SceneTree
## The HUD's share of the frame, split in two: "frozen" stops its _process
## (no queue_redraw, so last frame's drawing stays on screen and is only
## rendered), "hidden" hides its layer (nothing drawn or rendered). Six
## alternations of each against the live HUD, medians.
##     godot --path . --resolution 1920x1080 --script tools/hud_ab.gd -- --demo --seed=7 --gfx=2

const SECS := 2.5


func _median() -> float:
	var times := []
	var last := Time.get_ticks_usec()
	var t0 := last
	while Time.get_ticks_usec() - t0 < SECS * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	return times[times.size() / 2]


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 14000:
		await process_frame
	var hud: Node = game.hud
	var layer: CanvasLayer = hud.get_parent()
	var sums := {"live": [], "frozen": [], "hidden": []}
	for i in 6:
		sums.live.append(await _median())
		hud.set_process(false)
		sums.frozen.append(await _median())
		hud.set_process(true)
		sums.live.append(await _median())
		layer.visible = false
		sums.hidden.append(await _median())
		layer.visible = true
	for k in sums:
		var v: Array = sums[k]
		v.sort()
		print("HUDAB %-7s median of medians %.2f ms  (%s)" % [k, v[v.size() / 2], ", ".join(v.map(func(x): return "%.1f" % x))])
	quit()
