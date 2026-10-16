extends RefCounted
## The two Wildwood-layout maps added 2026-10-16 (claude-faisallaptop):
##
##   Stonekeep Fortress ("winter"): the Wildwood under snow. Snowfield ground,
##   frosted crowns and snow-capped pines, an icy river with floes, snow
##   drifts and snowmen instead of flowers, falling snow, and a low, cold sun.
##
##   Twilight Grove ("twilight"): the Wildwood at dusk. Dusk-teal meadow,
##   violet shade under teal-mint crowns, a violet river, glowing mushroom
##   rings and blooms everywhere, drifting motes, and a magenta sunset sky.
##
## Both keep the Wildwood's layout, routes and colliders, so bots, balance and
## online play are the same as on the Wildwood; only the look changes. The
## builders in game.gd read `game.season` for the few things they place
## differently (flowers, fallen leaves, ground textures); everything else is
## a colour grade over the finished world (grade()), applied before the
## match starts and before scripts/static_batch.gd merges the scenery.

const Stats = preload("res://scripts/stats.gd")
const StyleProfile = preload("res://scripts/visual/style_profile.gd")
const SNOW := Color(0.93, 0.96, 1.0)

# Scripts whose models keep their colours: people, crowns, pickups and cues.
const KEEP_SCRIPTS := ["unit.gd", "monarch.gd", "character_model.gd", "guide.gd", "heal_orb.gd", "blessing.gd",
	"seal.gd", "turret.gd", "projectile.gd"]


static func kind_of(map_variant: int) -> String:
	var k: String = Stats.MAPS[map_variant][1]
	return k if k in ["winter", "twilight"] else ""


static func tex_swaps(season: String) -> Dictionary:
	## Ground textures that change with the season (game._pbr's tex_swap).
	match season:
		"winter":
			return {"grass": "snow", "hedge": "snow", "moss": "snow", "flagstone_moss": "flagstone_grey"}
		"twilight":
			return {"grass": "grass_twilight"}
	return {}


# --- Colour grade ------------------------------------------------------------

static func _green(c: Color) -> float:
	## How much a colour reads as foliage or grass (0..1).
	var h := c.h
	var wh := smoothstep(0.12, 0.18, h) * (1.0 - smoothstep(0.47, 0.53, h))
	return wh * smoothstep(0.12, 0.3, c.s) * smoothstep(0.08, 0.2, c.v)


static func surface(season: String, c: Color) -> Color:
	var g := _green(c)
	var out := c
	match season:
		"winter":
			# Greens go under snow (keeping a little of their value so shapes
			# still read); everything else cools and greys a touch.
			var snow := Color.from_hsv(0.58, 0.07, clampf(0.8 + 0.22 * c.v, 0.0, 1.0), c.a)
			out = c.lerp(snow, 0.82 * g)
			var grey := Color(out.get_luminance(), out.get_luminance(), out.get_luminance(), out.a)
			out = out.lerp(grey, 0.22 * (1.0 - g))
			out.b = minf(out.b * 1.04 + 0.015, 1.0)
		"twilight":
			# Greens slide to a deep dusk teal; pinks and violets get richer.
			if g > 0.0:
				var teal := Color.from_hsv(lerpf(c.h, 0.45, 0.7), clampf(c.s * 0.9, 0.0, 1.0), c.v * 0.95, c.a)
				out = c.lerp(teal, g)
			elif c.h > 0.7 or c.h < 0.02:
				out = Color.from_hsv(c.h, clampf(c.s * 1.15, 0.0, 1.0), c.v, c.a)
	return out


static func foliage(season: String, c: Color, top: bool) -> Color:
	## Leaf-shader crowns: bottom_color is the shade under a crown, top_color
	## its lit top.
	match season:
		"winter":
			if top:
				return c.lerp(SNOW, 0.85)   # snow on every crown
			return c.lerp(Color.from_hsv(0.5, 0.35, 0.32), 0.45)   # dark evergreen shade
		"twilight":
			if top:
				return c.lerp(Color(0.5, 1.0, 0.86), 0.7)   # teal-mint tops catching the last light
			return c.lerp(Color(0.36, 0.22, 0.56), 0.55)       # violet shade
	return c


static func water(season: String, deep: bool) -> Color:
	match season:
		"winter":
			return Color(0.32, 0.56, 0.78) if deep else Color(0.72, 0.88, 0.97)
		"twilight":
			return Color(0.18, 0.1, 0.46) if deep else Color(0.5, 0.36, 0.86)
	return Color.WHITE


static func _keep(n: Node, top: Node) -> bool:
	var p := n
	while p and p != top:
		var s: Script = p.get_script()
		if s and s.resource_path.get_file() in KEEP_SCRIPTS:
			return true
		p = p.get_parent()
	return false


static func grade(game: Node3D, season: String) -> int:
	## Recolour the finished world for the season. Team colours (banners,
	## rugs, roofs) and anything that glows as a gameplay cue are left as
	## they are. Returns how many materials changed.
	if season == "":
		return 0
	var team := [game._team_color(0), game._team_color(1), Stats.FACTIONS[0].color, Stats.FACTIONS[1].color]
	var seen := {}
	var changed := 0
	for n in game.find_children("*", "GeometryInstance3D", true, false):
		if _keep(n, game):
			continue
		var mats: Array = []
		if n.material_override:
			mats.append(n.material_override)
		if n is MeshInstance3D and n.mesh:
			for i in n.get_surface_override_material_count():
				if n.get_surface_override_material(i):
					mats.append(n.get_surface_override_material(i))
			for i in n.mesh.get_surface_count():
				if n.mesh.surface_get_material(i):
					mats.append(n.mesh.surface_get_material(i))
		elif n is MultiMeshInstance3D and n.multimesh:
			var mm: MultiMesh = n.multimesh
			if mm.mesh:
				for i in mm.mesh.get_surface_count():
					if mm.mesh.surface_get_material(i):
						mats.append(mm.mesh.surface_get_material(i))
			if mm.use_colors and not seen.has(mm):
				seen[mm] = true
				for i in mm.instance_count:
					mm.set_instance_color(i, surface(season, mm.get_instance_color(i)))
		elif n is GPUParticles3D or n is CPUParticles3D:
			if n is CPUParticles3D:
				n.color = surface(season, n.color)
			if n.get("draw_pass_1") is Mesh and n.draw_pass_1.surface_get_material(0):
				mats.append(n.draw_pass_1.surface_get_material(0))
			if n is CPUParticles3D and n.mesh and n.mesh.surface_get_material(0):
				mats.append(n.mesh.surface_get_material(0))
		for m in mats:
			if seen.has(m):
				continue
			seen[m] = true
			if _grade_material(season, m, team):
				changed += 1
	return changed


static func _grade_material(season: String, m: Material, team: Array) -> bool:
	if m is ShaderMaterial:
		var any := false
		if m.get_shader_parameter("bottom_color") != null:
			m.set_shader_parameter("bottom_color", foliage(season, m.get_shader_parameter("bottom_color"), false))
			m.set_shader_parameter("top_color", foliage(season, m.get_shader_parameter("top_color"), true))
			any = true
		if m.get_shader_parameter("shallow") != null:
			m.set_shader_parameter("shallow", water(season, false))
			m.set_shader_parameter("deep", water(season, true))
			any = true
		return any
	if not m is BaseMaterial3D:
		return false
	var c: Color = m.albedo_color
	for t in team:
		if Vector3(c.r - t.r, c.g - t.g, c.b - t.b).length() < 0.12:
			return false   # a team colour
	if m.emission_enabled and m.emission_energy_multiplier > 0.5:
		# Glows: lanterns, crystals, mushrooms, buds. Twilight lets them shine.
		if season == "twilight":
			m.emission_energy_multiplier *= 1.5
			return true
		return false
	var nc := surface(season, c)
	if nc.is_equal_approx(c):
		return false
	m.albedo_color = nc
	return true


# --- Set pieces --------------------------------------------------------------

static func decorate(game: Node3D, season: String, river: Dictionary) -> void:
	## The season's own scenery, placed on open ground away from the lanes
	## (game._open_ground), decorative only: no colliders. `river` carries
	## the river's half width, water level, bridge rows and island radius.
	match season:
		"winter":
			_snow_drifts(game)
			_ice_floes(game, river)
			_snowmen(game)
		"twilight":
			_glow_rings(game)
			_lantern_motes(game)


static func _scatter(game: Node3D, count: int, seed_v: int, margin: Vector2 = Vector2(4, 2)) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < count * 20:
		tries += 1
		var p := Vector3(r.randf_range(-game.map_half.x + margin.x, game.map_half.x - margin.x), 0,
			r.randf_range(-game.map_half.y + margin.y, game.map_half.y - margin.y))
		if game._open_ground(p):
			out.append(p)
	return out


static func _multimesh(game: Node3D, mesh: Mesh, mat: Material, xforms: Array, shadow: bool) -> void:
	## One MultiMesh a DETAIL_CHUNK cell (so each cell culls on its own).
	var cells := {}
	var chunk: float = StyleProfile.DETAIL_CHUNK
	for t in xforms:
		var k := Vector2i(floori(t.origin.x / chunk), floori(t.origin.z / chunk))
		cells.get_or_add(k, []).append(t)
	for k in cells:
		var list: Array = cells[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		if not shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(mmi)


static func _snow_drifts(game: Node3D) -> void:
	## Low soft mounds of snow over the open field.
	var r := RandomNumberGenerator.new()
	r.seed = 4401
	var mound := SphereMesh.new()
	mound.radius = 0.5
	mound.height = 0.5
	mound.radial_segments = 10
	mound.rings = 4
	mound.is_hemisphere = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW
	mat.roughness = 0.95
	var xforms: Array = []
	for p in _scatter(game, 420, 4402):
		var s := r.randf_range(0.8, 2.4)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s * r.randf_range(1.0, 1.8), s * r.randf_range(0.25, 0.45), s))
		xforms.append(Transform3D(b, p + Vector3(0, -0.02, 0)))
	_multimesh(game, mound, mat, xforms, false)


static func _ice_floes(game: Node3D, river: Dictionary) -> void:
	## Flat plates of ice drifting in the river (they bob with the water's
	## own shader-free stillness; the river keeps flowing between them).
	var r := RandomNumberGenerator.new()
	r.seed = 4411
	var plate := CylinderMesh.new()
	plate.top_radius = 0.6
	plate.bottom_radius = 0.66
	plate.height = 0.08
	plate.radial_segments = 7
	plate.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.94, 1.0)
	mat.roughness = 0.35
	mat.metallic_specular = 0.7
	var half: float = river.half
	var water_y: float = river.y
	var xforms: Array = []
	var z: float = -game.map_half.y + 2.0
	while z < game.map_half.y - 2.0:
		z += r.randf_range(1.4, 3.2)
		var clear: bool = absf(z) > float(river.island) + 1.5
		for bz in river.bridges:
			if absf(z - bz) < 4.0:
				clear = false
		if not clear:
			continue   # clear of the shrine island and the bridges
		var x := r.randf_range(-half + 0.9, half - 0.9)
		var s := r.randf_range(0.6, 1.5)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s * r.randf_range(0.8, 1.4), 1.0, s))
		xforms.append(Transform3D(b, Vector3(x, water_y + 0.03, z)))
	_multimesh(game, plate, mat, xforms, false)


static func _snowmen(game: Node3D) -> void:
	## A few snowmen on open ground near each castle and in the villages.
	var snow := StandardMaterial3D.new()
	snow.albedo_color = SNOW
	snow.roughness = 0.9
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.08, 0.08, 0.1)
	var carrot := StandardMaterial3D.new()
	carrot.albedo_color = Color(1.0, 0.5, 0.12)
	var scarf := [StandardMaterial3D.new(), StandardMaterial3D.new()]
	scarf[0].albedo_color = Stats.FACTIONS[0].color
	scarf[1].albedo_color = Stats.FACTIONS[1].color
	var spots := _scatter(game, 10, 4421, Vector2(10, 6))
	for i in spots.size():
		var p: Vector3 = spots[i]
		var root := Node3D.new()
		root.position = p
		root.rotation.y = float(i) * 1.7
		game.add_child(root)
		var y := 0.0
		for k in 3:
			var rad: float = [0.5, 0.37, 0.27][k]
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rad
			sm.height = rad * 2.0
			sm.radial_segments = 14
			sm.rings = 7
			ball.mesh = sm
			ball.material_override = snow
			y += rad * (0.85 if k > 0 else 1.0)
			ball.position = Vector3(0, y, 0)
			y += rad * 0.85
			root.add_child(ball)
		var head_y := y - 0.27 * 0.85
		var nose := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.05
		cone.height = 0.24
		cone.radial_segments = 6
		nose.mesh = cone
		nose.material_override = carrot
		nose.rotation.x = PI / 2.0
		nose.position = Vector3(0, head_y, 0.3)
		root.add_child(nose)
		for e in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.035
			em.height = 0.07
			em.radial_segments = 6
			em.rings = 3
			eye.mesh = em
			eye.material_override = coal
			eye.position = Vector3(e * 0.09, head_y + 0.08, 0.24)
			root.add_child(eye)
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.22
		tm.outer_radius = 0.32
		tm.rings = 12
		tm.ring_segments = 6
		band.mesh = tm
		band.material_override = scarf[0 if p.x < 0.0 else 1]
		band.position = Vector3(0, head_y - 0.24, 0)
		root.add_child(band)


static func _glow_rings(game: Node3D) -> void:
	## Fairy rings of glowing mushrooms across the dusk meadow.
	var r := RandomNumberGenerator.new()
	r.seed = 4431
	var cap := SphereMesh.new()
	cap.radius = 0.16
	cap.height = 0.18
	cap.is_hemisphere = true
	cap.radial_segments = 8
	cap.rings = 3
	var stem := CylinderMesh.new()
	stem.top_radius = 0.04
	stem.bottom_radius = 0.06
	stem.height = 0.22
	stem.radial_segments = 5
	stem.rings = 1
	var cap_mats := []
	for col in [Color(0.4, 0.95, 1.0), Color(0.95, 0.45, 1.0), Color(0.6, 1.0, 0.7)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.8
		cap_mats.append(m)
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.85, 0.82, 0.9)
	var caps := [[], [], []]
	var stems: Array = []
	for c in _scatter(game, 34, 4432, Vector2(8, 5)):
		var n := r.randi_range(7, 12)
		var rad := r.randf_range(0.9, 1.8)
		var kind := r.randi() % 3
		for k in n:
			var a := TAU * k / n + r.randf_range(-0.15, 0.15)
			var p: Vector3 = c + Vector3(cos(a) * rad, 0, sin(a) * rad)
			var s := r.randf_range(0.8, 1.5)
			caps[kind].append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p + Vector3(0, 0.2 * s, 0)))
			stems.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p + Vector3(0, 0.1 * s, 0)))
	for k in 3:
		_multimesh(game, cap, cap_mats[k], caps[k], false)
	_multimesh(game, stem, stem_mat, stems, false)


static func _lantern_motes(game: Node3D) -> void:
	## Slow glowing motes over the whole field (one particle system per
	## field quarter; they never touch the fight).
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var p := CPUParticles3D.new()
			p.amount = 60
			p.lifetime = 9.0
			p.preprocess = 9.0
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(game.map_half.x * 0.5, 1.5, game.map_half.y * 0.5)
			p.direction = Vector3(0, 1, 0)
			p.spread = 60.0
			p.initial_velocity_min = 0.08
			p.initial_velocity_max = 0.25
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			var q := QuadMesh.new()
			q.size = Vector2(0.14, 0.14)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = Color(1.0, 0.7, 1.0) if qx < 0.0 else Color(0.6, 1.0, 0.95)
			mat.albedo_texture = _soft_dot()
			q.material = mat
			p.mesh = q
			var fade := Gradient.new()
			fade.set_color(0, Color(1, 1, 1, 0))
			fade.add_point(0.25, Color(1.6, 1.6, 1.6, 1))
			fade.add_point(0.75, Color(1.6, 1.6, 1.6, 1))
			fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
			p.color_ramp = fade
			game.add_child(p)
			p.global_position = Vector3(qx * game.map_half.x * 0.5, 1.6, qz * game.map_half.y * 0.5)


static var _dot: Texture2D


static func _soft_dot() -> Texture2D:
	## A round soft dot, made once.
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot


# --- Weather and air ---------------------------------------------------------

# What drifts through the air over each map, around the camera:
# [amount, lifetime, size, colour, emission box, direction, speed min/max,
#  gravity, turbulence, additive].
const AIR := {
	"winter": [1600, 6.0, 0.12, Color(1, 1, 1, 0.85), Vector3(30, 2, 22), Vector3(0.25, -1, 0.1), 2.4, 3.6, Vector3(0, -0.6, 0), 0.6, false],
	"day": [320, 9.0, 0.11, Color(1.0, 0.96, 0.78, 0.8), Vector3(30, 5, 22), Vector3(1, 0.15, 0.3), 0.3, 0.7, Vector3(0, -0.02, 0), 0.4, true],
	"night": [240, 7.0, 0.16, Color(0.85, 1.0, 0.45, 1.0), Vector3(30, 3, 22), Vector3(0, 1, 0), 0.1, 0.35, Vector3.ZERO, 0.8, true],
	"volcano": [520, 5.0, 0.11, Color(1.0, 0.55, 0.2, 1.0), Vector3(30, 4, 22), Vector3(0.1, 1, 0.05), 0.8, 1.8, Vector3(0, 0.4, 0), 0.7, true],
	"twilight": [220, 8.0, 0.12, Color(1.0, 0.75, 1.0, 0.9), Vector3(30, 4, 22), Vector3(0.2, 0.4, 0.1), 0.15, 0.4, Vector3.ZERO, 0.6, true],
}


static func attach_weather(cam: Camera3D, kind: String) -> void:
	## The air over the map (visual pass 2026-10-16): falling snow on
	## Stonekeep, pollen drifting in the Wildwood's sunlight, fireflies by
	## moonlight, embers rising off Ember Pass and motes at twilight. One GPU
	## particle system rides with each camera; the specks drift in world
	## space. Nothing here touches the fight.
	if cam == null:
		return
	var old := cam.get_node_or_null("Air")
	if old:
		old.free()   # the map's light changed (day <-> night on the title screen)
	if not AIR.has(kind) or RenderingServer.get_rendering_device() == null:
		return
	var a: Array = AIR[kind]
	var p := GPUParticles3D.new()
	p.name = "Air"
	p.amount = a[0]
	p.lifetime = a[1]
	p.preprocess = a[1]
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -50, -70), Vector3(80, 80, 90))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = a[4]
	pm.direction = a[5]
	pm.spread = 12.0 if kind == "winter" else 60.0
	pm.initial_velocity_min = a[6]
	pm.initial_velocity_max = a[7]
	pm.gravity = a[8]
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = a[9]
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	if kind != "winter":
		# Fade in and out over each speck's life (fireflies pulse).
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.add_point(0.3, Color(1, 1, 1, 1))
		fade.add_point(0.7, Color(1, 1, 1, 1))
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
		var gt := GradientTexture1D.new()
		gt.gradient = fade
		pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(a[2], a[2])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if a[10]:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.albedo_color = a[3] * Color(1.6, 1.6, 1.6, 1.0) if a[10] else a[3]
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(p)
	# A world-level box over the ground the camera looks at (the camera sits
	# at CAMERA_OFFSET from it, pitched down), turned back level. Snow falls
	# from 12 m; the rest hangs near head height.
	var lift := 12.0 if kind == "winter" else 2.5
	var to_ground := -Vector3(0, 19.0, 16.0) + Vector3(0, lift, 0)
	p.position = cam.basis.inverse() * to_ground
	p.basis = cam.basis.inverse()
