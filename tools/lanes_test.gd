extends SceneTree

## Headless checks for the Stonekeep Fortress and Twilight Grove layouts
## (scripts/lanes.gd): the plaza graph is connected, every spot the game uses
## (heal orbs, blessings, lumber nooks, bot lanes, rally points, the castles'
## barricade and trap posts) is on walkable ground, the walkable ground is
## the same for both teams (point-mirrored), and a walker that follows
## route() with clamp_walk() gets from anywhere to anywhere (no dead ends, no
## corner it sticks on), door to door included. No save is touched.
##     godot --headless --path . --script tools/lanes_test.gd

const Lanes = preload("res://scripts/lanes.gd")

var fails := 0


class FakeGame:
	var CASTLE_X := 60.0
	var CASTLE_DEPTH := 11.0
	var units: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL  " + what)
		fails += 1


func walk(l, from: Vector3, to: Vector3, max_steps: int = 900) -> bool:
	## Steps 0.5 m at a time toward route()'s next point, held on the ground.
	var p := from
	for i in max_steps:
		if Vector2(p.x - to.x, p.z - to.z).length() < 1.2:
			return true
		var nxt: Vector3 = l.route(p, to)
		var d := Vector3(nxt.x - p.x, 0, nxt.z - p.z)
		if d.length() < 0.05:
			return Vector2(p.x - to.x, p.z - to.z).length() < 3.0
		p = l.clamp_walk(p + d.normalized() * minf(0.5, d.length()))
	return false


func _init() -> void:
	var game := FakeGame.new()
	for kind in ["winter", "twilight"]:
		var l = Lanes.new(game, kind)
		var name: String = "Stonekeep" if kind == "winter" else "Twilight"
		var n: int = l.ids.size()
		for i in n:
			for j in n:
				check(l.dist[i][j] < INF, "%s: %s reaches %s on the graph" % [name, l.ids[i], l.ids[j]])
		var spots := {}
		for p in l.heal_orb_spots():
			spots["heal orb %s" % p] = p
		for p in l.blessing_spots():
			spots["blessing %s" % p] = p
		var econ: Dictionary = l.econ_spots()
		for p in econ.wood + econ.ore:
			spots["lumber %s" % p] = p
			spots["lumber twin %s" % -p] = -p
		for id in l.lanes:
			spots["lane %s" % id] = l.node(id)
		for side in [-1.0, 1.0]:
			spots["rally %s" % side] = Vector3(side * 29.0, 0, 0)          # game.rally_point: 20 m outside the door
			for zs in [-1.0, 1.0]:
				spots["knight post %s %s" % [side, zs]] = Vector3(side * 40.0, 0, zs * 5.0)   # _prep_goal barricades
				spots["mage post %s %s" % [side, zs]] = Vector3(side * 42.5, 0, zs * 7.5)
				spots["trap %s %s" % [side, zs]] = Vector3(side * 42.0, 0, zs * 1.5)
		for k in spots:
			check(l.walkable(spots[k], 0.5), "%s: %s on walkable ground" % [name, k])
		# Fair: the same ground for both teams.
		var z := -35.5
		var asym := 0
		while z < 36.0:
			var x := -51.5
			while x < 52.0:
				var p := Vector3(x, 0, z)
				if l.walkable(p, 0.05) != l.walkable(-p, 0.05) and absf(l.field(p)) > 0.12:
					asym += 1
				x += 1.0
			z += 1.0
		check(asym == 0, "%s: walkable ground is point-mirrored (%d cells differ)" % [name, asym])
		# Every node to every node, and door to door, by route().
		var stuck := 0
		for i in n:
			for j in n:
				if i != j and not walk(l, l.pos[i], l.pos[j]):
					stuck += 1
					print("      stuck: %s -> %s" % [l.ids[i], l.ids[j]])
		check(stuck == 0, "%s: route() walks every node to every node (%d stuck)" % [name, stuck])
		check(walk(l, Vector3(-46, 0, 0), Vector3(46, 0, 0), 2000), "%s: door to door" % name)
		check(walk(l, Vector3(46, 0, 0), Vector3(-46, 0, 0), 2000), "%s: door to door (back)" % name)
		# Off-node starts: points scattered over the walkable ground.
		var r := RandomNumberGenerator.new()
		r.seed = 7
		var bad := 0
		var tried := 0
		while tried < 160:
			var a := Vector3(r.randf_range(-41, 41), 0, r.randf_range(-34, 34))
			var b := Vector3(r.randf_range(-41, 41), 0, r.randf_range(-34, 34))
			if not l.walkable(a, 0.6) or not l.walkable(b, 0.6):
				continue
			tried += 1
			if not walk(l, a, b, 1400):
				bad += 1
				print("      stuck: %s -> %s" % [a.snapped(Vector3.ONE * 0.1), b.snapped(Vector3.ONE * 0.1)])
		check(bad == 0, "%s: route() walks random point pairs (%d of %d stuck)" % [name, bad, tried])
		print("%s: %d nodes, %d corridors, %d terrain cells" % [name, n, l.segs.size(), l.cells.size()])
	print("lanes test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
