extends Node
## Headless combat checks, run with tools/tests/run.sh (or
## `godot --headless --path . --fixed-fps 60 -- --demo --selftest`).
## Starts a bot match, freezes every unit, then stages one-on-one hits and
## checks their effects. Prints a TEST PASS / TEST FAIL line per check and
## quits with the number of failures as the exit code.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role
const Projectile = preload("res://scripts/projectile.gd")

var game
var failures := 0


func _ready() -> void:
	_run()


func _check(ok: bool, name: String, detail: String = "") -> void:
	if ok:
		print("TEST PASS %s" % name)
	else:
		failures += 1
		print("TEST FAIL %s %s" % [name, detail])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _first(team: int):
	for u in game.units:
		if u.team == team and not u.is_player and not u.dead:
			return u
	return null


func _finish(u) -> void:
	## With Downed & Revive merged, a last heart knocks a unit down first:
	## finish it off so death checks still see a death.
	if u.get("downed"):
		u._die()


func _stage(attacker, victim) -> void:
	## Victim one metre in front of the attacker, at the same height, with
	## nothing (protection, armour pool, dodge, shield) between them.
	victim.global_position = attacker.global_position + Vector3(1, 0, 0)
	victim.spawn_protect = 0.0
	victim.home_defense = false
	victim.resist_pool = 0.0
	victim.dodge_timer = 0.0
	victim.guard_timer = 0.0
	victim.blocking = false
	victim.slow_timer = 0.0
	victim.hearts = victim.max_hearts()
	attacker.energy = attacker.energy_max()
	attacker.attack_timer = 0.0


func _run() -> void:
	await _frames(120)
	for u in game.units:
		u.process_mode = Node.PROCESS_MODE_DISABLED
	var attacker = _first(0)
	var victim = _first(1)
	victim.set_role(Role.BASE)

	# 1. Venom Fang (the Assassin Rogue's base attack) slows whoever it cuts.
	attacker.set_role(Role.ROGUE)
	attacker.variants[Role.ROGUE] = 0
	attacker._stats_cache = {}
	var s: Dictionary = attacker.attack_stats()
	_check(s.get("attack_name", "") == "Venom Fang" and s.has("slow"), "venom_fang_kit", str(s.get("attack_name")))
	_stage(attacker, victim)
	attacker._attack(Vector3(1, 0, 0))
	_check(victim.hearts == victim.max_hearts() - 1, "venom_fang_hits", "hearts=%d" % victim.hearts)
	_check(is_equal_approx(victim.slow_timer, s.slow), "venom_fang_slows", "slow_timer=%.2f want %.2f" % [victim.slow_timer, s.slow])

	# Hit feel: the hit drew effects, the victim flashes, its animation holds.
	var fx: Node = game.get_node_or_null("Fx")
	_check(fx != null and fx.get_child_count() > 0, "fx_hit_drawn", "fx children=%d" % (fx.get_child_count() if fx else -1))
	_check(victim.flash_timer > 0.0, "fx_hit_flash", "flash_timer=%.2f" % victim.flash_timer)
	_check(victim.hitstop_timer > 0.0 and victim.model.anim.speed_scale == 0.0, "fx_hitstop_on",
		"hitstop=%.2f speed=%.2f" % [victim.hitstop_timer, victim.model.anim.speed_scale])

	# 2. The slow wears off on its own clock: still on at half time, gone after.
	victim.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(int(s.slow * 60.0 * 0.5))
	_check(victim.slow_timer > 0.0, "venom_fang_slow_lasts", "slow_timer=%.2f" % victim.slow_timer)
	_check(victim.status_fx.has("slow") and victim.status_fx.slow.emitting, "fx_slow_aura_on")
	_check(victim.model.anim.speed_scale == 1.0, "fx_hitstop_ends", "speed=%.2f" % victim.model.anim.speed_scale)
	_check(victim.flash_timer == 0.0 and victim.flash_mats.all(func(m): return m.albedo_color == victim.model.tint),
		"fx_flash_ends", "flash_timer=%.2f" % victim.flash_timer)
	await _frames(int(s.slow * 60.0 * 0.5) + 6)
	_check(victim.slow_timer == 0.0, "venom_fang_slow_expires", "slow_timer=%.2f" % victim.slow_timer)
	_check(not victim.status_fx.slow.emitting, "fx_slow_aura_off")
	victim.process_mode = Node.PROCESS_MODE_DISABLED

	# 3. A second cut refreshes the slow rather than stacking it.
	_stage(attacker, victim)
	victim.slow_timer = 0.5
	attacker._attack(Vector3(1, 0, 0))
	_check(is_equal_approx(victim.slow_timer, s.slow), "venom_fang_no_stack", "slow_timer=%.2f" % victim.slow_timer)

	# 4. Plain melee (Knight's sword, a soldier's fists) does not slow.
	for r in [Role.KNIGHT, Role.BASE]:
		attacker.set_role(r)
		_stage(attacker, victim)
		attacker._attack(Vector3(1, 0, 0))
		_check(victim.hearts < victim.max_hearts() and victim.slow_timer == 0.0, "no_slow_role%d" % r,
			"hearts=%d slow_timer=%.2f" % [victim.hearts, victim.slow_timer])

	# 5. Dying clears the slow, so nobody respawns slowed.
	attacker.set_role(Role.ROGUE)
	_stage(attacker, victim)
	victim.hearts = 1
	attacker._attack(Vector3(1, 0, 0))
	_finish(victim)
	_check(victim.dead and victim.slow_timer == 0.0, "slow_cleared_on_death", "dead=%s slow_timer=%.2f" % [victim.dead, victim.slow_timer])

	# 6. Effects clean up after themselves: one-shots free within ~2 s.
	var before: int = fx.get_child_count()
	for i in 20:
		fx.blast(attacker.global_position, 3.0, ["fire", "frost", "nature", "dark", "arcane"][i % 5])
		fx.heal_on(attacker, 2, victim)
	_check(fx.get_child_count() > before, "fx_blast_heal_drawn")
	await _frames(240)
	_check(fx.get_child_count() <= before, "fx_cleanup", "children %d -> %d" % [before, fx.get_child_count()])

	# 7. Walls and doors stop shots: arrows fired across each castle from a
	# ring of spots outside it (so through the walls, both doors, the keep)
	# must never fly through anything solid. Units are moved off the map.
	await _wall_shots()
	await _rampart_and_splash()

	# 8. Every ability on both sides (plain kit and both promotions) casts
	# with its own look, and the body is back to its normal shape after.
	await _all_skills()

	# 9. Grab (F / RB): every press reaches out and answers with a pop or a
	# whiff, and rapid retries (bots at a locked vault) don't stack effects.
	await _grab()

	# 10. The killing blow throws the body back, and it stands up straight on respawn.
	await _death_fling()

	# 11. A player's hit from range answers with a hit confirm; a melee-range
	# hit (which already has its own weight) does not.
	await _hit_confirm()

	print("TESTS DONE failures=%d" % failures)
	get_tree().quit(failures)


func _wall_shots() -> void:
	for u in game.units:
		u.global_position = Vector3(0, -60, 0)
	var shooters := [_first(0), _first(1)]
	var shots := []
	for castle in 2:
		var cx: float = -game.CASTLE_X if castle == 0 else game.CASTLE_X
		for k in 48:
			# Spots 0-23 outside the walls aiming in; 24-47 in the yard aiming out.
			var ang := TAU * (k % 24) / 24.0
			var ring := Vector3(cos(ang), 0, sin(ang))
			var from := Vector3(cx, 0, 0) + ring * (19.0 if k < 24 else 5.5)
			if k >= 24 and absf(from.x) > absf(cx):
				from.x -= signf(cx) * 4.0   # keep the yard spots out of the keep's back rooms
			var dir := -ring if k < 24 else ring
			for team in 2:
				var shot = Projectile.new()
				shot.owner_unit = shooters[team]
				game.add_child(shot)
				shot.setup(game, team, from, dir, {"damage": 1, "gate_damage": 0, "range": 38.0, "shot_speed": 32.0}, Color.WHITE)
				shots.append({"shot": shot, "from": shot.global_position, "last": shot.global_position, "team": team, "castle": castle, "k": k})
	for f in 120:
		await get_tree().physics_frame
		for e in shots:
			if is_instance_valid(e.shot):
				e.last = e.shot.global_position
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var leaks := 0
	var detail := ""
	for e in shots:
		var path: Vector3 = e.last - e.from
		if path.length() < 0.5:
			continue
		var ray := PhysicsRayQueryParameters3D.create(e.from, e.last - path.normalized() * 0.4, 1 | 4 | 8)
		var hit := ray_hit(space, ray)
		if not hit.is_empty():
			leaks += 1
			if detail.length() < 600:
				detail += " [team%d castle%d spot%d through %s at %s]" % [e.team, e.castle, e.k, hit.collider.name, (hit.position as Vector3).snapped(Vector3.ONE * 0.1)]
	_check(leaks == 0 and shots.size() == 192, "shots_stop_on_walls_and_doors", "%d of %d shots flew through something:%s" % [leaks, shots.size(), detail])


func ray_hit(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D) -> Dictionary:
	return space.intersect_ray(ray)


func _rampart_and_splash() -> void:
	## An archer on the rampart still hits someone on the field below, and a
	## fireball bursting on the outside of the front wall spares a defender
	## standing just inside it.
	var archer = _first(1)    # Humans: castle at +x, front wall faces -x
	var target = _first(0)
	archer.set_role(Role.RANGER)
	target.set_role(Role.BASE)
	var post: Vector3 = game.wall_posts[1][0]
	archer.global_position = post
	_stage(archer, target)
	target.global_position = post + Vector3(-9.0, -post.y, 0)
	archer.global_position = post
	var dir: Vector3 = target.global_position - archer.global_position
	dir.y = 0.0
	archer._attack(dir.normalized())
	await _frames(40)
	_check(target.hearts == target.max_hearts() - 1, "rampart_archer_hits_below", "hearts=%d archer at %s target at %s" % [target.hearts, archer.global_position, target.global_position])

	# Fireball at the front wall from outside: a Human 1.6 m outside the wall
	# is caught (so the blast did go off there), one 1.6 m inside is not.
	var fx_x: float = game.gates[1].position.x
	var z := -8.0
	var mage = _first(0)
	var humans: Array = game.units.filter(func(u): return u.team == 1 and not u.dead)
	var inside = humans[0]
	var outside = humans[1]
	target.global_position = Vector3(0, -60, 0)
	archer.global_position = Vector3(0, -60, 0)
	for pair in [[inside, fx_x + 1.6], [outside, fx_x - 1.6]]:
		var u = pair[0]
		u.set_role(Role.BASE)
		u.global_position = Vector3(pair[1], 0, z + 1.2)
		u.spawn_protect = 0.0
		u.home_defense = false
		u.resist_pool = 0.0
		u.blocking = false
		u.dodge_timer = 0.0
		u.guard_timer = 0.0
		u.hearts = u.max_hearts()
	var ball = Projectile.new()
	ball.owner_unit = mage
	game.add_child(ball)
	ball.setup(game, 0, Vector3(fx_x - 8.0, 0, z), Vector3(1, 0, 0), {"damage": 1, "gate_damage": 0, "range": 20.0, "shot_speed": 28.0, "splash": 3.5, "fire": true}, Color.ORANGE)
	await _frames(40)
	_check(outside.hearts == outside.max_hearts() - 1, "splash_hits_outside_wall", "hearts=%d" % outside.hearts)
	_check(inside.hearts == inside.max_hearts(), "splash_blocked_by_wall", "hearts=%d" % inside.hearts)


func _all_skills() -> void:
	var fx: Node = game.get_node("Fx")
	var cast := 0
	var bent := []
	for team in [0, 1]:
		var u = _first(team)
		if u == null:
			_check(false, "skills_team%d" % team, "no unit")
			continue
		for r in Stats.ROLES:
			if r == Role.BASE:
				continue
			for v in [-1, 0, 1]:
				u.set_role(r)
				if v < 0:
					u.variants.erase(r)
				elif Stats.VARIANTS.has(r) and v < Stats.VARIANTS[r].size():
					u.variants[r] = v
				else:
					continue
				u._stats_cache = {}
				for i in u.abilities().size():
					u.global_position = Vector3(-20, 0, 3)
					u.energy = 9999.0
					u.ability_timers = [0.0, 0.0]
					u.hearts = u.max_hearts()
					u.model.process_mode = Node.PROCESS_MODE_ALWAYS   # let its tweens play
					u.use_ability(i, Vector3(1, 0, 0))
					cast += 1
					await _frames(25)
					if u.model.scale.distance_to(Vector3.ONE) > 0.01 or u.model.position.length() > 0.01 or u.model.rotation.length() > 0.01:
						bent.append(u.ability(i).name)
					u.guard_timer = 0.0
					u.bubble_timer = 0.0
					u.stealth_timer = 0.0
		u.variants.erase(u.role)
	print("skills cast=%d" % cast)
	_check(cast >= 40, "skills_all_cast", "cast=%d" % cast)
	_check(bent.is_empty(), "skills_body_restored", str(bent))
	await _frames(240)
	_check(fx.get_child_count() < 40, "skills_fx_cleanup", "children=%d" % fx.get_child_count())


func _grab() -> void:
	var fx: Node = game.get_node("Fx")
	var u = _first(0)
	u.global_position = Vector3(-20, 0, 3)
	u.model.process_mode = Node.PROCESS_MODE_ALWAYS
	u.set_meta("grab_ms", -100000)
	var before: int = fx.get_child_count()
	game.try_interact(u)
	var once: int = fx.get_child_count()
	for i in 10:
		game.try_interact(u)
	_check(once > before and fx.get_child_count() <= once + 3, "grab_feedback_once", "fx %d -> %d -> %d" % [before, once, fx.get_child_count()])
	await _frames(40)
	_check(u.model.scale.distance_to(Vector3.ONE) < 0.01 and u.model.rotation.length() < 0.01, "grab_body_restored")


func _death_fling() -> void:
	var a = _first(0)
	var v = _first(1)
	a.global_position = Vector3(-20, 0, 3)
	_stage(a, v)
	v.model.process_mode = Node.PROCESS_MODE_ALWAYS
	v.hearts = 1
	v.take_damage(1, a, a.global_position, 6.0, {"fx": "heavy"})
	_finish(v)
	await _frames(25)
	var flung: float = Vector2(v.model.position.x, v.model.position.z).length()
	_check(v.dead and flung > 0.5, "death_fling", "dead=%s flung=%.2f" % [v.dead, flung])
	v.model.revive()
	_check(v.model.position.length() < 0.01, "death_fling_reset")


func _hit_confirm() -> void:
	var a = _first(0)
	var v = _first(1)
	a.global_position = Vector3(-20, 0, 3)
	_stage(a, v)
	var was: bool = a.is_player
	a.is_player = true
	var before: int = a.hit_confirms
	v.take_damage(1, a, a.global_position, 0.0, {})
	_check(a.hit_confirms == before, "hit_confirm_not_melee", "confirms=%d" % (a.hit_confirms - before))
	_stage(a, v)
	v.global_position = a.global_position + Vector3(9, 0, 0)
	v.take_damage(1, a, a.global_position, 0.0, {})
	_check(a.hit_confirms == before + 1, "hit_confirm_ranged", "confirms=%d" % (a.hit_confirms - before))
	a.is_player = was
	await _frames(2)
