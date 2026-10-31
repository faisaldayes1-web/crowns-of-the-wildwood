extends RefCounted
## Forest kit (claude-faisal/crowns-foliage, 2026-10-31; Faisal's 10-31 order,
## picks Battle A / Spawn D): the match world's trees and the dressing on the
## ground outside the walls, rebuilt as many small, distinct stylised trees.
##
##   - Round-crowned broadleaf trees (a dome of leaf lobes over a visible
##     trunk, pick A) and layered conifers (pick D), in varied sizes and
##     greens, grouped into a dense canopy. They replace the few huge,
##     trunkless blob crowns game.gd used to grow.
##   - Ground dressing: grey boulders, flower clumps, low bushes, wooden
##     fences, dirt trails and soft patches of lighter and darker grass.
##   - A variant per map: Wildwood and Moonlit (broadleaf and pine, a pink
##     blossom tree now and then on the Elf side, autumn gold on the Human
##     side), Stonekeep (snow-laden pines), Twilight (teal and violet crowns
##     with glowing blooms). Ember Pass builds its own world (volcano.gd).
##
## Gameplay is untouched: game.gd still makes every tree's collider, map_trees
## entry and placement checks exactly as before and only hands the LOOK to
## this kit (tree_at). The extra trees, the fill forest and the dressing are
## decoration with no colliders. Fill trees grow only outside the playable
## field (|x| > map_half.x or |z| > map_half.y) and never inside the castles
## or the spawn yards; inside the field a tree spot gets at most a couple of
## close, lower companions inside the old crown's footprint, so the canopy
## is lower than the blobs were and sight lines only open up.
##
## Rendering: every kit mesh shares one material (forest_kit.gdshader, colours
## baked into vertex colours) and is drawn as MultiMeshes, one per mesh per
## CHUNK x CHUNK metre cell, so each cell culls on its own. The Low preset
## gets a lighter fill and fewer flowers and patches.
## "--no-forest-kit" turns the kit off (the old trees come back) for A/B.

const StyleProfile = preload("res://scripts/visual/style_profile.gd")
const CHUNK := 32.0
const GRID := 4.0   # spatial hash cell for trunk spacing checks
const NEEDLE := 5.0  # UV.x of pine tiers: sway like leaves, flat needle shading (forest_kit.gdshader)

var game
var trees := []       # [pos: Vector3, big: bool, hint: String, max_h: float, seed: int]
var bushes := []      # [pos: Vector3, seed: int]
var _occ := {}        # Vector2i -> Array of Vector3(x, radius, z): trunks and fences already placed
var _blocks := {}     # Vector2i (8 m) -> Array of AABB (built things, from game.audit_blocks)
var _props := {}      # Vector2i (8 m) -> Array of Vector3 (props, from game.audit_props)
var _trails := []     # [from, to, width] dirt trails (decor), kept clear like paths
var _place := {}      # mesh key -> Array of [Transform3D, Color]
var _meshes := {}     # mesh key -> ArrayMesh
var mat: ShaderMaterial
var ground_mat: ShaderMaterial
var palette := "day"  # day, night, winter, twilight
var low := false
static var _unit := []


static func enabled(g) -> bool:
	## The match world only (not the menus' diorama), and not Ember Pass,
	## which dresses its own basalt plateaus (volcano.gd).
	return g.world_style and g.vmap == null and not "--no-forest-kit" in OS.get_cmdline_user_args()


func _init(g) -> void:
	game = g


# --- Hooks from game.gd (registration only; meshes are made in finish()) -----

func tree_at(pos: Vector3, big: bool, hint: String = "", max_h: float = 0.0) -> void:
	## A tree spot game.gd has already checked and given a collider.
	## hint: "" picks by side, "pine", "broad", "canopy" (a courtyard tree),
	## "autumn" (the Kingdom's orange or gold pines: 0/1 in seed parity).
	trees.append([pos, big, hint, max_h, absi(int(pos.x * 13 + pos.z * 7))])
	_mark(pos, 0.9)


func bush_at(pos: Vector3, seed: int) -> void:
	bushes.append([pos, seed])


# --- Spatial checks ------------------------------------------------------------

func _key(p: Vector3, cell: float) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.z / cell))


func _mark(p: Vector3, r: float) -> void:
	var k := _key(p, GRID)
	if not _occ.has(k):
		_occ[k] = []
	_occ[k].append(Vector3(p.x, r, p.z))


func _crowded(p: Vector3, r: float) -> bool:
	var k := _key(p, GRID)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for o in _occ.get(k + Vector2i(dx, dz), []):
				if Vector2(o.x - p.x, o.z - p.z).length() < r + o.y:
					return true
	return false


func _index_world() -> void:
	for blk in game.audit_blocks:
		var box: AABB = blk[1]
		if box.size.y < 0.3 or box.end.y < 0.3:
			continue   # floors, decals, the ground slabs
		var a := _key(box.position, 8.0)
		var b := _key(box.end, 8.0)
		for x in range(a.x, b.x + 1):
			for z in range(a.y, b.y + 1):
				var k := Vector2i(x, z)
				if not _blocks.has(k):
					_blocks[k] = []
				_blocks[k].append(box)
	for ap in game.audit_props:
		if not is_instance_valid(ap[1]) or not ap[1] is Node3D:
			continue
		var q: Vector3 = ap[1].global_position if ap[1].is_inside_tree() else ap[1].position
		var k := _key(q, 8.0)
		if not _props.has(k):
			_props[k] = []
		_props[k].append(q)


func _near_built(p: Vector3, m: float) -> bool:
	var k := _key(p, 8.0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var kk := k + Vector2i(dx, dz)
			for box in _blocks.get(kk, []):
				if p.x > box.position.x - m and p.x < box.end.x + m and p.z > box.position.z - m and p.z < box.end.z + m:
					return true
			for q in _props.get(kk, []):
				if Vector2(q.x - p.x, q.z - p.z).length() < m + 0.9:
					return true
	return false


func _near_trail(p: Vector3, m: float) -> bool:
	for t in _trails:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var s := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if Vector2(p.x, p.z).distance_to(Vector2(a.x, a.z) + ab * s) < t[2] / 2.0 + m:
			return true
	return false


func _in_field(p: Vector3) -> bool:
	return absf(p.x) < game.map_half.x and absf(p.z) < game.map_half.y


func _in_castle(p: Vector3, m: float) -> bool:
	## The walled castles and the spawn yards behind them (with margin m).
	var ax := absf(p.x)
	var az := absf(p.z)
	var c0: float = game.CASTLE_X - game.CASTLE_DEPTH - m
	var c1: float = game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH + 0.5 + m
	if ax > c0 and ax < game.CASTLE_X + game.CASTLE_DEPTH + m and az < game.CASTLE_HALF_Z + m:
		return true
	return ax > c0 and ax < c1 and az < game.CELLAR_HALF_Z + 1.0 + m


func _clear(p: Vector3, m: float) -> bool:
	## Open ground for decoration: off the river, roads, paths and trails, out
	## of buildings, castles and yards, and on the ground slab.
	if absf(p.x) < game.RIVER_HALF + 1.5 + m or Vector2(p.x, p.z).length() < game.ISLAND_R + 1.5 + m:
		return false
	if absf(p.x) > game.map_half.x + 38.0 or absf(p.z) > game.map_half.y + 28.0:
		return false
	if absf(p.x) > 108.0 and absf(p.z) < 34.0:
		return false   # the mountains
	if _in_castle(p, m) or game._near_path(p, m) or _near_trail(p, m) or _near_built(p, m):
		return false
	for mark in game.map_marks:
		if Vector2(p.x - mark[0].x, p.z - mark[0].z).length() < 4.0 + m:
			return false
	for c in game.cover_points:
		if Vector2(p.x - c.x, p.z - c.z).length() < 1.6 + m:
			return false
	return true


# --- Finish: fill, dressing, meshes -------------------------------------------

func finish() -> void:
	## Called once the whole land is built (after the season grade, which
	## must not touch the kit's own colours).
	var t0 := Time.get_ticks_msec()
	_ensure()
	_index_world()
	var r := RandomNumberGenerator.new()
	r.seed = 31031
	_trail_layout(r)
	_fences(r)
	for t in trees:
		_tree_cluster(t, r)
	_fill_forest(r)
	for b in bushes:
		_bush(b[0], b[1], r, 1.0)
	_dressing(r)
	_build()
	if OS.is_debug_build() or "--forest-kit-log" in OS.get_cmdline_user_args():
		var n := 0
		for k in _place:
			n += _place[k].size()
		print("FOREST KIT %s%s: %d placements, %d meshes, %d ms" % [palette, " low" if low else "", n, _meshes.size(), Time.get_ticks_msec() - t0])


func _add(key: String, xf: Transform3D, tint: Color = Color.WHITE) -> void:
	if not _place.has(key):
		_place[key] = []
	_place[key].append([xf, tint])


func _species(pos: Vector3, hint: String, seed: int) -> String:
	if palette == "winter":
		return "pine"
	if hint in ["pine", "broad", "autumn"]:
		return hint
	if hint == "canopy":
		return "broad"
	if pos.x < -8.0:
		return "pine" if seed % 4 == 1 else "broad"   # the Wildwood: mostly broadleaf
	if pos.x > 8.0:
		return "pine" if seed % 3 != 0 else "broad"   # the Kingdom's woods: mostly pine
	return "broad"


func _tree_key(species: String, pos: Vector3, seed: int) -> String:
	## Which mesh: species, palette accent and shape.
	match species:
		"pine":
			return "pine%d" % (seed % 3)
		"autumn":
			return "autumn%d" % (seed % 2)
		_:
			if palette in ["day", "night"] and pos.x < -8.0 and seed % 20 == 0 and not _in_castle(pos, 10.0):   # (none in the spawn camera's view)
				return "blossom"
			if palette in ["day", "night"] and pos.x > 8.0 and seed % 9 == 4:
				return "autumnbroad"
			return "broad%d" % (seed % 3)


func _tree(pos: Vector3, species: String, seed: int, scale: float, r: RandomNumberGenerator) -> void:
	var key := _tree_key(species, pos, seed)
	var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(scale * r.randf_range(0.92, 1.08), scale, scale * r.randf_range(0.92, 1.08)))
	# Green varies tree to tree: a little lighter or darker, warmer or cooler.
	var v := r.randf_range(0.86, 1.1)
	var tint := Color(v * r.randf_range(0.95, 1.05), v, v * r.randf_range(0.9, 1.04))
	_add(key, Transform3D(b, pos), tint)


func _tree_cluster(t: Array, r: RandomNumberGenerator) -> void:
	var pos: Vector3 = t[0]
	var big: bool = t[1]
	var hint: String = t[2]
	var max_h: float = t[3]
	var seed: int = t[4]
	var species := _species(pos, hint, seed)
	# Kit trees are ~4.6 m (broadleaf) and ~6 m (pine) at scale 1.
	var base_h := 6.0 if species in ["pine", "autumn"] else 4.6
	var s := (1.12 if big else 0.95) * r.randf_range(0.9, 1.08)
	if max_h > 0.0:
		s = minf(s, max_h / base_h)
	_tree(pos, species, seed, s, r)
	# Companions: lower trees round the spot. In the field they stay close
	# (inside the old crown's footprint, where nobody walked under a trunk
	# before either); outside it they spread into a grove.
	var field := _in_field(pos) or pos.y < -0.5
	var n := (1 if r.randf() < 0.6 else 2) if field else r.randi_range(2, 4)
	if hint == "canopy" or pos.y < -0.5 or _in_castle(pos, 1.0):
		n = 0 if pos.y < -0.5 else 1
	for i in n:
		var a := r.randf() * TAU
		var d := r.randf_range(1.05, 1.35) if field else r.randf_range(1.7, 2.7)
		var q := pos + Vector3(cos(a), 0, sin(a)) * d
		if _crowded(q, 0.7) or not _clear(q, 0.9):
			continue
		_mark(q, 0.7)
		var sp := species
		if species != "autumn" and palette != "winter" and r.randf() < 0.3:
			sp = "pine" if species == "broad" else "broad"
		_tree(q, sp, seed + 17 * (i + 1), s * r.randf_range(0.62, 0.86), r)
	# A low bush or two at the foot of grove trees.
	if not field and r.randf() < 0.5:
		var a := r.randf() * TAU
		_bush(pos + Vector3(cos(a), 0, sin(a)) * r.randf_range(1.4, 2.2), seed, r, 0.8)


func _fill_forest(r: RandomNumberGenerator) -> void:
	## A dense canopy outside the playable field: the out-of-bounds woods
	## behind the castles and along the north and south edges, on a jittered
	## grid, around the hamlets, farms and trails.
	var step := 2.7 if not low else 3.8
	var hx: float = game.map_half.x
	var hz: float = game.map_half.y
	var x := -118.0
	while x <= 118.0:
		var z := -54.0
		while z <= 54.0:
			var p := Vector3(x + r.randf_range(-1.1, 1.1), 0, z + r.randf_range(-1.1, 1.1))
			z += step
			if absf(p.x) < hx + 0.5 and absf(p.z) < hz + 0.5:
				continue   # the field: only game.gd's own trees there
			if r.randf() < 0.08:
				continue   # small clearings
			if _crowded(p, 1.25) or not _clear(p, 1.4):
				continue
			var seed := absi(int(p.x * 13 + p.z * 7)) + 5
			# Near the spawn yards the trees stay low so they never hide the yard.
			var near_yard := _in_castle(p, 7.0)
			var species := _species(p, "", seed)
			var s := r.randf_range(0.7, 1.12) if not near_yard else r.randf_range(0.6, 0.75)
			_mark(p, 1.1)
			_tree(p, species, seed, s, r)
		x += step


func _bush(pos: Vector3, seed: int, r: RandomNumberGenerator, s: float) -> void:
	if _crowded(pos, 0.5) or not _clear(pos, 0.4):
		return
	var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s * r.randf_range(0.8, 1.2))
	var v := r.randf_range(0.88, 1.08)
	_add("bush%d" % (seed % 2), Transform3D(b, pos), Color(v, v, v))


func _trail_layout(r: RandomNumberGenerator) -> void:
	## Dirt trails through the out-of-bounds woods: from behind each spawn
	## yard out to the map's end, beside the yards, and along the north and
	## south woods.
	var back: float = game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH + 1.5
	for sx in [-1.0, 1.0]:
		_trail([Vector3(sx * (back + 1.0), 0, 0.0), Vector3(sx * (back + 7.0), 0, 2.5), Vector3(sx * (back + 13.0), 0, 0.5), Vector3(sx * (back + 19.0), 0, 4.0)], 2.4)
		for zs in [-1.0, 1.0]:
			_trail([Vector3(sx * (back - 2.0), 0, zs * 15.5), Vector3(sx * (back + 5.0), 0, zs * 18.0), Vector3(sx * (back + 12.0), 0, zs * 17.0), Vector3(sx * (back + 20.0), 0, zs * 20.0)], 2.2)
	for zs in [-1.0, 1.0]:
		var pts := []
		var x := -76.0
		while x <= 76.0:
			pts.append(Vector3(x, 0, zs * (game.map_half.y + 8.0 + sin(x * 0.07 + zs) * 2.5)))
			x += 9.5
		_trail(pts, 2.0)


func _trail(pts: Array, w: float) -> void:
	## Walk the polyline every 1.5 m and keep the runs over open ground (off
	## buildings, castles and the river, and clear of the trees already
	## placed), as trail segments.
	var run := []
	var samples := []
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := maxi(int(a.distance_to(b) / 1.5), 1)
		for k in n:
			samples.append(a.lerp(b, float(k) / n))
	samples.append(pts[pts.size() - 1])
	for i in samples.size():
		var p: Vector3 = samples[i]
		var ok: bool = not _in_castle(p, 1.0) and not _near_built(p, 1.2) and absf(p.x) > game.RIVER_HALF + 4.0 and not game._near_path(p, 0.5) and not _crowded(p, w * 0.5 + 0.3) and absf(p.x) < 108.0
		if ok:
			run.append(p)
		if (not ok or i == samples.size() - 1) and run.size() > 2:
			for k in run.size() - 1:
				_trails.append([run[k], run[k + 1], w])
		if not ok:
			run = []


func _fences(r: RandomNumberGenerator) -> void:
	## Short runs of rail fence on the open ground outside the walls (pick D):
	## along the trails behind the yards and the forest edges. A post only
	## stands on clear ground; rails join neighbouring posts.
	var runs := []
	var back: float = game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH + 1.5
	for sx in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			runs.append([Vector3(sx * (back + 1.5), 0, zs * 13.4), Vector3(sx * (back + 11.0), 0, zs * 13.6)])
			runs.append([Vector3(sx * (back + 3.0), 0, zs * 21.5), Vector3(sx * (back + 13.0), 0, zs * 22.5)])
			runs.append([Vector3(sx * 30.0, 0, zs * (game.map_half.y + 4.6)), Vector3(sx * 44.0, 0, zs * (game.map_half.y + 5.2))])
	for run in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var n := int(a.distance_to(b) / 2.4)
		var dir := (b - a).normalized()
		var prev_ok := false
		for i in n + 1:
			var p := a + dir * 2.4 * i
			var ok: bool = _clear(p, 0.3) and not _crowded(p, 0.4)
			if ok and prev_ok:
				# A segment from the previous post to this one.
				var mid := p - dir * 1.2
				var yaw := atan2(-dir.z, dir.x)
				_add("fence", Transform3D(Basis(Vector3.UP, yaw), mid))
				_mark(mid, 1.4)
			prev_ok = ok


func _dressing(r: RandomNumberGenerator) -> void:
	## Boulders, flower clumps, bushes and grass tone patches.
	var fl := 0.5 if low else 1.0
	# Boulders: big ones out of bounds, knee-high ones in the field.
	for i in int(170 * fl):
		var p := Vector3(r.randf_range(-116, 116), 0, r.randf_range(-62, 62))
		var field := _in_field(p)
		if field and (not game._open_ground(p) or r.randf() < 0.5):
			continue
		if _crowded(p, 1.0) or not _clear(p, 1.0):
			continue
		var s := r.randf_range(0.35, 0.55) if field else r.randf_range(0.6, 1.4)
		_mark(p, s * 0.8)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s * r.randf_range(0.9, 1.3), s * r.randf_range(0.7, 1.0), s))
		_add("rock%d" % (i % 2), Transform3D(b, p + Vector3(0, -0.08 * s, 0)))
		# Pebbles and a flower clump or bush at its foot.
		for k in r.randi_range(1, 3):
			var a := r.randf() * TAU
			var q := p + Vector3(cos(a), 0, sin(a)) * s * r.randf_range(1.1, 1.6)
			if _clear(q, 0.2):
				var ps := s * r.randf_range(0.25, 0.4)
				_add("rock%d" % ((i + k) % 2), Transform3D(Basis(Vector3.UP, a).scaled(Vector3(ps, ps * 0.7, ps)), q))
		if r.randf() < 0.6:
			var a := r.randf() * TAU
			_bush(p + Vector3(cos(a), 0, sin(a)) * (s + 0.7), i, r, 0.7)
	# Flower clumps: out of bounds anywhere open, in the field on open lawn.
	var flowers := 0
	var tries := 0
	var want := int((520 if palette != "winter" else 90) * fl)
	while flowers < want and tries < want * 6:
		tries += 1
		var p := Vector3(r.randf_range(-112, 112), 0, r.randf_range(-58, 58))
		if _in_field(p) and not game._open_ground(p):
			continue
		if _crowded(p, 0.35) or not _clear(p, 0.3):
			continue
		flowers += 1
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.8, 1.25))
		_add("flower%d" % (flowers % 3), Transform3D(b, p))
		if r.randf() < 0.45:   # a clump a metre away: drifts, not dots
			var a := r.randf() * TAU
			var q := p + Vector3(cos(a), 0, sin(a)) * r.randf_range(0.6, 1.1)
			if _clear(q, 0.3):
				_add("flower%d" % ((flowers + 1) % 3), Transform3D(Basis(Vector3.UP, a), q))
	# Bushes along the forest edges, out of bounds, and a few on open lawn.
	for i in int(240 * fl):
		var p := Vector3(r.randf_range(-114, 114), 0, r.randf_range(-58, 58))
		if _in_field(p) and (not game._open_ground(p) or r.randf() < 0.6):
			continue
		_bush(p, i, r, r.randf_range(0.7, 1.1) if not _in_field(p) else r.randf_range(0.55, 0.75))
	# Grass tone patches: lighter, darker and warmer lawn everywhere open
	# (the field too: they are flat and see-through).
	var patches := int(900 * (0.6 if low else 1.0))
	var tones := _patch_tones()
	for i in patches:
		var p := Vector3(r.randf_range(-116, 116), 0.012 + 0.002 * (i % 4), r.randf_range(-62, 62))
		var s := r.randf_range(2.2, 5.5)
		if not _clear(Vector3(p.x, 0, p.z), s * 0.6):
			continue
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s * r.randf_range(1.0, 1.6), 1.0, s))
		_add("patch", Transform3D(b, p), tones[r.randi() % tones.size()])
	# Worn dirt at the trails' edges and under the fence runs.
	for t in _trails:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var n := int(a.distance_to(b) / 3.0)
		for k in n:
			var p := a.lerp(b, (k + r.randf()) / maxf(n, 1)) + Vector3(r.randf_range(-1.6, 1.6), 0.016, r.randf_range(-1.6, 1.6))
			var s := r.randf_range(1.2, 2.2)
			_add("patch", Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s * 1.3, 1, s)), p), tones[0] if palette == "winter" else Color(0.42, 0.33, 0.2, 0.75))


func _patch_tones() -> Array:
	match palette:
		"winter":
			return [Color(0.86, 0.9, 0.98, 0.7), Color(0.74, 0.82, 0.92, 0.6), Color(0.95, 0.97, 1.0, 0.8)]
		"twilight":
			return [Color(0.16, 0.42, 0.4, 0.6), Color(0.28, 0.5, 0.42, 0.55), Color(0.2, 0.36, 0.44, 0.45)]
	# Warm yellow-green, deep cool green, a sunlit lime and a dry straw.
	return [Color(0.56, 0.68, 0.26, 0.6), Color(0.2, 0.42, 0.16, 0.55), Color(0.5, 0.74, 0.3, 0.55), Color(0.66, 0.62, 0.32, 0.45)]


# --- Meshes ------------------------------------------------------------------

func _ensure() -> void:
	## Palette, preset and the shared material (also asked for before
	## finish() by the economy's wood trees, kit_tree()).
	if mat != null:
		return
	palette = game.season if game.season in ["winter", "twilight"] else ("night" if game.night() else "day")
	low = game.gfx_quality <= 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gfx="):   # (game.gd reads this test flag only after the world is built)
			low = int(arg.trim_prefix("--gfx=")) <= 0
	mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/forest_kit.gdshader")
	mat.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	mat.set_shader_parameter("glow_energy", 2.2 if palette == "twilight" else (1.4 if palette == "night" else 1.0))
	mat.set_shader_parameter("self_lit", 0.35 if palette == "twilight" else 0.0)


func kit_tree(parent: Node3D, key: String, at: Vector3, s: float, yaw: float) -> MeshInstance3D:
	## One kit model as its own MeshInstance3D (for things that move or
	## change, such as the economy's wood trees that are felled and regrow).
	_ensure()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_for(key)
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * s
	parent.add_child(mi)
	return mi


func _build() -> void:
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = load("res://assets/shaders/forest_ground.gdshader")
	ground_mat.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	for key in _place:
		var mesh := _mesh_for(key)
		if mesh == null:
			continue
		var list: Array = _place[key]
		var cells := {}
		for it in list:
			var xf: Transform3D = it[0]
			var k := _key(xf.origin, CHUNK)
			if not cells.has(k):
				cells[k] = []
			cells[k].append(it)
		var ground: bool = key == "patch"
		var small: bool = ground or key.begins_with("flower") or key.begins_with("rock") or key.begins_with("bush")
		for k in cells:
			var items: Array = cells[k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = items.size()
			for i in items.size():
				mm.set_instance_transform(i, items[i][0])
				mm.set_instance_color(i, items[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "ForestKit_%s" % key
			mmi.multimesh = mm
			mmi.material_override = ground_mat if ground else mat
			mmi.set_meta("no_batch", true)
			if small:
				# Flat patches, flowers, pebbles and bushes cast no sun shadow
				# (they would only add shadow draws for specks).
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			game.add_child(mmi)
	if not _trails.is_empty():
		var tm := MeshInstance3D.new()
		tm.name = "ForestKit_trails"
		tm.mesh = _trail_mesh()
		tm.material_override = mat
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tm.set_meta("no_batch", true)
		game.add_child(tm)


func kit_mesh(key: String) -> ArrayMesh:
	## For the close-up sheet and tests: the mesh behind a key.
	return _mesh_for(key)


func _mesh_for(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seed := key.hash()
	var shape := int(key.right(1)) if key.right(1).is_valid_int() else 0
	if key.begins_with("pine"):
		_make_pine(st, seed, shape, "")
	elif key.begins_with("autumn") and key != "autumnbroad":
		_make_pine(st, seed, shape, "autumn" if shape == 0 else "gold")
	elif key.begins_with("broad"):
		_make_broad(st, seed, shape, "")
	elif key == "blossom":
		_make_broad(st, seed, 1, "blossom")
	elif key == "autumnbroad":
		_make_broad(st, seed, 2, "autumn")
	elif key.begins_with("bush"):
		_make_bush(st, seed, shape)
	elif key.begins_with("rock"):
		_make_rock(st, seed, shape)
	elif key.begins_with("flower"):
		_make_flowers(st, seed, shape)
	elif key == "fence":
		_make_fence(st)
	elif key == "patch":
		_make_patch(st, seed)
	else:
		return null
	var m := st.commit()
	_meshes[key] = m
	return m


# Colours -------------------------------------------------------------------

func _hsv(v: Vector3) -> Color:
	return Color.from_hsv(v.x, v.y, v.z)


func _leaf_ramp(accent: String) -> Array:
	## [shade under the crown, sunlit top] for broadleaf crowns.
	if accent == "blossom":
		return [Color.from_hsv(0.985, 0.66, 0.5), Color.from_hsv(0.02, 0.42, 1.0)]   # warm coral-pink blossom (the picks' flower pinks), not lilac
	if accent == "autumn":
		return [StyleProfile.AUTUMN_BOTTOM, StyleProfile.AUTUMN_TOP]
	match palette:
		"twilight":
			if accent == "violet":   # one grove tree in three, as an accent
				return [Color(0.2, 0.2, 0.32), Color(0.46, 0.5, 0.7)]
			# (Greener than the target teal: the dusk light is magenta.)
			return [Color(0.03, 0.24, 0.2), Color(0.22, 0.96, 0.58)]
		"winter":
			return [Color(0.12, 0.3, 0.22), Color(0.9, 0.94, 1.0)]
	# The picks' crowns: deep cool green in the shade, warm yellow-green on top
	# (grade pass 2026-10-31: sunlit tops a clear step lighter, was v 0.5).
	return [Color.from_hsv(0.4, 0.86, 0.09), Color.from_hsv(0.26, 0.88, 0.4)]


func _pine_ramp(accent: String) -> Array:
	if accent == "autumn":
		return [StyleProfile.AUTUMN_BOTTOM, StyleProfile.AUTUMN_TOP]
	if accent == "gold":
		return [StyleProfile.GOLD_BOTTOM, StyleProfile.GOLD_TOP]
	match palette:
		"twilight":
			return [Color(0.03, 0.22, 0.18), Color(0.2, 0.82, 0.52)]
		"winter":
			return [Color(0.1, 0.34, 0.24), Color(0.24, 0.56, 0.36)]
	# Grade pass 2026-10-31: deep blue-green inside, vivid yellow-green tips.
	return [Color.from_hsv(0.44, 0.86, 0.08), Color.from_hsv(0.29, 0.86, 0.38)]


func _bark() -> Array:
	if palette == "twilight":
		return [Color(0.26, 0.2, 0.3), Color(0.42, 0.33, 0.4)]
	return [Color(0.3, 0.2, 0.13), Color(0.5, 0.35, 0.22)]


# Primitives ------------------------------------------------------------------

static func _hash(v: Vector3, seed: int) -> float:
	var h := sin(v.x * 12.9898 + v.y * 78.233 + v.z * 37.719 + float(seed % 1000) * 0.618) * 43758.5453
	return h - floorf(h)


static func _unit_sphere() -> void:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 7
	s.rings = 4
	var a := s.get_mesh_arrays()
	_unit = [a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_INDEX]]


func _v(st: SurfaceTool, p: Vector3, n: Vector3, c: Color, kind: float) -> void:
	st.set_normal(n)
	st.set_color(c)
	st.set_uv(Vector2(kind, 0.0))
	st.add_vertex(p)


func _lobe(st: SurfaceTool, c: Vector3, rad: float, squash: float, seed: int, cb: Color, ct: Color, y0: float, y1: float, kind: float, jitter: float = 0.14, snow: float = -1.0) -> void:
	## A lumpy leaf clump (or rock): a jittered sphere, coloured by height
	## through the whole crown (y0..y1), darker underneath.
	if _unit.is_empty():
		_unit_sphere()
	var verts: PackedVector3Array = _unit[0]
	var idx: PackedInt32Array = _unit[1]
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var cols := PackedColorArray()
	pts.resize(verts.size())
	nrm.resize(verts.size())
	cols.resize(verts.size())
	for i in verts.size():
		var d: Vector3 = verts[i]
		var j := 1.0 + (_hash(d.snapped(Vector3.ONE * 0.01), seed) - 0.5) * 2.0 * jitter
		var p := c + Vector3(d.x, d.y * squash, d.z) * rad * j
		pts[i] = p
		nrm[i] = Vector3(d.x, d.y / maxf(squash, 0.2), d.z).normalized()
		var t := clampf((p.y - y0) / maxf(y1 - y0, 0.01), 0.0, 1.0)
		var col := cb.lerp(ct, smoothstep(0.0, 1.0, t))
		col = col * (0.58 + 0.42 * clampf(d.y * 0.5 + 0.6, 0.0, 1.0))   # self shade under each clump (grade pass: deeper, so clumps separate)
		if snow >= 0.0 and d.y > snow:
			col = col.lerp(Color(0.93, 0.96, 1.0), smoothstep(snow, snow + 0.3, d.y))
		col.a = 1.0
		cols[i] = col
	for k in range(0, idx.size(), 3):
		for m in [idx[k], idx[k + 1], idx[k + 2]]:
			_v(st, pts[m], nrm[m], cols[m], kind)


func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, ca: Color, cb: Color, kind: float) -> void:
	## A tapered tube from a (radius ra) to b (radius rb), no caps.
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(axis).normalized()
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := side * cos(a0) + fwd * sin(a0)
		var d1 := side * cos(a1) + fwd * sin(a1)
		var b0 := a + d0 * ra
		var b1 := a + d1 * ra
		var t0 := b + d0 * rb
		var t1 := b + d1 * rb
		# (Godot culls counter-clockwise faces: this order faces out.)
		_v(st, t0, d0, cb, kind)
		_v(st, b0, d0, ca, kind)
		_v(st, b1, d1, ca, kind)
		_v(st, t0, d0, cb, kind)
		_v(st, b1, d1, ca, kind)
		_v(st, t1, d1, cb, kind)


func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, c0: Color, c1: Color, c2: Color, kind: float) -> void:
	var n := (p1 - p0).cross(p2 - p0).normalized()
	# Emitted p0, p2, p1: the face whose normal is n is the one drawn.
	_v(st, p0, n, c0, kind)
	_v(st, p2, n, c2, kind)
	_v(st, p1, n, c1, kind)


func _box(st: SurfaceTool, c: Vector3, h: Vector3, yaw: float, col: Color, kind: float) -> void:
	## An axis box (half extents h) turned by yaw round y.
	var bs := Basis(Vector3.UP, yaw)
	var faces := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.BACK, Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.DOWN, Vector3.RIGHT]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var w: Vector3 = f[2]
		var o: Vector3 = n * h
		var uu: Vector3 = u * h
		var ww: Vector3 = w * h
		var q := [o - uu - ww, o + uu - ww, o + uu + ww, o - uu + ww]
		var shade := col * (1.0 if n.y > 0.5 else (0.7 if n.y < -0.5 else 0.86))
		shade.a = 1.0
		var p := []
		for v in q:
			p.append(c + bs * v)
		var nn: Vector3 = bs * n
		# Front faces wind clockwise seen from outside (Godot).
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for i in tri:
				_v(st, p[i], nn, shade, kind)


# Models ------------------------------------------------------------------------

func _make_broad(st: SurfaceTool, seed: int, shape: int, accent: String) -> void:
	## Pick A's broadleaf: a straight trunk with a fork or two, and a round
	## dome of leaf clumps (a skirt, a ring and a top knot), ~4.6 m tall.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var ramp := _leaf_ramp("violet" if palette == "twilight" and accent == "" and shape == 1 else accent)
	var bark := _bark()
	var trunk_h: float = [1.7, 1.9, 1.55][shape]
	var crown_r: float = [1.45, 1.25, 1.6][shape]
	var cy: float = trunk_h + crown_r * 0.7    # crown centre
	_cyl(st, Vector3(0, -0.1, 0), Vector3(0, trunk_h + 0.3, 0), 0.22, 0.13, 6, bark[0], bark[1], 1.0)
	# Root flare and two boughs into the crown.
	for k in 3:
		var a := TAU * k / 3.0 + r.randf() * 0.6
		_cyl(st, Vector3(cos(a) * 0.36, -0.05, sin(a) * 0.36), Vector3(0, 0.45, 0), 0.07, 0.14, 4, bark[0], bark[0], 1.0)
	for k in 2:
		var a := TAU * k / 2.0 + r.randf() * 0.8
		_cyl(st, Vector3(0, trunk_h * 0.75, 0), Vector3(cos(a) * crown_r * 0.45, cy - 0.1, sin(a) * crown_r * 0.45), 0.09, 0.05, 4, bark[0], bark[1], 1.0)
	var y0: float = cy - crown_r * 0.85
	var y1: float = cy + crown_r * 1.0
	# Many small round clumps (pick A's crowns read as a pile of little
	# leaf balls): a skirt ring, a shoulder ring, a crown ring and a top
	# knot round a solid core.
	var lobes := []
	var spin := r.randf() * TAU
	var rings := [[7, 0.74, -0.22, 0.4], [6, 0.56, 0.22, 0.38], [4, 0.3, 0.58, 0.36]]   # count, reach, height, size (x crown_r)
	for ring in rings:
		var cnt: int = ring[0] - (1 if shape == 1 else 0)
		for i in cnt:
			var a := spin + TAU * (i + 0.5 * float(rings.find(ring))) / cnt + r.randf_range(-0.22, 0.22)
			lobes.append([Vector3(cos(a), 0, sin(a)) * crown_r * ring[1] * r.randf_range(0.92, 1.08) + Vector3(0, cy + crown_r * (ring[2] + r.randf_range(-0.07, 0.07)), 0), crown_r * ring[3] * r.randf_range(0.88, 1.14)])
	lobes.append([Vector3(r.randf_range(-0.1, 0.1), cy + crown_r * 0.82, r.randf_range(-0.1, 0.1)), crown_r * 0.34])
	lobes.append([Vector3(0, cy, 0), crown_r * 0.72])   # the core: no see-through gaps
	var glow: bool = palette == "twilight" or (palette == "night" and accent == "")
	for i in lobes.size():
		var snow := 0.45 if palette == "winter" else -1.0
		_lobe(st, lobes[i][0], lobes[i][1], 0.84, seed + i * 31, ramp[0], ramp[1], y0, y1, 0.0, 0.16, snow)
	if palette == "twilight":
		# Glowing blooms dotted over the crown (the grove look).
		for i in 9:
			var a := r.randf() * TAU
			var up := r.randf_range(-0.1, 0.8)
			var d := Vector3(cos(a) * (1.0 - up * 0.5), up, sin(a) * (1.0 - up * 0.5)).normalized()
			var bc := Color(0.55, 0.95, 1.0, 1.0) if i % 3 != 0 else Color(1.0, 0.55, 0.9, 1.0)
			_lobe(st, Vector3(0, cy, 0) + d * crown_r * 1.02, 0.11, 1.0, seed + 700 + i, bc, bc, 0.0, 1.0, 3.0, 0.1)
	elif accent == "" and palette in ["day", "night"] and shape == 2:
		# Small white blossoms on one shape in three (pick A's dotted crowns).
		for i in 7:
			var a := r.randf() * TAU
			var up := r.randf_range(0.0, 0.85)
			var d := Vector3(cos(a) * (1.0 - up * 0.5), up, sin(a) * (1.0 - up * 0.5)).normalized()
			var bc := Color(0.98, 0.95, 0.86, 1.0)
			_lobe(st, Vector3(0, cy, 0) + d * crown_r * 1.0, 0.08, 1.0, seed + 900 + i, bc, bc, 0.0, 1.0, 4.0 if not glow else 3.0, 0.1)


func _make_pine(st: SurfaceTool, seed: int, shape: int, accent: String) -> void:
	## Pick D's conifer: a short visible trunk and five drooping tiers of
	## needles stepping in to a point, ~6 m tall. Stonekeep's carry snow on
	## every tier.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var ramp := _pine_ramp(accent)
	var bark := _bark()
	var tiers: int = [5, 4, 6][shape]
	var base_r: float = [1.55, 1.35, 1.7][shape]
	var top: float = [6.0, 5.2, 6.4][shape]
	var foot := 1.0     # first tier's rim height
	_cyl(st, Vector3(0, -0.1, 0), Vector3(0, top * 0.6, 0), 0.2, 0.08, 6, bark[0], bark[1], 1.0)
	var snow: bool = palette == "winter"
	var snow_c := Color(0.93, 0.96, 1.0, 1.0)
	for i in tiers:
		var f := float(i) / tiers
		var rr: float = base_r * (1.0 - f * 0.78)
		var rim_y: float = foot + (top - foot - 0.9) * f
		var apex_y: float = rim_y + (top - foot) / tiers * 1.75
		if i == tiers - 1:
			apex_y = top
		var n := 10
		var spin := r.randf() * TAU
		var t_lo: float = clampf(rim_y / top, 0.0, 1.0)
		var t_hi: float = clampf(apex_y / top, 0.0, 1.0)
		# Stepped tiers (pick D, grade pass 2026-10-31): each tier is light
		# at its drooping tips and dark where it runs in under the tier
		# above, so the cone reads as stacked skirts, not one smooth blob.
		# Only the top tier is light right up to its point.
		var c_tip: Color = ramp[0].lerp(ramp[1], 0.62 + t_lo * 0.38)
		var c_apex: Color = ramp[0].lerp(ramp[1], 0.85 if i == tiers - 1 else 0.05 + t_hi * 0.15)
		var c_under: Color = ramp[0] * 0.5
		c_under.a = 1.0
		var apex := Vector3(0, apex_y, 0)
		var under := Vector3(0, rim_y + 0.25, 0)
		var rim := []
		for k in n * 2:
			var a := spin + TAU * k / (n * 2)
			var tip := k % 2 == 0
			var rad: float = rr * (1.0 if tip else 0.84) * r.randf_range(0.94, 1.06)
			var y := rim_y - (0.16 if tip else -0.08)
			rim.append(Vector3(cos(a) * rad, y, sin(a) * rad))
		for k in n * 2:
			var p0: Vector3 = rim[k]
			var p1: Vector3 = rim[(k + 1) % (n * 2)]
			var c0 := c_tip if k % 2 == 0 else c_tip.lerp(c_apex, 0.35)
			var c1 := c_tip if (k + 1) % 2 == 0 else c_tip.lerp(c_apex, 0.35)
			var ca := c_apex
			if snow:
				# Snow lies on the upper slope, the drooping tips stay green.
				ca = c_apex.lerp(snow_c, 0.8)
				c0 = c0.lerp(snow_c, 0.08 if k % 2 == 0 else 0.45)
				c1 = c1.lerp(snow_c, 0.08 if (k + 1) % 2 == 0 else 0.45)
			_tri(st, apex, p1, p0, ca, c1, c0, NEEDLE)
			_tri(st, under, p0, p1, c_under, c0 * 0.55, c1 * 0.55, NEEDLE)
	if palette == "twilight":
		for i in 6:
			var a := r.randf() * TAU
			var f := r.randf_range(0.0, 0.8)
			var y: float = foot + (top - foot - 0.9) * f
			var rad: float = base_r * (1.0 - f * 0.78) * 0.95
			var bc := Color(0.55, 0.95, 1.0, 1.0) if i % 2 == 0 else Color(1.0, 0.6, 0.9, 1.0)
			_lobe(st, Vector3(cos(a) * rad, y - 0.15, sin(a) * rad), 0.1, 1.0, seed + 800 + i, bc, bc, 0.0, 1.0, 3.0, 0.1)


func _make_bush(st: SurfaceTool, seed: int, shape: int) -> void:
	## A low, round shrub (~0.8 m) of three to five clumps.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var ramp := _leaf_ramp("")
	if palette == "day" or palette == "night":
		ramp = [Color.from_hsv(0.36, 0.8, 0.24), Color.from_hsv(0.27, 0.7, 0.66)]
	var n := 4 if shape == 0 else 5
	for i in n:
		var a := TAU * i / n + r.randf() * 0.5
		var d := 0.0 if i == 0 else r.randf_range(0.3, 0.45)
		var rad := r.randf_range(0.34, 0.46) * (1.15 if i == 0 else 1.0)
		var c := Vector3(cos(a) * d, rad * 0.75, sin(a) * d)
		_lobe(st, c, rad, 0.8, seed + i * 13, ramp[0], ramp[1], 0.0, 0.9, 0.0, 0.14, 0.4 if palette == "winter" else -1.0)
	if shape == 1 and palette in ["day", "night", "twilight"]:
		# Berries or blooms on one bush in two.
		for i in 5:
			var a := r.randf() * TAU
			var bc := Color(0.95, 0.4, 0.45, 1.0) if palette != "twilight" else Color(0.6, 0.95, 1.0, 1.0)
			_lobe(st, Vector3(cos(a) * 0.45, r.randf_range(0.35, 0.7), sin(a) * 0.45), 0.06, 1.0, seed + 300 + i, bc, bc, 0.0, 1.0, 4.0 if palette != "twilight" else 3.0, 0.1)


func _make_rock(st: SurfaceTool, seed: int, shape: int) -> void:
	## A grey boulder (~1 m at scale 1): one big lump and a smaller one
	## leaning on it, with a mossy (or snowy) top.
	var lo := Color(0.42, 0.42, 0.44)
	var hi := Color(0.72, 0.71, 0.68)
	if palette == "twilight":
		lo = Color(0.26, 0.3, 0.36)
		hi = Color(0.52, 0.56, 0.62)
	var snow := 0.5 if palette == "winter" else -1.0
	_lobe(st, Vector3(0, 0.45, 0), 0.62, 0.78, seed, lo, hi, 0.0, 0.95, 2.0, 0.24, snow)
	if shape == 1:
		_lobe(st, Vector3(0.55, 0.25, 0.2), 0.36, 0.8, seed + 7, lo, hi, 0.0, 0.95, 2.0, 0.26, snow)
	if palette in ["day", "night"]:
		# A moss cap on the top, kept inside the rock's top (no floating patch).
		var moss := Color.from_hsv(0.27, 0.6, 0.42)
		_lobe(st, Vector3(0.05, 0.72, -0.05), 0.3, 0.35, seed + 3, moss * 0.8, moss, 0.6, 0.85, 0.0, 0.2)


func _make_flowers(st: SurfaceTool, seed: int, shape: int) -> void:
	## A clump of wildflowers (~0.35 m): a few leaf tufts and five to seven
	## blooms in one of the picks' colours (white, pink, orange, yellow).
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var leaf := [Color.from_hsv(0.33, 0.75, 0.3), Color.from_hsv(0.27, 0.7, 0.55)]
	var cols := [Color(0.98, 0.97, 0.92), Color(1.0, 0.56, 0.72), Color(1.0, 0.62, 0.22)]
	var kind := 4.0
	if palette == "twilight":
		leaf = [Color(0.16, 0.3, 0.3), Color(0.3, 0.6, 0.5)]
		cols = [Color(0.55, 0.95, 1.0), Color(1.0, 0.55, 0.9), Color(0.75, 0.6, 1.0)]
		kind = 3.0
	elif palette == "winter":
		leaf = [Color(0.2, 0.32, 0.26), Color(0.4, 0.5, 0.42)]
		cols = [Color(0.75, 0.85, 1.0), Color(0.95, 0.95, 1.0), Color(0.6, 0.8, 0.95)]
	for i in 3:
		var a := TAU * i / 3.0 + r.randf()
		_lobe(st, Vector3(cos(a) * 0.12, 0.06, sin(a) * 0.12), 0.13, 0.6, seed + i, leaf[0], leaf[1], 0.0, 0.16, 0.0, 0.2)
	var bloom: Color = cols[shape % cols.size()]
	var second: Color = cols[(shape + 1) % cols.size()] if shape == 2 else bloom
	for i in r.randi_range(5, 7):
		var a := r.randf() * TAU
		var d := r.randf_range(0.04, 0.24)
		var h := r.randf_range(0.18, 0.34)
		var base := Vector3(cos(a) * d, 0.0, sin(a) * d)
		_cyl(st, base, base + Vector3(0, h, 0), 0.015, 0.012, 3, leaf[0], leaf[1], 0.0)
		var bc: Color = bloom if i % 3 != 2 else second
		bc.a = 1.0
		# A flat five-petal star facing up, with a yellow eye.
		var c := base + Vector3(0, h, 0)
		var pr := r.randf_range(0.06, 0.085)
		var eye := Color(1.0, 0.85, 0.3, 1.0)
		for k in 5:
			var a0 := TAU * k / 5.0
			var a1 := TAU * (k + 0.5) / 5.0
			var a2 := TAU * (k + 1) / 5.0
			var p0 := c + Vector3(cos(a0) * pr * 0.45, 0.0, sin(a0) * pr * 0.45)
			var p1 := c + Vector3(cos(a1) * pr, 0.01, sin(a1) * pr)
			var p2 := c + Vector3(cos(a2) * pr * 0.45, 0.0, sin(a2) * pr * 0.45)
			_v(st, c + Vector3(0, 0.012, 0), Vector3.UP, eye, kind)
			_v(st, p1, Vector3.UP, bc, kind)
			_v(st, p2, Vector3.UP, bc, kind)
			_v(st, c + Vector3(0, 0.012, 0), Vector3.UP, eye, kind)
			_v(st, p0, Vector3.UP, bc, kind)
			_v(st, p1, Vector3.UP, bc, kind)


func _make_fence(st: SurfaceTool) -> void:
	## One 2.4 m bay of rail fence along x: a post at each end, two rails.
	var wood := Color(0.52, 0.36, 0.22)
	var dark := Color(0.4, 0.27, 0.16)
	if palette == "twilight":
		wood = Color(0.42, 0.33, 0.38)
		dark = Color(0.32, 0.24, 0.3)
	for sx in [-1.2, 1.2]:
		_box(st, Vector3(sx, 0.5, 0), Vector3(0.09, 0.55, 0.09), 0.0, dark, 1.0)
		_box(st, Vector3(sx, 1.08, 0), Vector3(0.11, 0.04, 0.11), 0.0, wood, 1.0)
	_box(st, Vector3(0, 0.82, 0), Vector3(1.22, 0.06, 0.04), 0.0, wood, 1.0)
	_box(st, Vector3(0, 0.45, 0), Vector3(1.22, 0.06, 0.04), 0.03, wood, 1.0)
	if palette == "winter":
		_box(st, Vector3(0, 0.9, 0), Vector3(1.2, 0.025, 0.05), 0.0, Color(0.93, 0.96, 1.0), 4.0)


func _make_patch(st: SurfaceTool, seed: int) -> void:
	## A ragged flat disc (radius ~1), opaque in the middle, fading to its rim.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var n := 14
	var mid := Color(1, 1, 1, 1)
	var edge := Color(1, 1, 1, 0)
	var rim := []
	for k in n:
		var a := TAU * k / n
		var rad := r.randf_range(0.75, 1.1)
		rim.append(Vector3(cos(a) * rad, 0, sin(a) * rad))
	for k in n:
		var p0: Vector3 = rim[k]
		var p1: Vector3 = rim[(k + 1) % n]
		_v(st, Vector3.ZERO, Vector3.UP, mid, 4.0)
		_v(st, p0, Vector3.UP, edge, 4.0)
		_v(st, p1, Vector3.UP, edge, 4.0)


func _trail_mesh() -> ArrayMesh:
	## The dirt trails: flat strips with ragged edges, a lighter worn middle.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var dirt := Color(0.5, 0.38, 0.24, 1.0)
	var worn := Color(0.62, 0.5, 0.34, 1.0)
	if palette == "winter":
		dirt = Color(0.78, 0.82, 0.88, 1.0)
		worn = Color(0.86, 0.89, 0.94, 1.0)
	elif palette == "twilight":
		dirt = Color(0.34, 0.26, 0.3, 1.0)
		worn = Color(0.44, 0.34, 0.38, 1.0)
	for t in _trails:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var w: float = t[2]
		var dir := (b - a)
		dir.y = 0
		var len := dir.length()
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var n := maxi(int(len / 1.2), 1)
		var prev := []
		for i in n + 1:
			var c := a + dir * len * float(i) / n + Vector3(0, 0.018, 0)
			var hw0 := w * 0.5 * r.randf_range(0.8, 1.15)
			var hw1 := w * 0.5 * r.randf_range(0.8, 1.15)
			var row := [c - side * hw0, c - side * hw0 * 0.35, c + side * hw1 * 0.35, c + side * hw1]
			if not prev.is_empty():
				var cs := [dirt, worn, worn, dirt]
				for k in 3:
					_v(st, prev[k], Vector3.UP, cs[k], 4.0)
					_v(st, row[k], Vector3.UP, cs[k], 4.0)
					_v(st, row[k + 1], Vector3.UP, cs[k + 1], 4.0)
					_v(st, prev[k], Vector3.UP, cs[k], 4.0)
					_v(st, row[k + 1], Vector3.UP, cs[k + 1], 4.0)
					_v(st, prev[k + 1], Vector3.UP, cs[k + 1], 4.0)
			prev = row
	return st.commit()
