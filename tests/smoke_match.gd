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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var waited := 0
	while (not game.playing or game.player == null or not game.player.is_on_floor()) and waited < 3600:
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
	var dealt0: int = p.damage_dealt
	p.aim_mode = "move"
	for round in 2:
		for key in [KEY_J, KEY_Q]:
			p.global_position = Vector3(-12, 0.1, 0)
			foe.global_position = p.global_position + Vector3(1.5, 0, 0)
			foe.hearts = foe.max_hearts()
			foe.spawn_protect = 0.0
			foe.home_defense = false
			foe.downed = false
			p.energy = p.energy_max()
			p.attack_timer = 0.0
			p.ability_timers = [0.0, 0.0]
			p.aim = Vector3(1, 0, 0)
			_key(key, true)
			await _frames(40)
			_key(key, false)
			await _frames(20)
	var dealt: int = p.damage_dealt - dealt0
	print("SMOKE: hit dealt %d damage" % dealt)
	print("SMOKE: ok" if dealt > 0 else "SMOKE: FAIL no damage")
	get_tree().quit(0 if dealt > 0 else 1)
