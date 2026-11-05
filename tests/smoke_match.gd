extends Node
## `--smoke-match`: the build gate's end-to-end check (claude-faisal 11-05). A
## fresh-profile boot straight into a short bot match as the default player.
## Puts an enemy in front of the player, then fires the basic attack (the
## real J key, as left-click would) and the first skill (the real Q key) and
## checks damage was dealt. Logs "SMOKE: hit dealt N damage" and "SMOKE: ok"
## (or "SMOKE: FAIL ..."), then quits. ~30 s.

const Stats = preload("res://scripts/stats.gd")

var game


func _ready() -> void:
	_run()


func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _lmb(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = get_viewport().get_mouse_position()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
	if down:
		Input.action_press(game.player._a("move_interact"))   # headless drops raw mouse-button state
	else:
		Input.action_release(game.player._a("move_interact"))


func shot_frames(key: int) -> int:
	return 6 if key == 0 else 20


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var waited := 0
	while (not game.playing or game.player == null or not game.player.is_on_floor()) and waited < 3600:
		await get_tree().physics_frame
		waited += 1
	await _frames(30)
	waited = 0
	while game.loading_layer != null and game.loading_layer.visible and waited < 1800:   # the loading art covers the world
		await get_tree().physics_frame
		waited += 1
	await _frames(30)
	var p = game.player
	game.pc_movement = "wasd"
	game.pad_active = false
	p.has_mouse = true
	var foe = null
	for u in game.units:
		if u.team != p.team and not u.dead:
			foe = u
			break
	if foe == null:
		print("SMOKE: FAIL no enemy")
		get_tree().quit(1)
		return
	for u in game.units:
		if u != p and u != foe:
			u.process_mode = Node.PROCESS_MODE_DISABLED
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	var shot_path := ""
	var dist := 1.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--smoke-role="):
			p.set_role(int(a.trim_prefix("--smoke-role=")))
		if a.begins_with("--smoke-dist="):
			dist = float(a.trim_prefix("--smoke-dist="))
		if a.begins_with("--smoke-shot="):
			shot_path = a.trim_prefix("--smoke-shot=")
	var dealt0: int = p.damage_dealt
	p.aim_mode = "mouse"
	for round in 2:
		for key in [0, KEY_Q]:   # 0 = LEFT-CLICK, aimed at the cursor over the enemy
			p.global_position = Vector3(-12, 0.1, 0)
			foe.global_position = p.global_position + Vector3(dist, 0, 0)
			foe.hearts = foe.max_hearts()
			foe.spawn_protect = 0.0
			foe.home_defense = false
			foe.downed = false
			p.energy = p.energy_max()
			p.attack_timer = 0.0
			p.ability_timers = [0.0, 0.0]
			p.aim = Vector3(1, 0, 0)
			var cam: Camera3D = game.camera_for(p)
			game.mouse_override = cam.unproject_position(foe.global_position + Vector3(0, 1.0, 0))
			p.aim_mode = "mouse"
			if key == 0:
				_lmb(true)
			else:
				_key(key, true)
			await _frames(shot_frames(key))
			if shot_path != "" and round == 1 and key == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(shot_path)
				print("SMOKE: saved ", shot_path)
			await _frames(40 - shot_frames(key))
			if key == 0:
				_lmb(false)
			else:
				_key(key, false)
			await _frames(20)
	var dealt: int = p.damage_dealt - dealt0
	print("SMOKE: hit dealt %d damage" % dealt)
	print("SMOKE: ok" if dealt > 0 else "SMOKE: FAIL no damage")
	get_tree().quit(0 if dealt > 0 else 1)
