extends Node3D
## The main menu's 3D backdrop. The title looks at a battle scene built
## after the game's key art (title_diorama.gd); the other screens (Select Map, Create Your Character, Ready Up) are shot in a
## torch-lit castle hall built off the edge of the map, with the hero and
## the lobby's fighters standing in it on glowing pedestals.
##
## Characters are placed from screen positions (see `_floor_at`), so they
## line up with the 2D menu whatever the window size.

const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const TitleDiorama = preload("res://scripts/title_diorama.gd")
const Face = preload("res://scripts/face.gd")
const Role = Stats.Role

const HALL := Vector3(0, 0, 420)   # far past the map's south edge
# Player colours for the lobby's P1-P4 tags and pedestal glows.
const SLOT_COLORS := [Color(0.2, 0.45, 1.0), Color(0.95, 0.22, 0.2), Color(0.25, 0.85, 0.3), Color(1.0, 0.8, 0.15)]

var game
var cam: Camera3D
var hall: Node3D
var title_cast: Node3D       # the battle scene behind the title (title_diorama.gd)
var hero: Node3D             # the character creator's model
var hero_key := ""
var hero_spin := 0.0            # extra turn (radians): the STORE turns the hero to show a cape
var lobby_models: Array = [null, null, null, null]
var lobby_keys: Array = ["", "", "", ""]
var pedestals: Array = []    # [node, ring material, light] per lobby slot
var screen := ""
var t := 0.0
var hidden_labels: Array = []
var rug: Node3D              # the round rug under the character creator's hero
var backdrop: CanvasLayer    # the title's painted background (animated)
var embers: Array = []       # [CPUParticles2D, image px] per torch on it

# The title background's live bits, in image pixels (1672x941): the
# waterfalls, the pool under the bridge and the torch flames.
const BG_SIZE := Vector2(1672, 941)
const BG_FALLS := [Rect2(792, 536, 92, 128), Rect2(1012, 538, 50, 104), Rect2(1512, 170, 36, 122), Rect2(752, 742, 182, 52)]
const BG_POOL := Rect2(600, 780, 430, 161)
const BG_FLAMES := [Vector2(583, 400), Vector2(1119, 404), Vector2(707, 463), Vector2(792, 466), Vector2(885, 462),
	Vector2(964, 467), Vector2(701, 497), Vector2(400, 576), Vector2(584, 581), Vector2(1110, 584), Vector2(496, 778),
	Vector2(225, 298), Vector2(1380, 436)]


func _exit_tree() -> void:
	for l in hidden_labels:
		if is_instance_valid(l):
			l.visible = true
	_restore_env()


# --- Lighting moods --------------------------------------------------------------
# The menus light their own sets: a golden afternoon on the title, warm
# candlelight in the hall. The world's settings come back when the match starts.

const ENV_KEYS := ["ambient_light_energy", "ambient_light_color", "ambient_light_sky_contribution", "tonemap_exposure",
	"glow_intensity", "glow_bloom", "glow_hdr_threshold", "adjustment_saturation", "adjustment_contrast",
	"adjustment_brightness", "fog_enabled", "fog_light_color", "ssil_intensity"]
var env_saved := {}
var mood := ""


func _restore_env() -> void:
	var env: Environment = game.world_environment if game else null
	if env == null or env_saved.is_empty():
		return
	for k in ENV_KEYS:
		env.set(k, env_saved[k])
	game.sun_light.light_color = env_saved.sun_color
	game.sun_light.light_energy = env_saved.sun_energy
	if game.fill_light:
		game.fill_light.light_energy = env_saved.fill_energy
	env_saved = {}


func _set_mood(want: String) -> void:
	var env: Environment = game.world_environment
	if env == null or want == mood:
		return
	mood = want
	if env_saved.is_empty():
		for k in ENV_KEYS:
			env_saved[k] = env.get(k)
		env_saved.sun_color = game.sun_light.light_color
		env_saved.sun_energy = game.sun_light.light_energy
		env_saved.fill_energy = game.fill_light.light_energy if game.fill_light else 0.0
	for k in ENV_KEYS:
		env.set(k, env_saved[k])
	if want == "hall":
		# Candlelight: little sky light, warm and glowing, deep shadows.
		env.ambient_light_sky_contribution = 0.0
		# (Warmer and a touch brighter since 2026-10-09, after the
		# create-character reference's candle-lit hall.)
		env.ambient_light_color = Color(0.62, 0.5, 0.4)
		env.ambient_light_energy = 0.55
		env.tonemap_exposure = 0.92
		env.glow_intensity = 0.8
		env.glow_bloom = 0.1
		env.glow_hdr_threshold = 0.95
		env.adjustment_saturation = 1.08
		env.adjustment_contrast = 1.2
		env.adjustment_brightness = 0.95
		env.fog_enabled = false
		game.sun_light.light_energy = 0.0
		if game.fill_light:
			game.fill_light.light_energy = 0.0
	else:
		# A golden afternoon: warm sun, rich colour, a soft glow on the light.
		env.ambient_light_energy = 0.7
		env.ambient_light_color = Color(0.85, 0.85, 0.75)
		env.adjustment_saturation = 1.32
		env.adjustment_contrast = 1.12
		env.glow_intensity = 0.65
		env.fog_light_color = Color(0.92, 0.9, 0.82)
		game.sun_light.light_color = Color(1.0, 0.84, 0.6)
		game.sun_light.light_energy = 1.5


func _flame(pos: Vector3, out: Vector3) -> void:
	## A lit flame over a wall torch: a bright core in a soft orange glow.
	var top := pos + out * 0.5 + Vector3(0, 0.98, 0)
	game._add_flame(top, 0.17, Color(1.0, 0.5, 0.12))
	game._add_flame(top + Vector3(0, 0.1, 0), 0.09, Color(1.0, 0.92, 0.55))


func build(g) -> void:
	game = g
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	hall = Node3D.new()
	add_child(hall)
	_build_hall()
	title_cast = TitleDiorama.new()
	add_child(title_cast)
	_build_backdrop()


func activate() -> void:
	cam.make_current()


func _process(delta: float) -> void:
	t += delta
	if screen == "lobby":
		for i in pedestals.size():
			# A slow pulse in each pedestal's ring.
			var p: Array = pedestals[i]
			p[1].emission_energy_multiplier = 1.6 + sin(t * 2.4 + i) * 0.4


# --- Camera shots ----------------------------------------------------------------

func show_screen(name: String) -> void:
	if name == screen:
		return
	screen = name
	hero_spin = 0.0
	title_cast.visible = false
	backdrop.visible = name == "title"
	if name == "title":
		_place_embers()
	_set_mood("title" if name == "title" else "hall")
	if rug:
		rug.visible = name in ["character", "store"]
	match name:
		"title":
			# Across the stream at the castle and its crown, the two armies either side.
			cam.fov = TitleDiorama.CAM_FOV
			var from: Vector3 = TitleDiorama.ORIGIN + TitleDiorama.CAM_FROM
			var to: Vector3 = TitleDiorama.ORIGIN + TitleDiorama.CAM_AT
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--debug-title-cam="):  # testing: x,y,z,look x,y,z (relative to the scene)
					var v := arg.trim_prefix("--debug-title-cam=").split(",")
					from = TitleDiorama.ORIGIN + Vector3(float(v[0]), float(v[1]), float(v[2]))
					to = TitleDiorama.ORIGIN + Vector3(float(v[3]), float(v[4]), float(v[5]))
				if arg.begins_with("--debug-title-fov="):
					cam.fov = float(arg.trim_prefix("--debug-title-fov="))
			cam.global_position = from
			cam.look_at(to)
		"map":
			cam.fov = 50.0
			cam.global_position = HALL + Vector3(0, 2.4, 8.5)
			cam.look_at(HALL + Vector3(0, 2.6, -6.0))
		"character", "store":
			cam.fov = 37.0
			cam.global_position = HALL + Vector3(0.6, 1.55, 6.2)
			cam.look_at(HALL + Vector3(0.6, 1.25, 0.0))
		"lobby":
			cam.fov = 40.0
			cam.global_position = HALL + Vector3(0, 2.2, 11.2)
			cam.look_at(HALL + Vector3(0, 1.35, 0.0))
	if hero:
		hero.visible = name in ["character", "store"]
	for i in 4:
		if lobby_models[i]:
			lobby_models[i].visible = name == "lobby"
		if i < pedestals.size():
			pedestals[i][0].visible = name == "lobby"


func _floor_at(frac: Vector2, y: float = 0.0) -> Vector3:
	## The point on the floor (height y) seen at this fraction of the screen.
	var vp := get_viewport().get_visible_rect().size
	var p := frac * vp
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	if absf(d.y) < 0.001:
		return o + d * 6.0
	var k := (y - o.y) / d.y
	return o + d * k


# --- The hero (character creator) --------------------------------------------------

func show_hero(team: int, role: int, custom: Dictionary, rank: int) -> void:
	## Rebuild the creator's model when a choice changes.
	var key := "%d|%d|%s|%d" % [team, role, str(custom), rank]
	if key != hero_key:
		hero_key = key
		if hero:
			hero.queue_free()
		hero = CharacterModel.new()
		add_child(hero)
		hero.setup(team, role, "", custom, rank)
		hero.scale = Vector3.ONE * 1.0
	hero.visible = screen in ["character", "store"]
	hero.global_position = _floor_at(Vector2(0.39, 0.86))
	if rug == null:
		rug = _round_rug()
	rug.global_position = hero.global_position + Vector3(0, 0.02, 0)
	rug.visible = screen in ["character", "store"]
	hero.rotation.y = PI + 0.32 + hero_spin + sin(t * 0.6) * 0.05  # turned a little toward the panel


# --- The lobby ------------------------------------------------------------------------

func show_lobby(slots: Array) -> void:
	## slots: up to four {team, role, custom, rank, empty, color} entries.
	if pedestals.is_empty():
		for i in 4:
			pedestals.append(_make_pedestal(SLOT_COLORS[i]))
	for i in 4:
		var s: Dictionary = slots[i] if i < slots.size() else {"empty": true}
		var frac := Vector2(0.15 + i * 0.233, 0.672)
		var pos := _floor_at(frac)
		var ped: Array = pedestals[i]
		ped[0].global_position = pos
		ped[0].visible = screen == "lobby"
		var col: Color = s.get("color", SLOT_COLORS[i])
		var empty: bool = s.get("empty", false)
		ped[1].albedo_color = (col if not empty else Color(0.4, 0.4, 0.45)).darkened(0.2)
		ped[1].emission = col if not empty else Color(0.3, 0.3, 0.35)
		ped[2].light_color = col
		ped[2].light_energy = 0.0 if empty else 1.6
		var key := "" if empty else "%d|%d|%s|%d" % [s.team, s.role, str(s.get("custom", {})), s.get("rank", 1)]
		if key != lobby_keys[i]:
			lobby_keys[i] = key
			if lobby_models[i]:
				lobby_models[i].queue_free()
				lobby_models[i] = null
			if key != "":
				var m = CharacterModel.new()
				add_child(m)
				m.setup(s.team, s.role, "", s.get("custom", {}), s.get("rank", 1))
				m.scale = Vector3.ONE * 1.12
				# Ready-up stances, as on the art: casters mid-spell.
				match int(s.role):
					Role.MAGE: m.hold("Spellcasting")
				lobby_models[i] = m
				if s.get("cheer", false):
					m.play_once("Cheer")
		if lobby_models[i]:
			lobby_models[i].visible = screen == "lobby"
			lobby_models[i].global_position = pos + Vector3(0, 0.22, 0)
			lobby_models[i].rotation.y = PI + (pos.x - cam.global_position.x) * -0.05


func cheer(i: int) -> void:
	if i < lobby_models.size() and lobby_models[i]:
		lobby_models[i].play_once("Cheer")


func _make_pedestal(color: Color) -> Array:
	## A round stone dais with a glowing ring in the player's colour.
	var root := Node3D.new()
	add_child(root)
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.95
	cyl.bottom_radius = 1.05
	cyl.height = 0.22
	base.mesh = cyl
	base.material_override = game._stone(Color(0.8, 0.78, 0.74), 0.5)
	base.position.y = 0.11
	root.add_child(base)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.82
	tor.outer_radius = 0.95
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.albedo_color = color.darkened(0.2)
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 1.8
	ring.material_override = rm
	ring.position.y = 0.2
	ring.scale = Vector3(1, 0.4, 1)
	root.add_child(ring)
	# A soft disc of light on the dais top.
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.8
	dm.bottom_radius = 0.8
	dm.height = 0.01
	disc.mesh = dm
	disc.material_override = rm
	disc.position.y = 0.225
	disc.transparency = 0.55
	root.add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 3.2
	light.position.y = 0.7
	root.add_child(light)
	root.visible = false
	return [root, rm, light]


# --- The title's battle scene ------------------------------------------------------

func place_title_cast() -> void:
	if title_cast.visible:
		title_cast.place_heroes(cam, get_viewport().get_visible_rect().size)


func _build_backdrop() -> void:
	## The title's painted background on a layer under the menu: its water
	## and torches animate in assets/shaders/title_bg.gdshader, and embers
	## drift up from each torch.
	backdrop = CanvasLayer.new()
	backdrop.layer = -1
	add_child(backdrop)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu/title_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/title_bg.gdshader")
	sm.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	var falls := []
	for r in BG_FALLS:
		falls.append(Vector4(r.position.x / BG_SIZE.x, r.position.y / BG_SIZE.y, r.end.x / BG_SIZE.x, r.end.y / BG_SIZE.y))
	sm.set_shader_parameter("falls", falls)
	sm.set_shader_parameter("pool", Vector4(BG_POOL.position.x / BG_SIZE.x, BG_POOL.position.y / BG_SIZE.y, BG_POOL.end.x / BG_SIZE.x, BG_POOL.end.y / BG_SIZE.y))
	var pts := []
	for p in BG_FLAMES:
		pts.append(p / BG_SIZE)
	sm.set_shader_parameter("flames", pts)
	sm.set_shader_parameter("flame_count", BG_FLAMES.size())
	sm.set_shader_parameter("aspect", BG_SIZE.x / BG_SIZE.y)
	bg.material = sm
	backdrop.add_child(bg)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	for p in BG_FLAMES:
		var e := CPUParticles2D.new()
		e.amount = 6
		e.lifetime = 1.1
		e.preprocess = 1.0
		e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 3.0
		e.direction = Vector2(0, -1)
		e.spread = 25.0
		e.initial_velocity_min = 14.0
		e.initial_velocity_max = 30.0
		e.gravity = Vector2(0, -12)
		e.scale_amount_min = 1.2
		e.scale_amount_max = 2.4
		e.color_ramp = ramp
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		e.material = mat
		backdrop.add_child(e)
		embers.append([e, p])
	backdrop.visible = false


func _place_embers() -> void:
	## Put each torch's embers over its flame, wherever the picture lands on screen.
	var vp := get_viewport().get_visible_rect().size
	var k := maxf(vp.x / BG_SIZE.x, vp.y / BG_SIZE.y)
	var off := (vp - BG_SIZE * k) / 2.0
	for e in embers:
		e[0].position = off + e[1] * k - Vector2(0, 6) * k
		e[0].scale = Vector2.ONE * k / 0.7656


# --- The hall ----------------------------------------------------------------------------

func _hall_banner(color: String, pos: Vector3, h: float, facing: float) -> void:
	## A crown banner hung from a gold rod (assets/ui/menu/banner_crown_*.png).
	var root := Node3D.new()
	game.add_child(root)
	root.global_position = pos
	root.rotation.y = facing
	var cloth := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(h * 0.5, h)
	cloth.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/ui/menu/banner_crown_%s.png" % color)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	cloth.material_override = m
	cloth.position = Vector3(0, -h / 2.0, 0.08)
	root.add_child(cloth)
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.05
	rm.bottom_radius = 0.05
	rm.height = h * 0.5 + 0.4
	rod.mesh = rm
	rod.material_override = game._gold()
	rod.rotation.z = PI / 2.0
	rod.position = Vector3(0, 0.03, 0.1)
	root.add_child(rod)


func _flame_at(pos: Vector3, r: float = 0.07) -> void:
	game._add_flame(pos, r, Color(1.0, 0.55, 0.15))
	game._add_flame(pos + Vector3(0, r * 0.6, 0), r * 0.5, Color(1.0, 0.92, 0.55))


func _candle(pos: Vector3, h: float = 0.28) -> void:
	game._add_block(pos + Vector3(0, h / 2.0, 0), Vector3(0.09, h, 0.09), Color.GRAY, false, game._material(Color(0.96, 0.9, 0.78)))
	_flame_at(pos + Vector3(0, h + 0.07, 0))


func _candle_wheel(pos: Vector3) -> void:
	## An iron ring of candles on chains, with its own warm light.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.85
	ring.mesh = tm
	ring.material_override = game._iron()
	game.add_child(ring)
	ring.global_position = pos
	for k in 8:
		var a := TAU * k / 8.0
		_candle(pos + Vector3(cos(a) * 0.8, 0.04, sin(a) * 0.8), 0.22)
	for k in 3:
		var a := TAU * k / 3.0
		var chain := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.015
		cm.bottom_radius = 0.015
		cm.height = 3.6
		chain.mesh = cm
		chain.material_override = game._iron()
		game.add_child(chain)
		chain.global_position = pos + Vector3(cos(a) * 0.4, 1.8, sin(a) * 0.4)
		chain.rotation.z = cos(a) * 0.12
		chain.rotation.x = -sin(a) * 0.12
	game._add_light(pos + Vector3(0, -0.4, 0), Color(1.0, 0.68, 0.36), 1.8, 8.0)


func _candelabra(pos: Vector3) -> void:
	## Three candles on a wall bracket.
	game._add_block(pos + Vector3(0, 0, 0.12), Vector3(0.6, 0.06, 0.2), Color.GRAY, false, game._gold())
	game._add_block(pos + Vector3(0, -0.2, 0.05), Vector3(0.08, 0.4, 0.08), Color.GRAY, false, game._gold())
	for x in [-0.25, 0.0, 0.25]:
		_candle(pos + Vector3(x, 0.03, 0.15), 0.22 if x != 0.0 else 0.3)
	game._add_light(pos + Vector3(0, 0.5, 0.5), Color(1.0, 0.66, 0.34), 0.9, 4.5)


func _round_rug() -> Node3D:
	## A round rug like the one under the hero on the art: red field, gold
	## ring, blue centre with a gold star of points.
	var root := Node3D.new()
	add_child(root)
	var layers := [[1.55, Color(0.45, 0.08, 0.1)], [1.4, Color(0.85, 0.65, 0.25)], [1.3, Color(0.55, 0.1, 0.12)], [0.85, Color(0.85, 0.65, 0.25)], [0.78, Color(0.14, 0.2, 0.5)]]
	for i in layers.size():
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = layers[i][0]
		cm.bottom_radius = layers[i][0]
		cm.height = 0.02
		cm.radial_segments = 40
		d.mesh = cm
		d.material_override = game._carpet(layers[i][1]) if i % 2 == 0 else game._gold()
		d.position.y = 0.004 * i
		root.add_child(d)
	for k in 8:
		var pt := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.2, 0.5, 0.01)
		pt.mesh = pm
		pt.material_override = game._gold()
		var a := TAU * k / 8.0
		pt.position = Vector3(cos(a) * 1.05, 0.03, sin(a) * 1.05)
		pt.rotation = Vector3(-PI / 2.0, -a - PI / 2.0, 0)
		root.add_child(pt)
	root.scale = Vector3(1.45, 1.0, 1.45)
	return root


func _window(pos: Vector3) -> void:
	## A tall arched window with diamond leading: sky-blue panes in a
	## timber frame.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.68, 0.9)
	glass.emission_enabled = true
	glass.emission = Color(0.5, 0.7, 1.0)
	glass.emission_energy_multiplier = 0.35
	var frame: Material = game._timber(Color(0.5, 0.36, 0.26))
	var w := 2.6
	var hgt := 4.4
	game._add_block(pos + Vector3(0, 0, 0.02), Vector3(w, hgt, 0.06), Color.GRAY, false, glass)
	var arch := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = w / 2.0
	cm.bottom_radius = w / 2.0
	cm.height = 0.06
	arch.mesh = cm
	arch.material_override = glass
	arch.rotation.x = PI / 2.0
	game.add_child(arch)
	arch.global_position = pos + Vector3(0, hgt / 2.0, 0.02)
	for x in [-w / 2.0 - 0.06, w / 2.0 + 0.06]:
		game._add_block(pos + Vector3(x, 0.3, 0.08), Vector3(0.2, hgt + 0.6, 0.16), Color.GRAY, false, frame)
	game._add_block(pos + Vector3(0, -hgt / 2.0 - 0.08, 0.1), Vector3(w + 0.5, 0.22, 0.3), Color.GRAY, false, frame)
	# Mullions and a transom, then diagonal leading in both directions.
	game._add_block(pos + Vector3(0, 0.6, 0.08), Vector3(0.1, hgt + 1.2, 0.08), Color.GRAY, false, frame)
	game._add_block(pos + Vector3(0, 0.9, 0.08), Vector3(w, 0.1, 0.08), Color.GRAY, false, frame)
	var lq := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, hgt)
	lq.mesh = qm
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = load("res://assets/ui/menu/window_lead.png")
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lm.alpha_scissor_threshold = 0.4
	lm.roughness = 0.6
	lq.material_override = lm
	game.add_child(lq)
	lq.global_position = pos + Vector3(0, 0, 0.06)
	var sun: OmniLight3D = game._add_light(pos + Vector3(0, 0.6, 1.4), Color(0.8, 0.9, 1.0), 1.2, 7.0)
	sun.name = "WindowLight"


func _throne(pos: Vector3) -> void:
	## A tall throne like the art's: a red back with a gold crown in a gold
	## frame, gold spires on its posts, on red-carpeted steps.
	var gold: Material = game._gold()
	var red: Material = game._cloth(Color(0.72, 0.1, 0.12))
	var carpet: Material = game._carpet(Color(0.62, 0.08, 0.1))
	# Three carpeted steps, gold-edged, widest at the bottom.
	for k in 3:
		var w := 3.6 - k * 0.6
		var d := 2.6 - k * 0.55
		var y := 0.12 + k * 0.24
		game._add_block(pos + Vector3(0, y, 0.55 - k * 0.27), Vector3(w, 0.24, d), Color.GRAY, false, carpet)
		game._add_block(pos + Vector3(0, y + 0.115, 0.55 - k * 0.27 + d / 2.0), Vector3(w, 0.03, 0.05), Color.GRAY, false, gold)
	var top := pos + Vector3(0, 0.72, -0.15)
	# Seat and arms.
	game._add_block(top + Vector3(0, 0.3, 0.1), Vector3(1.4, 0.6, 0.9), Color.GRAY, false, gold)
	game._add_block(top + Vector3(0, 0.66, 0.12), Vector3(1.16, 0.14, 0.8), Color.GRAY, false, red)
	for x in [-0.66, 0.66]:
		game._add_block(top + Vector3(x, 0.85, 0.12), Vector3(0.14, 0.36, 0.86), Color.GRAY, false, gold)
	# The tall back: gold frame, red cushion, a crown emblem.
	game._add_block(top + Vector3(0, 1.75, -0.32), Vector3(1.36, 2.5, 0.16), Color.GRAY, false, gold)
	game._add_block(top + Vector3(0, 1.68, -0.22), Vector3(1.06, 2.1, 0.06), Color.GRAY, false, red)
	var crown := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.62, 0.62)
	crown.mesh = q
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = load("res://assets/ui/menu/icon_crown.png")
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cm.alpha_scissor_threshold = 0.4
	cm.emission_enabled = true
	cm.emission = Color(0.4, 0.3, 0.1)
	crown.material_override = cm
	game.add_child(crown)
	crown.global_position = top + Vector3(0, 2.05, -0.18)
	# Posts with gold spires either side and on top.
	for x in [-0.78, 0.78]:
		game._add_block(top + Vector3(x, 1.55, -0.3), Vector3(0.18, 3.1, 0.2), Color.GRAY, false, gold)
		_spire(top + Vector3(x, 3.1, -0.3), 0.14, 0.55, gold)
	_spire(top + Vector3(0, 3.0, -0.32), 0.2, 0.75, gold)


func _spire(base: Vector3, r: float, h: float, mat: Material) -> void:
	## A gold finial: a ball and a cone point.
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	ball.mesh = sm
	ball.material_override = mat
	game.add_child(ball)
	ball.global_position = base + Vector3(0, r, 0)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r * 0.75
	cm.height = h
	cone.mesh = cm
	cone.material_override = mat
	game.add_child(cone)
	cone.global_position = base + Vector3(0, r * 1.7 + h / 2.0, 0)


func _armour_stand(pos: Vector3) -> void:
	## A suit of plate armour on a stone plinth, flanking the throne.
	game._add_block(pos + Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 1.0), Color.GRAY, false, game._stone(Color(0.7, 0.66, 0.6), 0.5))
	var m = CharacterModel.new()
	hall.add_child(m)
	m.setup(1, Role.KNIGHT, "", {}, 3)
	if m.anim and m.anim.has_animation("Idle"):
		m.anim.play("Idle")
		m.anim.seek(0.4, true)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.5, 0.53, 0.6)
	steel.metallic = 0.6
	steel.roughness = 0.45
	for mi in m._meshes(m):
		mi.material_override = steel
	for n in m.find_children("*", "Node3D", true, false):
		if n.get_script() == Face:
			n.visible = false
	m.global_position = pos + Vector3(0, 0.3, 0)
	m.scale = Vector3.ONE * 1.05
	m.rotation.y = PI
	m.process_mode = Node.PROCESS_MODE_DISABLED


func _build_hall() -> void:
	## Stone walls, a flagstone floor, timber beams, blue lion banners, torches,
	## barrels and crates. Built with the world's own helpers, then moved here.
	var before: int = game.get_child_count()
	var was_mossy: bool = game.mossy
	game.mossy = false
	var c := HALL
	# Grey castle stone (the greystone texture where the art pass has made it).
	var stone: Material = game._pbr("greystone", 0.3, Color(0.86, 0.8, 0.72)) if ResourceLoader.exists("res://assets/textures/greystone_color.jpg") \
		else game._stone(Color(0.74, 0.73, 0.74), 0.3)
	var floor_mat: Material = game._plank_dark(Color(0.72, 0.56, 0.44))
	game._add_block(c + Vector3(0, -0.1, 0), Vector3(30, 0.2, 24), Color.GRAY, false, floor_mat)
	# Back wall, side walls angled in a little, and a dark ceiling to keep the sky out.
	game._add_block(c + Vector3(0, 4.5, -6.5), Vector3(30, 9, 1.0), Color.GRAY, false, stone)
	for s in [-1.0, 1.0]:
		game._add_block(c + Vector3(s * 11.0, 4.5, 2.0), Vector3(1.0, 9, 18), Color.GRAY, false, stone)
	game._add_block(c + Vector3(0, 9.2, 0), Vector3(30, 0.4, 24), Color.GRAY, false, game._plank_dark())
	# Timber posts and a beam along the back wall.
	var timber: Material = game._timber(Color(0.75, 0.6, 0.45))
	for x in [-8.5, -3.2, 3.2, 8.5]:
		game._add_block(c + Vector3(x, 3.5, -5.8), Vector3(0.5, 7.0, 0.5), Color.GRAY, false, timber)
	game._add_block(c + Vector3(0, 6.9, -5.8), Vector3(22, 0.5, 0.6), Color.GRAY, false, timber)
	for s in [-1.0, 1.0]:
		game._add_block(c + Vector3(s * 10.3, 6.9, 1.0), Vector3(0.6, 0.5, 15), Color.GRAY, false, timber)
	# Warm wood panelling round the lower walls.
	var panel: Material = game._plank_dark(Color(0.8, 0.6, 0.45))
	game._add_block(c + Vector3(0, 0.8, -5.92), Vector3(21.0, 1.6, 0.16), Color.GRAY, false, panel)
	game._add_block(c + Vector3(0, 1.64, -5.84), Vector3(21.0, 0.1, 0.3), Color.GRAY, false, timber)
	for s in [-1.0, 1.0]:
		game._add_block(c + Vector3(s * 10.42, 0.8, 2.0), Vector3(0.16, 1.6, 17.0), Color.GRAY, false, panel)
		game._add_block(c + Vector3(s * 10.36, 1.64, 2.0), Vector3(0.3, 0.1, 17.0), Color.GRAY, false, timber)
	# Red and blue crown banners between the posts and down the side walls.
	for b in [[-5.85, "red", 4.2], [-1.6, "blue", 3.2], [1.6, "blue", 3.2], [5.85, "red", 4.2]]:
		_hall_banner(b[1], c + Vector3(b[0], 6.4, -5.95), b[2], 0.0)
	for s in [-1.0, 1.0]:
		for z in [-2.6, 1.0, 4.6]:
			_hall_banner("red" if z == 1.0 else "blue", c + Vector3(s * 10.3, 5.6, z), 3.2, -s * PI / 2.0)
	# A tall arched window over the throne, sunlight pouring in.
	_window(c + Vector3(0, 4.0, -5.94))
	_throne(c + Vector3(0, 0, -4.9))
	# Candle stands along the walls.
	for p in [Vector3(-7.4, 0, -5.3), Vector3(-4.4, 0, -5.3), Vector3(4.4, 0, -5.3), Vector3(7.4, 0, -5.3),
			Vector3(-9.8, 0, 2.2), Vector3(9.8, 0, 2.2)]:
		game._add_candle_stand(c + p)
	# Candle wheels hung from the beams, and candelabras on the walls.
	for x in [-5.0, 5.0]:
		_candle_wheel(c + Vector3(x, 5.4, -1.5))
	for x in [-7.2, -3.6, 3.6, 7.2]:
		_candelabra(c + Vector3(x, 3.4, -5.85))
	# A warm key light on the fighters and the hero, from above the camera.
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.76)
	key.light_energy = 2.6
	key.spot_range = 22.0
	key.spot_angle = 34.0
	key.spot_attenuation = 0.6
	key.shadow_enabled = true
	game.add_child(key)
	key.global_position = c + Vector3(0, 6.5, 9.0)
	key.look_at(c + Vector3(0, 0.8, 0.0))
	# Torches on the posts.
	for x in [-8.5, -3.2, 3.2, 8.5]:
		game._add_wall_torch(c + Vector3(x, 2.4, -5.5), Vector3(0, 0, 1))
		_flame(c + Vector3(x, 2.4, -5.5), Vector3(0, 0, 1))
	for s in [-1.0, 1.0]:
		game._add_wall_torch(c + Vector3(s * 10.45, 2.4, 1.5), Vector3(-s, 0, 0))
		_flame(c + Vector3(s * 10.45, 2.4, 1.5), Vector3(-s, 0, 0))
	# Fire bowls either side of the middle (they flank the SELECT MAP panel).
	for s in [-1.0, 1.0]:
		game._add_brazier(c + Vector3(s * 6.4, 0, 1.2))
	# Warm fill so the hall reads bright and friendly, not a dungeon.
	game._add_light(c + Vector3(0, 5.5, 3.0), Color(1.0, 0.7, 0.45), 1.2, 16.0)
	game._add_light(c + Vector3(-6, 3.0, -3.0), Color(1.0, 0.7, 0.45), 1.2, 9.0)
	game._add_light(c + Vector3(6, 3.0, -3.0), Color(1.0, 0.7, 0.45), 1.2, 9.0)
	# Clutter in the corners: barrels, crates, a weapon rack, chests.
	game.prop_solid = false
	for p in [["dungeon/barrel_large", Vector3(-9.2, 0, -4.6), 1.3, 0.3], ["dungeon/barrel_small_stack", Vector3(-7.4, 0, -4.9), 1.2, 0.0],
			["dungeon/crates_stacked", Vector3(8.8, 0, -4.4), 1.2, -0.4], ["dungeon/barrel_large_decorated", Vector3(7.0, 0, -4.9), 1.2, 0.8],
			
			["dungeon/chest", Vector3(-9.6, 0, 0.0), 1.3, PI / 2.0], ["dungeon/keg_decorated", Vector3(9.6, 0, -1.6), 1.2, -PI / 2.0],
			["dungeon/box_stacked", Vector3(9.4, 0, 2.8), 1.2, -0.3], ["dungeon/barrel_small", Vector3(-9.4, 0, 3.4), 1.2, 0.0],
			["dungeon/barrel_large", Vector3(-9.0, 0, 6.2), 1.3, 0.6], ["dungeon/crates_stacked", Vector3(9.0, 0, 6.0), 1.2, 0.2]]:
		game._prop(p[0], c + p[1], p[2], p[3])
	# A blue runner with gold edges down the middle (the lobby's walkway).
	game._add_block(c + Vector3(0, 0.015, 1.5), Vector3(4.2, 0.03, 13.0), Color.GRAY, false, game._carpet(Color(0.16, 0.26, 0.62)))
	for s in [-1.0, 1.0]:
		game._add_block(c + Vector3(s * 1.95, 0.032, 1.5), Vector3(0.14, 0.01, 13.0), Color.GRAY, false, game._gold())
	game.mossy = was_mossy
	# The world's name tags (door health, the monarchs) stay hidden behind the menu.
	for l in game.find_children("*", "Label3D", true, false):
		if l.visible:
			l.visible = false
			hidden_labels.append(l)
	var made: Array = []
	for i in range(before, game.get_child_count()):
		made.append(game.get_child(i))
	for n in made:
		n.reparent(hall, true)
	# Suits of armour either side of the throne.
	for x in [-2.6, 2.6]:
		_armour_stand(c + Vector3(x, 0, -5.1))
