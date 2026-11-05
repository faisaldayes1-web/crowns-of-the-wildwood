extends SceneTree
## CI gate (claude-faisal/crowns-gates 2026-11-04): one map, one couch mode,
## one player count. Builds the match the way --play does (bots fill every
## seat the local players leave), then checks:
##   * the match: 2 x team_size units, couch_players local seats, one split
##     pane each when 2-4 players share the screen;
##   * spawns: no unit starts inside a wall, house or fence (a physics query
##     at its chest), nor off the map;
##   * objectives: thrones, crowns, heal orbs, blessings, wood and ore nodes,
##     storehouses and turret pads stand on the map; orbs, blessings and pads
##     stay clear of solid walls; no two objectives stand on top of each other;
##   * a short bot fight (--frames=N, default 900 at 60 fps): no unit falls
##     through the ground or leaves the map, and the bots actually move.
## Script errors are caught by the CI step's grep. Run from the project root:
##   tools/tests/isolated.sh --headless --path . --fixed-fps 60 --script tools/gates/world_gate.gd -- --play --seed=7 --map=2 --couch=3 --couch-mode=coop --no-prep

const Isolated = preload("res://tools/tests/isolated.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _init() -> void:
	if not Isolated.ok("tools/gates/world_gate.gd"):
		quit(2)
		return
	var frames := int(_arg("--frames=", "900"))
	var couch := int(_arg("--couch=", "1"))
	var label := "%s map=%s couch=%d mode=%s" % [_arg("--mode=", "crowns"), _arg("--map=", "0"), couch, _arg("--couch-mode=", "versus")]
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var waited := 0
	while (game.units.is_empty() or not game.playing) and waited < 3000:
		await process_frame
		waited += 1
	check(not game.units.is_empty() and game.playing, "%s: the match never started" % label)
	if game.units.is_empty():
		_finish(game, label)
		return
	await physics_frame
	await physics_frame
	# --- the match itself
	check(game.units.size() == 2 * game.team_size, "%s: %d units, expected %d" % [label, game.units.size(), 2 * game.team_size])
	check(game.couch_players == couch, "%s: couch_players %d, expected %d" % [label, game.couch_players, couch])
	var seated := 0
	for u in game.locals:
		if u != null and is_instance_valid(u):
			seated += 1
	check(seated == couch, "%s: %d local seats filled, expected %d" % [label, seated, couch])
	if couch > 1:
		var panes: int = game.panes.size()   # (3 players also get a dark filler plate, not a pane)
		check(game.couch_active and panes == couch, "%s: split screen has %d panes, expected %d" % [label, panes, couch])
	var half: Vector2 = game.map_half
	# --- spawns: nobody starts inside something solid
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	var excl: Array[RID] = []
	for u in game.units:
		if u is CollisionObject3D:
			excl.append(u.get_rid())
	var start := {}
	for u in game.units:
		var p: Vector3 = u.global_position
		start[u] = p
		check(absf(p.x) <= half.x + 2.0 and absf(p.z) <= half.y + 2.0, "%s: %s spawns off the map at %s" % [label, u.display_name, p.snapped(Vector3.ONE * 0.1)])
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
		q.exclude = excl
		q.collide_with_areas = false
		var what := []
		for h in space.intersect_shape(q, 4):
			if h.collider is StaticBody3D:
				what.append(str(h.collider.name))
		check(what.is_empty(), "%s: CLIP spawn %s starts inside %s at %s" % [label, u.display_name, ", ".join(what), p.snapped(Vector3.ONE * 0.1)])
	# --- objectives
	var objs: Array = []   # [name, position, clearance radius (0: not checked against walls)]
	for i in game.thrones.size():
		objs.append(["throne%d" % i, game.thrones[i], 0.0])
	for m in game.monarchs:
		if is_instance_valid(m):
			objs.append(["crown%d" % m.team if "team" in m else "crown", m.global_position, 0.0])
	for o in game.heal_orbs:
		if is_instance_valid(o):
			objs.append(["heal_orb", o.global_position, 0.6])
	for b in game.blessings:
		if is_instance_valid(b):
			objs.append(["blessing", b.global_position, 0.6])
	if game.economy != null:
		for n in game.economy.nodes:
			if is_instance_valid(n):
				objs.append(["%s_node" % n.kind, n.global_position, 0.0])
		for t in 2:
			if game.economy.depots[t].is_finite():
				objs.append(["depot%d" % t, game.economy.depots[t], 0.0])
			for pad in game.economy.pads[t]:
				objs.append(["pad%d" % t, pad.pos, 0.6])
	check(objs.size() > 10, "%s: only %d objectives found" % [label, objs.size()])
	for o in objs:
		var p: Vector3 = o[1]
		check(absf(p.x) <= half.x and absf(p.z) <= half.y, "%s: %s off the map at %s" % [label, o[0], p.snapped(Vector3.ONE * 0.1)])
		if o[2] <= 0.0:
			continue
		var box := AABB(p + Vector3(-o[2], 0.25, -o[2]), Vector3(o[2] * 2.0, 1.2, o[2] * 2.0))
		for blk in game.audit_blocks:
			if blk[0] in ["ramp", "vault", "gate", "bridge", "hearth", "railing"]:
				continue
			var bb: AABB = blk[1]
			if bb.end.y <= 0.3 or bb.size.y < 0.3:
				continue   # floors and the ground
			var pen: float = game._penetration(box, bb)
			check(pen <= 0.15, "%s: CLIP objective %s inside %s by %.2f at %s" % [label, o[0], blk[0], pen, p.snapped(Vector3.ONE * 0.1)])
	for i in objs.size():
		for j in range(i + 1, objs.size()):
			var ni: String = objs[i][0]
			var nj: String = objs[j][0]
			if (ni.begins_with("throne") and nj.begins_with("crown")) or (nj.begins_with("throne") and ni.begins_with("crown")):
				continue   # the crown sits on its throne
			var a: Vector3 = objs[i][1]
			var b: Vector3 = objs[j][1]
			var d := Vector2(a.x - b.x, a.z - b.z).length()
			check(d >= 1.0 or absf(a.y - b.y) > 2.0, "%s: CLIP objective %s and %s %.2f m apart at %s" % [label, ni, nj, d, a.snapped(Vector3.ONE * 0.1)])
	# --- a short bot fight
	for i in frames:
		await process_frame
	var moved := 0
	for u in game.units:
		if not is_instance_valid(u):
			continue
		var p: Vector3 = u.global_position
		check(p.y > -3.0, "%s: %s fell through the ground (y %.1f at %s)" % [label, u.display_name, p.y, p.snapped(Vector3.ONE * 0.1)])
		check(absf(p.x) <= half.x + 4.0 and absf(p.z) <= half.y + 4.0, "%s: %s left the map at %s" % [label, u.display_name, p.snapped(Vector3.ONE * 0.1)])
		if u in game.locals:
			continue   # local players stand idle
		if start.has(u) and Vector2(p.x - start[u].x, p.z - start[u].z).length() > 3.0:
			moved += 1
	var bots: int = 2 * game.team_size - couch
	check(moved * 2 >= bots, "%s: only %d of %d bots moved more than 3 m" % [label, moved, bots])
	print("world gate %s: %d units, %d objectives, %d of %d bots moved, %d frames" % [label, game.units.size(), objs.size(), moved, bots, frames])
	_finish(game, label)


func _finish(game, label: String) -> void:
	print("world gate %s: %d failure(s)" % [label, failures])
	game.queue_free()
	for i in 10:
		await process_frame
	quit(1 if failures > 0 else 0)
