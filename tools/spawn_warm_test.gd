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
	print("spawn warm test: %d failure(s)" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
