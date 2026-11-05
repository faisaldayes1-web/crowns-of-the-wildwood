extends SceneTree
## Stonekeep's frozen tarns are slippery (claude-faisal/crowns-visual2
## 2026-11-04): on ice a unit that stops walking keeps sliding, and a shove
## carries further; off ice it stops at once. Run headless:
##     tools/tests/isolated.sh --headless --path . --fixed-fps 60 --script tools/ice_slide_test.gd -- --demo --seed=7 --map=3

const Isolated = preload("res://tools/tests/isolated.gd")
const Unit = preload("res://scripts/unit.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func coast(game, u, at: Vector3, frames: int) -> float:
	## Puts u at `at` walking 6 m/s east, roots it (its feet stop asking for
	## anything) and returns how far it carries on over `frames` physics frames.
	u.global_position = at + Vector3(0, 0.05, 0)
	u.knockback = Vector3.ZERO
	u.slide_vel = Vector3(6, 0, 0)
	u.root_timer = 5.0
	await physics_frame
	var from: Vector3 = u.global_position
	for i in frames:
		u.root_timer = 5.0
		await physics_frame
	return Vector2(u.global_position.x - from.x, u.global_position.z - from.z).length()


func _init() -> void:
	if not Isolated.ok("tools/ice_slide_test.gd"):
		quit(2)
		return
	# The rule itself.
	var v := Unit.ice_step(Vector3.ZERO, Vector3(6, 0, 0), true, 0.1)
	check(absf(v.x - Unit.ICE_ACCEL * 0.1) < 0.001, "on ice speed should build at ICE_ACCEL (got %s)" % v)
	check(Unit.ice_step(Vector3(6, 0, 0), Vector3.ZERO, false, 0.1) == Vector3.ZERO, "off ice a unit should stop at once")
	check(Unit.ice_step(Vector3(6, 0, 0), Vector3.ZERO, true, 0.1).x > 5.0, "on ice a unit should keep sliding")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var waited := 0
	while (game.units.is_empty() or game.lmap == null) and waited < 6000:
		await process_frame
		waited += 1
	check(game.lmap != null and game.lmap.kind == "winter", "map 3 should be Stonekeep (winter lanes)")
	if game.lmap == null:
		print("ice slide test: %d failure(s)" % (failures + 1))
		quit(1)
		return
	var tarn := Vector3(-3.0, 0, 27.0)
	check(game.lmap.on_ice(tarn), "the north-south tarn centre should be ice")
	check(not game.lmap.on_ice(Vector3(-20, 0, 0)), "the lane by the gate should not be ice")
	var u = null
	for c in game.units:
		if is_instance_valid(c) and not c.dead:
			u = c
			break
	check(u != null, "no live unit")
	if u != null:
		var on := await coast(game, u, tarn, 30)
		var off := await coast(game, u, Vector3(-20, 0, 0.5), 30)
		print("ice slide: %.2f m coasting on ice, %.2f m off ice (0.5 s)" % [on, off])
		check(on > 1.5, "on ice a unit should coast well over 1.5 m in 0.5 s (got %.2f)" % on)
		check(off < 0.3, "off ice a unit should stop at once (coasted %.2f)" % off)
	print("ice slide test: %d failure(s)" % failures)
	game.queue_free()
	for i in 10:
		await process_frame
	quit(1 if failures > 0 else 0)
