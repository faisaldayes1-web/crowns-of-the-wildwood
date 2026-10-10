extends SceneTree
## Finds stalls: times every menu press and every frame of a short match in
## which the player keeps clicking (attack), dodging and using skills, and
## prints each frame slower than HITCH_MS with what happened just before.
## CPU side only (headless has no GPU work). Run from the project root:
##     godot --headless --path . --script tools/hitch_probe.gd

const HITCH_MS := 20.0

var last := 0
var frames: Array = []   # [ms, label]
var label := ""


func _frame() -> void:
	var now := Time.get_ticks_usec()
	if last > 0:
		frames.append([(now - last) / 1000.0, label])
	last = now


func timed(what: String, f: Callable) -> void:
	var t := Time.get_ticks_usec()
	f.call()
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	print("PRESS %-28s %7.1f ms" % [what, ms])
	label = what


func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)


func key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _init() -> void:
	var cfg := "user://controls.cfg"
	var saved := FileAccess.get_file_as_bytes(cfg) if FileAccess.file_exists(cfg) else PackedByteArray()
	process_frame.connect(_frame)
	var t0 := Time.get_ticks_usec()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	print("BOOT main scene ready %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for i in 10:
		await process_frame
	var m = game.main_menu
	for step in [["customize", null], ["back", null], ["settings", null], ["back", null], ["store", null], ["back", null], ["play", null]]:
		timed("menu " + step[0], func(): m._press(step[0], step[1]))
		for i in 5:
			await process_frame
	timed("menu to_lobby", func(): m._press("to_lobby", null))
	for i in 5:
		await process_frame
	timed("menu start match", func(): m.start())
	for i in 30:
		await process_frame
	label = "match"
	# 20 s of play at whatever speed headless runs: click to attack every
	# 10 frames, dodge, skills, scoreboard and pause now and then.
	for i in 1200:
		if i % 10 == 0:
			click(Vector2(700, 300))
			label = "click attack"
		elif i % 97 == 0:
			key(KEY_SPACE)
			label = "dodge"
		elif i % 131 == 0:
			key(KEY_Q)
			label = "skill Q"
		elif i % 173 == 0:
			key(KEY_E)
			label = "skill E"
		else:
			label = "match"
		if i % 60 == 0:
			game.player.velocity = Vector3.ZERO
		await process_frame
	var slow := frames.filter(func(f): return f[0] > HITCH_MS)
	var total := 0.0
	var worst := 0.0
	for f in frames:
		total += f[0]
		worst = maxf(worst, f[0])
	print("FRAMES %d  mean %.1f ms  worst %.1f ms  over %.0f ms: %d" % [frames.size(), total / frames.size(), worst, HITCH_MS, slow.size()])
	var by := {}
	for f in slow:
		by[f[1]] = by.get(f[1], []) + [snappedf(f[0], 0.1)]
	for k in by:
		print("HITCH after %-20s %s" % [k, str(by[k].slice(0, 12))])
	if saved.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	else:
		var f := FileAccess.open(cfg, FileAccess.WRITE)
		f.store_buffer(saved)
	quit()
