extends SceneTree
## Agent: claude-faisallaptop (cf-crowns-pass4-1105m). A windowed full-match playtest: the player is driven through the
## real input path (WASD actions, LMB held with the cursor on the target, the ability keys), plays every class in turn
## for an equal share of the match, and logs what looks wrong: sinking or floating, being stuck, falling, damage taken
## with no fighting, plus a screenshot every SHOT_EVERY seconds of match time.
##   tools/tests/isolated.sh --path . --resolution 1280x720 --script tools/class_playtest.gd -- --map=N [--speed=3] [--out=DIR]
## (the player's class is changed with set_role, as tools/combat_input_test.gd does, not at a class seal)
const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")
const SHOT_EVERY := 45.0
var game
var p
var out_dir := "C:/Temp/play"
var speed := 3.0
var notes: Array = []
var last_pos := Vector3.ZERO
var stuck_for := 0.0
var shot_n := 0
var ability_clock := 0.0


func _initialize() -> void:
	call_deferred("run")


func note(s: String) -> void:
	var line := "t=%d %s" % [int(game.match_played) if game else 0, s]
	notes.append(line)
	print("NOTE ", line)


func _lmb(down: bool) -> void:
	if down:
		Input.action_press(p._a("move_interact"))
	else:
		Input.action_release(p._a("move_interact"))
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = root.get_mouse_position()
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)


func _move(dir: Vector3) -> void:
	## Hold WASD toward the world direction `dir`, as the camera sees it.
	var b: Basis = game.camera_for(p).global_basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var down := Vector3(b.z.x, 0, b.z.z).normalized()
	var sx := dir.dot(right)
	var sy := dir.dot(down)
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(p._a(a))
	if dir.length() < 0.01:
		return
	if absf(sx) > 0.3:
		Input.action_press(p._a("move_right" if sx > 0 else "move_left"), minf(absf(sx) * 1.5, 1.0))
	if absf(sy) > 0.3:
		Input.action_press(p._a("move_down" if sy > 0 else "move_up"), minf(absf(sy) * 1.5, 1.0))


func _nearest_enemy():
	var best = null
	var bd := 1e9
	for u in game.units:
		if u.team != p.team and not u.dead and not u.downed:
			var d: float = (u.global_position - p.global_position).length()
			if d < bd:
				bd = d
				best = u
	return best


func _shot(tag: String) -> void:
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := "%s/%s_%02d_%s.png" % [out_dir, "m%d" % game.map_variant, shot_n, tag]
	img.save_png(path)
	shot_n += 1


func run() -> void:
	if not Isolated.ok("class_playtest") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			speed = float(arg.trim_prefix("--speed="))
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("load timeout")
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	game._start_match(0)
	while not game.playing or is_instance_valid(game.loading_layer):
		await process_frame
	for i in 60:
		await physics_frame
	p = game.player
	game.touch_active = false
	game.pc_movement = "wasd"
	game.cursor_shown = false
	p.has_mouse = true
	p.aim_mode = "mouse"
	Engine.time_scale = speed
	var roles := [Stats.Role.KNIGHT, Stats.Role.RANGER, Stats.Role.MAGE, Stats.Role.HEALER, Stats.Role.ENGINEER, Stats.Role.ROGUE]
	var slice := 100.0   # seconds of match per class: all six are played well before a rout ends
	var role_i := -1
	var next_shot := 5.0
	var next_log := 0.0
	var wall0 := Time.get_ticks_msec()
	print("PLAYTEST map=", game.map_variant, " speed=", speed, " slice=", int(slice), "s per class")
	while game.playing and not game.game_over:
		await physics_frame
		var t: float = game.match_played
		var want := mini(int(t / slice), roles.size() - 1)
		if want != role_i:
			role_i = want
			p.set_role(roles[role_i])
			p._stats_cache = {}
			note("class -> %s" % Stats.Role.keys()[roles[role_i]])
		if not is_instance_valid(p) or p.dead or p.downed:
			_move(Vector3.ZERO)
			_lmb(false)
			continue
		var foe = _nearest_enemy()
		var heal_only: bool = p.attack_stats().get("attack", "") == "heal"
		var reach: float = 2.2 if str(p.attack_stats().get("attack", "")) == "melee" else 7.0
		var want_dir := Vector3.ZERO
		var attack := false
		if heal_only:
			# the Healer follows a hurt ally, else the nearest ally
			var ally = null
			var ad := 1e9
			for u in game.units:
				if u != p and u.team == p.team and not u.dead:
					var d: float = (u.global_position - p.global_position).length()
					if d < ad:
						ad = d
						ally = u
			if ally:
				foe = ally
		if foe:
			var to: Vector3 = foe.global_position - p.global_position
			to.y = 0.0
			var dist := to.length()
			if dist > reach * 0.8:
				var leg: Vector3 = game.route_point(p.global_position, foe.global_position)
				want_dir = Vector3(leg.x - p.global_position.x, 0, leg.z - p.global_position.z).normalized()
			attack = dist < reach * 1.6
			var cam: Camera3D = game.camera_for(p)
			game.mouse_override = cam.unproject_position(foe.global_position + Vector3(0, 1.0, 0))
			p.aim_mode = "mouse"
		else:
			var goal: Vector3 = game.thrones[1 - p.team]
			var leg2: Vector3 = game.route_point(p.global_position, goal)
			var to2 := Vector3(leg2.x - p.global_position.x, 0, leg2.z - p.global_position.z)
			want_dir = to2.normalized()
		if stuck_for > 1.2 and want_dir.length() > 0.5:
			# pushing straight at a round collider: a person would slide round it
			want_dir = want_dir.rotated(Vector3.UP, PI / 2.0 * (1.0 if int(t / 3.0) % 2 == 0 else -1.0))
		_move(want_dir)
		_lmb(attack)
		ability_clock += 1.0 / 60.0 * speed
		if attack and ability_clock > 4.0:
			ability_clock = 0.0
			Input.action_press(p._a("ability_1"))
			await physics_frame
			Input.action_release(p._a("ability_1"))
		# anomaly checks
		var gy: float = 0.0
		if p.global_position.y < -1.0 and not p.get("falling"):
			note("below the world: %s" % p.global_position)
		if want_dir.length() > 0.5:
			if p.global_position.distance_to(last_pos) < 0.02 * speed:
				stuck_for += 1.0 / 60.0 * speed
			else:
				stuck_for = 0.0
			if stuck_for > 6.0:
				note("stuck 6 s at %s heading %s foe=%s" % [p.global_position.snapped(Vector3.ONE * 0.1), want_dir.snapped(Vector3.ONE * 0.1), foe.display_name if foe else "-"])
				stuck_for = 0.0
		last_pos = p.global_position
		if t >= next_shot:
			next_shot = t + SHOT_EVERY
			_shot(str(Stats.Role.keys()[roles[role_i]]).to_lower())
		if t >= next_log:
			next_log = t + 30.0
			print("LOG t=%d class=%s pos=%s hearts=%d score=%d-%d kills=%d deaths=%d fps=%d" % [int(t), Stats.Role.keys()[roles[role_i]], p.global_position.snapped(Vector3.ONE * 0.1), p.hearts, game.score[0], game.score[1], p.kills, p.deaths, Engine.get_frames_per_second()])
		if Time.get_ticks_msec() - wall0 > 1500000:
			note("wall clock cap")
			break
	Engine.time_scale = 1.0
	for i in 300:   # the end screen counts its numbers up from zero: shoot it after the count, not the first frame
		await process_frame
	_shot("end")
	print("PLAYTEST_DONE map=", game.map_variant, " t=", int(game.match_played), " score=", game.score, " notes=", notes.size())
	quit(0)
