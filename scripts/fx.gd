extends Node3D
## Combat effects: hit sparks, slash arcs, spell bursts, heals, status auras.
## One instance lives under the game node (Fx.of(game) makes it on first use).
## Everything here is CPU particles, unshaded additive or alpha quads and
## generated gradient textures, so it looks the same in the Compatibility
## renderer the web (iPad) build uses as in Forward+. Nothing here changes
## gameplay: it only draws.

const STYLE_SPARK := 0   # bright streaks that fly out and fall
const STYLE_MOTE := 1    # soft glowing dots that drift up
const STYLE_SMOKE := 2   # soft grey puffs that grow and fade
const STYLE_SHARD := 3   # tumbling chips (ice, wood, stone, leaves)

# What each kind of hit looks like: core colour, spark colour, extra style.
const KINDS := {
	"melee": {"core": Color(1.0, 0.95, 0.8), "spark": Color(1.0, 0.85, 0.45), "extra": -1},
	"fist": {"core": Color(1.0, 0.9, 0.75), "spark": Color(1.0, 0.75, 0.5), "extra": STYLE_SMOKE},
	"venom": {"core": Color(0.75, 1.0, 0.45), "spark": Color(0.45, 0.95, 0.3), "extra": STYLE_MOTE},
	"arrow": {"core": Color(1.0, 0.95, 0.8), "spark": Color(0.85, 0.7, 0.5), "extra": STYLE_SHARD},
	"arcane": {"core": Color(0.85, 0.65, 1.0), "spark": Color(0.7, 0.45, 1.0), "extra": STYLE_MOTE},
	"fire": {"core": Color(1.0, 0.85, 0.4), "spark": Color(1.0, 0.5, 0.12), "extra": STYLE_SMOKE},
	"frost": {"core": Color(0.85, 0.95, 1.0), "spark": Color(0.6, 0.85, 1.0), "extra": STYLE_SHARD},
	"holy": {"core": Color(1.0, 0.97, 0.75), "spark": Color(1.0, 0.88, 0.45), "extra": STYLE_MOTE},
	"dark": {"core": Color(0.75, 0.45, 1.0), "spark": Color(0.5, 0.2, 0.75), "extra": STYLE_SMOKE},
	"nature": {"core": Color(0.8, 1.0, 0.6), "spark": Color(0.4, 0.85, 0.3), "extra": STYLE_SHARD},
	"heavy": {"core": Color(1.0, 0.97, 0.9), "spark": Color(1.0, 0.8, 0.4), "extra": STYLE_SMOKE},
}

static var _tex := {}
var _mats := {}
var _arc_mesh: ArrayMesh
var _quad: QuadMesh
var _streak: BoxMesh
var _chip: BoxMesh
var game


static func of(g) -> Node:
	## The game's effects node, made the first time anyone asks.
	var f: Node = g.get_node_or_null("Fx")
	if f == null:
		f = load("res://scripts/fx.gd").new()
		f.name = "Fx"
		f.game = g
		g.add_child(f)
	return f


func _ready() -> void:
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_streak = BoxMesh.new()
	_streak.size = Vector3(0.05, 0.42, 0.05)
	_chip = BoxMesh.new()
	_chip.size = Vector3(0.13, 0.05, 0.1)


# --- Textures and materials --------------------------------------------------

static func texture(kind: String) -> Texture2D:
	## Generated once: "soft" (round glow), "ring" (a bright band),
	## "star" (a four-point flare), "rune" (a ring with ticks).
	if _tex.has(kind):
		return _tex[kind]
	var t: Texture2D
	if kind == "soft" or kind == "ring":
		var g := Gradient.new()
		if kind == "soft":
			g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		else:
			g.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 0.9, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.08), Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		t = gt
	else:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
				var r := p.length()
				var a := 0.0
				if kind == "star":
					# Two thin crossed rays and a hot core.
					var ray := maxf(1.0 - absf(p.x) * 9.0, 0.0) * maxf(1.0 - absf(p.y), 0.0) \
						+ maxf(1.0 - absf(p.y) * 9.0, 0.0) * maxf(1.0 - absf(p.x), 0.0)
					a = clampf(ray + maxf(1.0 - r * 2.2, 0.0), 0.0, 1.0)
				else:
					# rune: a thin ring with eight ticks and an inner ring
					var band := maxf(1.0 - absf(r - 0.86) * 22.0, 0.0) + maxf(1.0 - absf(r - 0.62) * 30.0, 0.0) * 0.7
					var ang := atan2(p.y, p.x)
					var tick := maxf(1.0 - absf(fposmod(ang, TAU / 8.0) - TAU / 16.0) * 10.0, 0.0)
					if r > 0.64 and r < 0.84:
						band += tick
					a = clampf(band, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		t = ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


func _mat(tex: String, additive: bool, billboard: int) -> StandardMaterial3D:
	## Shared particle and decal materials; the colour comes from vertex
	## colour (particles) or the instance's modulate tween (quads get a dup).
	var key := "%s/%s/%d" % [tex, additive, billboard]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	if tex != "":
		m.albedo_texture = texture(tex)
	m.billboard_mode = billboard
	if billboard == BaseMaterial3D.BILLBOARD_PARTICLES:
		m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	_mats[key] = m
	return m


# --- Particles ---------------------------------------------------------------

func burst(where: Vector3, color: Color, count: int, speed: float, life: float, style: int = STYLE_SPARK,
		dir: Vector3 = Vector3.UP, spread: float = 180.0, size: float = 1.0) -> void:
	var n = _net_open("fx", "burst", [where, color, count, speed, life, style, dir, spread, size])
	_x_burst(where, color, count, speed, life, style, dir, spread, size)
	_net_close(n)


func _x_burst(where: Vector3, color: Color, count: int, speed: float, life: float, style: int = STYLE_SPARK,
		dir: Vector3 = Vector3.UP, spread: float = 180.0, size: float = 1.0) -> void:
	## A one-shot spray. `dir`/`spread` aim it (hits spray away from the blow).
	if count <= 0:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = 2.0
	p.damping_max = 5.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	match style:
		STYLE_SPARK:
			p.mesh = _streak
			p.particle_flag_align_y = true
			p.gravity = Vector3(0, -16, 0)
			p.scale_amount_min = 0.5 * size
			p.scale_amount_max = 1.1 * size
			p.mesh.material = _mat("", true, BaseMaterial3D.BILLBOARD_DISABLED)
			ramp.colors = PackedColorArray([Color(1, 1, 1, 1).lerp(color, 0.3), color, Color(color, 0)])
		STYLE_MOTE:
			p.mesh = _quad
			p.gravity = Vector3(0, 2.8, 0)
			p.scale_amount_min = 0.25 * size
			p.scale_amount_max = 0.55 * size
			p.material_override = _mat("soft", true, BaseMaterial3D.BILLBOARD_PARTICLES)
			ramp.colors = PackedColorArray([Color(1, 1, 1, 1).lerp(color, 0.5), color, Color(color, 0)])
		STYLE_SMOKE:
			p.mesh = _quad
			p.gravity = Vector3(0, 1.2, 0)
			p.explosiveness = 0.8
			p.scale_amount_min = 0.7 * size
			p.scale_amount_max = 1.3 * size
			var grow := Curve.new()
			grow.add_point(Vector2(0, 0.5))
			grow.add_point(Vector2(1, 1.6))
			p.scale_amount_curve = grow
			p.material_override = _mat("soft", false, BaseMaterial3D.BILLBOARD_PARTICLES)
			ramp.colors = PackedColorArray([Color(color, 0.55), Color(color, 0.35), Color(color, 0)])
		STYLE_SHARD:
			p.mesh = _chip
			p.gravity = Vector3(0, -14, 0)
			p.angular_velocity_min = -720.0
			p.angular_velocity_max = 720.0
			p.particle_flag_rotate_y = true
			p.scale_amount_min = 0.6 * size
			p.scale_amount_max = 1.3 * size
			p.mesh.material = _mat("", false, BaseMaterial3D.BILLBOARD_DISABLED)
			ramp.colors = PackedColorArray([color.lightened(0.3), color, Color(color, 0)])
	p.color_ramp = ramp
	add_child(p)
	p.global_position = where
	p.emitting = true
	get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


func _sprite(where: Vector3, tex: String, color: Color, size: float, life: float, grow: float = 1.6,
		flat: bool = false, spin: float = 0.0, additive: bool = true) -> MeshInstance3D:
	## A textured quad that pops, grows and fades: flares, rings, glows, decals.
	var q := MeshInstance3D.new()
	q.mesh = _quad
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = _mat(tex, additive, BaseMaterial3D.BILLBOARD_DISABLED if flat else BaseMaterial3D.BILLBOARD_ENABLED).duplicate()
	m.vertex_color_use_as_albedo = false
	m.albedo_color = color
	q.material_override = m
	add_child(q)
	q.global_position = where
	if flat:
		q.rotation = Vector3(-PI / 2.0, randf() * TAU, 0)
	q.scale = Vector3.ONE * size * 0.45
	var tw := q.create_tween()
	tw.set_parallel(true)
	tw.tween_property(q, "scale", Vector3.ONE * size * grow, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	if spin != 0.0:
		tw.tween_property(q, "rotation:y" if flat else "rotation:z", q.rotation.y + spin if flat else spin, life)
	tw.chain().tween_callback(q.queue_free)
	return q


func flare(where: Vector3, color: Color, size: float = 1.4, life: float = 0.16) -> void:
	var n = _net_open("fx", "flare", [where, color, size, life])
	_x_flare(where, color, size, life)
	_net_close(n)


func _x_flare(where: Vector3, color: Color, size: float = 1.4, life: float = 0.16) -> void:
	## The bright four-point star that marks the moment of a hit.
	# Kept small and half-strength: additive white on sunlit grass washes out.
	_sprite(where, "star", Color(color, 0.85), size * 0.6, life, 1.3, false, randf_range(-0.8, 0.8))
	_sprite(where, "soft", Color(color, 0.45), size * 0.5, life * 1.3, 1.2)


func ground_ring(where: Vector3, radius: float, color: Color, life: float = 0.45) -> void:
	var n = _net_open("fx", "ground_ring", [where, radius, color, life])
	_x_ground_ring(where, radius, color, life)
	_net_close(n)


func _x_ground_ring(where: Vector3, radius: float, color: Color, life: float = 0.45) -> void:
	## A shockwave on the ground that races out to `radius`.
	_sprite(Vector3(where.x, where.y + 0.14, where.z), "ring", color, radius * 2.0 / 1.5, life, 1.5, true)


func ground_glow(where: Vector3, radius: float, color: Color, life: float = 0.5) -> void:
	var n = _net_open("fx", "ground_glow", [where, radius, color, life])
	_x_ground_glow(where, radius, color, life)
	_net_close(n)


func _x_ground_glow(where: Vector3, radius: float, color: Color, life: float = 0.5) -> void:
	_sprite(Vector3(where.x, where.y + 0.12, where.z), "soft", Color(color, color.a * 0.45), radius * 2.0 / 1.2, life, 1.2, true)


func rune(where: Vector3, radius: float, color: Color, life: float = 0.55) -> void:
	var n = _net_open("fx", "rune", [where, radius, color, life])
	_x_rune(where, radius, color, life)
	_net_close(n)


func _x_rune(where: Vector3, radius: float, color: Color, life: float = 0.55) -> void:
	## A spinning circle of light under a caster.
	_sprite(Vector3(where.x, where.y + 0.13, where.z), "rune", color, radius * 2.0, life, 1.15, true, 1.6)


func scorch(where: Vector3, radius: float, color: Color = Color(0.08, 0.06, 0.05, 0.7), life: float = 3.5) -> void:
	var n = _net_open("fx", "scorch", [where, radius, color, life])
	_x_scorch(where, radius, color, life)
	_net_close(n)


func _x_scorch(where: Vector3, radius: float, color: Color = Color(0.08, 0.06, 0.05, 0.7), life: float = 3.5) -> void:
	## A dark mark left on the ground by a blast; fades slowly.
	_sprite(Vector3(where.x, where.y + 0.11, where.z), "soft", color, radius * 2.0 / 1.25, life, 1.25, true, 0.0, false)


func beam(from: Vector3, to: Vector3, color: Color, life: float = 0.3, width: float = 0.16) -> void:
	var n = _net_open("fx", "beam", [from, to, color, life, width])
	_x_beam(from, to, color, life, width)
	_net_close(n)


func _x_beam(from: Vector3, to: Vector3, color: Color, life: float = 0.3, width: float = 0.16) -> void:
	## A thin line of light from one point to another (heals, drains).
	var d := to - from
	var length := d.length()
	if length < 0.2:
		return
	var b := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, length)
	b.mesh = box
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	b.material_override = m
	add_child(b)
	b.global_position = from + d * 0.5
	b.look_at(to, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	var tw := b.create_tween()
	tw.set_parallel(true)
	tw.tween_property(b, "scale", Vector3(0.2, 0.2, 1.0), life).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(b.queue_free)


# --- Slash arcs ---------------------------------------------------------------

func _arc() -> ArrayMesh:
	## A flat crescent (160°, radius 0.55-1.75) whose alpha runs from 0 at the
	## trailing end to 1 at the leading end, so the swing reads as motion.
	if _arc_mesh:
		return _arc_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 18
	var span := deg_to_rad(160.0)
	for i in seg:
		var a0 := -span / 2.0 + span * i / seg
		var a1 := -span / 2.0 + span * (i + 1) / seg
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var thick0 := sin(t0 * PI) * 0.75 + 0.25
		var thick1 := sin(t1 * PI) * 0.75 + 0.25
		var r_in0 := 1.75 - 1.2 * thick0
		var r_in1 := 1.75 - 1.2 * thick1
		var c0 := Color(1, 1, 1, t0 * t0)
		var c1 := Color(1, 1, 1, t1 * t1)
		var o0 := Vector3(sin(a0), 0, -cos(a0)) * 1.75
		var o1 := Vector3(sin(a1), 0, -cos(a1)) * 1.75
		var i0 := Vector3(sin(a0), 0, -cos(a0)) * r_in0
		var i1 := Vector3(sin(a1), 0, -cos(a1)) * r_in1
		var ci0 := Color(1, 1, 1, 0)
		for v in [[i0, ci0], [o0, c0], [o1, c1], [i0, ci0], [o1, c1], [i1, ci0]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	_arc_mesh = st.commit()
	return _arc_mesh


func slash(origin: Vector3, aim: Vector3, color: Color, reach: float = 1.0, heavy: bool = false, flip: bool = false) -> void:
	var n = _net_open("fx", "slash", [origin, aim, color, reach, heavy, flip])
	_x_slash(origin, aim, color, reach, heavy, flip)
	_net_close(n)


func _x_slash(origin: Vector3, aim: Vector3, color: Color, reach: float = 1.0, heavy: bool = false, flip: bool = false) -> void:
	## A crescent that sweeps across the aim direction and fades: the swing.
	var s := MeshInstance3D.new()
	s.mesh = _arc()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, 0.95)
	s.material_override = m
	add_child(s)
	s.global_position = origin + Vector3(0, 0.95 if not heavy else 0.8, 0)
	var yaw := atan2(aim.x, -aim.z)
	var sweep := deg_to_rad(70.0) * (-1.0 if flip else 1.0)
	s.rotation = Vector3(deg_to_rad(randf_range(-12.0, 12.0)), -yaw + sweep * -0.5, 0)
	if flip:
		s.scale = Vector3(-1, 1, 1)
	var sc := reach * (1.25 if heavy else 1.0)
	s.scale *= sc
	var life := 0.2 if heavy else 0.15
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "rotation:y", -yaw + sweep * 0.5, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 1.4).set_delay(life * 0.35)
	tw.chain().tween_callback(s.queue_free)


# --- Composite effects ---------------------------------------------------------

func hit(where: Vector3, push: Vector3, kind: String, amount: int = 1) -> void:
	var n = _net_open("fx", "hit", [where, push, kind, amount])
	_x_hit(where, push, kind, amount)
	_net_close(n)


func _x_hit(where: Vector3, push: Vector3, kind: String, amount: int = 1) -> void:
	## The moment a blow lands: flare, sparks thrown away from the attacker,
	## and a kind-specific extra (smoke, motes, chips).
	var k: Dictionary = KINDS.get(kind, KINDS.melee)
	var big := amount >= 2 or kind == "heavy"
	var away := push if push.length() > 0.05 else Vector3.UP
	away = (away + Vector3(0, 0.6, 0)).normalized()
	flare(where, k.core, 1.6 if big else 1.15, 0.18 if big else 0.14)
	burst(where, k.spark, 12 if big else 7, 9.0 if big else 7.0, 0.32, STYLE_SPARK, away, 38.0)
	match int(k.extra):
		STYLE_SMOKE:
			burst(where, Color(0.55, 0.5, 0.48) if kind != "dark" else Color(0.3, 0.15, 0.4), 4, 1.6, 0.6, STYLE_SMOKE, Vector3.UP, 60.0, 0.8)
		STYLE_MOTE:
			burst(where, k.spark, 8, 3.0, 0.55, STYLE_MOTE)
		STYLE_SHARD:
			burst(where, k.spark, 6, 5.0, 0.5, STYLE_SHARD, away, 50.0)
	if big:
		ground_ring(Vector3(where.x, where.y - 1.0, where.z), 1.4, k.spark, 0.3)


func blast(where: Vector3, radius: float, kind: String) -> void:
	var n = _net_open("fx", "blast", [where, radius, kind])
	_x_blast(where, radius, kind)
	_net_close(n)


func _x_blast(where: Vector3, radius: float, kind: String) -> void:
	## An area hit (fireball, frost burst, splash bolts, curses): flare,
	## shockwave, sparks, debris or motes, smoke and a scorch mark.
	var k: Dictionary = KINDS.get(kind, KINDS.arcane)
	var ground := Vector3(where.x, where.y - 1.0 if where.y > 0.8 else where.y, where.z)
	var big := radius >= 2.5
	flare(where, k.core, 1.2 + radius * 0.35, 0.22)
	ground_ring(ground, radius, k.spark, 0.4 if big else 0.32)
	ground_glow(ground, radius * 0.9, k.spark, 0.45)
	burst(where, k.spark, int(10 + radius * 6), 6.0 + radius * 2.0, 0.5, STYLE_SPARK, Vector3.UP, 85.0)
	match kind:
		"fire":
			burst(where, Color(1.0, 0.6, 0.15), int(6 + radius * 3), 3.0, 0.8, STYLE_MOTE)
			burst(where + Vector3(0, 0.3, 0), Color(0.22, 0.2, 0.19), int(4 + radius * 2), 2.0, 1.3, STYLE_SMOKE, Vector3.UP, 70.0, 1.0 + radius * 0.2)
			scorch(ground, radius * 0.8)
		"frost":
			burst(where, Color(0.85, 0.95, 1.0), int(8 + radius * 3), 6.0, 0.7, STYLE_SHARD)
			burst(where, Color(0.8, 0.95, 1.0), int(4 + radius * 2), 1.5, 1.0, STYLE_SMOKE, Vector3.UP, 80.0, 1.0)
			scorch(ground, radius * 0.75, Color(0.75, 0.9, 1.0, 0.45), 2.5)
		"nature":
			burst(where, Color(0.35, 0.75, 0.25), int(8 + radius * 3), 5.0, 0.8, STYLE_SHARD)
			scorch(ground, radius * 0.7, Color(0.15, 0.3, 0.1, 0.5), 2.5)
			# Brambles burst out of the ground round the impact.
			thorns(ground, radius * 0.75, Color(0.3, 0.6, 0.2), int(6 + radius * 2.5), 0.9 if big else 0.6, 1.2 if big else 0.6)
			petals(where, Color(0.4, 0.85, 0.3), int(4 + radius * 2), 3.0, 1.2)
		"dark":
			burst(where, Color(0.6, 0.25, 0.85), int(8 + radius * 3), 3.0, 0.9, STYLE_MOTE)
			burst(where, Color(0.25, 0.1, 0.35), 5, 1.5, 1.0, STYLE_SMOKE, Vector3.UP, 80.0, 1.1)
		_:
			burst(where, k.spark, int(6 + radius * 3), 3.0, 0.7, STYLE_MOTE)


func heal_on(target: Node3D, amount: int, healer: Node3D = null) -> void:
	var n = _net_open("fx", "heal_on", [target, amount, healer])
	_x_heal_on(target, amount, healer)
	_net_close(n)


func _x_heal_on(target: Node3D, amount: int, healer: Node3D = null) -> void:
	## Green light rising round whoever is mended, a cross of light over
	## them, and a thread from the healer when it came from someone else.
	var at := target.global_position
	var green := Color(0.4, 1.0, 0.5)
	ground_glow(at, 1.0 + amount * 0.2, green, 0.6)
	burst(at + Vector3(0, 0.5, 0), green, 8 + amount * 4, 2.2, 0.9, STYLE_MOTE, Vector3.UP, 35.0)
	for i in mini(amount, 3):
		_cross(at + Vector3(randf_range(-0.45, 0.45), 1.5 + i * 0.35, randf_range(-0.3, 0.3)), green, i * 0.08)
	if healer and healer != target:
		beam(healer.global_position + Vector3(0, 1.2, 0), at + Vector3(0, 1.0, 0), Color(0.5, 1.0, 0.6, 0.8), 0.3, 0.12)


func _cross(where: Vector3, color: Color, delay: float) -> void:
	## A little "+" of light that floats up and fades.
	var l := Label3D.new()
	l.text = "+"
	l.font_size = 72
	l.pixel_size = 0.01
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.3, 0.1, 0.9)
	l.modulate = Color(color, 0.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = where
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", where.y + 0.9, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func cast(caster: Node3D, color: Color, radius: float = 1.1) -> void:
	var n = _net_open("fx", "cast", [caster, color, radius])
	_x_cast(caster, color, radius)
	_net_close(n)


func _x_cast(caster: Node3D, color: Color, radius: float = 1.1) -> void:
	## A spell leaving the hands: a rune circle under the caster and a glow.
	rune(caster.global_position, radius, color, 0.5)
	burst(caster.global_position + Vector3(0, 1.1, 0), color, 6, 2.0, 0.4, STYLE_MOTE)


func death(where: Vector3, color: Color) -> void:
	var n = _net_open("fx", "death", [where, color])
	_x_death(where, color)
	_net_close(n)


func _x_death(where: Vector3, color: Color) -> void:
	## A fall: a puff of dust, sparks of the team colour and a wisp rising.
	burst(where + Vector3(0, 0.6, 0), Color(0.6, 0.57, 0.52), 8, 2.2, 1.0, STYLE_SMOKE, Vector3.UP, 80.0, 1.2)
	burst(where + Vector3(0, 1.0, 0), color, 14, 3.5, 0.9, STYLE_MOTE)
	ground_ring(where, 1.8, color.lightened(0.3), 0.5)
	var wisp := CPUParticles3D.new()
	wisp.one_shot = true
	wisp.amount = 10
	wisp.lifetime = 1.2
	wisp.explosiveness = 0.3
	wisp.local_coords = false
	wisp.direction = Vector3.UP
	wisp.spread = 8.0
	wisp.initial_velocity_min = 2.5
	wisp.initial_velocity_max = 3.5
	wisp.gravity = Vector3.ZERO
	wisp.mesh = _quad
	wisp.scale_amount_min = 0.35
	wisp.scale_amount_max = 0.6
	wisp.material_override = _mat("soft", true, BaseMaterial3D.BILLBOARD_PARTICLES)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(color.lightened(0.4), 0)])
	wisp.color_ramp = ramp
	add_child(wisp)
	wisp.global_position = where + Vector3(0, 1.0, 0)
	wisp.emitting = true
	get_tree().create_timer(1.6).timeout.connect(wisp.queue_free)


func status_emitter(host: Node3D, kind: String) -> CPUParticles3D:
	## A looping aura on a unit, switched on and off with `emitting`:
	## "slow" green venom drips, "root" vines of light, "haste" wind streaks,
	## "guard" bark/steel motes.
	var p := CPUParticles3D.new()
	p.emitting = false
	p.local_coords = false
	p.mesh = _quad
	p.material_override = _mat("soft", true, BaseMaterial3D.BILLBOARD_PARTICLES)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	var ramp := Gradient.new()
	match kind:
		"slow":
			p.amount = 10
			p.lifetime = 0.7
			p.gravity = Vector3(0, -3.0, 0)
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.3
			p.position = Vector3(0, 1.3, 0)
			ramp.colors = PackedColorArray([Color(0.6, 1.0, 0.35, 0.9), Color(0.3, 0.75, 0.2, 0)])
		"root":
			p.amount = 14
			p.lifetime = 0.6
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = 0.75
			p.emission_ring_inner_radius = 0.6
			p.emission_ring_height = 0.05
			p.direction = Vector3.UP
			p.spread = 5.0
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 2.0
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.25
			p.position = Vector3(0, 0.1, 0)
			ramp.colors = PackedColorArray([Color(0.75, 0.95, 1.0, 0.9), Color(0.4, 0.8, 0.5, 0)])
		"haste":
			p.amount = 10
			p.lifetime = 0.35
			p.mesh = _streak
			p.material_override = null
			p.mesh.material = _mat("", true, BaseMaterial3D.BILLBOARD_DISABLED)
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.0
			p.position = Vector3(0, 0.9, 0)
			ramp.colors = PackedColorArray([Color(0.9, 0.97, 1.0, 0.7), Color(0.9, 0.97, 1.0, 0)])
		_:  # guard
			p.amount = 12
			p.lifetime = 0.8
			p.emission_sphere_radius = 0.8
			p.gravity = Vector3(0, 1.0, 0)
			p.scale_amount_min = 0.15
			p.scale_amount_max = 0.3
			p.position = Vector3(0, 1.0, 0)
			ramp.colors = PackedColorArray([Color(0.75, 0.88, 1.0, 0.8), Color(0.5, 0.75, 1.0, 0)])
	p.color_ramp = ramp
	host.add_child(p)
	return p


# --- Skill building blocks (used by skill_fx.gd) -------------------------------

const STYLE_PETAL := 4    # flat flakes that flutter down slowly (leaves, petals, feathers)


func petals(where: Vector3, color: Color, count: int, speed: float = 3.0, life: float = 1.4, up: float = 1.0) -> void:
	var n = _net_open("fx", "petals", [where, color, count, speed, life, up])
	_x_petals(where, color, count, speed, life, up)
	_net_close(n)


func _x_petals(where: Vector3, color: Color, count: int, speed: float = 3.0, life: float = 1.4, up: float = 1.0) -> void:
	## Leaves, petals or feathers: flat flakes thrown up that tumble and drift down.
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4 * up
	p.initial_velocity_max = speed * up
	p.gravity = Vector3(0, -2.2, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.particle_flag_rotate_y = true
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.18, 0.1)
	p.mesh = leaf
	p.mesh.material = _mat("soft", false, BaseMaterial3D.BILLBOARD_DISABLED)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([color.lightened(0.25), color, Color(color, 0)])
	p.color_ramp = ramp
	add_child(p)
	p.global_position = where
	p.emitting = true
	get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


func swirl(host: Node3D, color: Color, count: int = 24, radius: float = 0.9, rise: float = 2.5, life: float = 0.9,
		glow: bool = true) -> void:
	var n = _net_open("fx", "swirl", [host, color, count, radius, rise, life, glow])
	_x_swirl(host, color, count, radius, rise, life, glow)
	_net_close(n)


func _x_swirl(host: Node3D, color: Color, count: int = 24, radius: float = 0.9, rise: float = 2.5, life: float = 0.9,
		glow: bool = true) -> void:
	## Light spiralling up round a unit (casts, buffs). Follows the unit.
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.2
	p.amount = count
	p.lifetime = life
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.8
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = rise * 0.7
	p.initial_velocity_max = rise
	p.gravity = Vector3.ZERO
	p.tangential_accel_min = 9.0
	p.tangential_accel_max = 12.0
	p.radial_accel_min = -1.5
	p.radial_accel_max = -0.5
	p.mesh = _quad
	p.material_override = _mat("soft", glow, BaseMaterial3D.BILLBOARD_PARTICLES)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.4
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.9).lerp(color, 0.4), Color(color, 0)])
	p.color_ramp = ramp
	host.add_child(p)
	p.position = Vector3(0, 0.15, 0)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


func afterimage(model: Node3D, color: Color, life: float = 0.35) -> void:
	var n = _net_open("fx", "afterimage", [model, color, life])
	_x_afterimage(model, color, life)
	_net_close(n)


func _x_afterimage(model: Node3D, color: Color, life: float = 0.35) -> void:
	## A see-through copy of the body in its current pose that fades where it
	## stood: dashes and blinks leave a trail of these.
	if model == null or not is_instance_valid(model):
		return
	var ghost: Node3D = model.duplicate(0)
	for n in ghost.find_children("*", "AnimationPlayer", true, false):
		n.queue_free()
	for n in ghost.find_children("*", "Label3D", true, false):
		n.queue_free()
	for n in ghost.find_children("*", "GPUParticles3D", true, false) + ghost.find_children("*", "CPUParticles3D", true, false) + ghost.find_children("*", "Light3D", true, false):
		n.queue_free()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Mixed, not added: additive ghosts blow out to white on sunlit grass.
	m.albedo_color = Color(color, 0.6 * color.a)
	m.disable_receive_shadows = true
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	ghost.global_transform = model.global_transform
	var tw := ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "scale", ghost.scale * 1.06, life)
	tw.chain().tween_callback(ghost.queue_free)


func trail_ghosts(model: Node3D, color: Color, count: int = 4, every: float = 0.05, life: float = 0.35) -> void:
	var n = _net_open("fx", "trail_ghosts", [model, color, count, every, life])
	_x_trail_ghosts(model, color, count, every, life)
	_net_close(n)


func _x_trail_ghosts(model: Node3D, color: Color, count: int = 4, every: float = 0.05, life: float = 0.35) -> void:
	## A run of afterimages left behind while the body moves (dashes).
	for i in count:
		get_tree().create_timer(every * i).timeout.connect(func(): afterimage(model, color, life))


func thorns(where: Vector3, radius: float, color: Color, count: int = 12, life: float = 1.0, height: float = 1.1) -> void:
	var n = _net_open("fx", "thorns", [where, radius, color, count, life, height])
	_x_thorns(where, radius, color, count, life, height)
	_net_close(n)


func _x_thorns(where: Vector3, radius: float, color: Color, count: int = 12, life: float = 1.0, height: float = 1.1) -> void:
	## A ring of thorny spikes that burst out of the ground and sink back.
	var root := Node3D.new()
	add_child(root)
	root.global_position = where
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color.lightened(0.2)
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.8
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.13
	spike.height = height
	spike.radial_segments = 5
	spike.rings = 1
	for i in count:
		var a := TAU * i / count + randf_range(-0.15, 0.15)
		for k in 2:
			var s := MeshInstance3D.new()
			s.mesh = spike
			s.material_override = m
			var r := radius * (1.0 if k == 0 else randf_range(0.45, 0.8))
			s.position = Vector3(cos(a) * r, -height * 0.6, sin(a) * r)
			s.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
			s.scale = Vector3.ONE * randf_range(0.7, 1.2) * (1.0 if k == 0 else 0.75)
			root.add_child(s)
			var tw := s.create_tween()
			tw.tween_property(s, "position:y", height * 0.35, 0.12).set_delay(randf() * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(life * 0.6)
			tw.tween_property(s, "position:y", -height * 0.7, life * 0.3).set_ease(Tween.EASE_IN)
	get_tree().create_timer(life + 0.4).timeout.connect(root.queue_free)


func dome(host: Node3D, radius: float, color: Color, life: float = 0.5) -> void:
	var n = _net_open("fx", "dome", [host, radius, color, life])
	_x_dome(host, radius, color, life)
	_net_close(n)


func _x_dome(host: Node3D, radius: float, color: Color, life: float = 0.5) -> void:
	## A shell of light that snaps up round a unit and fades (shields, wards).
	var d := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 20
	sph.rings = 10
	d.mesh = sph
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, 0.22)
	m.rim_enabled = false
	d.material_override = m
	host.add_child(d)
	d.position = Vector3(0, 0.9, 0)
	d.scale = Vector3.ONE * radius * 0.3
	var tw := d.create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "scale", Vector3(radius, radius * 0.85, radius), life * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_delay(life * 0.3)
	tw.chain().tween_callback(d.queue_free)


func rays(where: Vector3, color: Color, count: int = 8, length: float = 3.0, life: float = 0.4) -> void:
	var n = _net_open("fx", "rays", [where, color, count, length, life])
	_x_rays(where, color, count, length, life)
	_net_close(n)


func _x_rays(where: Vector3, color: Color, count: int = 8, length: float = 3.0, life: float = 0.4) -> void:
	## Beams of light flaring out from a point (holy flashes).
	for i in count:
		var a := TAU * i / count + randf() * 0.3
		var dir := Vector3(cos(a), randf_range(0.1, 0.6), sin(a)).normalized()
		beam(where, where + dir * length * randf_range(0.6, 1.0), color, life, 0.09)


# --- Online: mirror every effect to the joiners (scripts/net.gd) -------------

func _net_open(target: String, method: String, args: Array):
	## Host: record an effect for the joiners' screens; effects this one
	## draws inside itself are not recorded twice (Net.depth).
	var n = get_node_or_null("/root/Net")
	if n:
		n.rec(target, method, args)
		n.depth += 1
	return n


func _net_close(n) -> void:
	if n:
		n.depth -= 1
