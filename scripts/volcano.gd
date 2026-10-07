extends RefCounted
## Ember Pass: the volcano map (Faisal's concept art, 2026-10-07). Each
## faction's castle stands on its own basalt plateau above a sea of lava. A
## stone causeway runs from each castle door to a watch post; from there
## bridges cross the lava to the Crossing (north) and to the Fire Objective
## (south), and a grand stair links the two in the middle. The team holding
## the Fire Objective fights in FIRE form (see Stats.FIRE_FORM).
##
## Walkable ground is a small graph: round plazas (nodes) joined by straight
## corridors (edges), plus each castle's plateau. Units are kept on it by
## clamp_walk() (nobody can step into the lava) and bots path along the graph
## with route().

const Stats = preload("res://scripts/stats.gd")

# Plazas: [centre, radius]. Mirrored in x: g/m are each side's door court and
# watch post, c the Crossing, f the Fire Objective.
const NODES := {
	"g0": [Vector3(-45, 0, 0), 4.5], "m0": [Vector3(-27, 0, 0), 6.5],
	"c": [Vector3(0, 0, -17), 7.5], "f": [Vector3(0, 0, 17), 9.0],
	"m1": [Vector3(27, 0, 0), 6.5], "g1": [Vector3(45, 0, 0), 4.5],
}
# Corridors: [from, to, half width, kind].
const EDGES := [
	["g0", "m0", 3.4, "causeway"], ["m0", "c", 2.6, "bridge"], ["m0", "f", 2.6, "bridge"],
	["g1", "m1", 3.4, "causeway"], ["m1", "c", 2.6, "bridge"], ["m1", "f", 2.6, "bridge"],
	["c", "f", 3.2, "stairs"],
]
const LAND_X := 41.0      # each castle's plateau starts this far out (|x|)...
const LAND_X1 := 93.0     # ...and ends here
const LAND_Z := 15.0      # half-width of the plateau (z)
const LAVA_Y := -1.6
const FIRE_POS := Vector3(0, 0, 17)
const CROSSING := Vector3(0, 0, -17)

var game
var ids: Array = []        # node names, index = graph vertex
var pos: Array = []        # their centres
var rad: Array = []        # their radii
var dist: Array = []       # all-pairs path length
var nxt: Array = []        # next hop on the shortest path
var segs: Array = []       # [a index, b index, half, kind]

# The Fire Objective: progress runs from -1 (the Elves hold it) to +1 (the
# Humans hold it); the owner changes at the ends and goes neutral at 0.
var fire_owner := -1
var fire_progress := 0.0
var fire_counts := [0, 0]
var fire_contested := false
var fire_held := [0.0, 0.0]   # seconds each team held it this match (demo report)
var fire_captures := [0, 0]
var ring_mat: StandardMaterial3D
var core: Node3D
var core_mats: Array = []
var fire_light: OmniLight3D
var lava_mat: ShaderMaterial
var cover_props: Array = []  # big props by the plazas the obelisks keep clear of
# For the map: where the obelisks, spike clusters and the beasts' bones are.
var deco_obelisks: Array = []
var deco_spikes: Array = []
var deco_bones: Array = []   # [centre, yaw, length]


func _init(p_game) -> void:
	game = p_game
	for id in NODES:
		ids.append(id)
		pos.append(NODES[id][0])
		rad.append(NODES[id][1])
	for e in EDGES:
		segs.append([ids.find(e[0]), ids.find(e[1]), e[2], e[3]])
	_build_graph()


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


# --- Walkable ground ---------------------------------------------------------

func castle_of(p: Vector3) -> int:
	## Which team's plateau `p` is on, or -1 out over the lava network.
	if absf(p.x) >= LAND_X and absf(p.x) <= LAND_X1 and absf(p.z) <= LAND_Z:
		return 0 if p.x < 0.0 else 1
	return -1


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (ap - ab * t).length()


func walkable(p: Vector3, margin: float = 0.0) -> bool:
	if castle_of(p) >= 0:
		return true
	for i in pos.size():
		if _flat(p, pos[i]) < rad[i] - margin:
			return true
	for s in segs:
		if _seg_dist(p, pos[s[0]], pos[s[1]]) < s[2] - margin:
			return true
	return false


func clamp_walk(p: Vector3) -> Vector3:
	## `p` if it is on solid ground, else the nearest point that is.
	if walkable(p):
		return p
	var best := p
	var best_d := INF
	for side in [-1.0, 1.0]:
		var q := Vector3(side * clampf(side * p.x, LAND_X + 0.05, LAND_X1 - 0.05), p.y, clampf(p.z, -LAND_Z + 0.05, LAND_Z - 0.05))
		var d := _flat(p, q)
		if d < best_d:
			best_d = d
			best = q
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
	return best


func _straight(a: Vector3, b: Vector3) -> bool:
	## Whether the straight walk from a to b stays on solid ground.
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
	for s in segs:
		if _seg_dist(p, pos[s[0]], pos[s[1]]) < s[2] + 0.3:
			return [s[0], s[1]]
	var best := 0
	for i in pos.size():
		if _flat(p, pos[i]) - rad[i] < _flat(p, pos[best]) - rad[best]:
			best = i
	return [best]


func route(from: Vector3, to: Vector3) -> Vector3:
	## The next point to walk toward on the way to `to` over the plazas and
	## bridges. Castle doors, keeps and ramps are left to the game's own
	## routing, which takes this as its target.
	if castle_of(from) >= 0 and castle_of(from) == castle_of(to):
		return to
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
		return pos[bi]   # inside a corridor (or the plateau): straight to its end
	if bi == bj:
		return pos[bi] if _flat(from, pos[bi]) > 1.0 else to
	var k: int = nxt[bi][bj]
	# Out of this plaza along the corridor to the next one: its mouth first,
	# then straight down the middle.
	var dir: Vector3 = (pos[k] - pos[bi])
	dir.y = 0.0
	var mouth: Vector3 = pos[bi] + dir.normalized() * maxf(rad[bi] - 1.2, 0.0)
	if _flat(from, mouth) > 1.3:
		return mouth
	return pos[k]


func fire_spot(offset: Vector3) -> Vector3:
	## Where a bot holding the Fire Objective stands.
	var o := Vector3(offset.x, 0, offset.z) * 1.6
	if o.length() > 5.0:
		o = o.normalized() * 5.0
	return FIRE_POS + o


func blessing_spots() -> Array:
	return [CROSSING, Vector3(0, 0, 0), Vector3(-13.5, 0, -8.5), Vector3(13.5, 0, -8.5),
		Vector3(-13.5, 0, 8.5), Vector3(13.5, 0, 8.5)]


func heal_orb_spots() -> Array:
	var fx: float = game.CASTLE_X - game.CASTLE_DEPTH
	var out := []
	for sx in [-1.0, 1.0]:
		out.append(Vector3(sx * (fx + 4.5), 0, 0))       # each castle yard
		out.append(Vector3(sx * 25.0, 0, 3.6))           # the watch posts
		out.append(Vector3(sx * 3.8, 0, -21.0))          # the Crossing
		out.append(Vector3(sx * 5.6, 0, 22.0))           # the Fire Objective's back
	return out


# --- The Fire Objective --------------------------------------------------------

func tick(delta: float) -> void:
	_animate(delta)
	if not game.playing or game.game_over or game.in_prep():
		return
	var s: Dictionary = Stats.FIRE_POINT
	fire_counts = [0, 0]
	for u in game.units:
		if not u.dead and u.global_position.y > -1.0 and _flat(u.global_position, FIRE_POS) < s.radius:
			fire_counts[u.team] += 1
	fire_contested = fire_counts[0] > 0 and fire_counts[1] > 0
	var rate: float = 1.0 / s.capture_time
	if fire_contested:
		pass   # a fight on the point freezes it
	elif fire_counts[0] > 0 or fire_counts[1] > 0:
		var t := 0 if fire_counts[0] > 0 else 1
		var n: int = mini(fire_counts[t], s.max_count)
		var step: float = rate * (1.0 + s.extra_rate * (n - 1)) * delta
		fire_progress = clampf(fire_progress + (-step if t == 0 else step), -1.0, 1.0)
	else:
		# Left alone it settles back: to its holder, or to neutral.
		var rest := 0.0 if fire_owner < 0 else (-1.0 if fire_owner == 0 else 1.0)
		fire_progress = move_toward(fire_progress, rest, rate * s.settle * delta)
	if fire_owner == 0 and fire_progress >= 0.0 or fire_owner == 1 and fire_progress <= 0.0:
		_set_owner(-1)
	if fire_progress <= -1.0 and fire_owner != 0:
		_set_owner(0)
	elif fire_progress >= 1.0 and fire_owner != 1:
		_set_owner(1)
	if fire_owner >= 0:
		fire_held[fire_owner] += delta


func _set_owner(team: int) -> void:
	var was := fire_owner
	fire_owner = team
	if game.demo:
		print("FIRE t=%d owner=%s" % [game.match_clock(), ["Elves", "Humans"][team] if team >= 0 else "none"])
	if team >= 0:
		fire_captures[team] += 1
		var name: String = Stats.FACTIONS[team].name
		game.announce("%s HOLD THE FIRE! Their classes burn in FIRE form." % name.to_upper())
		game.chat_system("The %s captured the Fire Objective." % name)
		game.sfx.ui("horn", -4.0, 0.8)
		game.spawn_pillar(FIRE_POS, Color(1.0, 0.55, 0.15), 9.0, 1.4)
		game.spawn_ring(FIRE_POS, Stats.FIRE_POINT.radius, game._team_color(team), 0.9)
		game.spawn_flash(FIRE_POS + Vector3(0, 3, 0), Color(1.0, 0.5, 0.15), 6.0, 0.6)
		game.shake_at(FIRE_POS, 0.25)
	elif was >= 0:
		game.toast("The %s lost the Fire Objective" % Stats.FACTIONS[was].name, Color(1.0, 0.65, 0.35))
		game.chat_system("The Fire Objective is neutral again.")
	for u in game.units:
		u.refresh_fire()


func holds_fire(team: int) -> bool:
	return fire_owner == team


func bots_wanted(team: int) -> int:
	## How many bots a team sends to the Fire Objective.
	var s: Dictionary = Stats.FIRE_POINT
	var enemies_on: bool = fire_counts[1 - team] > 0
	if fire_owner != team:
		return s.bots_take + (1 if enemies_on else 0)
	return s.bots_hold + (1 if enemies_on else 0)


func status(my_team: int) -> Dictionary:
	## The HUD's line about the Fire Objective.
	var p := absf(fire_progress)
	var lead := -1 if absf(fire_progress) < 0.001 else (0 if fire_progress < 0.0 else 1)
	var text := ""
	var color := Color(0.35, 0.12, 0.04)
	if fire_contested:
		text = "The Fire Objective is contested."
	elif fire_owner >= 0 and p >= 0.999:
		text = "%s hold the Fire Objective: their classes take Fire form." % Stats.FACTIONS[fire_owner].name
		color = game._team_color(fire_owner).darkened(0.45)
	elif fire_counts[0] + fire_counts[1] > 0 and lead >= 0:
		text = "%s are capturing the Fire Objective: %d%%" % [Stats.FACTIONS[lead].name, int(p * 100.0)]
		color = game._team_color(lead).darkened(0.45)
	elif fire_owner >= 0:
		text = "%s hold the Fire Objective: their classes take Fire form." % Stats.FACTIONS[fire_owner].name
		color = game._team_color(fire_owner).darkened(0.45)
	else:
		text = "Capture the Fire Objective to unlock Fire classes."
	return {"text": text, "color": color, "progress": fire_progress, "owner": fire_owner, "contested": fire_contested}


func _animate(delta: float) -> void:
	if core == null:
		return
	core.rotation.y += delta * 0.6
	var t := Time.get_ticks_msec() / 1000.0
	core.position.y = 2.6 + sin(t * 1.3) * 0.18
	var tint := Color(1.0, 0.55, 0.15)
	if fire_owner >= 0:
		tint = Color(1.0, 0.55, 0.15).lerp(game._team_color(fire_owner).lightened(0.2), 0.55)
	elif absf(fire_progress) > 0.01:
		var lead := 0 if fire_progress < 0.0 else 1
		tint = Color(1.0, 0.55, 0.15).lerp(game._team_color(lead).lightened(0.2), absf(fire_progress) * 0.5)
	var pulse := 1.0 + (0.6 * sin(t * 10.0) if fire_contested else 0.15 * sin(t * 2.0))
	if ring_mat:
		ring_mat.albedo_color = Color(tint.r * 1.6, tint.g * 1.6, tint.b * 1.6)
		ring_mat.emission = tint
		ring_mat.emission_energy_multiplier = 1.6 * pulse
	if fire_light:
		fire_light.light_energy = 1.4 * pulse
		fire_light.light_color = tint


# --- Building the world ------------------------------------------------------------

func basalt(tint: Color = Color(0.25, 0.19, 0.2)) -> StandardMaterial3D:
	return game._pbr("rock", 0.22, tint)


func _mesh(mesh: Mesh, at: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	m.rotation = rot
	m.material_override = mat
	if not shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(m)
	return m


func _box(at: Vector3, size: Vector3, mat: Material, yaw: float = 0.0, shadow: bool = true) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, at, mat, Vector3(0, yaw, 0), shadow)


func build() -> void:
	## Everything but the castles (game.gd builds those as on every map).
	_build_floor()
	_build_lava()
	_build_plateaus()
	for s in segs:
		_build_corridor(s)
	for i in pos.size():
		_build_plaza(i)
	_build_fire_objective()
	_build_crossing()
	for t in 2:
		_build_watch_post(t)
	_build_spires()
	_build_volcano()
	_build_embers()
	_build_demonic()


func _build_floor() -> void:
	## Invisible ground at y 0 everywhere (the cellars sunk as usual), so
	## shots and drops land; clamp_walk() keeps walkers off the lava.
	var gx: float = game.map_half.x + 40.0
	var gz: float = game.map_half.y + 30.0
	var h0: float = game.CASTLE_X + game.CASTLE_DEPTH - 0.5
	var h1: float = game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH + 0.5
	var hz: float = game.CELLAR_HALF_Z + 0.5
	var lane: float = game.CASTLE_X + game.CASTLE_DEPTH - 2.0
	game._add_collider(Vector3(0, -0.5, 0), Vector3(lane * 2, 1, gz * 2))
	for sx in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			game._add_collider(Vector3(sx * (lane + h0) / 2.0, -0.5, zs * (1.9 + gz) / 2.0), Vector3(h0 - lane, 1, gz - 1.9))
			game._add_collider(Vector3(sx * (h0 + h1) / 2.0, -0.5, zs * (hz + gz) / 2.0), Vector3(h1 - h0, 1, gz - hz))
		game._add_collider(Vector3(sx * (h1 + gx) / 2.0, -0.5, 0), Vector3(gx - h1, 1, gz * 2))


func _build_lava() -> void:
	lava_mat = ShaderMaterial.new()
	lava_mat.shader = load("res://assets/shaders/lava.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(320, 220)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var lava := _mesh(plane, Vector3(0, LAVA_Y, 0), lava_mat, Vector3.ZERO, false)
	lava.name = "Lava"
	# The lava lights everything from below: a few big warm fills.
	for p in [Vector3(-14, LAVA_Y + 1.2, 0), Vector3(14, LAVA_Y + 1.2, 0), Vector3(0, LAVA_Y + 1.2, -32), Vector3(0, LAVA_Y + 1.2, 32),
			Vector3(-30, LAVA_Y + 1.2, 22), Vector3(30, LAVA_Y + 1.2, 22), Vector3(-30, LAVA_Y + 1.2, -22), Vector3(30, LAVA_Y + 1.2, -22)]:
		game._add_light(p, Color(1.0, 0.16, 0.05), 0.65, 15.0)


func _skirt(at: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	## The craggy rock face under a platform, down into the lava.
	_box(at + Vector3(0, -size.y / 2.0 - 0.02, 0), Vector3(size.x, size.y, size.z), basalt(), yaw)
	# A darker, glowing-hot band where it meets the lava.
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.08, 0.02, 0.01)
	hot.emission_enabled = true
	hot.emission = Color(0.85, 0.1, 0.03)
	hot.emission_energy_multiplier = 0.14
	_box(at + Vector3(0, LAVA_Y + 0.12, 0), Vector3(size.x + 0.25, 0.3, size.z + 0.25), hot, yaw, false)


func _build_plateaus() -> void:
	## Each castle's plateau: dark rock with a cliff down to the lava, the
	## spawn cellar's hole left open as on the Wildwood.
	var h0: float = game.CASTLE_X + game.CASTLE_DEPTH - 0.5
	var h1: float = game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH + 0.5
	var hz: float = game.CELLAR_HALF_Z + 0.5
	var lane: float = game.CASTLE_X + game.CASTLE_DEPTH - 2.0
	var top := basalt(Color(0.38, 0.3, 0.29))
	var depth := absf(LAVA_Y) + 1.5
	for t in 2:
		var sx := -1.0 if t == 0 else 1.0
		var pieces := [
			[(LAND_X + lane) / 2.0, 0.0, lane - LAND_X, LAND_Z * 2.0],
			[(lane + h0) / 2.0, (1.9 + LAND_Z) / 2.0, h0 - lane, LAND_Z - 1.9],
			[(lane + h0) / 2.0, -(1.9 + LAND_Z) / 2.0, h0 - lane, LAND_Z - 1.9],
			[(h0 + h1) / 2.0, (hz + LAND_Z) / 2.0, h1 - h0, LAND_Z - hz],
			[(h0 + h1) / 2.0, -(hz + LAND_Z) / 2.0, h1 - h0, LAND_Z - hz],
			[(h1 + LAND_X1) / 2.0, 0.0, LAND_X1 - h1, LAND_Z * 2.0]]
		for pc in pieces:
			_box(Vector3(sx * pc[0], -0.05, pc[1]), Vector3(pc[2], 0.1, pc[3]), top)
		# Cliffs round the outside only (the cellar hole keeps its own walls).
		var cx: float = sx * (LAND_X + LAND_X1) / 2.0
		var w: float = LAND_X1 - LAND_X
		for zs in [-1.0, 1.0]:
			_skirt(Vector3(cx, -0.1, zs * (LAND_Z - 0.6)), Vector3(w + 1.4, depth, 1.6))
		_skirt(Vector3(sx * (LAND_X + 0.6), -0.1, 0), Vector3(1.6, depth, LAND_Z * 2.0))
		_skirt(Vector3(sx * (LAND_X1 - 0.6), -0.1, 0), Vector3(1.6, depth, LAND_Z * 2.0))
		# Crags and boulders along the rim, clear of the door's causeway.
		var r := RandomNumberGenerator.new()
		r.seed = 77 + t
		var x := LAND_X + 1.0
		while x < LAND_X1:
			for zs in [-1.0, 1.0]:
				var p := Vector3(sx * x + r.randf_range(-0.6, 0.6), 0, zs * (LAND_Z - 0.5 + r.randf_range(-0.3, 0.6)))
				var rock := _mesh(game._rock_mesh(int(x * 13) + t * 7 + int(zs), r.randf_range(0.7, 1.3)), p + Vector3(0, 0.15, 0),
					basalt(Color(0.22, 0.17, 0.18)), Vector3(0, r.randf() * TAU, 0))
				rock.scale = Vector3(1.0, r.randf_range(0.6, 1.3), 1.0)
			x += r.randf_range(2.6, 4.2)
		var z := -LAND_Z + 1.0
		while z < LAND_Z:
			if absf(z) > 4.4:
				var p := Vector3(sx * (LAND_X + 0.5), 0, z + r.randf_range(-0.4, 0.4))
				_mesh(game._rock_mesh(int(z * 17) + t * 3, r.randf_range(0.6, 1.0)), p + Vector3(0, 0.1, 0), basalt(Color(0.22, 0.17, 0.18)))
			z += r.randf_range(2.4, 3.6)
		if t == 0:
			# The Elves bring the forest with them: pines and glowing crystals
			# on their plateau, at the corners outside the walls.
			for p in [Vector3(-44, 0, -12.5), Vector3(-46.5, 0, 12.6), Vector3(-73, 0, -13.6), Vector3(-80, 0, 13.4), Vector3(-90, 0, -12), Vector3(-90, 0, 11)]:
				game._add_tree(p, false)
			for p in [Vector3(-43.6, 0, -8.5), Vector3(-43.6, 0, 8.5)]:
				game._add_crystal(p, 1.1)
		else:
			for p in [Vector3(43.8, 0, -8.6), Vector3(43.8, 0, 8.6)]:
				_hell_torch(p, 2.1)
	game.map_trees.clear()   # the minimap paints this map itself


func _build_corridor(s: Array) -> void:
	var a: Vector3 = pos[s[0]]
	var b: Vector3 = pos[s[1]]
	var half: float = s[2]
	var kind: String = s[3]
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := d.length()
	var dir := d / length
	var yaw := atan2(dir.x, dir.z)
	var mid := (a + b) / 2.0
	var side := Vector3(dir.z, 0, -dir.x)
	game.map_paths.append([a, b, half * 2.0])
	if kind == "bridge":
		# A timber deck on stone piers, rails both sides, torches on posts.
		var deck: Material = game._plank_dark(Color(0.5, 0.4, 0.36))
		_box(mid + Vector3(0, -0.12, 0), Vector3(half * 2.0, 0.24, length), deck, yaw)
		# Stone kerbs under the rails.
		var kerb: Material = game._ashlar(Color(0.4, 0.33, 0.33))
		for sd in [-1.0, 1.0]:
			_box(mid + side * sd * (half + 0.12) + Vector3(0, -0.08, 0), Vector3(0.36, 0.4, length - rad[s[0]] - rad[s[1]] + 1.0), kerb, yaw)
		var timber: Material = game._timber(Color(0.32, 0.22, 0.18))
		var n := int(length / 2.6)
		for k in n + 1:
			var at: Vector3 = a + dir * (float(k) / n * length)
			if _flat(at, a) < rad[s[0]] - 0.2 or _flat(at, b) < rad[s[1]] - 0.2:
				continue
			for sd in [-1.0, 1.0]:
				_box(at + side * sd * (half + 0.12) + Vector3(0, 0.55, 0), Vector3(0.16, 1.1, 0.16), timber, yaw)
			if k % 4 == 2:
				# Piers down into the lava.
				_box(at + Vector3(0, (LAVA_Y - 0.3) / 2.0 - 0.2, 0), Vector3(half * 1.6, absf(LAVA_Y) + 0.2, 1.1), basalt(Color(0.42, 0.36, 0.34)), yaw)
			if k % 4 == 0 and k > 0 and k < n:
				for sd in [-1.0, 1.0]:
					_hell_torch(at + side * sd * (half + 0.12) + Vector3(0, 0.0, 0), 1.6)
		# The rails themselves.
		var start: Vector3 = a + dir * (rad[s[0]] - 0.3)
		var end: Vector3 = b - dir * (rad[s[1]] - 0.3)
		var rl: float = _flat(start, end)
		for sd in [-1.0, 1.0]:
			_box((start + end) / 2.0 + side * sd * (half + 0.12) + Vector3(0, 1.08, 0), Vector3(0.12, 0.12, rl), timber, yaw)
			_box((start + end) / 2.0 + side * sd * (half + 0.12) + Vector3(0, 0.6, 0), Vector3(0.08, 0.08, rl), timber, yaw)
		# Chains hanging under the deck edge, a lick of glow from below.
		_box(mid + Vector3(0, -0.36, 0), Vector3(half * 2.0 - 0.3, 0.2, length - 1.0), basalt(Color(0.25, 0.2, 0.2)), yaw)
		return
	# Causeway and the grand stair: paved rock with a cliff skirt.
	var pave: Material = game._flagstone(Color(0.42, 0.35, 0.35))
	_box(mid + Vector3(0, -0.04, 0), Vector3(half * 2.0, 0.08, length), pave, yaw)
	_skirt(mid + Vector3(0, -0.08, 0), Vector3(half * 2.0 + 0.6, absf(LAVA_Y) + 1.5, length), yaw)
	var kerb: Material = game._ashlar(Color(0.44, 0.36, 0.35))
	var start: Vector3 = a + dir * (rad[s[0]] - 0.4)
	var end: Vector3 = b - dir * (rad[s[1]] - 0.4)
	if kind == "causeway" and castle_of(a) >= 0:
		start = a + dir * (LAND_X - absf(a.x) + 0.2) * (1.0 if absf(a.x) > LAND_X else 0.0)
	var cl: float = _flat(start, end)
	var cm := (start + end) / 2.0
	# Low parapets with merlons, torches on every fourth.
	for sd in [-1.0, 1.0]:
		_box(cm + side * sd * (half + 0.15) + Vector3(0, 0.25, 0), Vector3(0.4, 0.5, cl), kerb, yaw)
		var n := int(cl / 1.6)
		for k in n:
			var at: Vector3 = start + dir * ((k + 0.5) * cl / n)
			if k % 2 == 0:
				_box(at + side * sd * (half + 0.15) + Vector3(0, 0.62, 0), Vector3(0.44, 0.3, 0.6), kerb, yaw)
			if k % 6 == 3:
				_hell_torch(at + side * sd * (half + 0.55), 1.7)
	if kind == "stairs":
		# Step lines across the flags, so the long run reads as a stair.
		var steps := int(cl / 1.1)
		var edge: Material = game._ashlar(Color(0.38, 0.31, 0.31))
		for k in steps:
			var at: Vector3 = start + dir * ((k + 0.5) * cl / steps)
			_box(at + Vector3(0, 0.005, 0), Vector3(half * 2.0, 0.03, 0.14), edge, yaw, false)


func _build_plaza(i: int) -> void:
	var c: Vector3 = pos[i]
	var r: float = rad[i]
	if castle_of(c) >= 0:
		# The door court on the plateau: just the paving.
		game._add_rosette(c + Vector3(0, 0.012, 0), r + 0.5, Color(0.62, 0.55, 0.55))
		return
	var top := CylinderMesh.new()
	top.top_radius = r
	top.bottom_radius = r
	top.height = 0.1
	top.radial_segments = 40
	_mesh(top, c + Vector3(0, -0.05, 0), game._flagstone(Color(0.42, 0.35, 0.35)))
	var cliff := CylinderMesh.new()
	cliff.top_radius = r + 0.5
	cliff.bottom_radius = r + 1.6
	cliff.height = absf(LAVA_Y) + 1.6
	cliff.radial_segments = 9
	_mesh(cliff, c + Vector3(0, -cliff.height / 2.0 - 0.1, 0), basalt())
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.08, 0.02, 0.01)
	hot.emission_enabled = true
	hot.emission = Color(0.85, 0.1, 0.03)
	hot.emission_energy_multiplier = 0.14
	var band := CylinderMesh.new()
	band.top_radius = r + 1.5
	band.bottom_radius = r + 1.7
	band.height = 0.3
	band.radial_segments = 9
	_mesh(band, c + Vector3(0, LAVA_Y + 0.12, 0), hot, Vector3.ZERO, false)
	# A low kerb round the rim, broken where the corridors come in.
	var gaps := []
	for s in segs:
		if s[0] == i or s[1] == i:
			var o: int = s[1] if s[0] == i else s[0]
			var d: Vector3 = pos[o] - c
			gaps.append([atan2(d.z, d.x), asin(clampf((s[2] + 0.5) / r, 0.0, 1.0))])
	var kerb: Material = game._ashlar(Color(0.44, 0.36, 0.35))
	var n := int(TAU * r / 1.3)
	for k in n:
		var ang := TAU * k / n
		var open := false
		for g in gaps:
			if absf(wrapf(ang - g[0], -PI, PI)) < g[1]:
				open = true
		if open:
			continue
		var at := c + Vector3(cos(ang), 0, sin(ang)) * (r + 0.2)
		_box(at + Vector3(0, 0.22, 0), Vector3(0.45, 0.44 if k % 2 == 0 else 0.7, 1.0), kerb, -ang)


func _build_fire_objective() -> void:
	## The Fire Objective: a round rune court with a burning crystal hanging
	## over a font of fire, braziers and red banners round it, and the capture
	## ring that glows in the holder's colour.
	var c := FIRE_POS
	game._add_rosette(c + Vector3(0, 0.014, 0), 8.2, Color(0.42, 0.3, 0.3))
	# A ring of burning runes round the font, glowing straight off the paving.
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_texture = load("res://assets/textures/emblems/runes.png")
	rune_mat.albedo_color = Color(1.0, 0.16, 0.04)
	rune_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rune_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rune_plane := PlaneMesh.new()
	rune_plane.size = Vector2(10.4, 10.4)
	_mesh(rune_plane, c + Vector3(0, 0.03, 0), rune_mat, Vector3.ZERO, false)
	# The capture ring.
	var torus := TorusMesh.new()
	torus.inner_radius = Stats.FIRE_POINT.radius - 0.22
	torus.outer_radius = Stats.FIRE_POINT.radius
	torus.rings = 64
	torus.ring_segments = 6
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.6, 0.9, 0.3)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.55, 0.15)
	var ring := _mesh(torus, c + Vector3(0, 0.03, 0), ring_mat, Vector3.ZERO, false)
	ring.scale = Vector3(1.0, 0.25, 1.0)
	# The font: a shallow glowing basin, level with the court so nobody trips.
	var font := CylinderMesh.new()
	font.top_radius = 2.0
	font.bottom_radius = 2.0
	font.height = 0.04
	font.radial_segments = 24
	var font_mat := StandardMaterial3D.new()
	font_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	font_mat.albedo_color = Color(1.8, 0.7, 0.2)
	_mesh(font, c + Vector3(0, 0.02, 0), font_mat, Vector3.ZERO, false)
	var rim := TorusMesh.new()
	rim.inner_radius = 2.0
	rim.outer_radius = 2.5
	rim.rings = 32
	rim.ring_segments = 8
	var rim_m := _mesh(rim, c + Vector3(0, 0.06, 0), game._ashlar(Color(0.45, 0.38, 0.36)))
	rim_m.scale = Vector3(1.0, 0.4, 1.0)
	game._add_fire(c + Vector3(0, 0.05, 0), 6.0)
	# The burning crystal, floating and turning over the font.
	core = Node3D.new()
	core.position = c + Vector3(0, 2.6, 0)
	game.add_child(core)
	for k in 5:
		var prism := PrismMesh.new()
		var big := k == 0
		prism.size = Vector3(0.9, 2.6, 0.9) if big else Vector3(0.45, 1.3, 0.45)
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.55, 0.06, 0.04)
		cm.emission_enabled = true
		cm.emission = Color(1.0, 0.18, 0.04)
		cm.emission_energy_multiplier = 1.5
		cm.roughness = 0.2
		cm.metallic = 0.3
		core_mats.append(cm)
		var up := MeshInstance3D.new()
		up.mesh = prism
		up.material_override = cm
		var ang := k * TAU / 4.0
		up.position = Vector3.ZERO if big else Vector3(cos(ang) * 0.75, -0.35, sin(ang) * 0.75)
		up.rotation = Vector3(0 if big else sin(ang) * 0.35, ang, 0 if big else cos(ang) * 0.35)
		core.add_child(up)
		var down := MeshInstance3D.new()
		down.mesh = prism
		down.material_override = cm
		down.position = up.position + Vector3(0, -prism.size.y if big else -prism.size.y * 0.9, 0)
		down.rotation = up.rotation + Vector3(PI, 0, 0)
		core.add_child(down)
	fire_light = game._add_light(c + Vector3(0, 3.2, 0), Color(1.0, 0.3, 0.1), 1.5, 12.0)
	_ash_plume(c + Vector3(0, 4.2, 0), 14, 1.4)
	# Braziers and fire banners round the court, off the corridor mouths.
	for k in 6:
		var ang := TAU * (k + 0.5) / 6.0 + PI / 2.0
		var at := c + Vector3(cos(ang), 0, sin(ang)) * 7.9
		var open := false
		for s in segs:
			if s[0] == ids.find("f") or s[1] == ids.find("f"):
				var o: int = s[1] if s[0] == ids.find("f") else s[0]
				var d: Vector3 = pos[o] - c
				if absf(wrapf(ang - atan2(d.z, d.x), -PI, PI)) < 0.5:
					open = true
		if open:
			continue
		game._add_brazier(at)
		_fire_banner(c + Vector3(cos(ang), 0, sin(ang)) * 8.7, ang)
	game.map_marks.append([c, "fire"])


func _fire_banner(at: Vector3, ang: float) -> void:
	## A red banner with a flame on a tall post (the concept's fire flags).
	var timber: Material = game._timber(Color(0.4, 0.28, 0.2))
	_box(at + Vector3(0, 1.9, 0), Vector3(0.18, 3.8, 0.18), timber)
	var out := Vector3(-cos(ang), 0, -sin(ang))
	var yaw := atan2(out.x, out.z)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.4, 0.03, 0.03)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.9)
	_mesh(q, at + out * 0.14 + Vector3(0, 2.55, 0), cloth, Vector3(0, yaw, 0))
	var hem: Material = game._gold()
	_box(at + out * 0.14 + Vector3(0, 3.52, 0), Vector3(1.3, 0.1, 0.1), hem, yaw)
	game._add_fire(at + out * 0.17 + Vector3(0, 2.25, 0), 2.2)


func _build_crossing() -> void:
	## The Crossing: the high plaza where the northern bridges meet, with
	## both factions' banners at its back.
	var c := CROSSING
	game._add_rosette(c + Vector3(0, 0.014, 0), 6.6, Color(0.6, 0.54, 0.54))
	game._add_banner_pole(0, c + Vector3(-3.6, 0, -6.2))
	game._add_banner_pole(1, c + Vector3(3.6, 0, -6.2))
	game._add_brazier(c + Vector3(-6.0, 0, -3.6))
	game._add_brazier(c + Vector3(6.0, 0, -3.6))
	game.map_marks.append([c, "crossing"])


func _build_watch_post(team: int) -> void:
	## Each side's watch post at the far end of its causeway: a rosette in
	## the team's colour, a banner, a low wall to shoot from (cover), a
	## tower stump and torches.
	var sx := -1.0 if team == 0 else 1.0
	var c: Vector3 = pos[ids.find("m%d" % team)]
	game._add_rosette(c + Vector3(0, 0.014, 0), 5.6, Color(0.42, 0.52, 0.42) if team == 0 else Color(0.46, 0.48, 0.6))
	game._add_banner_pole(team, c + Vector3(sx * 2.0, 0, -5.4))
	# Cover: a low wall right on the south rim (solid; no gap behind it for
	# anyone to get wedged in), shooters' spots in front of it.
	var wall := c + Vector3(sx * 1.0, 0, 6.0)
	var stone: Material = game._ashlar(Color(0.44, 0.36, 0.35))
	_box(wall + Vector3(0, 0.55, 0), Vector3(2.8, 1.1, 0.7), stone)
	game._add_collider(wall + Vector3(0, 0.55, 0), Vector3(2.8, 1.1, 0.7))
	game.cover_points.append(wall + Vector3(0, 0, -1.4))
	# A broken watchtower stump standing on the rock just off the north rim
	# (outside the walkable plaza, so nobody gets stuck behind it).
	var tower := c + Vector3(-sx * 2.6, 0, -6.9)
	cover_props.append(tower)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 1.25
	cyl.height = 2.4
	cyl.radial_segments = 10
	_mesh(cyl, tower + Vector3(0, 1.2, 0), stone)
	var footing := CylinderMesh.new()
	footing.top_radius = 1.6
	footing.bottom_radius = 2.0
	footing.height = absf(LAVA_Y) + 0.2
	footing.radial_segments = 8
	_mesh(footing, tower + Vector3(0, LAVA_Y / 2.0 - 0.1, 0), basalt())
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		_box(tower + Vector3(cos(a) * 0.9, 2.55, sin(a) * 0.9), Vector3(0.45, 0.4, 0.45), stone, a)
	_hell_torch(c + Vector3(-sx * 5.6, 0, 1.6), 1.8)
	_hell_torch(c + Vector3(sx * 4.8, 0, -2.6), 1.8)
	game.map_marks.append([c, "post"])


func _build_spires() -> void:
	## Basalt columns standing out of the lava: short beside the walkways (so
	## nobody is hidden), taller and thicker further out.
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var cols := []
	var x := -118.0
	while x <= 118.0:
		var z := -62.0
		while z <= 62.0:
			var p := Vector3(x + r.randf_range(-1.4, 1.4), 0, z + r.randf_range(-1.4, 1.4))
			z += 3.4
			var gap := _flat(p, clamp_walk(p))
			if gap < 2.4 or r.randf() > 0.6:
				continue
			# Keep pools of open lava between the clusters.
			if fmod(absf(p.x * 0.13 + p.z * 0.07), 2.0) < 0.55 and gap < 14.0:
				continue
			var reach := clampf((gap - 2.4) / 12.0, 0.0, 1.0)
			var h: float = lerpf(0.5, 5.5, reach) * r.randf_range(0.5, 1.15)
			if absf(p.z) > 34.0 or absf(p.x) > 96.0:
				h += r.randf_range(1.0, 5.0)
			var w: float = r.randf_range(0.8, 1.7) * (1.0 + reach * 0.4)
			cols.append([p, w, h])
		x += 3.4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var col := CylinderMesh.new()
	col.top_radius = 0.5
	col.bottom_radius = 0.58
	col.height = 1.0
	col.radial_segments = 6
	col.rings = 1
	mm.mesh = col
	mm.instance_count = cols.size() * 2
	var k := 0
	for c in cols:
		var p: Vector3 = c[0]
		var w: float = c[1]
		var h: float = c[2]
		var total := h - LAVA_Y + 0.5
		var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(w * 2.0, total, w * 2.0))
		mm.set_instance_transform(k, Transform3D(basis, Vector3(p.x, LAVA_Y - 0.5 + total / 2.0, p.z)))
		k += 1
		# A shorter neighbour column, so each reads as a cluster.
		var off := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized() * w * 1.1
		var h2 := h * r.randf_range(0.45, 0.8)
		var t2 := h2 - LAVA_Y + 0.5
		var b2 := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(w * 1.5, t2, w * 1.5))
		mm.set_instance_transform(k, Transform3D(b2, Vector3(p.x + off.x, LAVA_Y - 0.5 + t2 / 2.0, p.z + off.z)))
		k += 1
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = basalt(Color(0.2, 0.15, 0.16))
	game.add_child(inst)


func _build_volcano() -> void:
	## The volcano itself, smoking on the northern horizon, and its lava falls.
	var cone := CylinderMesh.new()
	cone.top_radius = 9.0
	cone.bottom_radius = 46.0
	cone.height = 34.0
	cone.radial_segments = 14
	_mesh(cone, Vector3(0, LAVA_Y + 16.5, -96), basalt(Color(0.16, 0.11, 0.12)))
	var crater := CylinderMesh.new()
	crater.top_radius = 8.2
	crater.bottom_radius = 8.2
	crater.height = 0.3
	_mesh(crater, Vector3(0, LAVA_Y + 33.6, -96), lava_mat, Vector3.ZERO, false)
	game._add_light(Vector3(0, LAVA_Y + 38, -96), Color(1.0, 0.22, 0.06), 6.0, 60.0)
	_ash_plume(Vector3(0, LAVA_Y + 35, -96), 30, 6.0)
	_demon_face()
	for ang in [-0.5, 0.1, 0.55]:
		# Lava falls pouring down its face.
		var fall_mat: ShaderMaterial = lava_mat.duplicate()
		fall_mat.set_shader_parameter("flow", 0.6)
		var q := QuadMesh.new()
		q.size = Vector2(4.0, 36.0)
		var at := Vector3(sin(ang) * 30.0, LAVA_Y + 15.0, -96 + cos(ang) * 30.0)
		var m := _mesh(q, at, fall_mat, Vector3(-0.85, ang, 0), false)
		m.name = "LavaFall"


func _build_embers() -> void:
	## Sparks drifting up off the lava over the whole field.
	for p in [Vector3(-14, LAVA_Y, 0), Vector3(14, LAVA_Y, 0), Vector3(0, LAVA_Y, -30), Vector3(0, LAVA_Y, 30), Vector3(-36, LAVA_Y, -24),
			Vector3(36, LAVA_Y, -24), Vector3(-36, LAVA_Y, 24), Vector3(36, LAVA_Y, 24), Vector3(0, LAVA_Y, 0)]:
		var e := CPUParticles3D.new()
		e.amount = 40
		e.lifetime = 5.0
		e.preprocess = 5.0
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		e.emission_box_extents = Vector3(12, 0.2, 12)
		e.direction = Vector3.UP
		e.spread = 25.0
		e.initial_velocity_min = 0.6
		e.initial_velocity_max = 1.6
		e.gravity = Vector3(0.3, 0.25, 0)
		e.scale_amount_min = 0.5
		e.scale_amount_max = 1.0
		var sph := SphereMesh.new()
		sph.radius = 0.05
		sph.height = 0.1
		sph.radial_segments = 6
		sph.rings = 3
		var em := StandardMaterial3D.new()
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		em.albedo_color = Color(1.7, 0.42, 0.12)
		sph.material = em
		e.mesh = sph
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.add_point(0.2, Color(1, 1, 1, 1))
		fade.set_color(fade.get_point_count() - 1, Color(1, 0.4, 0.2, 0))
		e.color_ramp = fade
		em.vertex_color_use_as_albedo = true
		em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		e.position = p
		game.add_child(e)


# --- The demonic dressing ------------------------------------------------------

func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col * 0.4
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _obsidian() -> StandardMaterial3D:
	## Black volcanic glass with a faint red sheen from the lava.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.045, 0.028, 0.035)
	m.roughness = 0.16
	m.metallic = 0.35
	m.emission_enabled = true
	m.emission = Color(0.55, 0.04, 0.02)
	m.emission_energy_multiplier = 0.18
	return m


func _bone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.68, 0.6, 0.5)
	m.roughness = 0.8
	return m


func _horn_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.06, 0.05)
	m.roughness = 0.35
	return m


func _limb(a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> void:
	## A tapered cylinder from a to b (horn and rib segments).
	var d := b - a
	if d.length() < 0.001:
		return
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = r0
	cyl.top_radius = r1
	cyl.height = d.length()
	cyl.radial_segments = 7
	cyl.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = cyl
	m.material_override = mat
	m.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + b) / 2.0)
	game.add_child(m)


func _horn(base: Vector3, out: Vector3, length: float, radius: float, mat: Material, segs: int = 7) -> void:
	## A curved demon horn: sweeps out, rises, then hooks back in at the tip.
	out = Vector3(out.x, 0, out.z).normalized()
	var prev := base
	for k in segs:
		var t := float(k + 1) / segs
		var p := base + out * length * 0.5 * sin(t * 2.3) + Vector3.UP * length * 0.85 * t * (1.0 - 0.3 * t)
		var t0 := float(k) / segs
		_limb(prev, p, radius * (1.0 - t0 * 0.85), radius * (1.0 - t * 0.85) + 0.02, mat)
		prev = p


func _skull(at: Vector3, size: float, yaw: float, eye: Color = Color(1.0, 0.12, 0.04)) -> void:
	## A horned beast skull with burning eye sockets, facing along yaw.
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(fwd.z, 0, -fwd.x)
	var bone := _bone()
	var cran := SphereMesh.new()
	cran.radius = 0.5 * size
	cran.height = 0.9 * size
	cran.radial_segments = 10
	cran.rings = 6
	_mesh(cran, at, bone, Vector3(0, yaw, 0))
	var snout := BoxMesh.new()
	snout.size = Vector3(0.55, 0.32, 0.55) * size
	_mesh(snout, at + fwd * 0.42 * size - Vector3(0, 0.16 * size, 0), bone, Vector3(0, yaw, 0))
	var glow := _glow_mat(eye, 3.0)
	for sd in [-1.0, 1.0]:
		var sock := SphereMesh.new()
		sock.radius = 0.11 * size
		sock.height = 0.18 * size
		_mesh(sock, at + fwd * 0.4 * size + side * sd * 0.2 * size + Vector3(0, 0.04 * size, 0), glow, Vector3.ZERO, false)
		_horn(at + side * float(sd) * 0.36 * size + Vector3(0, 0.15 * size, 0), side * sd + fwd * 0.3, 1.5 * size, 0.15 * size, _horn_mat(), 5)


func _hell_torch(at: Vector3, height: float = 1.8) -> void:
	## A black iron spike with a horned cage at the top holding a red flame.
	var iron := _horn_mat()
	_limb(at, at + Vector3(0, height, 0), 0.08, 0.06, iron)
	_box(at + Vector3(0, 0.06, 0), Vector3(0.42, 0.12, 0.42), iron)
	for sd in [-1.0, 1.0]:
		_horn(at + Vector3(sd * 0.1, height - 0.05, 0), Vector3(sd, 0, 0), 0.6, 0.06, iron, 4)
	game._add_flame(at + Vector3(0, height + 0.18, 0), 0.17, Color(1.0, 0.22, 0.05))
	game._add_flame(at + Vector3(0.04, height + 0.32, 0.02), 0.08, Color(1.0, 0.55, 0.15))
	game._add_light(at + Vector3(0, height + 0.5, 0), Color(1.0, 0.2, 0.06), 0.9, 5.5)


func _mouths(i: int) -> Array:
	## [angle, half-width] of each corridor entering plaza i.
	var out := []
	for sg in segs:
		if sg[0] == i or sg[1] == i:
			var o: int = sg[1] if sg[0] == i else sg[0]
			var d: Vector3 = pos[o] - pos[i]
			out.append([atan2(d.z, d.x), asin(clampf((sg[2] + 1.2) / rad[i], 0.0, 1.0))])
	return out


func _obelisk(at: Vector3, face: Vector3, footing: bool) -> void:
	## A black obelisk carved with burning runes, a horned skull on top. Stands
	## off the walkable ground, on its own rock footing over the lava.
	var yaw := atan2(face.x, face.z)
	deco_obelisks.append(at)
	if footing:
		var foot := CylinderMesh.new()
		foot.top_radius = 0.95
		foot.bottom_radius = 1.3
		foot.height = absf(LAVA_Y) + 0.3
		foot.radial_segments = 7
		_mesh(foot, at + Vector3(0, LAVA_Y / 2.0 - 0.1, 0), basalt())
	var obs := _obsidian()
	_box(at + Vector3(0, 0.25, 0), Vector3(1.25, 0.5, 1.25), obs, yaw)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.2
	shaft.bottom_radius = 0.48
	shaft.height = 3.2
	shaft.radial_segments = 4
	_mesh(shaft, at + Vector3(0, 2.1, 0), obs, Vector3(0, yaw + PI / 4.0, 0))
	# The rune strip down the face, and its glow on the ground.
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	for k in 4:
		_box(at + fwd * (0.32 - k * 0.045) + Vector3(0, 1.0 + k * 0.6, 0), Vector3(0.22 - k * 0.03, 0.34, 0.05), _glow_mat(Color(1.0, 0.1, 0.03), 2.6), yaw, false)
	_skull(at + Vector3(0, 3.95, 0), 0.62, yaw)
	game._add_light(at + fwd * 0.9 + Vector3(0, 1.6, 0), Color(1.0, 0.12, 0.04), 0.9, 4.5)


func _build_demonic() -> void:
	## What makes the pass hellish: obsidian spikes jutting from the lava,
	## rune obelisks crowned with horned skulls at the gates and plazas, and a
	## great beast's bones half sunk in the lava.
	var obs := _obsidian()
	# Gate obelisks either side of each causeway where it leaves the plateau.
	for t in 2:
		var sx := -1.0 if t == 0 else 1.0
		for zs in [-1.0, 1.0]:
			_obelisk(Vector3(sx * (LAND_X - 1.3), 0, zs * 5.3), Vector3(-sx, 0, 0), true)
	# Obelisks on the open rims of the plazas.
	for i in pos.size():
		if castle_of(pos[i]) >= 0:
			continue
		var gaps := _mouths(i)
		var placed := 0
		for k in 8:
			var ang := TAU * k / 8.0 + PI / 8.0
			var at: Vector3 = pos[i] + Vector3(cos(ang), 0, sin(ang)) * (rad[i] + 1.5)
			var clear := true
			for g in gaps:
				if absf(wrapf(ang - g[0], -PI, PI)) < g[1] + 0.35:
					clear = false
			# Keep the camera side (south, +z) of each plaza open, and clear of
			# the watch posts' tower stumps.
			if sin(ang) > 0.35 or not clear or placed >= 2:
				continue
			var near := false
			for o in cover_props:
				if _flat(o, at) < 3.0:
					near = true
			if near:
				continue
			_obelisk(at, Vector3(-cos(ang), 0, -sin(ang)), true)
			placed += 1
	# Obsidian spikes in clusters along the lava's edge, leaning away from the paths.
	var r := RandomNumberGenerator.new()
	r.seed = 666
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	mm.mesh = cone
	var xf := []
	var x := -104.0
	while x <= 104.0:
		var z := -46.0
		while z <= 46.0:
			var p := Vector3(x + r.randf_range(-1.0, 1.0), 0, z + r.randf_range(-1.0, 1.0))
			z += 2.8
			var edge := clamp_walk(p)
			var gap := _flat(p, edge)
			if gap < 1.5 or gap > 6.5 or r.randf() > 0.32:
				continue
			var away := Vector3(p.x - edge.x, 0, p.z - edge.z).normalized()
			# South of a walkway the spikes would hide fighters from the camera: keep them low.
			var tall: float = 2.0 if away.z > 0.3 else 3.6
			deco_spikes.append([p, away])
			for n in r.randi_range(2, 4):
				var h := r.randf_range(0.9, tall) * (1.0 if n == 0 else 0.65)
				var w := r.randf_range(0.18, 0.38) * (1.0 + h * 0.08)
				var tilt := r.randf_range(0.15, 0.55)
				var axis := Vector3(away.z, 0, -away.x)
				var b := Basis(axis, tilt) * Basis(Vector3.UP, r.randf() * TAU) * Basis.from_scale(Vector3(w * 2.0, h - LAVA_Y, w * 2.0))
				var o := p + Vector3(r.randf_range(-0.7, 0.7), 0, r.randf_range(-0.7, 0.7))
				var up: Vector3 = b * Vector3(0, 0.5, 0)
				xf.append(Transform3D(b, Vector3(o.x, LAVA_Y, o.z) + up))
		x += 2.8
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = obs
	game.add_child(inst)
	# A great beast's bones in the open lava: spine, ribs arching out, horned skull.
	_ribcage(Vector3(-21, 0, 33), 0.25, 15.0)
	_ribcage(Vector3(22, 0, -34), PI + 0.3, 13.0)


func _ribcage(center: Vector3, yaw: float, length: float) -> void:
	deco_bones.append([center, yaw, length])
	var fwd := Vector3(cos(yaw), 0, -sin(yaw))
	var side := Vector3(-fwd.z, 0, fwd.x)
	var bone := _bone()
	var y0 := LAVA_Y + 0.15
	var n := int(length / 1.1)
	for k in n:
		var at := center + fwd * (-length / 2.0 + k * length / (n - 1))
		var v := SphereMesh.new()
		v.radius = 0.5
		v.height = 0.8
		v.radial_segments = 8
		v.rings = 4
		_mesh(v, Vector3(at.x, y0 + 0.15, at.z), bone)
	for k in 6:
		var t := (k + 1.0) / 7.0
		var along := center + fwd * (-length / 2.0 + t * length * 0.8)
		var rr := 4.2 * sin(t * PI * 0.9 + 0.25)
		for sd in [-1.0, 1.0]:
			var prev := Vector3(along.x, y0 + 0.3, along.z)
			for q in 6:
				var a := PI * (q + 1) / 6.0
				var pnt: Vector3 = along + side * sd * rr * (1.0 - cos(a)) * 0.5 + fwd * (-0.6 * sin(a)) + Vector3(0, y0 + 0.3 + rr * 0.85 * sin(a), 0)
				_limb(prev, pnt, 0.24 - q * 0.02, 0.22 - q * 0.02, bone)
				prev = pnt
	_skull(center + fwd * (length / 2.0 + 2.0) + Vector3(0, y0 + 0.9, 0), 2.6, atan2(fwd.x, fwd.z))


func _ash_plume(at: Vector3, amount: int, scale: float) -> void:
	## Thick black smoke with a red underglow, rising and drifting.
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4 * scale
	p.direction = Vector3(0.15, 1, 0)
	p.spread = 14.0
	p.gravity = Vector3(0.2, 0.25, 0)
	p.initial_velocity_min = 0.5 * scale
	p.initial_velocity_max = 0.9 * scale
	p.scale_amount_min = 0.5 * scale
	p.scale_amount_max = 0.9 * scale
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.3, 0.04, 0.02, 0.0))
	grad.add_point(0.12, Color(0.1, 0.035, 0.035, 0.85))
	grad.set_color(grad.get_point_count() - 1, Color(0.03, 0.02, 0.025, 0.0))
	p.color_ramp = grad
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 8
	sph.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material = mat
	p.mesh = sph
	p.position = at
	game.add_child(p)


func _demon_face() -> void:
	## The volcano wears a demon's face: two great horns off its shoulders and
	## two burning eyes glaring down the pass.
	var horn := _horn_mat()
	for sd in [-1.0, 1.0]:
		_horn(Vector3(sd * 10.0, LAVA_Y + 28.0, -93.0), Vector3(sd, 0, 0.25), 28.0, 3.4, horn, 9)
	var eye := _glow_mat(Color(1.0, 0.1, 0.02), 5.0)
	for sd in [-1.0, 1.0]:
		var b := BoxMesh.new()
		b.size = Vector3(6.0, 1.5, 1.2)
		_mesh(b, Vector3(sd * 7.0, LAVA_Y + 21.0, -72.6), eye, Vector3(-0.75, 0, sd * 0.32), false)
	game._add_light(Vector3(0, LAVA_Y + 21.0, -68.0), Color(1.0, 0.1, 0.03), 4.0, 26.0)


func apply_light() -> void:
	## Hellish light: a blood-red sky over black smoke, a dim red sun through
	## the ash, low ambient so the lava does the lighting, heavy glow.
	var env: Environment = game.world_environment
	var sky: ProceduralSkyMaterial = game.sky_material
	sky.sky_top_color = Color(0.05, 0.01, 0.015)
	sky.sky_horizon_color = Color(0.42, 0.05, 0.03)
	sky.ground_bottom_color = Color(0.04, 0.01, 0.01)
	sky.ground_horizon_color = Color(0.32, 0.04, 0.02)
	env.ambient_light_energy = 0.22
	env.ambient_light_sky_contribution = 0.2
	env.ambient_light_color = Color(0.6, 0.44, 0.47)
	env.fog_light_color = Color(0.32, 0.05, 0.03)
	env.fog_density = 0.004
	env.glow_intensity = 0.65
	env.glow_hdr_threshold = 1.0
	env.adjustment_saturation = 1.05
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.12
	game.sun_light.light_color = Color(1.0, 0.6, 0.5)
	game.sun_light.light_energy = 0.9
	game.sun_light.rotation_degrees = Vector3(-42, -38, 0)
	if game.fill_light:
		game.fill_light.light_color = Color(1.0, 0.22, 0.12)
		game.fill_light.light_energy = 0.2
