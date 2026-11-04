extends SceneTree
## Pure-logic checks of scripts/player_movement.gd (no scene, no input map, no
## renderer): camera-relative directions, click goals, hold to keep moving,
## force-hold and force-move, and the sidestep around an obstacle.
##     godot --headless --path . --script tools/player_movement_test.gd
## claude-faisal3 2026-11-04.

const PM = preload("res://scripts/player_movement.gd")
const SPEED := 6.0
const DT := 1.0 / 60.0

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frame(pos: Vector3, extra: Dictionary = {}) -> Dictionary:
	var f := {"position": pos, "keys": Vector2.ZERO, "basis": Basis.IDENTITY, "mouse": true,
		"keyboard": false, "primary": false, "primary_tap": false, "hold": false, "force": false,
		"force_pulse": false, "ground": Vector3.INF, "choice": {}, "attack": false,
		"attack_tap": false, "interact": false, "interact_tap": false, "speed": SPEED, "delta": DT}
	f.merge(extra, true)
	return f


## Walks a click goal to completion against a blocker (Callable(from, to) -> to)
## and returns {pos, seconds, done}.
func walk(pm, start: Vector3, goal: Vector3, block: Callable, max_s: float = 6.0) -> Dictionary:
	var pos := start
	var t := 0.0
	var first := true
	while t < max_s:
		var f := frame(pos, {"primary": first, "primary_tap": first, "ground": goal})
		first = false
		var r: Dictionary = pm.resolve(f)
		if pm.target == Vector3.INF and not first and t > 0.0:
			return {"pos": pos, "seconds": t, "done": true}
		var step := Vector3(r.move.x, 0, r.move.y) * SPEED * DT
		pos = block.call(pos, pos + step)
		t += DT
	return {"pos": pos, "seconds": t, "done": false}


func _init() -> void:
	# Camera-relative keys: up on the stick is up the screen, whatever the yaw.
	check(PM.camera_motion(Vector2(0, -1), Basis.IDENTITY).distance_to(Vector2(0, -1)) < 0.001, "unrotated camera: up walks -Z, the screen's up")
	check(PM.camera_motion(Vector2(1, 0), Basis.IDENTITY).distance_to(Vector2(1, 0)) < 0.001, "unrotated camera: right walks +X")
	for yaw in [30.0, 90.0, 180.0, -135.0]:
		var basis := Basis(Vector3.UP, deg_to_rad(yaw))
		var up := PM.camera_motion(Vector2(0, -1), basis)
		var fwd := -basis.z
		check(up.distance_to(Vector2(fwd.x, fwd.z)) < 0.001, "camera yaw %d: up follows the camera forward" % int(yaw))
		var right := PM.camera_motion(Vector2(1, 0), basis)
		check(right.distance_to(Vector2(basis.x.x, basis.x.z)) < 0.001, "camera yaw %d: right follows the camera right" % int(yaw))
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(-55.0))   # the game's high isometric camera
	check(PM.camera_motion(Vector2(0, -1), tilted).distance_to(Vector2(0, -1)) < 0.001, "a pitched camera still walks the ground plane")
	check(absf(PM.camera_motion(Vector2(0, -0.5), Basis.IDENTITY).length() - 0.5) < 0.001, "a half-pushed stick walks at half speed")
	check(absf(PM.camera_motion(Vector2(1, 1), Basis.IDENTITY).length() - 1.0) < 0.001, "a diagonal is not faster than a straight line")
	check(PM.camera_motion(Vector2(NAN, 0), Basis.IDENTITY) == Vector2.ZERO, "a broken stick value walks nowhere")

	# A click walks to the point and stops.
	var open := func(_from: Vector3, to: Vector3) -> Vector3: return to
	var pm := PM.new()
	var r: Dictionary = walk(pm, Vector3.ZERO, Vector3(6, 0, 3), open)
	check(r.done and Vector2(r.pos.x - 6, r.pos.z - 3).length() < 0.3, "a click walks to the point and the goal ends (%.2f m off, %.2f s)" % [Vector2(r.pos.x - 6, r.pos.z - 3).length(), r.seconds])

	# Holding the button keeps retargeting to the cursor.
	pm = PM.new()
	var pos := Vector3.ZERO
	pm.resolve(frame(pos, {"primary": true, "primary_tap": true, "ground": Vector3(5, 0, 0)}))
	var out: Dictionary = pm.resolve(frame(pos, {"primary": true, "ground": Vector3(-5, 0, 0)}))
	check(out.move.x < -0.9, "holding the button, the goal follows the cursor to the other side")
	out = pm.resolve(frame(pos, {"primary": false, "ground": Vector3(5, 0, 0)}))
	check(out.move.x < -0.9, "releasing the button keeps the last goal")

	# Keys cancel a goal.
	pm = PM.new()
	pm.resolve(frame(pos, {"primary": true, "primary_tap": true, "ground": Vector3(5, 0, 0)}))
	out = pm.resolve(frame(pos, {"keyboard": true, "keys": Vector2(0, -1)}))
	check(pm.target == Vector3.INF and out.move.distance_to(Vector2(0, -1)) < 0.001, "a direction key cancels the click goal and drives instead")

	# Force hold: stand still and attack; never starts a walk.
	pm = PM.new()
	out = pm.resolve(frame(pos, {"hold": true, "primary": true, "primary_tap": true, "ground": Vector3(5, 0, 0)}))
	check(out.move == Vector2.ZERO and out.attack and out.attack_tap and pm.target == Vector3.INF, "Shift + click attacks in place and sets no goal")
	out = pm.resolve(frame(pos, {"hold": true, "primary": true, "interact": true, "interact_tap": true}))
	check(not out.interact and not out.interact_tap, "Shift + click never interacts")

	# Force move: walks to the cursor and suppresses attack and interaction.
	pm = PM.new()
	out = pm.resolve(frame(pos, {"force": true, "attack": true, "attack_tap": true, "interact": true, "ground": Vector3(5, 0, 0)}))
	check(out.force_move and not out.attack and not out.attack_tap and not out.interact and out.move.x > 0.9, "force move walks to the cursor with attack and interact suppressed")
	out = pm.resolve(frame(pos, {"force_pulse": true, "ground": Vector3(0, 0, 5)}))
	check(out.force_move and out.move.y > 0.9, "a wheel tick (force pulse) force-moves")

	# An obstacle dead ahead: sidestep along it and carry on.
	var pillar := func(from: Vector3, to: Vector3) -> Vector3:
		# a 1 m box at x 3..4, |z| < 0.5 that stops motion into it but lets the body slide
		var p := to
		if p.x > 3.0 and p.x < 4.5 and absf(p.z) < 0.5:
			p.x = from.x
		return p
	pm = PM.new()
	r = walk(pm, Vector3.ZERO, Vector3(8, 0, 0), pillar, 8.0)
	check(r.done and r.pos.distance_to(Vector3(8, 0, 0)) < 0.5, "a goal dead behind a pillar is reached by sidestepping (%.2f m off, %.2f s)" % [r.pos.distance_to(Vector3(8, 0, 0)), r.seconds])

	# Sidestepping early does not cut a long walk short.
	pm = PM.new()
	r = walk(pm, Vector3.ZERO, Vector3(40, 0, 0), pillar, 12.0)
	check(r.done and r.pos.distance_to(Vector3(40, 0, 0)) < 0.5, "a long walk that sidestepped a pillar early still arrives (%.2f m off, %.2f s)" % [r.pos.distance_to(Vector3(40, 0, 0)), r.seconds])

	# A real wall: sidestepping gives up and the goal is dropped, never walking through.
	var wall := func(from: Vector3, to: Vector3) -> Vector3:
		var p := to
		if p.x > 3.0:
			p.x = from.x
		return p
	pm = PM.new()
	r = walk(pm, Vector3.ZERO, Vector3(8, 0, 0), wall, 8.0)
	check(r.done and r.pos.x <= 3.01, "a goal behind an endless wall is dropped, not walked through (stopped at x=%.2f after %.2f s)" % [r.pos.x, r.seconds])
	check(r.seconds < 4.0, "and it is dropped within four seconds (%.2f s)" % r.seconds)

	# A new click resets the detours.
	pm = PM.new()
	pm.detours = 2
	pm.resolve(frame(Vector3.ZERO, {"primary": true, "primary_tap": true, "ground": Vector3(5, 0, 0)}))
	check(pm.detours == 0, "a fresh click gets fresh sidesteps")

	print("player movement test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
