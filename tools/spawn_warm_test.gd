extends SceneTree
## Spawn bursts after the match warm-up (claude-faisal/crowns-spawn 2026-11-04):
## every class re-dressed on every unit, and two volleys of shots, must not
## load or facet a new character scene, nor build a new projectile once the
## pool has one. Run headless from the project root:
##     tools/tests/isolated.sh --headless --path . --script tools/spawn_warm_test.gd -- --demo --seed=7 --map=3

const Isolated = preload("res://tools/tests/isolated.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const Stats = preload("res://scripts/stats.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Fx = preload("res://scripts/fx.gd")
const BUILD_MS := 40.0   # one warm rebuild (~5-8 ms on a desktop; CI runners are slower)

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	if not Isolated.ok("tools/spawn_warm_test.gd"):
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while game.units.is_empty():
		await process_frame
	var waited := 0
	while not game.warm_models_done and waited < 3000:   # the warm-up rack (scripts/game.gd _warm_up_models)
		await process_frame
		waited += 1
	check(game.warm_models_done, "the model warm-up never finished")
	for i in 5:
		await process_frame
	var res_before: Array = CharacterModel.res_cache.keys()
	var res_n: int = CharacterModel.res_cache.size()
	var flat_n: int = CharacterModel.flat_cache.size()
	CharacterModel.build_log.clear()
	# The burst: every unit takes every class in one go.
	for role in Stats.Role.values():
		for u in game.units:
			if is_instance_valid(u) and not u.dead:
				u.set_role(role)
		await process_frame
	var worst := 0.0
	for ms in CharacterModel.build_log:
		worst = maxf(worst, ms)
	print("spawn warm: %d rebuilds, worst %.1f ms" % [CharacterModel.build_log.size(), worst])
	check(CharacterModel.build_log.size() > 0, "no rebuilds ran")
	for k in CharacterModel.res_cache:
		if not k in res_before:
			print("  loaded after warm-up: ", k)
	check(CharacterModel.res_cache.size() == res_n, "a character scene/skin loaded after warm-up (%d -> %d)" % [res_n, CharacterModel.res_cache.size()])
	check(CharacterModel.flat_cache.size() == flat_n, "a mesh was faceted after warm-up (%d -> %d)" % [flat_n, CharacterModel.flat_cache.size()])
	check(worst < BUILD_MS, "a warm rebuild took %.1f ms (limit %.0f)" % [worst, BUILD_MS])
	# Shots: a volley, let it land, a second volley reuses the pool.
	var u = game.units[0]
	var s := {"damage": 1, "gate_damage": 1, "range": 6.0, "shot_speed": 30.0}
	var seen := {}
	for i in 12:
		game.spawn_shot(u, Vector3.FORWARD.rotated(Vector3.UP, i * 0.5), s, Color.WHITE)
	for c in game.get_children():
		if c is Projectile:
			seen[c.get_instance_id()] = true
	for i in 90:
		await physics_frame
	await process_frame
	check(game.shot_pool.size() >= 12, "finished shots not pooled (%d)" % game.shot_pool.size())
	var fresh := 0
	for i in 12:
		game.spawn_shot(u, Vector3.FORWARD.rotated(Vector3.UP, i * 0.5), s, Color.WHITE)
	for c in game.get_children():
		if c is Projectile and not seen.has(c.get_instance_id()):
			fresh += 1
	check(fresh == 0, "%d new projectiles built while the pool had shots" % fresh)
	# Effects, popups and lights: a second round builds no new nodes.
	var fx = Fx.of(game)
	for round in 2:
		var made: int = fx.pool_made
		for i in 8:
			var at: Vector3 = u.global_position + Vector3(i * 0.3, 0.1, 0)
			for style in 4:
				fx.burst(at, Color.WHITE, 4, 1.0, 0.25, style)
			fx.flare(at, Color.WHITE)
			fx.ground_ring(at, 1.0, Color.WHITE)
			fx.slash(at, Vector3.FORWARD, Color.WHITE)
			fx.beam(at, at + Vector3(2, 1, 0), Color.WHITE)
			fx.death(at, Color.WHITE)
			game.spawn_popup(at + Vector3(i, 0, 0), "-%d" % i, Color.WHITE)
			game.spawn_flash(at, Color.WHITE)
			game.spawn_pillar(at, Color.WHITE)
			fx.thorns(at, 1.5, Color.GREEN, 8)
			fx.dome(u, 1.2, Color.WHITE)
			fx.swirl(u, Color.WHITE)
			fx.afterimage(u.model, Color.WHITE)
		await create_timer(2.5).timeout   # (the longest, the death wisp, goes after 1.6 s)
		await process_frame
		if round == 1:
			check(fx.pool_made == made, "%d effect nodes built on the second round" % (fx.pool_made - made))
	# Back to an earlier class: the parked look is put on again, not rebuilt.
	var reuses: int = CharacterModel.look_reuses
	CharacterModel.build_log.clear()
	for role in [Stats.Role.KNIGHT, Stats.Role.RANGER]:
		for v in game.units:
			if is_instance_valid(v) and not v.dead:
				v.set_role(role)
		await process_frame
	print("spawn warm: look reuses %d" % (CharacterModel.look_reuses - reuses))
	check(CharacterModel.look_reuses - reuses >= CharacterModel.build_log.size() / 2, "parked looks not reused (%d of %d)" % [CharacterModel.look_reuses - reuses, CharacterModel.build_log.size()])
	print("spawn warm test: %d failure(s)" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
