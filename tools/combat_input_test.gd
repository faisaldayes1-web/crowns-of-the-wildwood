extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")
## Every class's basic attack and every damaging skill must hurt a dummy when
## driven through the real input path: keyboard+mouse (LEFT-CLICK held, aimed
## at the cursor; J as the alternate) and the pad (RT, right-stick aim).
## Run from the project root:
##     tools/tests/isolated.sh --headless --path . --script tools/combat_input_test.gd
## Add `-- --windowed-aim` when a real window is up, to also check the cursor warp.

var fails := 0
var game
var p
var dummy


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await physics_frame


func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _lmb(down: bool) -> void:
	# The click as the action it is bound to (headless drops raw mouse-button state).
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


func _stick_at_dummy() -> void:
	## The right stick pushed toward the dummy, as the camera sees it.
	var b: Basis = game.camera_for(p).global_basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var down := Vector3(b.z.x, 0, b.z.z).normalized()
	var to: Vector3 = (dummy.global_position - p.global_position)
	to.y = 0.0
	to = to.normalized()
	var sx := to.dot(right)
	var sy := to.dot(down)
	Input.action_press(p._a("aim_right" if sx >= 0.0 else "aim_left"), absf(sx))
	Input.action_press(p._a("aim_down" if sy >= 0.0 else "aim_up"), absf(sy))


func _release_all() -> void:
	_lmb(false)
	_key(KEY_J, false)
	_key(KEY_Q, false)
	_key(KEY_E, false)
	for a in ["move_interact", "attack", "ability_1", "ability_2", "aim_right", "aim_left", "aim_up", "aim_down"]:
		Input.action_release(p._a(a))
	for a in ["move_interact", "attack", "ability_1", "ability_2", "aim_right", "aim_left", "aim_up", "aim_down"]:
		Input.action_release(p._a(a))


func _stage(dist: float) -> void:
	## The dummy `dist` metres ahead (+x), healed and unprotected; the player rearmed.
	p.global_position = Vector3(-12, 0.05, 0)
	p.aim = Vector3(1, 0, 0)
	dummy.global_position = p.global_position + Vector3(dist, 0, 0)
	dummy.velocity = Vector3.ZERO
	if dummy.dead:
		dummy._respawn()
	dummy.downed = false
	dummy.revive_protect = 0.0
	dummy.spawn_protect = 0.0
	dummy.home_defense = false
	dummy.resist_pool = 0.0
	dummy.dodge_timer = 0.0
	dummy.guard_timer = 0.0
	dummy.blocking = false
	dummy.hearts = dummy.max_hearts()
	p.energy = p.energy_max()
	p.attack_timer = 0.0
	p.ability_timers = [0.0, 0.0]
	p.hearts = p.max_hearts()
	p.knockback = Vector3.ZERO
	p.velocity = Vector3.ZERO


func _aim_at_dummy_with_mouse() -> void:
	## Put the real cursor on the dummy. Headless has no window to warp in, so
	## fall back to the aim the cursor would have produced.
	var cam: Camera3D = game.camera_for(p)
	var screen := cam.unproject_position(dummy.global_position + Vector3(0, 1.0, 0))
	game.mouse_override = screen
	p.aim_mode = "mouse"
	p.has_mouse = true


func _hit(dist: float, hold: Callable, release: Callable, secs: float = 2.5) -> bool:
	_release_all()
	while p.bash_timer > 0.0 or p.dodge_timer > 0.0:   # a dash in flight swallows the next press
		await physics_frame
	await frames(3)
	_stage(dist)
	await frames(3)
	if not game.pad_active:
		_aim_at_dummy_with_mouse()
	var before: int = dummy.hearts
	hold.call()
	await physics_frame
	await physics_frame
	if OS.get_environment("DEBUG_COMBAT") != "":
		print("DBG aim=", p.aim, " mode=", p.aim_mode, " mfor=", game.mouse_for(p), " vp=", root.get_visible_rect().size, " dumscreen=", game.camera_for(p).unproject_position(dummy.global_position), " act=", Input.is_action_pressed(p._a("move_interact")), " uihit=", game.movement_ui_hit(), " prb=", game.movement_primary_blocked, " mouse=", game.menu_mouse(), " lc=", p.local_controls().attack, " key_j=", Input.is_physical_key_pressed(KEY_J), " lmb=", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), " pad=", game.pad_active, " has_mouse=", p.has_mouse, " blocked=", game.menu_blocks_input(p), game.menu_blocks_movement(p), " hearts=", dummy.hearts, " pos=", p.global_position, dummy.global_position, " en=", p.energy, " at=", p.attack_timer)
	var n := int(secs * 60.0)
	for i in n:
		await physics_frame
		if OS.get_environment("DEBUG_COMBAT") == "3" and i < 14 and game.pad_active:
			print("DBG t", i, " x=", p.global_position.x, " timers=", p.ability_timers, " buf=", p.input_buffer, " bash=", p.bash_timer, " dodge=", p.dodge_timer, " act=", Input.is_action_pressed(p._a("ability_1")), " jp=", Input.is_action_just_pressed(p._a("ability_1")), " ready=", p.ability_ready(0), " blocked=", game.menu_blocks_input(p))
		if OS.get_environment("DEBUG_COMBAT") == "2" and (p.bash_timer > 0.0 or p.bash_hit.size() > 0):
			print("DBG f", i, " bash=", p.bash_timer, " dist=", p._flat_to(dummy.global_position).length(), " hits=", p.bash_hit.size(), " dh=", dummy.hearts, " dprot=", dummy.is_protected(), " dmg=", p.bash_damage)
		if dummy.hearts < before or dummy.dead:
			break
	if OS.get_environment("DEBUG_COMBAT") != "" and not (dummy.hearts < before):
		print("DBG miss aim=", p.aim, " mode=", p.aim_mode, " timers=", p.ability_timers, " en=", p.energy, " pos=", p.global_position, " dummy=", dummy.global_position, " prot=", dummy.is_protected(), dummy.dodge_timer, dummy.guard_timer, dummy.revive_protect, " bh=", p.bash_hit, " dead=", dummy.dead, dummy.downed, " isdummy=", p.bash_hit.has(dummy), " blk=", dummy.blocking, " hd=", dummy.home_defense, " rp=", dummy.resist_pool, " bub=", dummy.get("bubble_timer"), " stick=", Input.get_vector(p._a("aim_left"), p._a("aim_right"), p._a("aim_up"), p._a("aim_down")))
	release.call()
	_release_all()
	await frames(10)
	return dummy.hearts < before or dummy.dead


func _init() -> void:
	if not Isolated.ok("tools/combat_input_test.gd"):
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var waited := 0
	while (game.main_menu == null or game.player == null and waited < 3) and waited < 1200:
		await physics_frame
		waited += 1
		if game.main_menu != null and waited > 5:
			break
	var m = game.main_menu
	m._press("play", null)
	m._press("team_size", 1)
	m._press("to_lobby", null)
	m.start()
	waited = 0
	while not game.playing and waited < 3000:
		await physics_frame
		waited += 1
	await frames(60)
	check(game.playing, "the match started")
	waited = 0
	while waited < 3000 and (game.player == null or not game.player.is_inside_tree() or not game.player.is_on_floor()):
		await physics_frame
		waited += 1
	if OS.get_environment("DEBUG_COMBAT") != "":
		print("DBG start waited=", waited, " player=", game.player, " floor=", game.player.is_on_floor(), " proc=", game.player.is_physics_processing(), " mode=", game.player.process_mode, " intro=", game.get("intro_active"), " tree_paused=", paused)
	p = game.player
	game.touch_active = false
	game.pc_movement = "wasd"
	game.cursor_shown = false
	for u in game.units:
		if u != p:
			u.process_mode = Node.PROCESS_MODE_DISABLED
	dummy = null
	for u in game.units:
		if u.team != p.team and not u.dead:
			dummy = u
			break
	check(dummy != null, "an enemy dummy exists")
	dummy.set_role(Stats.Role.BASE)
	dummy.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(-12, 0.1, 0)
	p.has_mouse = true

	for r in Stats.ROLES:
		if r == Stats.Role.BASE:
			continue
		p.set_role(r)
		p._stats_cache = {}
		var rname: String = str(Stats.Role.keys()[r])
		var dist := 1.6 if str(p.attack_stats().get("attack", "")) == "melee" else 5.0
		var heal_only: bool = p.attack_stats().get("attack", "") == "heal"

		# Keyboard + mouse: left-click is the basic attack.
		game.pad_active = false
		if not heal_only:
			var ok = await _hit(dist, func(): _lmb(true), func(): pass)
			check(ok, "%s: LEFT-CLICK basic attack damages the dummy (mouse)" % rname)
			# J stays as an alternate on the keyboard.
			ok = await _hit(dist, func(): _key(KEY_J, true), func(): pass)
			check(ok, "%s: J basic attack damages the dummy (keyboard alternate)" % rname)
		else:
			# Healers' Mend heals allies; with nobody hurt it fires a holy bolt.
			var ok = await _hit(dist, func(): _lmb(true), func(): pass)
			check(ok, "%s: LEFT-CLICK bolt damages the dummy (mouse)" % rname)

		# Pad: RT attacks, the right stick aims (+x here).
		game.pad_active = true
		var okp = await _hit(dist, func():
			_stick_at_dummy()
			Input.action_press(p._a("attack"), 1.0), func(): pass)
		check(okp, "%s: pad RT + right stick basic attack damages the dummy" % rname)

		# Skills that carry damage must hurt the dummy, mouse then pad.
		for i in p.abilities().size():
			var a: Dictionary = p.ability(i)
			if a.kind == "trap" or not (a.has("damage") or a.kind in ["bash", "cleave", "volley", "fireball", "smite", "shot"]):
				continue   # a trap needs a victim to step on it: covered by combat_test.gd
			for dev in ["mouse", "pad"]:
				game.pad_active = dev == "pad"
				var act: String = "ability_%d" % (i + 1)
				var okk = await _hit(2.5 if a.kind == "bash" else dist, func():
					if dev == "pad":
						_stick_at_dummy()
						Input.action_press(p._a(act))
					else:
						_key(KEY_Q if i == 0 else KEY_E, true), func(): pass)
				check(okk, "%s: skill %s damages the dummy (%s)" % [rname, a.name, dev])
		_release_all()

	# Left-click on a button must not swing: the economy/UI guard.
	game.pad_active = false
	p.set_role(Stats.Role.KNIGHT)
	_stage(1.6)
	check(game.pc_movement == "wasd", "default keyboard scheme is WASD + left-click attack")
	print("COMBAT INPUT TEST: %d failed" % fails)
	quit(fails)
