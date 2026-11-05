extends RefCounted
## Own layouts for the two season maps (claude-faisal/crowns-maps 2026-10-31,
## Faisal: "can we make them different? maybe the layout or structure?"):
##
##   Stonekeep Fortress ("winter"): a mountain-pass fortress. Snowy rock
##   ridges fill the field. One narrow pass from each forecourt runs into the
##   walled ruin of Stonekeep, whose two 4 m gates are the hard chokepoint;
##   two longer snow lanes swing round the flanks over frozen tarns (the ice
##   crossings of the frozen river).
##
##   Twilight Grove ("twilight"): open and winding. A ring path round a
##   glowing pool and its shrine tree, an outer loop through the trees, and
##   six short spokes between them and the forecourts: many routes, flanks
##   and ambushes, no single chokepoint.
##
##   The Wildwood ("heartwood", claude-faisal/crowns-wildwood 2026-11-04,
##   Faisal: map 0 "feels kind of basic" and "should be a little more unique
##   and maybe not be so linear"): three routes through a jungle-thick wood.
##   The middle road crosses a moat on one of four bridges onto the raised
##   ring of the Heart-Tree amphitheatre; two flank loops swing wide to the
##   north and south, each over a log bridge where the Heartbrook runs out of
##   the moat; and winding jungle trails link the glades in between.
##
## Like Ember Pass (scripts/volcano.gd) the walkable ground is data: round
## plazas joined by straight corridors, a few rectangles, and each castle's
## own land (land_dist()). clamp_walk() keeps everyone on it and route()
## walks bots over the plaza graph; game.gd keeps its doors, keeps and ramps.
## Everything off the walkable ground is the layout's terrain (ridges or a
## raised forest floor), raised here from the same distance field. The look
## (snow, dusk) is still scripts/visual/season.gd's.

const Stats = preload("res://scripts/stats.gd")
const Season = preload("res://scripts/visual/season.gd")

const LAND_X := 41.0        # each castle's land starts this far out (|x|): its door court, walls and grounds...
const LAND_Z := 20.0        # ...across the castle's front (|z|); the ridges / grove wrap round its flanks...
const MESH_X := 52.0        # ...out to here, where the outskirts begin (|x| beyond is all land)
const EDGE_Z := 60.0        # the terrain runs on past the field's edge (z 36) to here, into the haze
const CELL := 2.0           # minimap / collider cell
const TERRAIN_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;
// Two textures projected in world space and blended by vertex colour red:
// tops (snow / moss) where it is 1, faces (rock / forest litter) where 0.
uniform sampler2D top_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D face_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 top_tint : source_color = vec4(1.0);
uniform vec4 face_tint : source_color = vec4(1.0);
uniform float top_scale = 0.12;
uniform float face_scale = 0.22;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec3 tri(sampler2D t, float s) {
	vec3 b = pow(abs(wnrm), vec3(4.0));
	b /= (b.x + b.y + b.z);
	return texture(t, wpos.zy * s).rgb * b.x + texture(t, wpos.xz * s).rgb * b.y + texture(t, wpos.xy * s).rgb * b.z;
}
void fragment() {
	// (Flat tops read the ground's own texture the way BaseMaterial3D's
	// world triplanar does, so the banks meet the open ground without a seam.)
	vec3 b = pow(abs(wnrm), vec3(4.0));
	b /= (b.x + b.y + b.z);
	vec3 top = mix(tri(top_tex, top_scale), texture(top_tex, wpos.xz * vec2(1.0, -1.0) * top_scale).rgb, b.y) * top_tint.rgb;
	vec3 face = tri(face_tex, face_scale) * face_tint.rgb;
	ALBEDO = mix(face, top, COLOR.r) * mix(0.8, 1.0, COLOR.g);
	ROUGHNESS = 0.0;   // (also the ink pass's terrain mask)
	SPECULAR = 0.0;
	ALPHA = COLOR.b;   // the foot of a bank fades into the open ground instead of ending in a stair-stepped edge
}
"""

var game
var kind := ""
var ids: Array = []        # node names, index = graph vertex
var pos: Array = []        # their centres
var rad: Array = []        # their radii
var segs: Array = []       # [a index, b index, half width, kind]
var rects: Array = []      # walkable rectangles: [centre, half extents (Vector2 x/z)]
var flats: Array = []      # where the terrain stays flat (the ruin): [centre, half extents]
var lanes: Array = []      # node names a raider passes through, one picked per life
var dist: Array = []       # all-pairs path length
var nxt: Array = []        # next hop on the shortest path
var cells: Array = []      # [Vector2 centre, distance off the walkable ground] for the maps
var noise := FastNoiseLite.new()
const POOL_R := 7.5        # Twilight Grove's glowing pool at the centre
# The distance field baked on a grid (bots ask walkable() every tick):
# GRID metres a cell over the middle; outside it the shapes are asked directly.
const GRID := 0.5
const GX0 := -MESH_X - 2.0
const GZ0 := -38.0
var gnx := int((MESH_X + 2.0) * 2.0 / GRID) + 2
var gnz := int(38.0 * 2.0 / GRID) + 2
var grid := PackedFloat32Array()
var route_cache := {}      # quantised (from, to) -> next point (null: walk straight at `to`)


func _init(p_game, p_kind: String) -> void:
	game = p_game
	kind = p_kind
	noise.seed = 31 if kind == "winter" else (59 if kind == "heartwood" else 47)
	noise.frequency = 0.07
	var lay: Dictionary = stonekeep() if kind == "winter" else (heartwood() if kind == "heartwood" else twilight())
	for id in lay.nodes:
		ids.append(id)
		pos.append(lay.nodes[id][0])
		rad.append(lay.nodes[id][1])
	for e in lay.edges:
		segs.append([ids.find(e[0]), ids.find(e[1]), e[2], e[3]])
	rects = lay.get("rects", [])
	flats = lay.get("flats", [])
	lanes = lay.lanes
	_build_graph()
	_bake_grid()
	var z := -36.0 + CELL / 2.0
	while z < 36.0:
		var x := -MESH_X + CELL / 2.0
		while x < MESH_X:
			var d := sdf(Vector3(x, 0, z))
			if d > 0.4:
				cells.append([Vector2(x, z), d])
			x += CELL
		z += CELL


static func _mirror(nodes: Dictionary, half: Dictionary, flip_z: bool) -> void:
	## Each Elf-side node "<name>0" gets its Human twin "<name>1" (x mirrored,
	## and z too when the layout is point-symmetric).
	for id in half:
		nodes[id] = half[id]
		if id.ends_with("0"):
			var p: Vector3 = half[id][0]
			nodes[id.left(-1) + "1"] = [Vector3(-p.x, 0, -p.z if flip_z else p.z), half[id][1]]


static func stonekeep() -> Dictionary:
	var nodes := {}
	_mirror(nodes, {
		"g0": [Vector3(-43, 0, 0), 7.5],      # door court (the Knights' fortify barricades stand at its edge)
		"m0": [Vector3(-31, 0, 0), 8.0],      # forecourt (the raids rally here)
		"w0": [Vector3(-14.5, 0, 0), 3.0],    # before the ruin's west gate
		"n0": [Vector3(-24, 0, -20), 5.5],    # north snow lane, Elf end
		"s0": [Vector3(-24, 0, 20), 5.5],     # south snow lane, Elf end
		"k": [Vector3(0, 0, 0), 7.0],         # the ruin's courtyard
		"n": [Vector3(0, 0, -27), 7.5],       # the north tarn (ice crossing)
		"s": [Vector3(0, 0, 27), 7.5],        # the south tarn
		# Nooks off the lanes where the lumber trees grow (economy.gd).
		"q0": [Vector3(-37, 0, -10), 3.6], "r0": [Vector3(-37, 0, 10), 3.6],
		"t0": [Vector3(-31.5, 0, -25), 3.6], "u0": [Vector3(-31.5, 0, 25), 3.6],
	}, false)
	var edges := []
	for t in ["0", "1"]:
		edges.append_array([["g" + t, "m" + t, 5.0, "road"], ["m" + t, "w" + t, 2.4, "pass"], ["w" + t, "k", 2.0, "gate"],
			["m" + t, "n" + t, 3.6, "lane"], ["n" + t, "n", 3.6, "lane"], ["m" + t, "s" + t, 3.6, "lane"], ["s" + t, "s", 3.6, "lane"],
			["m" + t, "q" + t, 2.4, "nook"], ["m" + t, "r" + t, 2.4, "nook"], ["n" + t, "t" + t, 2.4, "nook"], ["s" + t, "u" + t, 2.4, "nook"]])
	return {"nodes": nodes, "edges": edges,
		"rects": [[Vector3.ZERO, Vector2(8.6, 7.0)]],       # the courtyard inside the ruin's walls
		"flats": [[Vector3.ZERO, Vector2(11.6, 9.6)]],   # the ruin stands on level ground
		"lanes": ["k", "k", "n", "s"]}                      # half the raids take the gate, a quarter each flank


static func twilight() -> Dictionary:
	var nodes := {}
	_mirror(nodes, {
		"g0": [Vector3(-43, 0, 0), 7.5],
		"m0": [Vector3(-31, 0, 0), 7.0],
		"a0": [Vector3(-26, 0, -16), 4.0],    # the outer loop, Elf side, north...
		"b0": [Vector3(-12, 0, -27), 4.5],
		"c0": [Vector3(-18, 0, 24), 4.0],     # ...and south
		"d0": [Vector3(-28, 0, 12), 4.0],
		"o0": [Vector3(3, 0, -29), 5.0],      # the loop's north end (its twin, o1, is the south end)
		# Glades off the paths where the lumber trees grow (economy.gd).
		"q0": [Vector3(-38, 0, -9), 3.6], "r0": [Vector3(-38, 0, 9), 3.6],
		"t0": [Vector3(-21, 0, -31.5), 3.6], "u0": [Vector3(-25.5, 0, 30.5), 3.6],
	}, true)
	# The ring round the pool: i0 east, i2 south, i4 west, i6 north.
	for k in 8:
		var a := TAU * k / 8.0
		nodes["i%d" % k] = [Vector3(cos(a) * 14.5, 0, sin(a) * 14.5), 3.4]
	var edges := []
	for k in 8:
		edges.append(["i%d" % k, "i%d" % ((k + 1) % 8), 3.0, "ring"])
	for t in ["0", "1"]:
		edges.append(["g" + t, "m" + t, 4.6, "road"])
	edges.append_array([["m0", "a0", 3.0, "loop"], ["a0", "b0", 3.0, "loop"], ["b0", "o0", 3.0, "loop"], ["o0", "c1", 3.0, "loop"],
		["c1", "d1", 3.0, "loop"], ["d1", "m1", 3.0, "loop"], ["m1", "a1", 3.0, "loop"], ["a1", "b1", 3.0, "loop"],
		["b1", "o1", 3.0, "loop"], ["o1", "c0", 3.0, "loop"], ["c0", "d0", 3.0, "loop"], ["d0", "m0", 3.0, "loop"],
		["m0", "i4", 3.4, "spoke"], ["m1", "i0", 3.4, "spoke"],
		["a0", "i5", 2.8, "spoke"], ["a1", "i1", 2.8, "spoke"],
		["c1", "i7", 2.8, "spoke"], ["c0", "i3", 2.8, "spoke"]])
	for t in ["0", "1"]:
		edges.append_array([["m" + t, "q" + t, 2.4, "nook"], ["m" + t, "r" + t, 2.4, "nook"], ["b" + t, "t" + t, 2.4, "nook"], ["c" + t, "u" + t, 2.4, "nook"]])
	return {"nodes": nodes, "edges": edges, "lanes": ["i6", "i2", "o0", "o1"],
		"flats": [[Vector3.ZERO, Vector2(9.8, 9.8)]]}   # the pool's banks stay level, open across the water


# The Wildwood's Heart-Tree amphitheatre: a raised ring round the tree, a moat,
# and ruined stone tiers outside it; the Heartbrook leaves the moat to the
# north-east and (its twin) the south-west.
const HEART_TOP := 0.9        # the dais's top, over the ground
const HEART_FLAT := 4.6       # the dais is level out to this radius...
const HEART_FOOT := 7.4       # ...and ramps down to the ground here
const MOAT_IN := 8.2
const MOAT_OUT := 10.4
const SEATS_OUT := 12.4       # the amphitheatre's tiers end here
const BROOK := [Vector3(6.6, 0, -6.6), Vector3(10.0, 0, -15.0), Vector3(12.0, 0, -25.0), Vector3(13.0, 0, -42.0)]
const BROOK_HALF := 1.25      # the water's half width (its banks stay flat a little wider)


static func heartwood() -> Dictionary:
	var nodes := {}
	_mirror(nodes, {
		"g0": [Vector3(-43, 0, 0), 7.5],
		"m0": [Vector3(-31, 0, 0), 7.0],
		"w0": [Vector3(-18, 0, 0), 3.8],      # the glade before the west moat bridge (the middle road)
		"a0": [Vector3(-26, 0, -15), 4.0],    # the north flank loop, Elf side...
		"b0": [Vector3(-13, 0, -27), 4.5],
		"o0": [Vector3(3, 0, -30), 5.0],      # ...its far end (its twin, o1, the south loop's)
		"c0": [Vector3(-18, 0, 25), 4.0],     # the south loop, Elf side
		"d0": [Vector3(-28, 0, 13), 4.0],
		"f0": [Vector3(0, 0, -15), 3.2],      # the north moat bridge's foot (its twin, f1, the south one's)
		"j0": [Vector3(-15, 0, -11), 3.4],    # jungle glades between the road and the loops
		"k0": [Vector3(-15, 0, 12), 3.4],
		# Glades off the paths where the lumber trees grow (economy.gd).
		"q0": [Vector3(-38, 0, -9), 3.6], "r0": [Vector3(-38, 0, 9), 3.6],
		"t0": [Vector3(-21, 0, -31.5), 3.6], "u0": [Vector3(-25.5, 0, 30.5), 3.6],
	}, true)
	# The dais ring round the Heart-Tree: i0 east, i2 south, i4 west, i6 north.
	for k in 8:
		var a := TAU * k / 8.0
		nodes["i%d" % k] = [Vector3(cos(a) * 5.2, 0, sin(a) * 5.2), 2.6]
	var edges := []
	for k in 8:
		edges.append(["i%d" % k, "i%d" % ((k + 1) % 8), 2.4, "ring"])
	edges.append_array([["w0", "i4", 2.2, "bridge"], ["w1", "i0", 2.2, "bridge"], ["f0", "i6", 2.2, "bridge"], ["f1", "i2", 2.2, "bridge"],
		["m0", "a0", 3.0, "loop"], ["a0", "b0", 3.0, "loop"], ["b0", "o0", 3.0, "loop"], ["o0", "c1", 3.0, "loop"],
		["c1", "d1", 3.0, "loop"], ["d1", "m1", 3.0, "loop"], ["m1", "a1", 3.0, "loop"], ["a1", "b1", 3.0, "loop"],
		["b1", "o1", 3.0, "loop"], ["o1", "c0", 3.0, "loop"], ["c0", "d0", 3.0, "loop"], ["d0", "m0", 3.0, "loop"]])
	for t in ["0", "1"]:
		var u := "1" if t == "0" else "0"
		edges.append_array([["g" + t, "m" + t, 4.6, "road"], ["m" + t, "w" + t, 3.4, "lane"],
			["a" + t, "j" + t, 2.6, "trail"], ["j" + t, "w" + t, 2.6, "trail"], ["j" + t, "f" + t, 2.6, "trail"],
			["d" + t, "k" + t, 2.6, "trail"], ["k" + t, "w" + t, 2.6, "trail"], ["k" + t, "f" + u, 2.6, "trail"],
			["f" + t, "o" + t, 2.6, "trail"],
			["m" + t, "q" + t, 2.4, "nook"], ["m" + t, "r" + t, 2.4, "nook"], ["b" + t, "t" + t, 2.4, "nook"], ["c" + t, "u" + t, 2.4, "nook"]])
	# Raids spread over all three routes: the moat bridges, the far loops and
	# the jungle glades.
	return {"nodes": nodes, "edges": edges, "lanes": ["i6", "o0", "j1", "i2", "o1", "k1", "j0", "k0"]}


static func brook_dist(p: Vector3) -> float:
	## How far `p` is from the Heartbrook's middle line (either of the twins).
	var d := INF
	for sgn in [1.0, -1.0]:
		for k in BROOK.size() - 1:
			d = minf(d, _seg_dist(p, BROOK[k] * sgn, BROOK[k + 1] * sgn))
	return d


func heart_y(p: Vector3) -> float:
	## The dais's surface height at `p` (0 off it).
	if kind != "heartwood":
		return 0.0
	var r := Vector2(p.x, p.z).length()
	return HEART_TOP * clampf((HEART_FOOT - r) / (HEART_FOOT - HEART_FLAT), 0.0, 1.0)


func _build_graph() -> void:
	var n := ids.size()
	dist = []
	nxt = []
	for i in n:
		var row := []
		var hop := []
		for j in n:
			row.append(0.0 if i == j else INF)
			hop.append(j if i == j else -1)
		dist.append(row)
		nxt.append(hop)
	for s in segs:
		var d: float = _flat(pos[s[0]], pos[s[1]])
		dist[s[0]][s[1]] = d
		dist[s[1]][s[0]] = d
		nxt[s[0]][s[1]] = s[1]
		nxt[s[1]][s[0]] = s[0]
	for k in n:
		for i in n:
			for j in n:
				if dist[i][k] + dist[k][j] < dist[i][j]:
					dist[i][j] = dist[i][k] + dist[k][j]
					nxt[i][j] = nxt[i][k]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (ap - ab * t).length()


static func _rect_dist(p: Vector3, c: Vector3, half: Vector2) -> float:
	var q := Vector2(absf(p.x - c.x) - half.x, absf(p.z - c.z) - half.y)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


# --- Walkable ground ---------------------------------------------------------

func sdf(p: Vector3) -> float:
	## How far `p` is outside the walkable ground (negative inside).
	var d: float = land_dist(p)
	for i in pos.size():
		d = minf(d, _flat(p, pos[i]) - rad[i])
	for s in segs:
		d = minf(d, _seg_dist(p, pos[s[0]], pos[s[1]]) - s[2])
	for r in rects:
		d = minf(d, _rect_dist(p, r[0], r[1]))
	return d


func _bake_grid() -> void:
	grid.resize(gnx * gnz)
	for j in gnz:
		for i in gnx:
			grid[j * gnx + i] = sdf(Vector3(GX0 + i * GRID, 0, GZ0 + j * GRID))


func field(p: Vector3) -> float:
	## sdf() from the baked grid (bilinear), or straight from the shapes off it.
	var fx := (p.x - GX0) / GRID
	var fz := (p.z - GZ0) / GRID
	var i := int(floor(fx))
	var j := int(floor(fz))
	if i < 0 or j < 0 or i >= gnx - 1 or j >= gnz - 1:
		return sdf(p)
	var tx := fx - i
	var tz := fz - j
	var k := j * gnx + i
	return lerpf(lerpf(grid[k], grid[k + 1], tx), lerpf(grid[k + gnx], grid[k + gnx + 1], tx), tz)


static func land_dist(p: Vector3) -> float:
	## How far `p` is outside the castles' land (negative inside): the band
	## before each front wall (|x| >= LAND_X, |z| <= LAND_Z) and everything
	## beyond MESH_X.
	var q := Vector2(LAND_X - absf(p.x), absf(p.z) - LAND_Z)
	var band: float = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	return minf(band, MESH_X - absf(p.x))


func castle_of(p: Vector3) -> int:
	## Which team's land `p` is on, or -1 out in the contested middle.
	if land_dist(p) <= 0.0:
		return 0 if p.x < 0.0 else 1
	return -1


func walkable(p: Vector3, margin: float = 0.0) -> bool:
	if absf(p.x) >= MESH_X + margin:
		return true
	return field(p) < -margin


func clamp_walk(p: Vector3) -> Vector3:
	## `p` if it is on walkable ground, else the nearest point that is.
	if walkable(p):
		return p
	var side := -1.0 if p.x < 0.0 else 1.0
	var best := Vector3(side * (MESH_X + 0.05), p.y, p.z)
	var best_d := _flat(p, best)
	var band := Vector3(side * maxf(absf(p.x), LAND_X + 0.05), p.y, clampf(p.z, -LAND_Z + 0.05, LAND_Z - 0.05))
	if _flat(p, band) < best_d:
		best_d = _flat(p, band)
		best = band
	for i in pos.size():
		var c: Vector3 = pos[i]
		var off := Vector3(p.x - c.x, 0, p.z - c.z)
		var q: Vector3 = c + (off.normalized() if off.length() > 0.001 else Vector3.FORWARD) * (rad[i] - 0.05)
		q.y = p.y
		var d := _flat(p, q)
		if d < best_d:
			best_d = d
			best = q
	for s in segs:
		var a: Vector3 = pos[s[0]]
		var b: Vector3 = pos[s[1]]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
		var on := Vector2(a.x, a.z) + ab * t
		var off := Vector2(p.x, p.z) - on
		var q2: Vector2 = on + (off.normalized() if off.length() > 0.001 else Vector2.ZERO) * (s[2] - 0.05)
		var q := Vector3(q2.x, p.y, q2.y)
		var d := _flat(p, q)
		if d < best_d:
			best_d = d
			best = q
	for r in rects:
		var c: Vector3 = r[0]
		var h: Vector2 = r[1]
		var q := Vector3(clampf(p.x, c.x - h.x + 0.05, c.x + h.x - 0.05), p.y, clampf(p.z, c.z - h.y + 0.05, c.z + h.y - 0.05))
		var d := _flat(p, q)
		if d < best_d:
			best_d = d
			best = q
	return best


func _straight(a: Vector3, b: Vector3) -> bool:
	## Whether the straight walk from a to b stays on walkable ground.
	var d := _flat(a, b)
	if d > 40.0:
		return false
	var steps := int(ceil(d / 0.8))
	for k in range(1, steps + 1):
		if not walkable(a.lerp(b, float(k) / steps), 0.35):
			return false
	return true


func _entries(p: Vector3) -> Array:
	## The graph nodes a walker at `p` can reach in a straight line.
	var c := castle_of(p)
	if c >= 0:
		return [ids.find("g%d" % c)]
	for i in pos.size():
		if _flat(p, pos[i]) < rad[i]:
			return [i]
	for r in rects:
		if _rect_dist(p, r[0], r[1]) < 0.0:
			var best := 0
			for i in pos.size():
				if _flat(p, pos[i]) < _flat(p, pos[best]):
					best = i
			return [best]
	var out := []
	for s in segs:
		if _seg_dist(p, pos[s[0]], pos[s[1]]) < s[2] + 0.3:
			out.append(s[0])
			out.append(s[1])
	if not out.is_empty():
		return out
	var best := 0
	for i in pos.size():
		if _flat(p, pos[i]) - rad[i] < _flat(p, pos[best]) - rad[best]:
			best = i
	return [best]


func route(from: Vector3, to: Vector3) -> Vector3:
	## The next point to walk toward on the way to `to` over the plazas and
	## corridors. Castle doors, keeps and ramps are left to the game's own
	## routing, which takes this as its target.
	if castle_of(from) >= 0 and castle_of(from) == castle_of(to):
		return to
	var key := Vector4i(roundi(from.x * 2.0), roundi(from.z * 2.0), roundi(to.x), roundi(to.z))
	if route_cache.has(key):
		var hit = route_cache[key]
		return to if hit == null else hit
	if route_cache.size() > 8000:
		route_cache.clear()
	var r = _route(from, to)
	route_cache[key] = null if r == to else r
	return r


func _route(from: Vector3, to: Vector3) -> Vector3:
	if _straight(from, to):
		return to
	var fa := _entries(from)
	var tb := _entries(to)
	var bi: int = fa[0]
	var bj: int = tb[0]
	var best := INF
	for i in fa:
		for j in tb:
			var cost: float = _flat(from, pos[i]) + dist[i][j] + _flat(pos[j], to)
			if cost < best:
				best = cost
				bi = i
				bj = j
	var in_disc: bool = _flat(from, pos[bi]) < rad[bi]
	if not in_disc:
		# In a corridor (or the castle land): straight to its end, unless
		# the next node along is in plain sight (corridor joins).
		if bi != bj:
			var k0: int = nxt[bi][bj]
			if _straight(from, pos[k0]) and _flat(from, pos[k0]) < _flat(pos[bi], pos[k0]):
				return pos[k0]
		return pos[bi]
	if bi == bj:
		return pos[bi] if _flat(from, pos[bi]) > 1.0 else to
	var k: int = nxt[bi][bj]
	# Out of this plaza along the corridor to the next one: its mouth first,
	# then straight down the middle.
	var dir: Vector3 = (pos[k] - pos[bi])
	dir.y = 0.0
	var mouth: Vector3 = pos[bi] + dir.normalized() * maxf(rad[bi] - 1.2, 0.0)
	if _flat(from, mouth) > 1.3 and not _straight(from, pos[k]):
		return mouth
	return pos[k]


func lane_via(u) -> Vector3:
	## A raider's lane for this life: the node it walks through on the way to
	## the enemy door, or INF once it is level with it (or past it). Lanes
	## change with every death, so raids spread over the whole map.
	if lanes.is_empty() or u.carrying:
		return Vector3.INF
	var k: int = (game.units.find(u) + u.deaths) % lanes.size()
	var p: Vector3 = pos[ids.find(lanes[k])]
	var toward := 1.0 if u.team == 0 else -1.0
	if (u.global_position.x - p.x) * toward > -2.0 or _flat(u.global_position, p) < 3.0:
		return Vector3.INF
	return p


# --- Bot match report (--demo) ---------------------------------------------------

var _sample_t := 0.0
var presence := {}   # area -> unit-seconds spent there (living units, every second)


func sample(delta: float) -> void:
	_sample_t += delta
	if _sample_t < 1.0:
		return
	_sample_t -= 1.0
	for u in game.units:
		if u.dead or u.global_position.y < -1.0:
			continue
		var area := _area(u.global_position)
		presence[area] = presence.get(area, 0) + 1


func _area(p: Vector3) -> String:
	## Which part of the layout `p` is in, by the lanes a raid can take.
	if castle_of(p) >= 0:
		return "castles"
	if kind == "winter":
		if absf(p.z) < 9.0:
			return "centre"   # forecourts, passes, gates and the courtyard
		return "north" if p.z < 0.0 else "south"
	var r := Vector2(p.x, p.z).length()
	if absf(p.x) > 26.0 and absf(p.z) < 9.0:
		return "forecourts"
	if kind == "heartwood":
		if r < MOAT_OUT + 1.0:
			return "heart"         # the dais ring round the Heart-Tree
		if absf(p.z) < 5.0:
			return "road"          # the middle road's glades and bridges
		if absf(p.z) > 20.0:
			return "loop_north" if p.z < 0.0 else "loop_south"
		return "jungle"
	if r < 19.0:
		return "ring"
	return "loop_north" if p.z < 0.0 else "loop_south"


func sample_report() -> String:
	var keys := presence.keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append("%s=%d" % [k, presence[k]])
	return " ".join(out)


# --- Spots -------------------------------------------------------------------

func node(id: String) -> Vector3:
	return pos[ids.find(id)]


func blessing_spots() -> Array:
	if kind == "winter":
		return [Vector3(0, 0, 0), Vector3(0, 0, -27), Vector3(0, 0, 27), Vector3(-24, 0, -20), Vector3(24, 0, 20),
			Vector3(-24, 0, 20), Vector3(24, 0, -20)]
	if kind == "heartwood":
		var top := Vector3(0, HEART_TOP, 0)
		return [node("i6") + top, node("i2") + top, node("j0"), node("j1"), node("k0"), node("k1"), node("o0"), node("o1")]
	return [node("i6"), node("i2"), node("i5"), node("i1"), node("i3"), node("i7"), node("o0"), node("o1")]


func heal_orb_spots() -> Array:
	## Each castle yard, then the layout's own; every spot has its twin.
	var fx: float = game.CASTLE_X - game.CASTLE_DEPTH
	var half := [Vector3(fx + 4.5, 0, 0)]
	if kind == "winter":
		half.append_array([Vector3(24, 0, -20), Vector3(24, 0, 20), Vector3(0, 0, -4.5)])
	elif kind == "heartwood":
		half.append_array([node("f0"), node("o1"), node("w1") + Vector3(0, 0, -2.0)])
	else:
		half.append_array([Vector3(0, 0, -14.5), Vector3(3, 0, -32.0), Vector3(28, 0, -12)])
	var out := []
	for p in half:
		out.append(p)
		out.append(Vector3(-p.x, 0, -p.z) if kind != "winter" or absf(p.z) < 6.0 else Vector3(-p.x, 0, p.z))
	return out


func cover() -> Dictionary:
	## Cover for game._add_cover: barricades [centre, length] (lying along z)
	## and boulders, on the Humans' half; the Elves' half mirrors them (-p).
	if kind == "winter":
		return {"barricades": [[Vector3(4.5, 0, -3.8), 2.6], [Vector3(-4.5, 0, -3.8), 2.6], [Vector3(27, 0, 4.5), 3.0]],
			"boulders": [Vector3(4.0, 0, -28.5), Vector3(-4.5, 0, -25.5), Vector3(17, 0, -24.2), Vector3(26.5, 0, -14),
				Vector3(-14, 0, -26.5)]}
	if kind == "heartwood":
		# Cover at the glades and loop bends, never on a bridge or the ring.
		return {"barricades": [[Vector3(20.0, 0, -2.4), 2.4], [Vector3(31, 0, 4.0), 3.0]],
			"boulders": [Vector3(24.5, 0, 17.5), Vector3(-12.0, 0, -25.0), Vector3(15.5, 0, -9.0), Vector3(17.0, 0, 13.5), Vector3(-1.5, 0, -28.5)]}
	return {"barricades": [[Vector3(14.5, 0, -4.5), 2.6], [Vector3(31, 0, 4.0), 3.0]],
		"boulders": [Vector3(23.5, 0, -18.5), Vector3(-12.5, 0, -24.5), Vector3(9.5, 0, -13.4), Vector3(27, 0, 9)]}


func econ_spots() -> Dictionary:
	## Lumber trees and ore deposits on the Elves' half (economy.gd mirrors them).
	var wood := [node("q0"), node("r0"), node("t0"), node("u0")]
	if kind == "winter":
		return {"wood": wood, "ore": [Vector3(-2.5, 0, -31.0)]}   # (and one on each tarn's shore)
	return {"wood": wood, "ore": []}


func height(x: float, z: float) -> float:
	## The terrain over the ground at (x, z): 0 on and round the walkable
	## ground and in the flat zones, rising with the distance off it.
	var p := Vector3(x, 0, z)
	var fd := INF
	for f in flats:
		fd = minf(fd, _rect_dist(p, f[0], f[1]))
	if fd < 0.0:
		return 0.0
	if kind == "heartwood" and (_in_heart(p, 0.0) or brook_dist(p) < BROOK_HALF + 1.4):
		return -0.15   # the amphitheatre's lawn and the Heartbrook's flat banks
	# Banks rise from the edge of the level ground, not in a step at it
	# (a step left the gate approach's paving looking like a floating slab).
	var d: float = minf(field(p), fd)
	if d <= 0.0:
		return -0.15
	# Toward the mesh's own border it sinks under the ground, so the seam
	# with the outskirts' ground never shows.
	var border: float = minf(MESH_X - absf(x), EDGE_Z - absf(z))
	if border < 9.0:
		d = minf(d, border * 0.7 - 1.0)   # foothills easing down to the outskirts
		if d <= 0.0:
			return -0.15
	var n := noise.get_noise_2d(x, z)
	if kind == "winter":
		# Ridges: about 45 degrees off the lane (lower than the camera's line
		# of sight to anyone standing at the foot, CAMERA_OFFSET 19 over 16),
		# craggy with noise, topping out near 7 m.
		return minf(d * 1.05, 7.0) + n * minf(d * 0.16, 1.3)
	if kind == "heartwood":
		# The Wildwood's jungle floor: rooty banks a little higher than the
		# Grove's, easing up off the brook's banks and the amphitheatre too.
		d = minf(d, brook_dist(p) - BROOK_HALF - 1.4)
		d = minf(d, Vector2(x, z).length() - SEATS_OUT - 0.6)
		if d <= 0.0:
			return -0.15
		return minf(d * 0.4, 1.3) + n * minf(d * 0.08, 0.35)
	# The grove's floor: soft mossy banks under the trees.
	return minf(d * 0.32, 0.9) + n * minf(d * 0.06, 0.25)


func pool_y() -> float:
	return 0.3   # (a hand deep over the basin, so the water shader reads depth, not shore foam)


# --- Build -------------------------------------------------------------------

func build() -> void:
	await _paths()
	await _terrain()
	await game._world_build_frame()
	_ridge_colliders()
	if kind == "winter":
		await _build_stonekeep()
	elif kind == "heartwood":
		await _build_heartwood()
	else:
		await _build_grove()


func _paths() -> void:
	## Paving down every corridor and over every plaza (the minimap draws
	## them from game.map_paths).
	var cob = game._stones()
	for s in segs:
		await game._world_build_frame()
		var a: Vector3 = pos[s[0]]
		var b: Vector3 = pos[s[1]]
		var w: float = clampf(s[2] * 2.0 - 1.4, 2.6, 5.4)
		if s[3] == "gate" or s[3] == "nook":
			continue   # the courtyard is flagged, the gate has a flagstone strip of its own; nooks are left wild
		if s[3] == "pass":
			w = 3.4
		if kind == "heartwood":
			if s[3] == "ring":
				continue   # the dais is paved itself
			# Narrow winding trails through the jungle, a little wider on the
			# loops and the middle road: the woods read, not a sea of cobbles.
			w = {"trail": 2.4, "loop": 3.0, "bridge": 3.0, "lane": 3.6}.get(s[3], w)
		game._add_path(a, b, w, cob, 0.0 if kind == "winter" else 1.2, s[3] == "pass" and ids[s[1]].begins_with("w"))   # (no verge on the snow: it read as a slab against the ridges)
	for sx in [-1.0, 1.0]:
		# The road runs on from the door court right up to the castle door.
		var g: Vector3 = node("g0" if sx < 0.0 else "g1")
		game._add_path(g, Vector3(sx * (game.CASTLE_X - game.CASTLE_DEPTH - 0.5), 0, 0), 5.0, cob, 0.0)
	for i in pos.size():
		var id: String = ids[i]
		if id.begins_with("g") or (id == "k" and kind == "winter") or id.begins_with("i"):
			continue
		await game._world_build_frame()
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rad[i] * 0.62
		cm.bottom_radius = rad[i] * 0.62
		cm.height = 0.02
		cm.radial_segments = 20
		cm.rings = 1
		disc.mesh = cm
		# The plaza is paved in the roads' own stones (it was a finer grey
		# cobble that met them abruptly), its rim fraying into the ground
		# like a road's (PATH_SHADER, radial).
		var r0: float = rad[i] * 0.62
		cm.top_radius = maxf(r0 - 1.1, 0.6)
		cm.bottom_radius = cm.top_radius
		disc.material_override = cob
		disc.position = pos[i] + Vector3(0, 0.034, 0)   # (+2 cm with the lanes, game._lane_lift)
		game.add_child(disc)
		var fr := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = r0 + 1.3
		fm.bottom_radius = fm.top_radius
		fm.height = 0.01
		fm.radial_segments = 28
		fm.rings = 1
		fr.mesh = fm
		var fmat: ShaderMaterial = cob.get_meta("fray").duplicate()
		fmat.set_shader_parameter("half_w", r0)
		fmat.set_shader_parameter("radial", true)
		fr.material_override = fmat
		fr.position = pos[i] + Vector3(0, 0.0305, 0)
		game.add_child(fr)


func _terrain() -> void:
	## The ground off the lanes as one mesh in 24 m chunks: vertex colour red
	## is the top texture's share (flat tops), green a little ambient
	## occlusion in the folds.
	var step := 1.0
	var nx := int(MESH_X * 2.0 / step) + 1
	var nz := int(EDGE_Z * 2.0 / step) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		if j % 12 == 0:
			await game._world_build_frame()
		for i in nx:
			var hv: float = height(-MESH_X + i * step, -EDGE_Z + j * step)
			if hv > 0.0:
				# Eased off the foot (visual only; the colliders keep height()): the bank rose
				# at a fixed 45 degrees straight from the ruin's flat edge, a long straight crease.
				hv *= smoothstep(0.0, 2.6 if kind == "winter" else 0.5, hv)
			hs[j * nx + i] = hv
	# One 3x3 blur over the visual heights: the 1 m facets' creases are what the ink pass
	# (a depth-fold edge detector) drew as thin angular seams across the snow and the lawn.
	var hb := hs.duplicate()
	for j in range(1, nz - 1):
		for i in range(1, nx - 1):
			var acc := 0.0
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					acc += hs[(j + dj) * nx + i + di]
			hb[j * nx + i] = maxf(acc / 9.0, -0.15) if hs[j * nx + i] > -0.15 or acc / 9.0 > 0.0 else -0.15
	hs = hb
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	mat.shader = sh
	# Tops wear the field's own ground (snow / dusk meadow) in the colour the
	# season grade gives it; faces are rock (Stonekeep) or mossy litter.
	var ground: StandardMaterial3D = game._grass()
	mat.set_shader_parameter("top_tex", ground.albedo_texture)
	mat.set_shader_parameter("top_tint", Season.surface(kind, ground.albedo_color))
	mat.set_shader_parameter("top_scale", ground.uv1_scale.x)
	if kind == "winter":
		mat.set_shader_parameter("face_tex", load("res://assets/textures/rock_color.jpg"))
		mat.set_shader_parameter("face_tint", Color(0.76, 0.81, 0.92))
	elif kind == "heartwood":
		mat.set_shader_parameter("face_tex", load("res://assets/textures/moss_color.jpg"))
		mat.set_shader_parameter("face_tint", Color(0.55, 0.62, 0.42))
	else:
		mat.set_shader_parameter("face_tex", load("res://assets/textures/moss_color.jpg"))
		mat.set_shader_parameter("face_tint", Color(0.42, 0.4, 0.58))
	var chunk := 24
	var cj := 0
	while cj < nz - 1:
		var ci := 0
		while ci < nx - 1:
			await game._world_build_frame()
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var any := false
			for j in range(cj, mini(cj + chunk, nz - 1)):
				for i in range(ci, mini(ci + chunk, nx - 1)):
					var h00: float = hs[j * nx + i]
					var h10: float = hs[j * nx + i + 1]
					var h01: float = hs[(j + 1) * nx + i]
					var h11: float = hs[(j + 1) * nx + i + 1]
					if h00 <= 0.0 and h10 <= 0.0 and h01 <= 0.0 and h11 <= 0.0:
						continue   # walkable ground: the field's own ground shows
					any = true
					var x0 := -MESH_X + i * step
					var z0 := -EDGE_Z + j * step
					var quad := [Vector3(x0, h00, z0), Vector3(x0 + step, h10, z0), Vector3(x0 + step, h11, z0 + step), Vector3(x0, h01, z0 + step)]
					for tri in [[0, 1, 2], [0, 2, 3]]:
						var a: Vector3 = quad[tri[0]]
						var b: Vector3 = quad[tri[1]]
						var c: Vector3 = quad[tri[2]]
						var nrm := (c - a).cross(b - a).normalized()
						if nrm.y < 0.0:
							nrm = -nrm
						for v in [a, b, c]:
							st.set_normal(_vnormal(hs, nx, nz, step, v))
							st.set_color(_vcolor(v, _vnormal(hs, nx, nz, step, v)))
							st.add_vertex(v)
			if any:
				var mi := MeshInstance3D.new()
				mi.mesh = st.commit()
				mi.material_override = mat
				mi.set_meta("terrain", true)
				game.add_child(mi)
			ci += chunk
		cj += chunk


func _vnormal(hs: PackedFloat32Array, nx: int, nz: int, step: float, v: Vector3) -> Vector3:
	var i := clampi(int(round((v.x + MESH_X) / step)), 0, nx - 1)
	var j := clampi(int(round((v.z + EDGE_Z) / step)), 0, nz - 1)
	var hl: float = maxf(hs[j * nx + maxi(i - 1, 0)], 0.0)
	var hr: float = maxf(hs[j * nx + mini(i + 1, nx - 1)], 0.0)
	var hu: float = maxf(hs[maxi(j - 1, 0) * nx + i], 0.0)
	var hd: float = maxf(hs[mini(j + 1, nz - 1) * nx + i], 0.0)
	return Vector3(hl - hr, 2.0 * step, hu - hd).normalized()


func _vcolor(v: Vector3, n: Vector3) -> Color:
	## Red: the top texture's share (snow on the flat, rock on the faces;
	## the grove's moss on top, litter on the banks). Green: light in the folds.
	var top: float
	if kind == "winter":
		# Snow holds on all but the steepest rock, and frosts even that
		# (final grade 2026-11-04: the gentle banks showed as grey smudges).
		top = smoothstep(0.42, 0.7, n.y)
		top = maxf(top, smoothstep(5.2, 6.6, v.y) * 0.8)   # snow caps on the high ground
		top = maxf(top, 0.35)
	else:
		top = smoothstep(0.75, 0.95, n.y)
	var lit := 1.0   # (no fold darkening: the foothills must match the open ground)
	return Color(top, lit, smoothstep(-0.02, 0.3, v.y))


func _ridge_colliders() -> void:
	## Shots stop at the ridges (and the grove's banks don't block anything:
	## the trunks do). Boxes over every cell well off the lanes, run along x.
	if kind != "winter":
		return
	var z := -36.0 + CELL / 2.0
	while z < 36.0:
		var run_start := INF
		var x := -MESH_X + CELL / 2.0
		while x <= MESH_X:
			var p := Vector3(x, 0, z)
			var solid: bool = x < MESH_X and sdf(p) > 1.8 and height(x, z) > 1.4
			if solid and run_start == INF:
				run_start = x
			elif not solid and run_start != INF:
				var x0: float = run_start - CELL / 2.0
				var x1: float = x - CELL / 2.0
				game._add_collider(Vector3((x0 + x1) / 2.0, 1.5, z), Vector3(x1 - x0, 3.0, CELL))
				run_start = INF
			x += CELL
		z += CELL


func _scatter_off(min_d: float, max_d: float, spacing: float, seed_v: int, jitter: float = 0.4) -> Array:
	## Jittered grid points between min_d and max_d off the walkable ground.
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := []
	var z := -EDGE_Z + spacing / 2.0
	while z < EDGE_Z:
		var x := -MESH_X + spacing / 2.0
		while x < MESH_X:
			var p := Vector3(x + r.randf_range(-jitter, jitter) * spacing, 0, z + r.randf_range(-jitter, jitter) * spacing)
			if absf(p.x) < MESH_X - 2.5:
				var d := sdf(p)
				var flat := false
				for f in flats:
					if _rect_dist(p, f[0], f[1]) < 0.5:
						flat = true
				if d >= min_d and d <= max_d and not flat:
					out.append(p)
			x += spacing
		z += spacing
	return out


# --- Stonekeep Fortress ------------------------------------------------------

func _build_stonekeep() -> void:
	# The ruin: a curtain wall round the courtyard with a gate east and west,
	# a round tower either side of each gate, flagstones inside.
	game.grey = true
	game.audit_label = "ruin"
	var floor_mat = game._uneven_flagstone(Color(0.86, 0.88, 0.92))
	var main_floor: ShaderMaterial = floor_mat.duplicate()
	main_floor.set_shader_parameter("center", Vector2(0.0, 0.0))
	main_floor.set_shader_parameter("half_ext", Vector2(9.8, 7.7))
	game._add_block(Vector3(0, 0.012, 0), Vector3(19.6, 0.02, 15.4), Color.WHITE, false, main_floor)
	for sx in [-1.0, 1.0]:
		await game._world_build_frame()
		# North and south walls (broken in two places each).
		# (The south wall, toward the camera, is ruined lower so it never
		# hides the courtyard fight.)
		var wz: float = sx * 8.0
		var wh: float = 3.0 if sx < 0.0 else 1.8
		game._add_wall(Vector3(-6.2, wh / 2.0, wz), Vector3(8.6, wh, 1.0))
		game._add_wall(Vector3(6.2, wh / 2.0, wz), Vector3(8.6, wh, 1.0))
		game._add_wall(Vector3(0, 0.6, wz), Vector3(3.8, 1.2, 1.0), false)   # the broken middle
		# The gate walls: x = +-10, the gate gap |z| < 2.4.
		for zs in [-1.0, 1.0]:
			var gh: float = 3.0 if zs < 0.0 else 2.0
			game._add_wall(Vector3(sx * 10.0, gh / 2.0, zs * 5.9), Vector3(1.0, gh, 4.2))
		# Flagstones through the gate and down the pass to its plaza.
		var gate_floor: ShaderMaterial = floor_mat.duplicate()
		gate_floor.set_shader_parameter("center", Vector2(sx * 12.3, 0.0))
		gate_floor.set_shader_parameter("half_ext", Vector2(3.4, 3.6))   # (wider than the gap: its fade lies under the towers and over the road end)
		game._add_block(Vector3(sx * 12.3, 0.013, 0), Vector3(6.8, 0.02, 7.2), Color.WHITE, false, gate_floor)
		game.map_marks.append([Vector3(sx * 12.8, 0, 0), "gate"])   # (keeps snowmen and drifts out of the gateway)
		await game._world_build_frame()
		for zs in [-1.0, 1.0]:
			_tower(Vector3(sx * 10.0, 0, zs * 3.6), 1.15, 4.6 if zs < 0.0 else 2.2)   # the south one a stump: the gate stays in view
		_tower(Vector3(sx * 10.0, 0, 8.0), 1.0, 2.4)
		_tower(Vector3(sx * 10.0, 0, -8.0), 1.0, 3.4)
		# A broken lintel stub over each gate, high enough to see under.
		game._add_block(Vector3(sx * 10.0, 4.3, -2.7), Vector3(1.3, 0.7, 1.8), Color.WHITE, false, game._ashlar())
		# Torches by the gates.
		game._add_torch(Vector3(sx * 8.0, 0, -2.8))
		game._add_torch(Vector3(sx * 8.0, 0, 2.8))
	game.audit_label = ""
	game.grey = false
	await game._world_build_frame()
	# Broken columns and rubble along the inside of the north and south walls
	# (the SE one stands clear of the wall stub's rubble at 4.9, 5.8).
	for c in [Vector3(-5.5, 0, -6.6), Vector3(6.6, 0, 6.6), Vector3(2.4, 0, -6.6), Vector3(-2.4, 0, 6.6)]:
		game._prop("dungeon/column", c, 1.1 if c.x > 0.0 else 0.75, 0.0)
		game._add_collider(c + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))
	game._prop("dungeon/rubble_large", Vector3(0, 0, -5.7), 0.35, 0.3)
	game._prop("dungeon/rubble_large", Vector3(0, 0, 5.7), 0.35, 2.1)
	# Banners of both sides on the gate towers: the ruin is no one's.
	for sx in [-1.0, 1.0]:
		game._add_flag(Vector3(sx * 10.0, 4.6, -3.6), 0 if sx < 0.0 else 1, -sx)
	game.map_marks.append([Vector3.ZERO, "keep"])
	await game._world_build_frame()
	# The frozen tarns on the flank lanes: the ice-bound river's crossings.
	for zs in [-1.0, 1.0]:
		var c := Vector3(0, 0, zs * 27.0)
		_ice(c, 6.6, 4.8)
		# The frozen river runs on north/south into the ridges (in its gorge).
		_ice(Vector3(0, 0, zs * 35.0), 2.2, 4.0)
		game.map_marks.append([c, "tarn"])
	await game._world_build_frame()
	# Crags at the foot of the ridges, so the lane edges read as rock.
	var r := RandomNumberGenerator.new()
	r.seed = 5501
	var rock_mat = game._pbr("rock", 0.45, Color(0.82, 0.86, 0.94))
	var n := 0
	for p in _scatter_off(0.6, 1.6, 3.4, 5502, 0.3):
		if absf(p.z) > 36.0:
			continue
		if _near_flat(p, 1.0):
			continue
		n += 1
		if n % 8 == 0:
			await game._world_build_frame()
		var mi := MeshInstance3D.new()
		mi.mesh = game._rock_mesh(r.randi() % 997, r.randf_range(0.8, 1.5))
		mi.material_override = rock_mat
		mi.position = Vector3(p.x, maxf(height(p.x, p.z), 0.0) * 0.5 + 0.2, p.z)
		mi.rotation.y = r.randf() * TAU
		mi.scale = Vector3(1.0, r.randf_range(0.7, 1.2), 1.0)
		game.add_child(mi)
	# Snowy pines up on the ridges.
	var bark = game._tree_bark()
	for p in _scatter_off(3.0, 30.0, 5.0, 5503, 0.45):
		n += 1
		if n % 6 == 0:
			await game._world_build_frame()
		var tr := RandomNumberGenerator.new()
		tr.seed = absi(int(p.x * 13 + p.z * 7))
		var at := Vector3(p.x, height(p.x, p.z) - 0.2, p.z)
		if game._kit():
			game._kit().tree_at(at, tr.randf() < 0.3, "pine")   # the forest kit's snowy pines
		else:
			var tree := Node3D.new()
			tree.position = at
			tree.rotation.y = tr.randf() * TAU
			game.add_child(tree)
			game._add_pine(tree, tr, bark, tr.randf() < 0.3)
		if absf(p.z) < 36.0:
			game.map_trees.append(Vector3(p.x, 0.0, p.z))


func lane_dist(p: Vector3) -> float:
	## Distance from `p` to the lanes, plazas and courtyards (not the castles'
	## land), negative on them.
	var d := INF
	for i in pos.size():
		d = minf(d, _flat(p, pos[i]) - rad[i])
	for s in segs:
		d = minf(d, _seg_dist(p, pos[s[0]], pos[s[1]]) - s[2])
	for r in rects:
		d = minf(d, _rect_dist(p, r[0], r[1]))
	return d


func decor_ok(p: Vector3, m: float) -> bool:
	## Whether scenery (the forest kit's trees, bushes, rocks, flowers) may
	## stand at `p` with margin m: off every lane and plaza, out of the
	## ruin and the pool.
	if absf(p.x) > MESH_X + 6.0 + m:
		return true
	if lane_dist(p) < m + 0.6:
		return false
	return not _near_flat(p, m + 0.3)


func in_flat(p: Vector3) -> bool:
	return _near_flat(p, 0.0)


func _in_heart(p: Vector3, m: float) -> bool:
	return kind == "heartwood" and Vector2(p.x, p.z).length() < SEATS_OUT + 0.6 + m


func _near_flat(p: Vector3, m: float) -> bool:
	if kind == "heartwood" and (_in_heart(p, m) or brook_dist(p) < BROOK_HALF + 0.6 + m):
		return true   # the amphitheatre and the Heartbrook stay clear of scenery
	for f in flats:
		if _rect_dist(p, f[0], f[1]) < m:
			return true
	return false


func _tower(at: Vector3, radius: float, h: float) -> void:
	## A round ruined tower: a stone drum with a broken crown, solid.
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = h
	shape.shape = cyl
	shape.position.y = h / 2.0
	body.add_child(shape)
	game.add_child(body)
	var stone = game._ashlar()
	var drum := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 1.1
	cm.height = h
	cm.radial_segments = 12
	drum.mesh = cm
	drum.position.y = h / 2.0
	drum.material_override = stone
	body.add_child(drum)
	# A cap ring and three broken merlons.
	var cap := MeshInstance3D.new()
	var capm := CylinderMesh.new()
	capm.top_radius = radius * 1.18
	capm.bottom_radius = radius * 1.18
	capm.height = 0.3
	capm.radial_segments = 12
	cap.mesh = capm
	cap.position.y = h + 0.1
	cap.material_override = game._ashlar(Color(0.92, 0.92, 0.95))
	body.add_child(cap)
	for k in 3:
		var a := TAU * k / 3.0 + at.x
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.55 - 0.15 * k, 0.5)
		m.mesh = bm
		m.position = Vector3(cos(a) * radius * 0.9, h + 0.5 - 0.07 * k, sin(a) * radius * 0.9)
		m.rotation.y = a
		m.material_override = stone
		body.add_child(m)
	game.audit_blocks.append(["wall", AABB(at - Vector3(radius, 0, radius), Vector3(radius * 2.0, h, radius * 2.0))])


var ice_sheets: Array = []   # [centre, rx, rz] of every ice sheet (on_ice: units slide there)


func on_ice(p: Vector3) -> bool:
	## True on a frozen tarn or the frozen river (the walkable sheet inside the rim).
	for s in ice_sheets:
		var c: Vector3 = s[0]
		var dx: float = (p.x - c.x) / s[1]
		var dz: float = (p.z - c.z) / s[2]
		if dx * dx + dz * dz < 1.0 and p.y < 0.6:
			return true
	return false


func _ice(c: Vector3, rx: float, rz: float) -> void:
	## A sheet of glossy cracked ice flush with the ground (ice.gdshader), with
	## a pale frosted rim. Units slide on it (on_ice, unit.gd).
	ice_sheets.append([c, rx, rz])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ice.gdshader")
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.9, 0.95, 1.0)
	rim.roughness = 0.6
	for k in 2:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.02
		cm.radial_segments = 28
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = rim if k == 0 else mat
		var grow := 0.5 if k == 0 else 0.0
		mi.scale = Vector3(rx + grow, 1.0, rz + grow)
		mi.position = c + Vector3(0, 0.018 + 0.004 * k, 0)
		game.add_child(mi)
	# (The cracks are drawn by the shader now: the four flat strips read as tape.)


# --- Twilight Grove ----------------------------------------------------------

func _build_grove() -> void:
	# The glowing pool and its shrine tree on an islet.
	var water := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = POOL_R
	cm.bottom_radius = POOL_R
	cm.height = 0.02
	cm.radial_segments = 40
	cm.rings = 1
	water.mesh = cm
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://assets/shaders/water.gdshader")
	wmat.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	wmat.set_shader_parameter("half_width", 1000.0)   # (the river shader's bank foam: none out in the pool...)
	wmat.set_shader_parameter("island_r", 2.5)        # (...only round the islet)
	wmat.set_shader_parameter("open_foam", 0.3)
	water.material_override = wmat
	water.position = Vector3(0, pool_y(), 0)
	game.add_child(water)
	# A deep basin under the see-through water, glowing faintly from below.
	var basin := MeshInstance3D.new()
	var bm0 := CylinderMesh.new()
	bm0.top_radius = POOL_R
	bm0.bottom_radius = POOL_R
	bm0.height = 0.01
	bm0.radial_segments = 40
	bm0.rings = 1
	basin.mesh = bm0
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.05, 0.16, 0.22)
	bmat.emission_enabled = true
	bmat.emission = Color(0.1, 0.45, 0.55)
	bmat.emission_energy_multiplier = 0.6
	bmat.roughness = 0.3
	basin.material_override = bmat
	basin.position = Vector3(0, 0.04, 0)
	game.add_child(basin)
	# A stone kerb round the water.
	var kerb = game._ashlar(Color(0.78, 0.76, 0.86))
	for k in 28:
		var a := TAU * k / 28.0
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.75, 0.44, 0.6)
		b.mesh = bm
		b.material_override = kerb
		b.position = Vector3(cos(a) * (POOL_R + 0.25), 0.22, sin(a) * (POOL_R + 0.25))
		b.rotation.y = -a + PI / 2.0
		game.add_child(b)
	await game._world_build_frame()
	# The islet and the shrine tree: a grown elven tree, glowing.
	var islet := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = 2.2
	im.bottom_radius = 2.6
	im.height = 0.5
	im.radial_segments = 16
	islet.mesh = im
	islet.material_override = game._pbr("moss", 0.5, Color(0.6, 0.62, 0.78))
	islet.position = Vector3(0, 0.2, 0)
	game.add_child(islet)
	game._add_tree_grown(Vector3(0, 0.4, 0), true)
	game.map_trees.append(Vector3(0, 1.0, 0))
	game._add_light(Vector3(0, 2.6, 0), Color(0.55, 0.95, 1.0), 2.2, 13.0)
	# Glowing stones and lily lights on the water.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.5, 0.95, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.45, 0.95, 1.0)
	glow.emission_energy_multiplier = 2.4
	var r := RandomNumberGenerator.new()
	r.seed = 6601
	for k in 14:
		var a := TAU * k / 14.0 + r.randf_range(-0.2, 0.2)
		var d := r.randf_range(3.4, POOL_R - 0.8)
		var lily := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.18
		lm.height = 0.18
		lm.is_hemisphere = true
		lm.radial_segments = 8
		lm.rings = 2
		lily.mesh = lm
		lily.material_override = glow
		lily.position = Vector3(cos(a) * d, pool_y() + 0.02, sin(a) * d)
		game.add_child(lily)
	game.map_marks.append([Vector3.ZERO, "pool"])
	await game._world_build_frame()
	# Lanterns round the ring (on the pool side, off the path).
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var p := Vector3(cos(a) * 10.6, 0, sin(a) * 10.6)
		game._prop("halloween/post_lantern", p, 0.75, -a)
		game._add_light(p + Vector3(0, 2.4, 0), Color(0.8, 0.6, 1.0), 0.9, 6.0)
	# The grove: trees packed on the banks between the paths, bushes and
	# fern clumps at their edges so the path edge reads.
	var n := 0
	var bark = game._tree_bark()
	for p in _scatter_off(2.4, 40.0, 3.9, 6602, 0.38):
		if absf(p.z) > 41.0 or Vector2(p.x, p.z).length() < POOL_R + 2.0:
			continue
		n += 1
		if n % 4 == 0:
			await game._world_build_frame()
		var big: bool = sdf(p) > 5.0 and (n % 3 == 0)
		var at := Vector3(p.x, maxf(height(p.x, p.z) - 0.1, 0.0), p.z)
		var seed_v := absi(int(p.x * 13 + p.z * 7))
		if p.x > 6.0 and seed_v % 2 == 0:
			# The Kingdom's half mixes in dark pines, as on the Wildwood.
			if game._kit():
				game._kit().tree_at(at, big, "pine")
			else:
				var tr := RandomNumberGenerator.new()
				tr.seed = seed_v
				var tree := Node3D.new()
				tree.position = at
				tree.rotation.y = tr.randf() * TAU
				game.add_child(tree)
				game._add_pine(tree, tr, bark, big)
			game.map_trees.append(Vector3(p.x, 1.0 if big else 0.0, p.z))
		else:
			game._add_tree_grown(at, big)
			game.map_trees.append(Vector3(p.x, 1.0 if big else 0.0, p.z))
	for p in _scatter_off(0.9, 2.0, 3.6, 6603, 0.3):
		if absf(p.z) > 36.0 or Vector2(p.x, p.z).length() < POOL_R + 1.5:
			continue
		n += 1
		if n % 6 == 0:
			await game._world_build_frame()
		game._add_bush(Vector3(p.x, maxf(height(p.x, p.z), 0.0), p.z), int(p.x * 7 + p.z * 3))


# --- The Wildwood: the Heart-Tree amphitheatre ---------------------------------

func _water_mat() -> ShaderMaterial:
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://assets/shaders/water.gdshader")
	wmat.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	wmat.set_shader_parameter("half_width", 1000.0)   # (no river-bank foam band: the kerbs and banks frame it)
	wmat.set_shader_parameter("island_r", 0.0)
	wmat.set_shader_parameter("open_foam", 0.25)
	return wmat


func _annulus(r0: float, r1: float, y: float, mat: Material, segs: int = 64) -> void:
	## A flat ring (the moat's water and its dark bed).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a0) * r1, 0, sin(a0) * r1),
			Vector3(cos(a1) * r1, 0, sin(a1) * r1), Vector3(cos(a1) * r0, 0, sin(a1) * r0)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for v in tri:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(p[v].x, p[v].z))
				st.add_vertex(p[v])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position.y = y
	game.add_child(mi)


func _ribbon(pts: Array, half: float, y: float, mat: Material) -> void:
	## A flat strip along a polyline (the Heartbrook's water and bed).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var side := Vector3(-dir.z, 0, dir.x) * half
		# Round joins: each piece runs half a width past its ends.
		var q := [a - side - dir * half * 0.5, a + side - dir * half * 0.5, b + side + dir * half * 0.5, b - side + dir * half * 0.5]
		for tri in [[0, 2, 1], [0, 3, 2]]:
			for v in tri:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(q[v].x, q[v].z))
				st.add_vertex(Vector3(q[v].x, 0, q[v].z))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position.y = y
	game.add_child(mi)


func _box_at(parent: Node3D, size: Vector3, at: Vector3, mat: Material, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


func _deck(centre: Vector3, along: Vector3, length: float, half: float, logs: bool) -> void:
	## A bridge over the water: planks (the moat) or split logs (the brook)
	## on two stringers, with a low rail each side. Walkers stay on the
	## corridor (walkable()), so the rails are only drawn.
	var pivot := Node3D.new()
	pivot.position = centre
	pivot.rotation.y = atan2(along.x, along.z)
	game.add_child(pivot)
	var dark = game._plank_dark(Color(0.86, 0.72, 0.54))
	var light = game._plank_dark(Color(0.94, 0.8, 0.62))
	var timber = game._timber(Color(0.72, 0.58, 0.44))
	var rail = game._timber(Color(0.9, 0.76, 0.58))
	for zs in [-1.0, 1.0]:
		_box_at(pivot, Vector3(0.3, 0.26, length), Vector3(zs * (half - 0.3), -0.1, 0), timber)
	var n := int(length / (0.62 if logs else 0.5))
	for k in n:
		var z := -length / 2.0 + (k + 0.5) * length / n
		if logs:
			var lg2 := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.26
			cm.bottom_radius = 0.26
			cm.height = half * 2.0 + 0.2
			cm.radial_segments = 8
			lg2.mesh = cm
			lg2.material_override = game._tree_bark()
			lg2.position = Vector3(0, -0.04, z)
			lg2.rotation.z = PI / 2.0
			lg2.scale = Vector3(0.45, 1.0, 1.0)   # split: flat side up
			pivot.add_child(lg2)
		else:
			_box_at(pivot, Vector3(half * 2.0, 0.1, length / n - 0.05), Vector3(0, 0.03, z), dark if k % 2 == 0 else light)
	# Rails: posts and a top bar.
	for xs in [-1.0, 1.0]:
		var x: float = xs * (half + 0.1)
		var posts := maxi(int(length / 1.6), 1)
		for k in posts + 1:
			_box_at(pivot, Vector3(0.16, 0.7, 0.16), Vector3(x, 0.35, -length / 2.0 + k * length / posts), timber)
		_box_at(pivot, Vector3(0.14, 0.12, length + 0.2), Vector3(x, 0.72, 0), rail)


func _crossing(a: Vector3, b: Vector3) -> Vector3:
	## Where the corridor a-b crosses the Heartbrook (INF if it does not).
	for sgn in [1.0, -1.0]:
		for k in BROOK.size() - 1:
			var c: Vector3 = BROOK[k] * sgn
			var d: Vector3 = BROOK[k + 1] * sgn
			var r := Vector2(b.x - a.x, b.z - a.z)
			var s := Vector2(d.x - c.x, d.z - c.z)
			var den := r.x * s.y - r.y * s.x
			if absf(den) < 0.0001:
				continue
			var ca := Vector2(c.x - a.x, c.z - a.z)
			var t := (ca.x * s.y - ca.y * s.x) / den
			var u := (ca.x * r.y - ca.y * r.x) / den
			if t > 0.0 and t < 1.0 and u >= 0.0 and u <= 1.0:
				return a.lerp(b, t)
	return Vector3.INF


func _build_heartwood() -> void:
	var stone = game._ashlar(Color(0.88, 0.86, 0.8))
	var mossy = game._ashlar(Color(0.72, 0.8, 0.62))
	# The moat: a dark bed under see-through water between stone kerbs.
	var bed := StandardMaterial3D.new()
	bed.albedo_color = Color(0.12, 0.3, 0.32)
	bed.roughness = 0.6
	_annulus(MOAT_IN - 0.2, MOAT_OUT + 0.2, 0.01, bed)
	var water := _water_mat()
	_annulus(MOAT_IN - 0.2, MOAT_OUT + 0.2, 0.04, water)
	await game._world_build_frame()
	for edge in [MOAT_IN - 0.25, MOAT_OUT + 0.25]:
		var count := int(TAU * edge / 1.5)
		for k in count:
			var a := TAU * (k + 0.5) / count
			var gap := false
			for q in 4:
				if absf(wrapf(a - q * PI / 2.0, -PI, PI)) < asin(2.6 / edge):
					gap = true   # a bridge lands here
			if gap:
				continue
			_box_at(game, Vector3(1.45, 0.34, 0.5), Vector3(cos(a) * edge, 0.17, sin(a) * edge), stone if k % 3 else mossy, -a + PI / 2.0)
	await game._world_build_frame()
	# The dais: a raised ring of cobbles round the tree, ramping down to the
	# bridges all the way round (walkable from anywhere: no ledge to stick on).
	var prof := [[0.0, HEART_TOP], [HEART_FLAT, HEART_TOP], [HEART_FOOT, 0.0], [MOAT_IN - 0.1, -0.05]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nseg := 48
	for k in nseg:
		var a0 := TAU * k / nseg
		var a1 := TAU * (k + 1) / nseg
		for i in prof.size() - 1:
			var r0: float = prof[i][0]
			var r1: float = prof[i + 1][0]
			var y0: float = prof[i][1]
			var y1: float = prof[i + 1][1]
			var q := [Vector3(cos(a0) * r0, y0, sin(a0) * r0), Vector3(cos(a0) * r1, y1, sin(a0) * r1),
				Vector3(cos(a1) * r1, y1, sin(a1) * r1), Vector3(cos(a1) * r0, y0, sin(a1) * r0)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for v in tri:
					var p: Vector3 = q[v]
					var slope := (y0 - y1) / maxf(r1 - r0, 0.01)
					var nrm := Vector3(cos(a0) * slope, 1.0, sin(a0) * slope).normalized()
					st.set_normal(nrm)
					st.set_uv(Vector2(p.x, p.z) * 0.25)
					st.add_vertex(p)
	var dais_mesh: ArrayMesh = st.commit()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = dais_mesh.create_trimesh_shape()
	body.add_child(shape)
	var dais := MeshInstance3D.new()
	dais.mesh = dais_mesh
	dais.material_override = game._stones()
	body.add_child(dais)
	game.add_child(body)
	# A carved kerb round the dais's top and a ring of glowing runes.
	var kc := 24
	for k in kc:
		var a := TAU * (k + 0.5) / kc
		_box_at(game, Vector3(1.1, 0.12, 0.34), Vector3(cos(a) * (HEART_FLAT + 0.1), HEART_TOP + 0.03, sin(a) * (HEART_FLAT + 0.1)), stone, -a + PI / 2.0)
	game._add_runes(Vector3(0, HEART_TOP - 0.03, 0), 2.6, Color(1.0, 0.6, 0.85))
	await game._world_build_frame()
	# The Heart-Tree: a giant blossom tree with glowing roots.
	var trunk_at := Vector3(0, HEART_TOP, 0)
	game._add_blocker(trunk_at, 1.9, 6.0)
	if game._kit():
		game._kit().kit_tree(game, "blossom", trunk_at + Vector3(0, 0.6, 0), 1.9, 0.6)
	else:
		game._add_tree_grown(trunk_at, true)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.7, 0.9)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.5, 0.8)
	glow.emission_energy_multiplier = 1.6
	var bark = game._tree_bark()
	# An ancient trunk, far thicker than the wood's, under the crown.
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.55
	tm.bottom_radius = 1.15
	tm.height = 3.6
	tm.radial_segments = 10
	trunk.mesh = tm
	trunk.material_override = bark
	trunk.position = trunk_at + Vector3(0, 1.8, 0)
	game.add_child(trunk)
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		var root := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.16
		rc.bottom_radius = 0.42
		rc.height = 1.5
		rc.radial_segments = 6
		root.mesh = rc
		root.material_override = bark
		root.position = Vector3(cos(a) * 1.15, HEART_TOP + 0.35, sin(a) * 1.15)
		root.rotation = Vector3(sin(a) * 0.85, 0, -cos(a) * 0.85)
		game.add_child(root)
		var bud := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.radial_segments = 8
		sm.rings = 4
		bud.mesh = sm
		bud.material_override = glow
		bud.position = Vector3(cos(a) * 2.35, HEART_TOP + 0.12, sin(a) * 2.35)
		game.add_child(bud)
	game._add_light(Vector3(0, HEART_TOP + 3.2, 0), Color(1.0, 0.72, 0.88), 1.8, 14.0)
	game.map_trees.append(Vector3(0, 1.0, 0))
	game.map_marks.append([Vector3.ZERO, "heart"])
	await game._world_build_frame()
	# The ruined amphitheatre: three tiers of stone seats in four arcs
	# between the bridges, some blocks fallen, a broken column at each end.
	var r := RandomNumberGenerator.new()
	r.seed = 7707
	for q in 4:
		var mid := PI / 4.0 + q * PI / 2.0
		for tier in 3:
			var rad: float = MOAT_OUT + 0.55 + tier * 0.55
			var h: float = 0.32 * (tier + 1)
			var span := deg_to_rad(15.0)
			var n := 6
			for k in n:
				if r.randf() < 0.14 * (tier + 1):
					continue   # fallen
				var a: float = mid - span + (k + 0.5) * span * 2.0 / n
				var arc_len: float = rad * span * 2.0 / n
				_box_at(game, Vector3(arc_len - 0.06, h, 0.52), Vector3(cos(a) * rad, h / 2.0, sin(a) * rad), stone if (k + tier) % 4 else mossy, -a + PI / 2.0)
		for e in [-1.0, 1.0]:
			var a: float = mid + e * deg_to_rad(19.0)
			var cp := Vector3(cos(a) * (MOAT_OUT + 1.1), 0, sin(a) * (MOAT_OUT + 1.1))
			game._prop("dungeon/column", cp, 0.7 if (q + int(e)) % 2 == 0 else 0.45, a)
		# A fallen block at the foot of each arc.
		var fa: float = mid + r.randf_range(-0.12, 0.12)
		_box_at(game, Vector3(0.9, 0.45, 0.6), Vector3(cos(fa) * (MOAT_OUT + 0.55), 0.2, sin(fa) * (MOAT_OUT + 0.55)), mossy, r.randf() * TAU)
	await game._world_build_frame()
	# The four moat bridges, with fire braziers at their outer heads.
	for q in 4:
		var a := q * PI / 2.0
		var dir := Vector3(cos(a), 0, sin(a))
		var mid_r := (HEART_FOOT + MOAT_OUT + 0.8) / 2.0
		_deck(dir * mid_r, dir, MOAT_OUT + 0.8 - HEART_FOOT + 0.6, 2.1, false)
		var side := Vector3(-dir.z, 0, dir.x)
		for e in [-1.0, 1.0]:
			game._add_stone_brazier(dir * (MOAT_OUT + 1.1) + side * e * 3.4, e > 0.0)
	await game._world_build_frame()
	# The Heartbrook: out of the moat to the north-east and the south-west,
	# with a log bridge wherever a path crosses it.
	var bed2 := bed.duplicate()
	for sgn in [1.0, -1.0]:
		var pts := []
		for p in BROOK:
			pts.append(p * sgn)
		# (Start it under the moat's kerb so the two waters meet.)
		pts[0] = pts[0].normalized() * (MOAT_OUT - 0.4) if pts[0].length() > 0.1 else pts[0]
		_ribbon(pts, BROOK_HALF + 0.15, 0.01, bed2)
		_ribbon(pts, BROOK_HALF + 0.15, 0.04, water)
		await game._world_build_frame()
	for s in segs:
		if s[3] in ["bridge", "ring"]:
			continue
		var a: Vector3 = pos[s[0]]
		var b: Vector3 = pos[s[1]]
		var c := _crossing(a, b)
		if c == Vector3.INF:
			continue
		var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		_deck(c, dir, BROOK_HALF * 2.0 + 2.4, minf(s[2], 2.3) - 0.1, false)
		game.map_marks.append([c, "logbridge"])
	game.map_marks.append([Vector3.ZERO, "brook"])
	await game._world_build_frame()
	# Pebbles and reeds along the brook's banks (off the paths).
	var pebble = game._pbr("rock", 0.45, Color(0.78, 0.8, 0.72))
	var reed := StandardMaterial3D.new()
	reed.albedo_color = Color(0.42, 0.62, 0.28)
	reed.roughness = 0.9
	var n := 0
	for sgn in [1.0, -1.0]:
		for k in BROOK.size() - 1:
			var a: Vector3 = BROOK[k] * sgn
			var b: Vector3 = BROOK[k + 1] * sgn
			var seg_len := Vector2(b.x - a.x, b.z - a.z).length()
			var dir := Vector3(b.x - a.x, 0, b.z - a.z) / seg_len
			var side := Vector3(-dir.z, 0, dir.x)
			var d := 1.0
			while d < seg_len:
				var e: float = 1.0 if int(d) % 2 == 0 else -1.0
				var p: Vector3 = a + dir * d + side * e * (BROOK_HALF + r.randf_range(0.3, 0.9))
				d += r.randf_range(1.6, 2.6)
				if lane_dist(p) < 0.8 or absf(p.z) > 38.0 or Vector2(p.x, p.z).length() < SEATS_OUT + 1.0:
					continue
				n += 1
				if n % 10 == 0:
					await game._world_build_frame()
				if n % 3 == 0:
					var mi := MeshInstance3D.new()
					mi.mesh = game._rock_mesh(r.randi() % 997, r.randf_range(0.3, 0.6))
					mi.material_override = pebble
					mi.position = p + Vector3(0, 0.08, 0)
					mi.rotation.y = r.randf() * TAU
					game.add_child(mi)
				else:
					for j in 3:
						var blade := _box_at(game, Vector3(0.06, r.randf_range(0.6, 1.0), 0.06), p + Vector3(r.randf_range(-0.25, 0.25), 0.4, r.randf_range(-0.25, 0.25)), reed)
						blade.rotation.z = r.randf_range(-0.25, 0.25)
	# Deer graze on the brook's banks out by the field's edge (and its twin).
	for sgn in [1.0, -1.0]:
		var c: Vector3 = Vector3(14.6, 0, -33.0) * sgn
		for k in 2:
			game._add_critter("deer", c + Vector3(0, 0, k * 2.5 * sgn), Rect2(c.x - 0.3, c.z - 3.5, 0.6, 7.0), 4400 + k + (0 if sgn > 0.0 else 10))
	await game._world_build_frame()
	# Ruined watchtowers over the far ends of the flank loops.
	for sgn in [1.0, -1.0]:
		_tower(Vector3(8.8, 0, -35.2) * sgn, 1.25, 4.2)
		_tower(Vector3(-3.6, 0, -36.4) * sgn, 0.9, 2.0)
		game._add_flag(Vector3(8.8, 4.2, -35.2) * sgn, 0 if sgn > 0.0 else 1, -sgn)
		game.map_marks.append([Vector3(8.8, 0, -35.2) * sgn, "tower"])
	await game._world_build_frame()
	# The jungle: trees packed on the banks between the paths, big ones
	# deep in, bushes and mushroom rings at the edges, fireflies in the glades.
	for p in _scatter_off(1.9, 40.0, 3.1, 7702, 0.42):
		if absf(p.z) > 41.0 or _near_flat(p, 1.0):
			continue
		n += 1
		if n % 4 == 0:
			await game._world_build_frame()
		var big: bool = sdf(p) > 4.5 and (n % 3 == 0)
		var at := Vector3(p.x, maxf(height(p.x, p.z) - 0.1, 0.0), p.z)
		game._add_tree_grown(at, big)
		game.map_trees.append(Vector3(p.x, 1.0 if big else 0.0, p.z))
	for p in _scatter_off(0.8, 1.8, 2.5, 7703, 0.35):
		if absf(p.z) > 36.0 or _near_flat(p, 0.5):
			continue
		n += 1
		if n % 6 == 0:
			await game._world_build_frame()
		game._add_bush(Vector3(p.x, maxf(height(p.x, p.z), 0.0), p.z), int(p.x * 7 + p.z * 3))
	var ring_n := 0
	for p in _scatter_off(1.6, 3.0, 9.0, 7704, 0.3):
		if absf(p.z) > 34.0 or _near_flat(p, 1.0):
			continue
		ring_n += 1
		if ring_n % 3 == 0:
			game._add_mushrooms(Vector3(p.x, maxf(height(p.x, p.z), 0.0), p.z), 300 + ring_n)
	for id in ["j0", "j1", "k0", "k1", "b0", "b1"]:
		game._add_fireflies(node(id) + Vector3(0, 0.4, 0))
	game._add_fireflies(Vector3(0, HEART_TOP + 1.0, 0))
	# Fallen giant logs in the undergrowth.
	var logs := 0
	for p in _scatter_off(4.0, 8.0, 11.0, 7705, 0.3):
		if absf(p.z) > 34.0 or _near_flat(p, 2.0) or logs >= 6:
			continue
		logs += 1
		var lg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.6
		cm.height = 4.2
		cm.radial_segments = 9
		lg.mesh = cm
		lg.material_override = bark
		lg.position = Vector3(p.x, height(p.x, p.z) + 0.35, p.z)
		lg.rotation = Vector3(0, r.randf() * TAU, PI / 2.0)
		game.add_child(lg)
		var mi2 := MeshInstance3D.new()
		var mm := SphereMesh.new()
		mm.radius = 0.55
		mm.height = 0.5
		mm.radial_segments = 8
		mm.rings = 3
		mi2.mesh = mm
		mi2.material_override = game._moss()
		mi2.position = lg.position + Vector3(0, 0.45, 0)
		game.add_child(mi2)
