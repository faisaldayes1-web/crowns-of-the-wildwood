extends SceneTree
## The Moonlit Wildwood's graveyard (scripts/graveyard.gd, scripts/zombie.gd):
## the rising timer, the Cursed Bell flipping the zombies' allegiance,
## neutral zombies attacking both teams and friendly ones only the enemy,
## units putting zombies down, the bots' interest in the bell, and zombies
## walking from the graves to the enemy door without stalling or stepping
## into the river. claude-faisal/crowns-graveyard 2026-11-04.
##     tools/tests/isolated.sh --headless --path . --fixed-fps 60 --script tools/graveyard_test.gd
## The match runs for real for the timer check; the rest drives the
## graveyard by hand with the game paused, so nothing else moves.

const Stats = preload("res://scripts/stats.gd")
const Isolated = preload("res://tools/tests/isolated.gd")
const Zombie = preload("res://scripts/zombie.gd")

var fails := 0
var game


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	call_deferred("run")


func _park_units() -> void:
	## Everyone far from the graveyard, standing, unhurt.
	var i := 0
	for u in game.units:
		u.global_position = Vector3(-40.0 if u.team == 0 else 40.0, 0.0, 28.0 - i * 1.5)
		u.downed = false
		u.dead = false
		u.hearts = u.max_hearts()
		u.dodge_timer = 0.0
		u.guard_timer = 0.0
		u.revive_protect = 0.0
		u.stealth_timer = 0.0
		u.spawn_protect = 0.0
		u.blocking = false
		i += 1


func _one(team: int):
	for u in game.units:
		if u.team == team:
			return u
	return null


func _clear_zombies(gy) -> void:
	for z in gy.zombies.duplicate():
		if is_instance_valid(z):
			z.free()
	gy.zombies.clear()


func _spawn(gy, at: Vector3):
	var z = Zombie.new()
	game.add_child(z)
	z.setup(game, gy, gy.next_id, at, gy.bell_owner)
	gy.next_id += 1
	gy.zombies.append(z)
	z.state = Zombie.State.WALK
	z.position.y = 0.0
	z.attack_cd = 0.0
	return z


func run() -> void:
	if not Isolated.ok("graveyard_test"):
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 300000
	while not (game.world_ready and game.playing):
		if Time.get_ticks_msec() > deadline:
			check(false, "the demo match started")
			_finish()
			return
		await process_frame
	var gy = game.graveyard
	check(gy != null, "the Moonlit Wildwood builds its graveyard")
	if gy == null:
		_finish()
		return
	check(gy.graves.size() == 16, "16 graves to rise from (got %d)" % gy.graves.size())

	# 1. The timer: nothing during the fortify phase, then a rising every interval.
	var s: Dictionary = Stats.GRAVEYARD
	game.prep_left = 0.0
	for i in 3:
		await process_frame
	check(gy.started and absf(gy.rise_left - s.interval) < 0.5, "the first rising is %d s into the battle (%.1f left)" % [s.interval, gy.rise_left])
	var before: float = gy.rise_left
	for i in 120:
		await physics_frame
	var ran: float = before - gy.rise_left
	check(ran > 1.0 and ran < 3.0, "the rising timer counts down with the match (%.2f s over 2 s)" % ran)
	check(gy.alive_zombies().is_empty(), "no zombies before the first rising")
	gy.rise_left = 0.02
	for i in 6:
		await process_frame
	check(gy.risings == 1 and gy.alive_zombies().size() == s.wave, "a rising brings %d zombies (got %d)" % [s.wave, gy.alive_zombies().size()])
	check(absf(gy.rise_left - s.interval) < 0.5, "the next rising is %d s later (%.1f left)" % [s.interval, gy.rise_left])
	var sides := {}
	for z in gy.alive_zombies():
		sides[signf(z.position.x)] = true
		check(z.state == Zombie.State.RISE and z.position.y < -0.5, "zombie %d rises out of the ground (y %.2f)" % [z.id, z.position.y])
	check(sides.size() == 2, "the rising comes up in both plots")
	gy.rise_left = 0.02
	for i in 6:
		await process_frame
	gy.rise_left = 0.02
	for i in 6:
		await process_frame
	check(gy.alive_zombies().size() <= s.max_alive, "no more than %d zombies at once (got %d)" % [s.max_alive, gy.alive_zombies().size()])

	# From here the game is paused and the graveyard driven by hand.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_zombies(gy)
	_park_units()
	var elf = _one(0)
	var human = _one(1)

	# 2. The bell: an Elf alone in the ring captures it; the zombies turn.
	gy.bell_owner = -1
	gy.bell_progress = 0.0
	var z0 = _spawn(gy, Vector3(-7.8, 0, -31.3))
	check(z0.team == -1 and z0.hostile_to(0) and z0.hostile_to(1), "with nobody holding the bell a zombie is hostile to both teams")
	elf.global_position = Vector3(-5.0, 0, -31.0)
	var secs := 0.0
	while gy.bell_owner != 0 and secs < 30.0:
		gy._capture(0.1)
		secs += 0.1
	check(gy.bell_owner == 0, "one Elf in the ring captures the Cursed Bell (%.1f s)" % secs)
	check(absf(secs - s.capture_time) < 1.0, "the capture takes about %d s" % s.capture_time)
	check(z0.team == 0 and not z0.hostile_to(0) and z0.hostile_to(1), "the Elves' bell makes the zombie theirs")
	check(z0.sash_mat.emission.is_equal_approx(game._team_color(0).lightened(0.08)) and z0.glow.light_color.is_equal_approx(game._team_color(0).lightened(0.08)), "the Elves' zombie glows Elf green")
	check(gy.status(0).text.begins_with("Elves hold the Cursed Bell"), "the HUD line says the Elves hold the bell (%s)" % gy.status(0).text)
	check(gy.bots_wanted(1) >= 1, "Human bots want the bell back (%d)" % gy.bots_wanted(1))
	check(gy.threat_for(0, z0.position, 5.0) == null and gy.threat_for(1, z0.position, 5.0) == z0, "bots see an Elf zombie as a threat only to Humans")
	# A Human in the ring with the Elf freezes it; alone it rings it back to neutral.
	human.global_position = Vector3(5.0, 0, -31.0)
	var p0: float = gy.bell_progress
	gy._capture(1.0)
	check(gy.bell_contested and gy.bell_progress == p0, "both teams in the ring freeze the bell")
	elf.global_position = Vector3(-40, 0, 20)
	secs = 0.0
	while gy.bell_owner == 0 and secs < 30.0:
		gy._capture(0.1)
		secs += 0.1
	check(gy.bell_owner == -1 and z0.team == -1, "taking it from the Elves rings it back to neutral first")
	while gy.bell_owner != 1 and secs < 60.0:
		gy._capture(0.1)
		secs += 0.1
	check(gy.bell_owner == 1 and z0.team == 1, "then the Humans own it and the zombie turns again")
	_park_units()

	# 3. Neutral zombies attack both teams.
	gy.bell_owner = -1
	gy.bell_progress = 0.0
	_clear_zombies(gy)
	for t in 2:
		var u = elf if t == 0 else human
		_park_units()
		var z = _spawn(gy, Vector3(-7.0, 0, -29.0))
		u.global_position = Vector3(-7.0, 0, -30.0)
		var h0: int = u.hearts
		for i in 90:
			z.step(1.0 / 30.0)
		check(u.hearts < h0, "a neutral zombie attacks the %s (hearts %d -> %d)" % [Stats.FACTIONS[t].name, h0, u.hearts])
		_clear_zombies(gy)

	# 4. A friendly zombie leaves its own team alone and goes for the enemy.
	_park_units()
	gy.bell_owner = 0
	var zf = _spawn(gy, Vector3(-7.0, 0, -29.0))
	elf.global_position = Vector3(-7.0, 0, -30.0)
	human.global_position = Vector3(-7.5, 0, -33.0)
	var he0: int = elf.hearts
	var hh0: int = human.hearts
	for i in 150:
		zf.step(1.0 / 30.0)
	check(elf.hearts == he0, "the Elves' zombie leaves an Elf standing next to it alone")
	check(human.hearts < hh0, "the Elves' zombie attacks the Human (hearts %d -> %d)" % [hh0, human.hearts])
	_clear_zombies(gy)

	# 5. Units put zombies down; friendly ones cannot be hit by their own side.
	_park_units()
	gy.bell_owner = -1
	var zk = _spawn(gy, Vector3(-7.0, 0, -29.0))
	elf.global_position = Vector3(-7.0, 0, -30.0)
	var swings := 0
	while zk.alive() and swings < 10:
		gy.melee(elf, Vector3(0, 0, 1), 1.7, 1)
		swings += 1
	check(not zk.alive() and swings == s.hp, "a zombie falls to %d hits (took %d)" % [s.hp, swings])
	check(gy.kills[0] == 1, "the kill is counted for the Elves")
	gy.bell_owner = 0
	var zo = _spawn(gy, Vector3(-7.0, 0, -29.0))
	check(not gy.melee(elf, Vector3(0, 0, 1), 1.7, 1) and zo.hp == s.hp, "the Elves cannot hit their own zombie")
	check(gy.shot_hit(0, zo.position + Vector3(0, 1.0, 0), 0.7) == null and gy.shot_hit(1, zo.position + Vector3(0, 1.0, 0), 0.7) == zo, "shots pass through friendly zombies and hit hostile ones")
	_clear_zombies(gy)

	# 6. No stalls: zombies of each side walk from every grave to the enemy
	# door over the flank bridge, never into the river.
	for t in 2:
		_park_units()
		for u in game.units:
			u.global_position = Vector3(0, 0, 33.0)   # out of everyone's way (south bank of the shrine)
			u.global_position.x = 30.0 if u.team == 0 else -30.0
		gy.bell_owner = t
		var walkers: Array = []
		for gi in range(0, gy.graves.size(), 2):
			var g = gy.graves[gi]
			walkers.append(_spawn(gy, g[0] + Vector3(-signf(g[0].x) * 0.9, 0, 0)))
		var wet := 0
		var worst_stall := 0.0
		for i in 30 * 45:
			for z in walkers:
				if is_instance_valid(z) and z.alive():
					z.step(1.0 / 30.0)
					worst_stall = maxf(worst_stall, z.stall)
					if absf(z.position.x) < game.RIVER_HALF + 0.3 and not gy._on_bridge(z.position):
						wet += 1
		var goal_x: float = (1.0 if t == 0 else -1.0) * (game.CASTLE_X - game.CASTLE_DEPTH - 4.0)
		var arrived := 0
		for z in walkers:
			if is_instance_valid(z) and absf(z.position.x - goal_x) < 4.0:
				arrived += 1
			elif is_instance_valid(z):
				print("  short of the door: zombie %d at %s (home %s, moved %.1f m)" % [z.id, z.position.snapped(Vector3.ONE * 0.1), z.home.snapped(Vector3.ONE * 0.1), z.moved])
		check(wet == 0, "%s zombies never step into the river (%d wet steps)" % [Stats.FACTIONS[t].name, wet])
		check(arrived == walkers.size(), "%s zombies all reach the enemy door in 45 s (%d / %d)" % [Stats.FACTIONS[t].name, arrived, walkers.size()])
		check(game.gates[1 - t].hp < Stats.GATE_HITS, "%s zombies claw at the enemy door when they get there" % Stats.FACTIONS[t].name)
		game.gates[1 - t].hp = Stats.GATE_HITS
		check(worst_stall < 3.0, "%s zombies never stall on the way (worst %.1f s)" % [Stats.FACTIONS[t].name, worst_stall])
		_clear_zombies(gy)
	# Neutral zombies wander their plot and keep near it.
	_park_units()
	gy.bell_owner = -1
	var wanderers: Array = []
	for gi in range(1, gy.graves.size(), 4):
		wanderers.append(_spawn(gy, gy.graves[gi][0] + Vector3(-signf(gy.graves[gi][0].x) * 0.9, 0, 0)))
	var far := 0.0
	var wet_n := 0
	for i in 30 * 30:
		for z in wanderers:
			z.step(1.0 / 30.0)
			far = maxf(far, (z.position - gy.CENTER).length())
			if absf(z.position.x) < game.RIVER_HALF + 0.3 and not gy._on_bridge(z.position):
				wet_n += 1
	var walked := 0.0
	for z in wanderers:
		walked += z.moved
	check(far < s.leash, "neutral zombies keep to the graveyard (farthest %.1f m)" % far)
	check(wet_n == 0, "neutral zombies stay out of the river")
	check(walked / wanderers.size() > 5.0, "neutral zombies shamble about (%.1f m each)" % (walked / wanderers.size()))
	# They crumble when their time is up.
	for z in wanderers:
		z.age = s.life + s.rise_time + 1.0
		z.step(0.1)
	check(wanderers.all(func(z): return not z.alive()), "zombies crumble after %d s" % s.life)
	_finish()


func _finish() -> void:
	print("graveyard_test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
