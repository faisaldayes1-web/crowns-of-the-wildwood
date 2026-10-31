extends RefCounted
## Castle kit (claude-faisal/crowns-castle, 2026-10-31): the castle and
## courtyard pieces of Faisal's picks Spawn D / Live battle A, modelled.
##   * chunky stone walls of big, individually bevelled blocks with a coping
##     course and crenellations (merlons with gaps), ivy on the Elves' walls;
##   * the courtyard's low block wall with timber posts, and a timber
##     palisade on a stone footing behind the class stations, team crests on
##     its posts;
##   * iron wall lanterns with a warm glass (emissive; only a few carry a
##     shadowless light), long team banners on the walls and towers;
##   * towers with a block plinth, a corbelled parapet, merlons and a tall
##     tiled roof in the team colour.
## Everything here is VISUAL ONLY: no colliders. The callers in game.gd keep
## every wall body, kerb, invisible wall, door, station, pad and lane exactly
## where it was, so gameplay is unchanged. Only the match world (world_style)
## uses the kit; the menus keep their old castle.

const CarvedBlock = preload("res://scripts/visual/carved_block.gd")
const StaticBatch = preload("res://scripts/static_batch.gd")
const Stats = preload("res://scripts/stats.gd")

const LANTERN_GLOW := Color(1.0, 0.68, 0.32)


# --- Materials -------------------------------------------------------------

static func _cache(g) -> Dictionary:
	if not g.has_meta(&"castle_kit"):
		g.set_meta(&"castle_kit", {})
	return g.get_meta(&"castle_kit")


static func wall_mat(g, grey: bool) -> StandardMaterial3D:
	## The wall bodies: courses of big bevelled blocks (tools/make_castle_textures.py).
	# Grade pass 2026-10-31: a step under white, so the sunlit tops of the
	# cream walls keep their block joints at the match camera.
	# Pass 2 (2026-10-31): warmer, browner sandstone (the picks' walls are
	# warm tan blocks with brown timber, not pale cream).
	return g._pbr("castle_blocks_grey" if grey else "castle_blocks", 0.3, Color(0.9, 0.88, 0.86) if grey else Color(0.88, 0.76, 0.6))


static func face_mats(g, grey: bool) -> Array:
	## Three close shades of the modelled blocks' stone, so neighbouring
	## blocks read as separate stones.
	var key := "face_grey" if grey else "face"
	var c := _cache(g)
	if not c.has(key + str(g.soot)):
		# (Grade pass 2026-10-31: a wider spread, so the blocks still read
		# apart under the brighter golden sun; was 1.0 / 0.93 / 1.04.)
		# (Pass 2 2026-10-31: warmer tan and a browner dark shade.)
		var tints := [Color(0.92, 0.82, 0.66), Color(0.72, 0.58, 0.43), Color(0.98, 0.87, 0.7)] if not grey \
			else [Color(0.95, 0.95, 0.95), Color(0.76, 0.78, 0.82), Color(1.0, 0.99, 0.97)]
		var mats := []
		for t in tints:
			mats.append(g._pbr("castle_face_grey" if grey else "castle_face", 0.5, t))
		c[key + str(g.soot)] = mats
	return c[key + str(g.soot)]


static func mortar_mat(g, grey: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = g._material((Color(0.22, 0.21, 0.23) if grey else Color(0.24, 0.15, 0.09)) * g.soot)   # darker joints (grade pass; pass 2 browner)
	m.roughness = 1.0
	return m


static func ivy_mats(g) -> Array:
	var c := _cache(g)
	if not c.has("ivy"):
		var a: StandardMaterial3D = g._material(Color.from_hsv(0.31, 0.7, 0.42))
		a.roughness = 0.9
		var b: StandardMaterial3D = g._material(Color.from_hsv(0.36, 0.75, 0.3))
		b.roughness = 0.9
		c["ivy"] = [a, b]
	return c["ivy"]


# --- Pieces ----------------------------------------------------------------

static func _block_mesh(g, size: Vector3) -> Mesh:
	## One chamfered block, shared by every block of the same size this build
	## (a fresh copy once the match-start batch has dropped its CPU arrays).
	var c := _cache(g)
	var key := "b%d_%d_%d" % [roundi(size.x * 50), roundi(size.y * 50), roundi(size.z * 50)]
	var m: Mesh = c.get(key)
	if m == null or not m.has_meta(&"batch_arrays"):
		m = CarvedBlock.mesh(size, minf(0.09, minf(size.x, minf(size.y, size.z)) * 0.2))
		c[key] = m
	return m


static func block(g, pos: Vector3, size: Vector3, mat: Material, rot_y: float = 0.0, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _block_mesh(g, size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	return mi


static func _box(g, pos: Vector3, size: Vector3, mat: Material, shadow: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)


static func _frame(a: Vector3, b: Vector3) -> Array:
	## [unit direction along a->b (flat), unit across, length]
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := d.length()
	var along := d / maxf(length, 0.001)
	return [along, Vector3(-along.z, 0, along.x), length]


static func block_course(g, a: Vector3, b: Vector3, y0: float, h: float, thick: float, grey: bool, seed: int,
		min_len: float = 0.7, max_len: float = 1.25, shadow: bool = true, mats_in: Array = []) -> void:
	## One course of individual blocks from a to b (their feet at y0), random
	## lengths, a hand-width gap between them, each its own shade and set a
	## touch proud or back, so the wall reads as stacked stones.
	var f := _frame(a, b)
	var along: Vector3 = f[0]
	var across: Vector3 = f[1]
	var length: float = f[2]
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var mats := face_mats(g, grey) if mats_in.is_empty() else mats_in
	var rot := atan2(-along.z, along.x)
	var t := 0.0
	while t < length - 0.05:
		var l := r.randf_range(min_len, max_len)
		if length - (t + l) < min_len * 0.6:
			l = length - t   # no sliver at the end
		var hh := h * r.randf_range(0.96, 1.0)
		var c := a + along * (t + l / 2.0) + across * r.randf_range(-0.025, 0.025)
		block(g, Vector3(c.x, y0 + hh / 2.0, c.z), Vector3(l - 0.05, hh, thick + r.randf_range(-0.02, 0.03)), mats[r.randi() % mats.size()], rot, shadow)
		t += l


static func merlons(g, a: Vector3, b: Vector3, y0: float, h: float, thick: float, grey: bool, seed: int,
		pitch: float = 1.3, fill: float = 0.58) -> void:
	## Crenellations: a merlon every `pitch` metres, `fill` of it solid.
	var f := _frame(a, b)
	var along: Vector3 = f[0]
	var length: float = f[2]
	var n := maxi(int(round(length / pitch)), 1)
	var step := length / n
	var mats := face_mats(g, grey)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var rot := atan2(-along.z, along.x)
	for k in n:
		var c := a + along * ((k + 0.5) * step)
		var hh := h * r.randf_range(0.94, 1.0)
		block(g, Vector3(c.x, y0 + hh / 2.0, c.z), Vector3(step * fill, hh, thick), mats[r.randi() % mats.size()], rot)


static func ivy(g, top: Vector3, out: Vector3, drop: float, seed: int, width: float = 0.9) -> void:
	## A curtain of ivy hanging from a wall top down its face: flattened leaf
	## clumps, wide at the top and thinning as it falls.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var mats := ivy_mats(g)
	var side := Vector3(-out.z, 0, out.x)
	var rows := maxi(int(drop / 0.32), 2)
	for k in rows:
		var f := float(k) / rows
		var span := width * (1.0 - f * 0.65)
		var n := maxi(int(span / 0.3), 1)
		for i in n:
			var p := top - Vector3(0, k * 0.32 + r.randf_range(0.0, 0.12), 0) + side * ((i + 0.5) / n - 0.5) * span + side * r.randf_range(-0.1, 0.1)
			var rr := r.randf_range(0.17, 0.26) * (1.0 - f * 0.3)
			var mi := MeshInstance3D.new()
			mi.mesh = g._rock_mesh(seed * 31 + k * 7 + i, rr, 0.3)
			mi.position = p + out * (rr * 0.25)
			mi.scale = Vector3(1, 1.15, 1) if absf(out.x) < 0.5 else Vector3(1, 1.15, 1)
			# Flatten against the wall.
			if absf(out.x) > 0.5:
				mi.scale.x = 0.38
			else:
				mi.scale.z = 0.38
			mi.material_override = mats[(k + i) % 2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(mi)


static func lantern(g, pos: Vector3, out: Vector3, lit: bool) -> void:
	## An iron wall lantern on a bracket: a dark cage, a warm glowing glass
	## and a little roof. `pos` is on the wall face. `lit` adds a cheap,
	## shadowless light (only a few per courtyard).
	var iron: Material = g._iron()
	var glass: StandardMaterial3D = g._material(Color(1.0, 0.8, 0.5))
	glass.emission_enabled = true
	glass.emission = LANTERN_GLOW
	glass.emission_energy_multiplier = 2.4
	var c := pos + out * 0.42
	_box(g, pos + out * 0.2 + Vector3(0, 0.22, 0), Vector3(0.06, 0.06, 0.06) + Vector3(absf(out.x), 0, absf(out.z)) * 0.36, iron, false)
	_box(g, c, Vector3(0.2, 0.3, 0.2), glass, false)
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			_box(g, c + Vector3(xs * 0.11, 0, zs * 0.11), Vector3(0.035, 0.34, 0.035), iron, false)
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.02
	rm.bottom_radius = 0.2
	rm.height = 0.16
	rm.radial_segments = 4
	roof.mesh = rm
	roof.rotation.y = PI / 4.0
	roof.position = c + Vector3(0, 0.24, 0)
	roof.material_override = iron
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(roof)
	_box(g, c - Vector3(0, 0.18, 0), Vector3(0.24, 0.05, 0.24), iron, false)
	if lit:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.74, 0.44)
		light.light_energy = 1.1
		light.omni_range = 5.5
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		light.position = c + out * 0.3
		g.add_child(light)


# --- Assemblies --------------------------------------------------------------

static func castle_wall_top(g, center: Vector3, size: Vector3, grey: bool, crenel: bool, ivy_on: bool) -> void:
	## On a wall body (the caller's solid box): a plinth course of blocks at
	## the foot, a coping course along the top and merlons, and (Elves) ivy
	## curtains on both faces here and there.
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	var half := Vector3(length / 2.0, 0, 0) if along_x else Vector3(0, 0, length / 2.0)
	var a := Vector3(center.x, 0, center.z) - half
	var b := Vector3(center.x, 0, center.z) + half
	var top := center.y + size.y / 2.0
	var foot := center.y - size.y / 2.0
	var seed := int(absf(center.x) * 13.0 + absf(center.z) * 7.0 + (100 if center.z < 0 else 0) + (50 if center.x < 0 else 0))
	# Coping: one course of big blocks, a little proud of both faces.
	block_course(g, a, b, top, 0.32, thick + 0.18, grey, seed, 0.9, 1.5)
	if crenel and size.y >= 2.0:
		merlons(g, a, b, top + 0.32, 0.62, thick + 0.02, grey, seed + 1)
	# A plinth course at the foot (taller walls only; low parapets stay clean).
	if size.y >= 2.0 and foot > -0.5:
		block_course(g, a, b, foot, 0.42, thick + 0.16, grey, seed + 2, 0.8, 1.4, false)
	if ivy_on:
		var r := RandomNumberGenerator.new()
		r.seed = seed + 3
		var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var out := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		var k := r.randf_range(0.8, 2.4)
		while k < length - 0.6:
			for s in [-1.0, 1.0]:
				if r.randf() < 0.55:
					var p: Vector3 = a + dir * k + out * s * (thick / 2.0 + 0.02)
					ivy(g, Vector3(p.x, top + 0.1, p.z), out * s, minf(size.y * r.randf_range(0.4, 0.75), 2.2), seed + int(k * 10) + int(s), r.randf_range(0.7, 1.2))
			k += r.randf_range(3.2, 5.5)


static func courtyard_wall(g, a: Vector3, b: Vector3, grey: bool, seed: int, merlon_h: float = 0.42, post_every: float = 4.6,
		tall_out: Vector3 = Vector3.ZERO) -> void:
	## The open courtyard's low wall on its kerb line a->b: a dark mortar
	## core, two courses of big bevelled blocks, a crenellated cap and timber
	## posts with iron-capped tops (picks Spawn D / Battle A).
	## tall_out (pass 2, 2026-10-31): a side wall the match camera looks
	## along, not across, is built tall and thick instead: three courses
	## thickened outward (along tall_out, away from the yard), brown timber
	## caps on some merlons and tall timber posts. Visual only: the kerb and
	## invisible wall stay the caller's.
	var f := _frame(a, b)
	var along: Vector3 = f[0]
	var length: float = f[2]
	var rot := atan2(-along.z, along.x)
	var mid := (a + b) / 2.0
	if tall_out != Vector3.ZERO:
		# Pass 4 (2026-10-31): the tall warm-brown brick wall (was pass 2's
		# 2.4 m block wall, _tall_courtyard_wall).
		_brick_wall(g, a, b, along, length, rot, seed, tall_out)
		return
	var core := Vector3(length, 0.9, 0.5) if absf(along.x) > 0.5 else Vector3(0.5, 0.9, length)
	_box(g, Vector3(mid.x, 0.3 + 0.45, mid.z), core, mortar_mat(g, grey))
	block_course(g, a, b, 0.3, 0.46, 0.72, grey, seed, 0.75, 1.3)
	var a2 := a + along * 0.35
	block_course(g, a2, b, 0.79, 0.44, 0.7, grey, seed + 1, 0.7, 1.2)
	block_course(g, a, a2, 0.79, 0.44, 0.7, grey, seed + 2, 0.3, 0.4)
	merlons(g, a, b, 1.25, merlon_h, 0.62, grey, seed + 3, 1.15, 0.55)
	# Timber posts through the wall, each with a dark iron cap.
	var wood: Material = g._timber(Color(0.72, 0.56, 0.4))
	var n := maxi(int(round(length / post_every)), 1)
	for k in n + 1:
		var p := a + along * (k * length / n)
		block(g, Vector3(p.x, 0.95, p.z), Vector3(0.36, 1.9, 0.86), wood, rot)
		block(g, Vector3(p.x, 1.94, p.z), Vector3(0.44, 0.1, 0.94), g._timber(Color(0.45, 0.32, 0.21)), rot)


static func _tall_courtyard_wall(g, a: Vector3, b: Vector3, along: Vector3, length: float, rot: float, grey: bool, seed: int,
		out: Vector3, posts_at: Array = [], flags: bool = true) -> void:
	var sh := out * 0.32   # the wall's centre line, moved outward off the kerb
	var a0 := a + sh
	var b0 := b + sh
	var mid := (a0 + b0) / 2.0
	var core := Vector3(length, 1.55, 0.86) if absf(along.x) > 0.5 else Vector3(0.86, 1.55, length)
	_box(g, Vector3(mid.x, 0.3 + 0.78, mid.z), core, mortar_mat(g, grey))
	block_course(g, a0, b0, 0.3, 0.5, 1.12, grey, seed, 0.8, 1.35)
	var a2 := a0 + along * 0.4
	block_course(g, a2, b0, 0.82, 0.5, 1.08, grey, seed + 1, 0.75, 1.25)
	block_course(g, a0, a2, 0.82, 0.5, 1.08, grey, seed + 2, 0.36, 0.44)
	block_course(g, a0, b0, 1.34, 0.48, 1.12, grey, seed + 4, 0.8, 1.4)
	# Crenellations, every other merlon under a brown plank cap.
	# (The palisade's two timber tints: no new materials to draw.)
	var wood: Material = g._timber(Color(0.66, 0.5, 0.34))
	var dark: Material = g._timber(Color(0.5, 0.36, 0.24))
	var pitch := 1.2
	var n := maxi(int(round(length / pitch)), 1)
	var step := length / n
	var mats := face_mats(g, grey)
	var r := RandomNumberGenerator.new()
	r.seed = seed + 5
	for k in n:
		var c := a0 + along * ((k + 0.5) * step)
		var hh := 0.58 * r.randf_range(0.94, 1.0)
		block(g, Vector3(c.x, 1.82 + hh / 2.0, c.z), Vector3(step * 0.6, hh, 0.98), mats[r.randi() % mats.size()], rot)
		if k % 3 == 1:
			block(g, Vector3(c.x, 1.82 + hh + 0.05, c.z), Vector3(step * 0.5, 0.1, 0.9), wood, rot, false)
	# Tall timber posts through the wall with dark caps. (Banners on its
	# yard face were tried: at the match camera they showed as slivers on
	# the wall's edge for a dozen extra draws, so the yard's banners stay on
	# the castle face and the station awnings.)
	var pts: Array = []
	if posts_at.is_empty():
		var np := maxi(int(round(length / 4.2)), 1)
		for k in np + 1:
			pts.append(a0 + along * (k * length / np))
	else:
		# (Pass 3: the station wall's posts stand between the class banners.)
		pts = [a0, b0]
		for q in posts_at:
			pts.append(Vector3(q.x, 0, q.z) + sh)
	for p in pts:
		block(g, Vector3(p.x, 1.3, p.z), Vector3(0.42, 2.6, 1.24), wood, rot)
		block(g, Vector3(p.x, 2.64, p.z), Vector3(0.52, 0.12, 1.34), dark, rot)
	if flags:
		# Pass 3 (2026-10-31): team flags on poles along the top (the picks'
		# walls fly banners). Flat cloth facing the camera, so they read at
		# the match camera where banners on the wall's faces showed as slivers.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var team_c: Color = Stats.FACTIONS[0].color
		for i in pts.size():
			if i % 2 == 1 and pts.size() > 3:
				continue
			_flag(st, pts[i] + Vector3(0, 2.7, 0), team_c, i)
		var mi := MeshInstance3D.new()
		mi.mesh = StaticBatch.kept_mesh(st)
		mi.material_override = _awning_mat(g)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)


static func _flag(st: SurfaceTool, foot: Vector3, col: Color, seed: int) -> void:
	## A flag on a pole: a dark pole with a gold knob and a swallow-tailed
	## cloth in the team colour with a gold stripe, flying along x.
	var dark := Color(0.3, 0.2, 0.12)
	var gold := Color(0.85, 0.66, 0.28)
	var h := 1.15
	_beam(st, foot, foot + Vector3(0, h, 0), 0.07, dark)
	_beam(st, foot + Vector3(0, h, 0), foot + Vector3(0, h + 0.1, 0), 0.12, gold)
	var dir := 1.0 if seed % 2 == 0 else -1.0
	var w := 0.78 * dir
	var t := foot + Vector3(0.03 * dir, h - 0.04, 0)
	var fh := 0.5
	var p0 := t
	var p1 := t + Vector3(w * 0.5, 0.06, 0.04)
	var p2 := t + Vector3(w, 0.0, 0.0)
	var c := col.lightened(0.05)
	c.a = 1.0
	# Cloth in two panels (a gentle wave), a swallow tail notched into the fly end.
	_quad(st, p0, p1, p1 - Vector3(0, fh, 0), p0 - Vector3(0, fh, 0), c)
	var c2 := c * 0.9
	c2.a = 1.0
	_quad(st, p1, p2, p2 - Vector3(w * 0.22, fh * 0.5, 0), p1 - Vector3(0, fh * 0.5, 0), c2)
	_quad(st, p1 - Vector3(0, fh * 0.5, 0), p2 - Vector3(w * 0.22, fh * 0.5, 0), p2 - Vector3(0, fh, 0), p1 - Vector3(0, fh, 0), c2)
	# The gold stripe across the cloth.
	var y0 := -fh * 0.4
	var y1 := -fh * 0.56
	_quad(st, p0 + Vector3(0, y0, 0.006), p1 + Vector3(0, y0, 0.006), p1 + Vector3(0, y1, 0.006), p0 + Vector3(0, y1, 0.006), gold)


# --- The yard's west wall (pass 4, 2026-10-31) ---------------------------------

static func brick_mats(g) -> Array:
	## Warm-brown brick (tools/make_castle_textures.py make_castle_brick): the
	## wall face and merlons, and a darker, browner plinth.
	var c := _cache(g)
	if not c.has("brick" + str(g.soot)):
		c["brick" + str(g.soot)] = [g._pbr("castle_brick", 0.3, Color(0.95, 0.86, 0.78)), g._pbr("castle_brick", 0.3, Color(0.7, 0.6, 0.54))]
	return c["brick" + str(g.soot)]


static func _brick_wall(g, a: Vector3, b: Vector3, along: Vector3, length: float, rot: float, seed: int, out: Vector3) -> void:
	## The open yard's outer side wall, the one the match camera looks along
	## (pick Battle A's left wall): a tall, thick warm-brown brick wall, a
	## darker plinth, a cream coping course, chunky brick merlons with cream
	## caps, lit braziers on corbels along its yard face and tall team banners
	## on poles over it. Its yard face stays where pass 2's wall had it
	## (0.24 m in from the kerb line) and it grows only outward, away from
	## the yard, so at the match camera it leans away from the yard. Visual
	## only: the kerb and the invisible wall stay the caller's.
	const INNER := -0.24
	const OUTER := 1.4
	const TOP := 2.9   # the brick body's top (the coping and merlons sit on it)
	var thick := OUTER - INNER
	var sh := out * (INNER + OUTER) / 2.0
	# Run a little past both corner piers, so the corners close.
	var a0 := a + sh - along * 0.6
	var b0 := b + sh + along * 0.6
	var full := length + 1.2
	var mid := (a0 + b0) / 2.0
	var bm := brick_mats(g)
	var cream := face_mats(g, false)
	var body := Vector3(full, TOP - 0.3, thick) if absf(along.x) > 0.5 else Vector3(thick, TOP - 0.3, full)
	_box(g, Vector3(mid.x, 0.3 + (TOP - 0.3) / 2.0, mid.z), body, bm[0])
	# A darker plinth course at the foot (shadowless: it sits in the wall's shade).
	block_course(g, a0, b0, 0.3, 0.46, thick + 0.14, false, seed, 0.9, 1.5, false, [bm[1]])
	# A thin cream string course two-thirds up, a hand proud of the brick.
	block_course(g, a0, b0, 1.96, 0.14, thick + 0.08, false, seed + 1, 1.2, 2.0, false, cream)
	# The coping: big blocks of the darker brick, proud of both faces.
	block_course(g, a0, b0, TOP, 0.3, thick + 0.22, false, seed + 2, 0.9, 1.5, true, [bm[1]])
	# Chunky brick merlons along the outer edge, the wall walk open behind
	# them on the yard side.
	var pitch := 1.35
	var n := maxi(int(round(full / pitch)), 1)
	var step := full / n
	var r := RandomNumberGenerator.new()
	r.seed = seed + 5
	var mt := 0.86
	var mo := out * (OUTER - 0.02 - mt / 2.0 - (INNER + OUTER) / 2.0)
	for k in n:
		var c := a0 + along * ((k + 0.5) * step) + mo
		var hh := 0.78 * r.randf_range(0.95, 1.0)
		block(g, Vector3(c.x, TOP + 0.3 + hh / 2.0, c.z), Vector3(step * 0.56, hh, mt), bm[0], rot)
	# Braziers on stone corbels along the yard face: an iron bowl and a
	# flame (game.gd's own fire, so it batches with the yard's), two of the
	# four with a cheap shadowless light.
	var iron: Material = g._iron()
	var fr := [0.17, 0.39, 0.61, 0.83]
	for i in fr.size():
		var p: Vector3 = a + along * (length * fr[i])
		var face := p + out * INNER
		block(g, Vector3(face.x, 2.38, face.z) - out * 0.22, Vector3(0.62, 0.24, 0.5), cream[0], rot)
		block(g, Vector3(face.x, 2.16, face.z) - out * 0.12, Vector3(0.4, 0.2, 0.3), cream[1], rot, false)
		var bowl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.15
		cm.height = 0.24
		cm.radial_segments = 10
		bowl.mesh = cm
		bowl.position = Vector3(face.x, 2.62, face.z) - out * 0.3
		bowl.material_override = iron
		bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(bowl)
		g._add_fire(Vector3(face.x, 2.68, face.z) - out * 0.3, 1.9)
		if i == 1 or i == 2:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.66, 0.32)
			light.light_energy = 1.2
			light.omni_range = 6.0
			light.omni_attenuation = 1.3
			light.shadow_enabled = false
			light.position = Vector3(face.x, 3.2, face.z) - out * 0.8
			g.add_child(light)
	# Tall team banners on poles over the merlons (pick Battle A's banners):
	# long hanging cloths facing the camera, hung on the pole's outer side so
	# they lean away from the yard.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var team_c: Color = Stats.FACTIONS[0].color
	var dir := signf(out.x) if absf(out.x) > 0.5 else 1.0
	for i in 5:
		var p: Vector3 = a + along * (length * (0.1 + 0.2 * i)) + out * (OUTER - 0.35)
		_banner_pole(st, Vector3(p.x, TOP + 0.3, p.z), team_c, dir)
	var mi := MeshInstance3D.new()
	mi.mesh = StaticBatch.kept_mesh(st)
	mi.material_override = _awning_mat(g)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)


static func _banner_pole(st: SurfaceTool, foot: Vector3, col: Color, dir: float) -> void:
	## A dark pole with a gold finial and a crossbar, and a long team-colour
	## banner hanging from it (flat, facing +z) with a gold hem, a gold
	## lozenge crest and a swallow-tailed foot. `dir` is the side of the
	## pole the cloth hangs on (+1 = +x).
	var dark := Color(0.3, 0.2, 0.12)
	var gold := Color(0.88, 0.68, 0.28)
	var h := 2.7
	_beam(st, foot, foot + Vector3(0, h, 0), 0.09, dark)
	_beam(st, foot + Vector3(0, h, 0), foot + Vector3(0, h + 0.16, 0), 0.16, gold)
	var w := 1.05
	var x0 := foot.x + dir * 0.06
	var x1 := x0 + dir * w
	var top := foot.y + h - 0.12
	var bot := top - 1.75
	var z := foot.z + 0.07
	_beam(st, Vector3(x0 - dir * 0.1, top + 0.04, z), Vector3(x1 + dir * 0.1, top + 0.04, z), 0.07, gold)
	var c := col.lightened(0.04)
	c.a = 1.0
	var lo := minf(x0, x1)
	var hi := maxf(x0, x1)
	_quad(st, Vector3(lo, top, z), Vector3(hi, top, z), Vector3(hi, bot, z), Vector3(lo, bot, z), c)
	# The swallow-tailed foot: two points, one under each outer edge.
	var tail := 0.38
	var mx := (lo + hi) / 2.0
	st.set_normal(Vector3(0, 0, 1))
	st.set_color(c)
	st.add_vertex(Vector3(lo, bot, z))
	st.add_vertex(Vector3(mx, bot, z))
	st.add_vertex(Vector3(lo, bot - tail, z))
	st.add_vertex(Vector3(mx, bot, z))
	st.add_vertex(Vector3(hi, bot, z))
	st.add_vertex(Vector3(hi, bot - tail, z))
	# A gold hem down both sides and under the crossbar.
	var e := 0.07
	_quad(st, Vector3(lo, top, z + 0.005), Vector3(lo + e, top, z + 0.005), Vector3(lo + e, bot, z + 0.005), Vector3(lo, bot, z + 0.005), gold)
	_quad(st, Vector3(hi - e, top, z + 0.005), Vector3(hi, top, z + 0.005), Vector3(hi, bot, z + 0.005), Vector3(hi - e, bot, z + 0.005), gold)
	_quad(st, Vector3(lo, top, z + 0.005), Vector3(hi, top, z + 0.005), Vector3(hi, top - e * 1.4, z + 0.005), Vector3(lo, top - e * 1.4, z + 0.005), gold)
	# A gold lozenge with a darker heart: the crest.
	var cy := top - 0.62
	for k in 2:
		var s := 1.0 - 0.45 * k
		var cc: Color = gold if k == 0 else col * 0.62
		cc.a = 1.0
		var zz := z + 0.01 + 0.005 * k
		_quad(st, Vector3(mx, cy + 0.36 * s, zz), Vector3(mx + 0.3 * s, cy, zz), Vector3(mx, cy - 0.36 * s, zz), Vector3(mx - 0.3 * s, cy, zz), cc)


static func palisade(g, a: Vector3, b: Vector3, team: int, face: Vector3, crest_at: Array, grey: bool, seed: int) -> void:
	## A timber palisade on a stone footing, behind the class stations: a
	## course of blocks, close vertical planks, two rails, square posts with
	## caps, and the team crest on the posts listed in `crest_at` (world
	## positions along the line), facing `face`.
	var f := _frame(a, b)
	var along: Vector3 = f[0]
	var across: Vector3 = f[1]
	var length: float = f[2]
	var rot := atan2(-along.z, along.x)
	block_course(g, a, b, 0.3, 0.5, 0.74, grey, seed, 0.8, 1.4)
	var dark: Material = g._timber(Color(0.5, 0.36, 0.24))
	var mid: Material = g._timber(Color(0.66, 0.5, 0.34))
	var r := RandomNumberGenerator.new()
	r.seed = seed
	# Planks: one long box per run with a plank texture would be a sticker;
	# separate planks with tops at slightly different heights instead.
	var w := 0.26
	var n := int(length / w)
	for k in n:
		var p := a + along * ((k + 0.5) * length / n)
		var h := 1.85 + r.randf_range(-0.06, 0.06)
		block(g, Vector3(p.x, 0.8 + h / 2.0, p.z), Vector3(length / n - 0.035, h, 0.1), mid if k % 3 else dark, rot)
	for y in [1.3, 2.38]:
		var rail_c := (a + b) / 2.0 - across * 0.09
		_box(g, Vector3(rail_c.x, y, rail_c.z), Vector3(length, 0.14, 0.1) if absf(along.x) > 0.5 else Vector3(0.1, 0.14, length), dark)
	# Square posts at both ends and under every crest.
	var posts: Array = [a, b]
	for cp in crest_at:
		posts.append(Vector3(cp.x, a.y, cp.z))
	for p in posts:
		block(g, Vector3(p.x, 1.35, p.z), Vector3(0.3, 2.7, 0.3), dark, rot)
		block(g, Vector3(p.x, 2.74, p.z), Vector3(0.38, 0.12, 0.38), g._gold(), rot)
	for cp in crest_at:
		g._add_crest(team, cp + face * 0.16 + Vector3(0, 1.95, 0), face, 0.5)


static func tower_dress(g, pos: Vector3, team: int, width: float, height: float, grey: bool, banner_out: Array) -> void:
	## A tower body's dressing: a block plinth, a corbelled parapet ring with
	## merlons, and long team banners on the faces in `banner_out`.
	var seed := int(absf(pos.x) * 11.0 + absf(pos.z) * 5.0)
	var hw := width / 2.0
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var across := Vector3(-side.z, 0, side.x)
		var a: Vector3 = pos + side * (hw + 0.04) - across * (hw + 0.12)
		var b: Vector3 = pos + side * (hw + 0.04) + across * (hw + 0.12)
		block_course(g, a, b, 0.0, 0.5, 0.3, grey, seed, 0.6, 1.0, false)
		# The parapet course a little proud, with a merlon at each corner and
		# one in the middle. (No string course: banners hang down the faces.)
		var a2: Vector3 = a + side * 0.14
		var b2: Vector3 = b + side * 0.14
		block_course(g, a2, b2, height - 0.4, 0.45, 0.4, grey, seed + 1, 0.8, 1.4)
		for f in [0.0, 0.5, 1.0]:
			var mp: Vector3 = a2.lerp(b2, f).lerp(a2.lerp(b2, 0.5), 0.12 if f != 0.5 else 0.0)
			block(g, Vector3(mp.x, height + 0.05 + 0.29, mp.z), Vector3(0.62, 0.58, 0.4), face_mats(g, grey)[int(f * 2) % 3], atan2(-across.z, across.x))
		seed += 7
	for out in banner_out:
		g._add_pennant(team, pos + out * (hw + 0.02) + Vector3(0, height - 0.75, 0), out, 0.95, 2.3)


static func tower_roof(g, pos: Vector3, team: int, width: float, height: float) -> void:
	## A tall tiled roof in the team colour with a gold finial, overhanging
	## the parapet (pick Spawn D's tower).
	var color: Color = Stats.FACTIONS[team].color
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.0
	rm.bottom_radius = width * 0.72
	rm.height = 2.4
	rm.radial_segments = 4
	roof.mesh = rm
	roof.rotation.y = PI / 4.0
	roof.position = pos + Vector3(0, height + 0.9 + 1.2, 0)
	roof.material_override = g._pbr("shingle", 1.4, color.lightened(0.08))
	g.add_child(roof)
	# The eave: a dark timber band under the tiles.
	_box(g, pos + Vector3(0, height + 0.86, 0), Vector3(width * 0.98, 0.14, width * 0.98), g._timber(Color(0.5, 0.36, 0.24)))
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			_box(g, pos + Vector3(xs * width * 0.42, height + 0.55, zs * width * 0.42), Vector3(0.18, 0.62, 0.18), g._timber(Color(0.5, 0.36, 0.24)))
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	knob.mesh = sm
	knob.position = pos + Vector3(0, height + 0.9 + 2.45, 0)
	knob.material_override = g._gold()
	g.add_child(knob)


static func courtyard_castle_face(g, team: int, bx: float, side: float) -> void:
	## The castle's back wall seen across the open spawn courtyard (pick
	## Spawn D's right-hand wall): a lit iron lantern either side of the
	## passage and a long team banner further along, hung on the wall's face.
	var face_x := bx + side * 0.62
	var out := Vector3(side, 0, 0)
	for zs in [-1.0, 1.0]:
		lantern(g, Vector3(face_x, 2.05, zs * 4.6), out, true)
		g._add_pennant(team, Vector3(face_x + side * 0.02, 2.95, zs * 7.8), out, 1.0, 2.2, zs > 0.0)
	# Pass 2 (2026-10-31): timber framing on the stone (the picks' walls mix
	# brown timber with the blocks): a beam under the wall top and posts
	# between the lanterns and banners, a hand proud of the face.
	var wood: Material = g._timber(Color(0.66, 0.5, 0.34))   # (the palisade's tints)
	var dark: Material = g._timber(Color(0.5, 0.36, 0.24))
	var hz: float = g.CELLAR_HALF_Z
	block(g, Vector3(face_x + side * 0.07, 3.05, 0.0), Vector3(0.16, 0.22, hz * 2.0 + 0.6), wood)
	for zs in [-1.0, 1.0]:
		for z in [6.2, 9.7]:
			block(g, Vector3(face_x + side * 0.08, 1.5, zs * z), Vector3(0.18, 3.0, 0.32), dark)


# --- Market row (pass 2, 2026-10-31) -------------------------------------------

## Each class station's awning colour (picks Spawn D / Battle A: the row reads
## as a market of class stalls, each under its own colour). Keys: Stats.Role.
const AWNING := {
	1: Color(0.2, 0.36, 0.72),    # Knight: royal blue
	2: Color(0.2, 0.5, 0.22),     # Ranger: forest green
	3: Color(0.42, 0.22, 0.74),   # Mage: violet
	4: Color(0.88, 0.64, 0.16),   # Healer: gold
	5: Color(0.86, 0.44, 0.14),   # Engineer: orange
	6: Color(0.64, 0.13, 0.17),   # Rogue: crimson
}


static func awning_color(role: int) -> Color:
	return AWNING.get(role, Color(0.3, 0.5, 0.3))


static func _awning_mat(g) -> StandardMaterial3D:
	var c := _cache(g)
	if not c.has("awning"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED   # thin cloth, seen from above and below
		c["awning"] = m
	return c["awning"]


static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color) -> void:
	var n := (p1 - p0).cross(p3 - p0).normalized()
	if n.y < -0.01 or (absf(n.y) <= 0.01 and n.z < 0.0):
		n = -n
	st.set_normal(n)
	st.set_color(col)
	for v in [p0, p1, p2, p0, p2, p3]:
		st.add_vertex(v)


static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	## A square timber from a to b (w thick), four long faces.
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized() * (w / 2.0)
	var v := axis.cross(u).normalized() * (w / 2.0)
	var corners := [u + v, -u + v, -u - v, u - v]
	for k in 4:
		var c0: Vector3 = corners[k]
		var c1: Vector3 = corners[(k + 1) % 4]
		var shade := col * (1.0 if (c0 + c1).y > 0.0 else 0.75)
		shade.a = 1.0
		_quad(st, a + c0, a + c1, b + c1, b + c0, shade)


static func station_awning(g, pos: Vector3, role: int, zb: float) -> void:
	## A striped market awning over a class station's sign: class colour and
	## cream stripes sloping out toward the yard from the sign's posts, a
	## scalloped valance with a gold trim, on two dark timber poles and
	## brackets. One vertex-coloured mesh per station (cheap to draw).
	## Everything sits behind (north of) the hat and above the camera's
	## sight lines onto the sign; visual only, no colliders.
	var col: Color = awning_color(role)
	var cream := Color(0.96, 0.9, 0.76)
	var gold := Color(0.85, 0.66, 0.28)
	var dark := Color(0.3, 0.2, 0.12)
	# High and shallow: the match camera looks down at ~50 degrees, so an
	# awning reaching further out or hanging lower would cover the sign's
	# emblem and name under it.
	var back_y := pos.y + 3.32
	var front_y := pos.y + 3.06
	var z0 := zb - 0.1
	var z1 := zb + 0.6
	var stripes := 5
	var width := 2.2
	var sw := width / stripes
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in stripes:
		var x0 := pos.x - width / 2.0 + k * sw
		var x1 := x0 + sw
		var c: Color = col if k % 2 == 0 else cream
		_quad(st, Vector3(x0, back_y, z0), Vector3(x1, back_y, z0), Vector3(x1, front_y, z1), Vector3(x0, front_y, z1), c)
		# The valance: a strip and a rounded (scalloped) flap per stripe.
		var vb := front_y - 0.14
		_quad(st, Vector3(x0, front_y, z1), Vector3(x1, front_y, z1), Vector3(x1, vb, z1), Vector3(x0, vb, z1), c * 0.92)
		var xc := (x0 + x1) / 2.0
		var segs := 6
		st.set_normal(Vector3(0, 0, 1))
		st.set_color(c * 0.92)
		for i in segs:
			var a0 := PI * i / segs
			var a1 := PI * (i + 1) / segs
			st.add_vertex(Vector3(xc, vb, z1))
			st.add_vertex(Vector3(xc + cos(a0) * sw / 2.0, vb - sin(a0) * sw * 0.32, z1))
			st.add_vertex(Vector3(xc + cos(a1) * sw / 2.0, vb - sin(a1) * sw * 0.32, z1))
	_beam(st, Vector3(pos.x - width / 2.0 - 0.02, front_y + 0.02, z1 + 0.03), Vector3(pos.x + width / 2.0 + 0.02, front_y + 0.02, z1 + 0.03), 0.05, gold)
	for xs in [-1.0, 1.0]:
		var bx: float = pos.x + xs * (width / 2.0 - 0.05)
		_beam(st, Vector3(bx, back_y - 0.06, z0), Vector3(bx, front_y - 0.06, z1), 0.08, dark)
		_beam(st, Vector3(bx, pos.y, z0 - 0.06), Vector3(bx, back_y, z0 - 0.06), 0.1, dark)
	var mi := MeshInstance3D.new()
	mi.mesh = StaticBatch.kept_mesh(st)   # (keeps its arrays for the batch: no GPU read-back)
	mi.material_override = _awning_mat(g)
	g.add_child(mi)


# --- Station wall and class banners (pass 3, 2026-10-31) ------------------------

static func station_wall(g, a: Vector3, b: Vector3, team: int, crest_at: Array, grey: bool, seed: int) -> void:
	## The courtyard's north wall behind the class stations (picks Spawn D /
	## Battle A): the tall crenellated block wall, thickened outward (north),
	## with brown timber posts between the stations carrying the team crest.
	## It replaces pass 2's timber palisade on the same kerb line; the kerb and
	## the invisible wall are the caller's. No flags here: anything above the
	## merlons would sit under the HUD's hint line at the match camera.
	var f := _frame(a, b)
	var along: Vector3 = f[0]
	var length: float = f[2]
	var rot := atan2(-along.z, along.x)
	_tall_courtyard_wall(g, a, b, along, length, rot, grey, seed, Vector3(0, 0, -1), crest_at, false)
	for cp in crest_at:
		# On the post's yard face (a post 1.24 thick about a line 0.32 out).
		g._add_crest(team, Vector3(cp.x, 1.75, a.z - 0.32 + 0.64), Vector3(0, 0, 1), 0.5)


static func station_banner(g, pos: Vector3, role: int, zb: float) -> void:
	## The class station's sign worn as a square class banner (pick Spawn D):
	## a gold rod with knobs across the sign posts, cloth tabs up to it and a
	## dagged tail below the panel, in the class colour with a gold hem. The
	## panel itself (class colour, the class crest in its glow, the name) is
	## game.gd's, so the sign and the hat stay exactly as readable; nothing
	## here rises above the sign's crossbeam (the HUD hint line sits there).
	var col: Color = awning_color(role)
	var gold := Color(0.85, 0.66, 0.28)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := zb + 0.04
	var rod_y := pos.y + 2.5
	_beam(st, Vector3(pos.x - 1.04, rod_y, z + 0.04), Vector3(pos.x + 1.04, rod_y, z + 0.04), 0.06, gold)
	var ct := col * 0.8
	ct.a = 1.0
	for xs in [-1.0, 1.0]:
		var kx: float = pos.x + xs * 1.08
		_beam(st, Vector3(kx, rod_y - 0.06, z + 0.04), Vector3(kx, rod_y + 0.06, z + 0.04), 0.12, gold)
		# Cloth tabs looping over the rod down to the panel's top.
		var tx: float = pos.x + xs * 0.5
		_quad(st, Vector3(tx - 0.1, rod_y + 0.03, z + 0.03), Vector3(tx + 0.1, rod_y + 0.03, z + 0.03), Vector3(tx + 0.1, pos.y + 2.4, z + 0.03), Vector3(tx - 0.1, pos.y + 2.4, z + 0.03), ct)
	# The dagged tail under the panel's lower hem: three points.
	var y0 := pos.y + 1.31
	var y1 := pos.y + 1.1
	var y2 := pos.y + 0.9
	var w := 0.75
	var c := col * 0.92
	c.a = 1.0
	_quad(st, Vector3(pos.x - w, y0, z), Vector3(pos.x + w, y0, z), Vector3(pos.x + w, y1, z), Vector3(pos.x - w, y1, z), c)
	for k in 3:
		var x0 := pos.x - w + k * (2.0 * w / 3.0)
		var x1 := x0 + 2.0 * w / 3.0
		st.set_normal(Vector3(0, 0, 1))
		st.set_color(c)
		st.add_vertex(Vector3(x0, y1, z))
		st.add_vertex(Vector3(x1, y1, z))
		st.add_vertex(Vector3((x0 + x1) / 2.0, y2, z))
	# A gold hem down the tail's sides and across its points' root.
	for xs in [-1.0, 1.0]:
		var hx: float = pos.x + xs * (w - 0.03)
		_quad(st, Vector3(hx - 0.03, y0, z + 0.005), Vector3(hx + 0.03, y0, z + 0.005), Vector3(hx + 0.03, y1, z + 0.005), Vector3(hx - 0.03, y1, z + 0.005), gold)
	_quad(st, Vector3(pos.x - w, y1 + 0.05, z + 0.005), Vector3(pos.x + w, y1 + 0.05, z + 0.005), Vector3(pos.x + w, y1, z + 0.005), Vector3(pos.x - w, y1, z + 0.005), gold)
	var mi := MeshInstance3D.new()
	mi.mesh = StaticBatch.kept_mesh(st)
	mi.material_override = _awning_mat(g)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
