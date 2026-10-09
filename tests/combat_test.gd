extends Node
## Headless combat checks, run with tools/tests/run.sh (or
## `godot --headless --path . --fixed-fps 60 -- --demo --selftest`).
## Starts a bot match, freezes every unit, then stages one-on-one hits and
## checks their effects. Prints a TEST PASS / TEST FAIL line per check and
## quits with the number of failures as the exit code.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

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
		if u.team == team and not u.is_player:
			return u
	return null


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
	_check(victim.dead and victim.slow_timer == 0.0, "slow_cleared_on_death", "dead=%s slow_timer=%.2f" % [victim.dead, victim.slow_timer])

	# 6. Effects clean up after themselves: one-shots free within ~2 s.
	var before: int = fx.get_child_count()
	for i in 20:
		fx.blast(attacker.global_position, 3.0, ["fire", "frost", "nature", "dark", "arcane"][i % 5])
		fx.heal_on(attacker, 2, victim)
	_check(fx.get_child_count() > before, "fx_blast_heal_drawn")
	await _frames(240)
	_check(fx.get_child_count() <= before, "fx_cleanup", "children %d -> %d" % [before, fx.get_child_count()])

	print("TESTS DONE failures=%d" % failures)
	get_tree().quit(failures)
