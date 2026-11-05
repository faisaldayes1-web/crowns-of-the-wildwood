extends SceneTree
## Ember Pass knock-off (claude-faisal 2026-11-04): a blow can shove a unit off
## an unrailed plateau rim into the lava, where it dies (no going down), the
## shover gets the kill and the usual respawn follows. Bridges (rails),
## causeways and the stair (parapets) and plazas (kerbs) keep it on. Run headless:
##     tools/tests/isolated.sh --headless --path . --fixed-fps 60 --script tools/lava_knockoff_test.gd -- --demo --seed=7 --map=2

const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func shove(u, att, at: Vector3, from_dir: Vector3, frames: int) -> void:
	## Puts u at `at`, the attacker a step the other way, and lands one melee
	## blow, which pushes u away from the attacker.
	u.global_position = at + Vector3(0, 0.05, 0)
	att.global_position = at + from_dir * 1.2 + Vector3(0, 0.05, 0)
	for x in [u, att]:
		x.knockback = Vector3.ZERO
		x.slide_vel = Vector3.ZERO
		x.velocity = Vector3.ZERO
		x.spawn_protect = 0.0
		x.root_timer = 5.0
	u.hearts = u.max_hearts()
	await physics_frame
	u.take_damage(1, att, att.global_position, Stats.KNOCK_MELEE)
	for i in frames:
		u.root_timer = 5.0
		att.root_timer = 5.0
		await physics_frame


func _init() -> void:
	if not Isolated.ok("tools/lava_knockoff_test.gd"):
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var waited := 0
	while (game.units.size() < 2 or game.vmap == null) and waited < 6000:
		await process_frame
		waited += 1
	check(game.vmap != null, "map 2 should be Ember Pass")
	if game.vmap == null:
		print("lava knockoff test: %d failure(s)" % (failures + 1))
		quit(1)
		return
	var v = game.vmap
	# The rule: which drops are open.
	check(v.open_edge(Vector3(-60, 0, 15.4)), "the Elves' plateau north rim should be open")
	check(v.open_edge(Vector3(70, 0, -15.4)), "the Humans' plateau south rim should be open")
	check(not v.open_edge(Vector3(-60, 0, 14.0)), "solid ground is no drop")
	check(not v.open_edge(Vector3(-41.3, 0, 2.0)), "where the causeway meets the plateau its parapet holds")
	var bm: Vector3 = (v.pos[v.ids.find("m0")] + v.pos[v.ids.find("c")]) / 2.0
	var bdir: Vector3 = (v.pos[v.ids.find("c")] - v.pos[v.ids.find("m0")]).normalized()
	var bside := Vector3(bdir.z, 0, -bdir.x)
	check(not v.open_edge(bm + bside * 2.9), "a bridge's rail should hold")
	check(not v.open_edge(v.pos[v.ids.find("f")] + Vector3(9.4, 0, 0)), "the Fire Objective's kerb should hold")

	var u = null
	var att = null
	for c in game.units:
		if is_instance_valid(c) and not c.dead and not c.is_player:
			if u == null:
				u = c
			elif att == null and c.team != u.team:
				att = c
	check(u != null and att != null, "need two live bots on opposite teams")
	if u != null and att != null:
		# 1. Shoved north off the open rim: into the lava.
		var kills0: int = att.kills
		var deaths0: int = u.deaths
		await shove(u, att, Vector3(-60, 0, 14.4), Vector3(0, 0, -1), 40)
		print("open rim: dead=%s lava_deaths=%d kills %d->%d" % [u.dead, u.lava_deaths, kills0, att.kills])
		check(u.dead, "a unit shoved off the open rim should die in the lava")
		check(not u.downed, "a lava death skips going down")
		check(u.lava_deaths == 1, "the fall should count once (got %d)" % u.lava_deaths)
		check(u.deaths == deaths0 + 1, "the fall should count as a death")
		check(att.kills == kills0 + 1, "the shover should get the kill")
		# 2. The usual respawn.
		var t := 0
		while u.dead and t < 60 * 40:
			await physics_frame
			t += 1
		check(not u.dead, "the unit should respawn after a lava death")
		check(v.walkable(u.global_position), "it should respawn on solid ground")
		# 3. Shoved sideways on a railed bridge: the rail holds.
		await shove(u, att, bm + bside * 2.2, -bside, 40)
		print("bridge: dead=%s at %s" % [u.dead, u.global_position.snapped(Vector3.ONE * 0.01)])
		check(not u.dead, "a unit shoved against a bridge rail should stay up")
		check(v.walkable(u.global_position), "and stay on the deck")
		check(u.lava_deaths == 1, "no extra lava death on the bridge")
		# 4. A gentle push into the rim (under LAVA_SHOVE, like walking into it)
		# never drops you in: clamp_walk holds you on the plateau.
		u.global_position = Vector3(-60, 0.05, 14.8)
		for i in 30:
			u.root_timer = 5.0
			u.knockback = Vector3(0, 0, Stats.LAVA_SHOVE * 0.7)
			await physics_frame
		check(not u.dead, "a gentle push into the rim should not drop you in")
		check(v.walkable(u.global_position), "and leave you on the plateau")
		# 5. The shove is strong enough to matter: about a metre on this map.
		var reach: float = pow(Stats.KNOCK_MELEE * Stats.LAVA_KNOCK_MULT, 2) / (2.0 * 40.0)
		check(reach > 1.0, "a melee shove should carry over a metre on Ember Pass (%.2f)" % reach)
	print("lava knockoff test: %d failure(s)" % failures)
	game.queue_free()
	for i in 10:
		await process_frame
	quit(1 if failures > 0 else 0)
