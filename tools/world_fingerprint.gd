extends SceneTree
## Gameplay fingerprint of a built match world, for checking that a visual
## change left gameplay alone. Run from the project root:
##     godot --headless --path . --script tools/world_fingerprint.gd -- --play --seed=7 [--map=1|2] [--debug-night]
## Prints one line per collider (shape, size, transform, layers), per
## gameplay anchor and per Ember Pass graph item, then the global RNG draw
## right after the world was built and a total hash. Two runs of the same
## source print identical output; any diff is a gameplay-relevant change.

var lines: PackedStringArray = []


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	# game._ready() builds the world and starts the match in one go, so the
	# next global draw after it shows how much of the shared RNG the build used.
	var probe := [0]
	var spawns: PackedStringArray = []
	game.ready.connect(func():
		probe[0] = randi()
		for u in game.units:
			spawns.append("ANCHOR unit spawn team%d %s %s" % [u.team, u.role_name(), _p(u.global_position)]))
	root.add_child(game)
	for i in 3:
		await process_frame
	_emit("RNG after build %d" % probe[0])
	var shapes := 0
	for n in root.find_children("*", "CollisionObject3D", true, false):
		if n in game.units:
			continue   # fighters move from the first frame: their spawn points are listed below
		var co: CollisionObject3D = n
		_emit("BODY %s %s layer=%d mask=%d" % [co.get_class(), _t(co.global_transform), co.collision_layer, co.collision_mask])
		for s in co.find_children("*", "", false, false):
			if s is CollisionShape3D:
				shapes += 1
				_emit("  SHAPE %s %s disabled=%s" % [_shape(s.shape), _t(s.global_transform), s.disabled])
			elif s is CollisionPolygon3D:
				shapes += 1
				_emit("  POLY %s depth=%.4f %s" % [s.polygon, s.depth, _t(s.global_transform)])
	_emit("ANCHOR thrones %s" % [_v(game.thrones)])
	for t in 2:
		for r in game.stations[t]:
			_emit("ANCHOR station %d %d %s" % [t, r, _p(game.stations[t][r])])
	_emit("ANCHOR upgrade_pads %s" % [_v(game.upgrade_pads)])
	_emit("ANCHOR wall_posts %s" % [str(game.wall_posts)])
	_emit("ANCHOR ramps %s" % [str(game.ramps)])
	_emit("ANCHOR cover_points %s" % [_v(game.cover_points)])
	_emit("ANCHOR cover_boxes %s" % [str(game.cover_boxes)])
	_emit("ANCHOR map_trees %s" % [_v(game.map_trees)])
	_emit("ANCHOR map_paths %s" % [str(game.map_paths)])
	_emit("ANCHOR map_marks %s" % [str(game.map_marks)])
	for o in game.heal_orbs:
		_emit("ANCHOR orb %s" % _p(o.global_position))
	for g in game.gates:
		_emit("ANCHOR gate %s hp=%s" % [_p(g.global_position), g.hp])
	for v in game.vaults:
		_emit("ANCHOR vault %s" % _p(v.global_position))
	for m in game.monarchs:
		_emit("ANCHOR monarch %s" % _p(m.global_position))
	lines.append_array(spawns)
	for t in game.turret_spots(0) + game.turret_spots(1):
		_emit("ANCHOR turret_spot %s" % str(t))
	if game.economy:
		for rn in game.economy.nodes:
			_emit("ANCHOR resource %s %s stock=%s" % [rn.get_script().resource_path.get_file(), _p(rn.global_position), rn.stock])
		_emit("ANCHOR depots %s" % [str(game.economy.depots)])
		for t in 2:
			for pad in game.economy.pads[t]:
				_emit("ANCHOR econ_pad %d %s" % [t, pad.pos])
	if game.vmap:
		var V = game.vmap
		_emit("EMBER NODES %s" % [str(V.NODES)])
		_emit("EMBER EDGES %s" % [str(V.EDGES)])
		_emit("EMBER ids %s pos %s rad %s" % [str(V.ids), str(V.pos), str(V.rad)])
		_emit("EMBER segs %s" % [str(V.segs)])
		_emit("EMBER dist %s" % [str(V.dist).sha256_text()])
		_emit("EMBER consts %s %s %s %s %s %s" % [V.LAND_X, V.LAND_X1, V.LAND_Z, V.LAVA_Y, V.FIRE_POS, V.CROSSING])
	var all := "\n".join(lines)
	print(all)
	print("FINGERPRINT colliders=%d shapes=%d lines=%d sha256=%s" % [root.find_children("*", "CollisionObject3D", true, false).size(), shapes, lines.size(), all.sha256_text()])
	quit()


func _emit(s: String) -> void:
	lines.append(s)


func _f(x: float) -> String:
	return "%.4f" % x


func _p(v: Vector3) -> String:
	return "(%s,%s,%s)" % [_f(v.x), _f(v.y), _f(v.z)]


func _v(a: Array) -> String:
	var out := []
	for v in a:
		out.append(_p(v) if v is Vector3 else str(v))
	return ",".join(out)


func _t(t: Transform3D) -> String:
	var b := t.basis
	return "o%s x%s y%s z%s" % [_p(t.origin), _p(b.x), _p(b.y), _p(b.z)]


func _shape(s: Shape3D) -> String:
	if s is BoxShape3D:
		return "Box%s" % _p(s.size)
	if s is SphereShape3D:
		return "Sphere(%s)" % _f(s.radius)
	if s is CapsuleShape3D:
		return "Capsule(%s,%s)" % [_f(s.radius), _f(s.height)]
	if s is CylinderShape3D:
		return "Cylinder(%s,%s)" % [_f(s.radius), _f(s.height)]
	if s is ConvexPolygonShape3D:
		return "Convex(%d,%s)" % [s.points.size(), str(s.points).sha256_text().substr(0, 16)]
	if s is ConcavePolygonShape3D:
		return "Concave(%d,%s)" % [s.get_faces().size(), str(s.get_faces()).sha256_text().substr(0, 16)]
	if s is WorldBoundaryShape3D:
		return "Plane%s" % str(s.plane)
	if s is HeightMapShape3D:
		return "Height(%d,%d,%s)" % [s.map_width, s.map_depth, str(s.map_data).sha256_text().substr(0, 16)]
	return s.get_class() if s else "null"
