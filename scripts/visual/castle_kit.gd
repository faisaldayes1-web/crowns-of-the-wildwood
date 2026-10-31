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
	return g._pbr("castle_blocks_grey" if grey else "castle_blocks", 0.3)


static func face_mats(g, grey: bool) -> Array:
	## Three close shades of the modelled blocks' stone, so neighbouring
	## blocks read as separate stones.
	var key := "face_grey" if grey else "face"
	var c := _cache(g)
	if not c.has(key + str(g.soot)):
		var tints := [Color(1.0, 1.0, 1.0), Color(0.93, 0.9, 0.86), Color(1.04, 1.0, 0.94)] if not grey \
			else [Color(1.0, 1.0, 1.0), Color(0.9, 0.91, 0.94), Color(1.05, 1.04, 1.02)]
		var mats := []
		for t in tints:
			mats.append(g._pbr("castle_face_grey" if grey else "castle_face", 0.5, t))
		c[key + str(g.soot)] = mats
	return c[key + str(g.soot)]


static func mortar_mat(g, grey: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = g._material((Color(0.3, 0.29, 0.3) if grey else Color(0.4, 0.31, 0.22)) * g.soot)
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
		min_len: float = 0.7, max_len: float = 1.25, shadow: bool = true) -> void:
	## One course of individual blocks from a to b (their feet at y0), random
	## lengths, a hand-width gap between them, each its own shade and set a
	## touch proud or back, so the wall reads as stacked stones.
	var f := _frame(a, b)
	var along: Vector3 = f[0]
	var across: Vector3 = f[1]
	var length: float = f[2]
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var mats := face_mats(g, grey)
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


static func courtyard_wall(g, a: Vector3, b: Vector3, grey: bool, seed: int, merlon_h: float = 0.42, post_every: float = 4.6) -> void:
	## The open courtyard's low wall on its kerb line a->b: a dark mortar
	## core, two courses of big bevelled blocks, a crenellated cap and timber
	## posts with iron-capped tops (picks Spawn D / Battle A).
	var f := _frame(a, b)
	var along: Vector3 = f[0]
	var length: float = f[2]
	var rot := atan2(-along.z, along.x)
	var mid := (a + b) / 2.0
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
