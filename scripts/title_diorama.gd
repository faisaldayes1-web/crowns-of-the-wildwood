extends Node3D
## The title screen's battle scene, laid out after the game's key art: the
## Human Kingdom's walls climbing the left side with blue lion banners, the
## elven forest and tree-houses on the right with green tree banners, and
## between them the castle on its terrace with the glowing crown at the gate,
## a waterfall pouring down under it into a stream with a stone bridge.
## Both armies fight across the stream while arrows, blue bolts, green magic
## and fireballs fly over it. A Knight and an Elf Ranger stand in front.
##
## Built far off the map (ORIGIN) with the world's own helpers, which add
## their nodes to the game; they are moved under this node afterwards.

const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const Role = Stats.Role

const ORIGIN := Vector3(0, 0, -430)
const CAM_FROM := Vector3(0, 5.2, 13.5)   # relative to ORIGIN
const CAM_AT := Vector3(0, 6.8, -14.0)
const CAM_FOV := 52.0

var game
var fighters: Array = []   # [model, kind, next action time]
var shots: Array = []      # [node, from, to, height, period, phase, spin]
var crown: Node3D
var beam: MeshInstance3D
var t := 0.0
var hero_knight
var hero_ranger


func build(g) -> void:
	game = g
	var before: int = game.get_child_count()
	var was_mossy: bool = game.mossy
	game.mossy = false
	game.prop_solid = false
	_ground()
	_keep()
	_waterfall_and_stream()
	_human_walls()
	_forest()
	_backdrop()
	game.mossy = was_mossy
	var made: Array = []
	for i in range(before, game.get_child_count()):
		made.append(game.get_child(i))
	for n in made:
		n.reparent(self, true)
	_grey_stone()
	_armies()
	_projectiles()


func _grey_stone() -> void:
	## The Kingdom builds in grey stone, as in the key art: swap the warm
	## sandstone for the grey stone texture (or a cool tint where it is missing).
	var grey := ResourceLoader.exists("res://assets/textures/greystone_color.jpg")
	var swapped := {}
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m = mi.material_override
		if not (m is StandardMaterial3D) or m.albedo_texture == null or not m.albedo_texture.resource_path.ends_with("/stone_color.jpg"):
			continue
		if not swapped.has(m):
			var g: StandardMaterial3D = m.duplicate()
			if grey:
				g.albedo_texture = load("res://assets/textures/greystone_color.jpg")
				g.normal_texture = load("res://assets/textures/greystone_normal.jpg")
				g.albedo_color = Color(0.85, 0.85, 0.88)
			else:
				var c: Color = m.albedo_color
				var v := (c.r + c.g + c.b) / 3.0
				g.albedo_color = Color(v * 0.72, v * 0.74, v * 0.82)
			swapped[m] = g
		mi.material_override = swapped[m]


func P(x: float, y: float, z: float) -> Vector3:
	return ORIGIN + Vector3(x, y, z)


# --- Pieces -------------------------------------------------------------------------

func _mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	(parent if parent else game).add_child(mi)
	mi.global_position = pos
	return mi


func _cyl(r_top: float, r_bot: float, h: float, segs: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	return c


func _banner(team: int, pos: Vector3, h: float, facing: float = 0.0, pole: bool = true) -> void:
	## A war banner (lion or tree) hung from a gold cross-bar, on a pole if asked.
	var root := Node3D.new()
	game.add_child(root)
	root.global_position = pos
	root.rotation.y = facing
	var w := h * 0.5
	var cloth := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	cloth.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/ui/menu/%s.png" % ("banner_tree" if team == 0 else "banner_lion"))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	cloth.material_override = m
	cloth.position = Vector3(0, -h / 2.0, 0.06)
	cloth.rotation.x = -0.04
	root.add_child(cloth)
	var bar := MeshInstance3D.new()
	bar.mesh = _cyl(0.05, 0.05, w + 0.3, 6)
	bar.material_override = game._gold()
	bar.rotation.z = PI / 2.0
	bar.position = Vector3(0, 0.02, 0.06)
	root.add_child(bar)
	if pole:
		var p := MeshInstance3D.new()
		p.mesh = _cyl(0.07, 0.09, h + 2.6, 6)
		p.material_override = game._timber(Color(0.8, 0.62, 0.45))
		p.position = Vector3(0, -(h + 2.6) / 2.0 + 0.5, 0)
		root.add_child(p)
		var knob := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.24
		knob.mesh = s
		knob.material_override = game._gold()
		knob.position = Vector3(0, 0.55, 0)
		root.add_child(knob)


func _torch(pos: Vector3) -> void:
	## A torch on a post with a flame and a warm light.
	_mesh(_cyl(0.06, 0.08, 1.6, 6), pos + Vector3(0, 0.8, 0), game._timber(Color(0.7, 0.55, 0.4)))
	_mesh(_cyl(0.16, 0.08, 0.25, 8), pos + Vector3(0, 1.65, 0), game._iron())
	game._add_flame(pos + Vector3(0, 1.88, 0), 0.2, Color(1.0, 0.5, 0.12))
	game._add_flame(pos + Vector3(0, 1.98, 0), 0.1, Color(1.0, 0.92, 0.55))
	game._add_light(pos + Vector3(0, 2.1, 0), Color(1.0, 0.65, 0.3), 1.2, 6.0)


func _spikes(from: Vector3, to: Vector3, lean: Vector3) -> void:
	## A row of sharpened stakes leaning toward the enemy.
	var n := int(from.distance_to(to) / 0.45) + 1
	var wood: Material = game._timber(Color(0.85, 0.66, 0.46))
	for i in n:
		var p := from.lerp(to, float(i) / maxf(n - 1, 1))
		var h := 1.3 + 0.25 * float(i % 3)
		var s := MeshInstance3D.new()
		s.mesh = _cyl(0.0, 0.13, h, 6)
		s.material_override = wood
		game.add_child(s)
		s.global_position = p + Vector3(0, h * 0.4, 0)
		s.look_at(s.global_position + lean + Vector3(0, 2.0, 0), Vector3.FORWARD if absf(lean.z) < 0.9 else Vector3.RIGHT)
		s.rotate_object_local(Vector3.RIGHT, -PI / 2.0)


# --- Ground, terrace and keep --------------------------------------------------------

func _ground() -> void:
	game._add_block(P(0, -0.1, -20), Vector3(140, 0.2, 90), Color.WHITE, false, game._grass())
	# The near bank: a worn earth clearing either side of the stream.
	game._add_block(P(-5, 0.01, 4), Vector3(9, 0.02, 10), Color.WHITE, false, game._dirt())
	game._add_block(P(6, 0.01, 4), Vector3(9, 0.02, 10), Color.WHITE, false, game._dirt())


func _keep() -> void:
	var stone: Material = game._ashlar()
	var cliff: Material = game._stone(Color(0.78, 0.76, 0.72), 0.2)
	# The rocky terrace the castle stands on, in two steps.
	game._add_block(P(0, 1.6, -26), Vector3(26, 3.2, 16), Color.WHITE, false, cliff)
	game._add_block(P(0, 4.0, -30), Vector3(20, 1.6, 10), Color.WHITE, false, cliff)
	# Grand stairs up the terrace either side of the falls.
	for s in [-1.0, 1.0]:
		game._add_ramp(P(s * 4.6, 0, -15.5), P(s * 4.6, 3.2, -19.5), 3.0, Color.WHITE, game._flagstone(Color(0.95, 0.9, 0.82)))
	# Curtain wall and gatehouse.
	game._add_wall(P(0, 7.3, -31), Vector3(20, 5.0, 1.6))
	game._add_block(P(0, 8.8, -29.6), Vector3(7, 8.0, 3.0), Color.WHITE, false, stone)
	for xs in [-1.0, 1.0]:
		for k in 3:
			game._add_block(P(xs * (1.0 + k * 1.2), 13.1, -28.3), Vector3(0.6, 0.6, 0.6), Color.WHITE, false, stone)
	# The gate: a dark arch with a gold-trimmed portcullis, glowing from inside.
	_mesh(_box(Vector3(3.0, 4.2, 0.2)), P(0, 6.9, -28.05), _mat(Color(0.12, 0.08, 0.05)))
	var arch := _mesh(_cyl(1.5, 1.5, 0.2, 16), P(0, 9.0, -28.05), _mat(Color(0.12, 0.08, 0.05)))
	arch.rotation.x = PI / 2.0
	for k in 5:
		_mesh(_box(Vector3(0.08, 5.6, 0.08)), P(-1.2 + k * 0.6, 7.6, -27.92), game._iron())
	game._add_light(P(0, 7.5, -26.8), Color(1.0, 0.8, 0.4), 1.0, 6.0)
	# Towers: two tall ones at the gate, two at the corners, two behind.
	game._add_tower(P(-5.2, 4.8, -28.6), 1, -1.0, 2.8, 10.5)
	game._add_tower(P(5.2, 4.8, -28.6), 1, 1.0, 2.8, 10.5)
	game._add_tower(P(-10.5, 4.8, -31.0), 1, -1.0, 3.0, 8.0)
	game._add_tower(P(10.5, 4.8, -31.0), 1, 1.0, 3.0, 8.0)
	game._add_tower(P(-3.5, 4.8, -35.0), 1, -1.0, 3.4, 14.0)
	game._add_tower(P(3.5, 4.8, -35.0), 1, 1.0, 3.4, 14.0)
	game._add_block(P(0, 10.0, -36), Vector3(7, 10, 5), Color.WHITE, false, stone)
	# Blue lion banners down the gatehouse and the curtain wall.
	for x in [-2.6, 2.6]:
		_banner(1, P(x, 12.4, -28.0), 3.6, 0.0, false)
	for x in [-8.0, 8.0]:
		_banner(1, P(x, 9.6, -30.1), 2.8, 0.0, false)
	for x in [-6.6, 6.6]:
		_banner(1, P(x, 14.8, -27.1), 2.6, 0.0, false)
	# Torches along the terrace edge.
	for x in [-11.0, -7.0, -2.2, 2.2, 7.0, 11.0]:
		_torch(P(x, 3.2, -18.6))
	_crown()


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _crown() -> void:
	## The prize: a big gold crown on a pedestal before the gate, in a column of light.
	var base := P(0, 3.2, -21.0)
	_mesh(_cyl(1.1, 1.3, 0.5, 16), base + Vector3(0, 0.25, 0), game._ashlar(Color(0.95, 0.92, 0.85)))
	_mesh(_cyl(0.75, 0.9, 1.2, 16), base + Vector3(0, 1.1, 0), game._ashlar(Color(0.95, 0.92, 0.85)))
	_mesh(_cyl(1.0, 0.8, 0.25, 16), base + Vector3(0, 1.8, 0), game._gold())
	crown = Node3D.new()
	game.add_child(crown)
	crown.global_position = base + Vector3(0, 3.1, 0)
	crown.scale = Vector3.ONE * 1.6
	var gold: StandardMaterial3D = game._gold()
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.25)
	gold.emission_energy_multiplier = 0.35
	var band := MeshInstance3D.new()
	band.mesh = _cyl(0.8, 0.7, 0.55, 20)
	band.material_override = gold
	crown.add_child(band)
	for k in 6:
		var a := TAU * k / 6.0
		var spike := MeshInstance3D.new()
		spike.mesh = _cyl(0.0, 0.26, 0.9, 6)
		spike.material_override = gold
		spike.position = Vector3(cos(a) * 0.72, 0.65, sin(a) * 0.72)
		crown.add_child(spike)
		var ball := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.1
		bs.height = 0.2
		ball.mesh = bs
		ball.material_override = gold
		ball.position = spike.position + Vector3(0, 0.48, 0)
		crown.add_child(ball)
		var gem := MeshInstance3D.new()
		var gs := SphereMesh.new()
		gs.radius = 0.11
		gs.height = 0.22
		gem.mesh = gs
		gem.material_override = _mat([Color(0.9, 0.1, 0.15), Color(0.15, 0.4, 1.0), Color(0.2, 0.85, 0.35)][k % 3], 1.2)
		gem.position = Vector3(cos(a) * 0.79, 0.0, sin(a) * 0.79)
		crown.add_child(gem)
	game._add_light(base + Vector3(0, 3.4, 1.0), Color(1.0, 0.82, 0.4), 3.0, 10.0)
	# The column of light rising from the crown into the sky.
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(1.0, 0.8, 0.35, 0.22)
	beam = _mesh(_cyl(1.6, 0.9, 26.0, 20), base + Vector3(0, 15.0, 0), bm)
	var core := bm.duplicate()
	core.albedo_color = Color(1.0, 0.92, 0.6, 0.35)
	_mesh(_cyl(0.6, 0.4, 26.0, 16), base + Vector3(0, 15.0, 0), core)


# --- Water ---------------------------------------------------------------------------

func _waterfall_and_stream() -> void:
	var noise: Texture2D = load("res://assets/textures/water_noise.png")
	var fall := ShaderMaterial.new()
	fall.shader = load("res://assets/shaders/waterfall.gdshader")
	fall.set_shader_parameter("noise_tex", noise)
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.4)
	_mesh(q, P(0, 1.65, -17.95), fall)
	# Upper fall from the gate pool down the first step.
	var q2 := QuadMesh.new()
	q2.size = Vector2(2.2, 1.6)
	_mesh(q2, P(0, 4.0, -24.9), fall)
	var pool := ShaderMaterial.new()
	pool.shader = load("res://assets/shaders/water.gdshader")
	pool.set_shader_parameter("noise_tex", noise)
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.4, 34)
	plane.subdivide_depth = 20
	_mesh(plane, P(0, 0.05, 0), pool)
	# Stone banks along the stream.
	for s in [-1.0, 1.0]:
		game._add_block(P(s * 2.5, 0.2, 0), Vector3(0.7, 0.45, 34), Color.WHITE, false, game._ashlar(Color(0.85, 0.82, 0.76)))
	# Spray where the falls land.
	for i in 6:
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5 + 0.1 * i
		sm.height = sm.radius * 1.4
		sp.mesh = sm
		var fm := _mat(Color(0.92, 0.97, 1.0), 0.3)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.albedo_color.a = 0.55
		sp.material_override = fm
		game.add_child(sp)
		sp.global_position = P(-1.0 + i * 0.4, 0.2, -17.3 + (i % 2) * 0.3)
	# The stone bridge over the stream, near the camera.
	var arch_stone: Material = game._ashlar(Color(0.92, 0.88, 0.8))
	game._add_block(P(0, 1.35, -4.0), Vector3(6.4, 0.5, 2.6), Color.WHITE, false, arch_stone)
	for s in [-1.0, 1.0]:
		game._add_block(P(s * 2.7, 0.6, -4.0), Vector3(1.2, 1.2, 2.6), Color.WHITE, false, arch_stone)
		game._add_block(P(0, 1.85, -4.0 + s * 1.15), Vector3(6.4, 0.5, 0.3), Color.WHITE, false, arch_stone)


# --- The Human walls (left) ------------------------------------------------------------

func _human_walls() -> void:
	# Walls climbing away up the left: near, middle and high, each on its hill.
	game._add_block(P(-17, 1.5, -22), Vector3(16, 3.0, 30), Color.WHITE, false, game._stone(Color(0.72, 0.7, 0.66), 0.2))
	game._add_block(P(-24, 4.5, -32), Vector3(14, 3.0, 22), Color.WHITE, false, game._stone(Color(0.72, 0.7, 0.66), 0.2))
	game._add_wall(P(-9.0, 1.5, -6.0), Vector3(1.6, 3.0, 12.0))
	game._add_wall(P(-11.5, 4.6, -18.0), Vector3(1.6, 3.2, 12.0))
	game._add_wall(P(-15.5, 7.6, -30.0), Vector3(1.6, 3.2, 12.0))
	game._add_tower(P(-9.2, 0, 0.6), 1, -1.0, 2.6, 4.6)
	game._add_tower(P(-11.6, 3.0, -11.6), 1, -1.0, 2.8, 5.0)
	game._add_tower(P(-15.6, 6.0, -23.8), 1, -1.0, 2.8, 5.4)
	game._add_tower(P(-19.0, 6.0, -37.0), 1, -1.0, 3.2, 8.0)
	# Wooden scaffolds and a siege ladder against the walls.
	game._prop("hex/building_scaffolding", P(-7.2, 0, -9.5), 2.6, PI / 2.0)
	game._prop("hex/building_scaffolding", P(-9.8, 3.0, -21.0), 2.4, PI / 2.0)
	game._prop("hex/weaponrack", P(-6.8, 0, -2.5), 2.2, PI / 2.0)
	game._prop("hex/crate_A_big", P(-6.5, 0, -0.5), 2.0, 0.4)
	game._prop("hex/barrel", P(-7.4, 0, 0.6), 2.0, 0.0)
	# Lion banners on poles along the ramparts and a big one down each tower.
	for p in [P(-8.6, 3.0, -2.0), P(-8.6, 3.0, -9.0), P(-11.0, 6.2, -14.5), P(-11.0, 6.2, -21.0), P(-15.0, 9.2, -27.0), P(-15.0, 9.2, -33.0)]:
		_banner(1, p + Vector3(0, 3.2, 0), 2.0, 0.5)
	for p in [P(-7.85, 4.0, 0.6), P(-10.15, 7.6, -11.6)]:
		_banner(1, p, 2.6, PI / 2.0 - 0.1, false)
	# The high castle on the far cliff, upper left.
	game._prop("hex/mountain_C_grass", P(-30, -0.5, -50), 9.0, 0.6)
	for p in [P(-26, 12.0, -48), P(-31, 13.0, -45), P(-22, 11.0, -52)]:
		game._add_tower(p, 1, -1.0, 3.0, 7.0)
	game._add_wall(P(-26.5, 14.0, -47.5), Vector3(8.0, 3.0, 1.4))


# --- The Elven forest (right) ----------------------------------------------------------

func _forest() -> void:
	game.mossy = true
	for p in [[P(14, 0, -6), 1.15], [P(20, 0, -18), 1.35], [P(11.5, 0, -24), 1.1]]:
		game._add_treehouse(p[0], int(p[0].x * 7 + p[0].z), p[1])
	for p in [P(9.5, 0, -8.5), P(11, 0, 3), P(16, 0, -1), P(24, 0, -8), P(26, 0, -28), P(15, 0, -34), P(8, 0, -32), P(30, 0, -14), P(21, 0, -40)]:
		game._add_tree_grown(p, true)
	game.mossy = false
	# Green tree banners on poles among the trees and on the platforms.
	for p in [P(7.6, 0, -4.0), P(10.0, 0, -14.0), P(17.0, 0, -11.0), P(7.6, 0, -20.0)]:
		_banner(0, p + Vector3(0, 4.6, 0), 2.4, -0.5)
	for p in [P(14.0, 3.8 * 1.15 + 2.6, -6.0), P(20.0, 3.8 * 1.35 + 2.6, -18.0)]:
		_banner(0, p, 1.8, -0.4)
	# Stakes and crates at the forest edge facing the stream.
	_spikes(P(5.2, 0, 5.0), P(5.2, 0, -6.0), Vector3(-1, 0, 0))
	_spikes(P(-5.0, 0, 6.5), P(-5.0, 0, -3.0), Vector3(1, 0, 0))
	game._prop("hex/crate_B_big", P(7.0, 0, 6.5), 2.0, 0.3)
	game._prop("hex/barrel", P(8.2, 0, 7.0), 2.0, 0.0)
	game._add_bush(P(9.0, 0, 6.0), 3)
	game._add_bush(P(-8.6, 0, 6.5), 5)
	for p in [P(7.5, 0, -1.5), P(4.0, 0, -12.0)]:
		_torch(p)


func _backdrop() -> void:
	for m in [["mountain_A_grass_trees", P(-8, -0.5, -70), 11.0], ["mountain_B_grass_trees", P(14, -0.5, -66), 12.0],
			["mountain_C_grass_trees", P(36, -0.5, -58), 11.0], ["mountain_A_grass", P(-40, -0.5, -64), 12.0],
			["mountain_B_grass", P(52, -0.5, -40), 12.0]]:
		game._prop("hex/" + m[0], m[1], m[2], 0.4)
	for p in [P(-14, 22, -60), P(18, 24, -64), P(36, 19, -50), P(-34, 20, -40)]:
		game._prop("hex/cloud_big", p, 4.0, 0.3)
	for i in 14:
		var r := RandomNumberGenerator.new()
		r.seed = 300 + i
		game._prop("hex/trees_A_large", P(r.randf_range(14, 40), 0, r.randf_range(-50, -30)), 3.2, r.randf() * TAU)


# --- The armies ---------------------------------------------------------------------------

func _fighter(team: int, role: int, pos: Vector3, face: Vector3, kind: String, scale: float = 1.0, rank: int = 2):
	var m = CharacterModel.new()
	add_child(m)
	m.setup(team, role, "", {}, rank)
	m.global_position = pos
	m.scale = Vector3.ONE * scale
	m.look_at(Vector3(face.x, pos.y, face.z), Vector3.UP, true)
	match kind:
		"aim":
			if m.anim and m.anim.has_animation("2H_Ranged_Aiming"):
				m.anim.get_animation("2H_Ranged_Aiming").loop_mode = Animation.LOOP_LINEAR
				m.hold("2H_Ranged_Aiming")
		"cast":
			m.hold("Spellcasting")
		"block":
			m.hold("Blocking")
	fighters.append([m, kind, randf() * 2.0])
	return m


func _armies() -> void:
	seed(12)
	var east := P(6, 0, -6)
	var west := P(-6, 0, -6)
	# Humans on the ramparts, shooting and casting across at the forest.
	var wall_spots := [[P(-8.6, 3.0, -4.0), Role.RANGER, "shoot"], [P(-8.6, 3.0, -7.0), Role.KNIGHT, "fight"],
		[P(-8.6, 3.0, -10.5), Role.MAGE, "cast"], [P(-11.0, 6.2, -16.0), Role.RANGER, "shoot"],
		[P(-11.0, 6.2, -19.0), Role.KNIGHT, "block"], [P(-11.0, 6.2, -22.5), Role.RANGER, "shoot"],
		[P(-15.0, 9.2, -28.0), Role.MAGE, "cast"], [P(-15.0, 9.2, -31.5), Role.RANGER, "shoot"]]
	for s in wall_spots:
		_fighter(1, s[1], s[0], s[0] + Vector3(10, 0, 3), s[2])
	# Humans on the near bank and the terrace stairs.
	for s in [[P(-3.6, 0, -6.0), Role.KNIGHT, "fight"], [P(-4.2, 0, -10.5), Role.HEALER, "cast"], [P(-3.4, 0, -13.0), Role.RANGER, "shoot"],
			[P(-6.0, 3.2, -19.0), Role.KNIGHT, "fight"], [P(-1.4, 1.6, -4.0), Role.KNIGHT, "fight"], [P(-3.8, 0, -2.0), Role.RANGER, "shoot"],
			[P(-6.2, 0, -4.0), Role.KNIGHT, "block"], [P(-5.4, 0, -8.0), Role.RANGER, "shoot"], [P(-6.6, 0, -12.5), Role.KNIGHT, "fight"],
			[P(-3.2, 3.2, -17.5), Role.MAGE, "cast"], [P(-7.0, 0, 1.0), Role.HEALER, "cast"]]:
		_fighter(1, s[1], s[0], east, s[2])
	# Elves along the forest edge and up on the tree-house platforms.
	for s in [[P(3.6, 0, -5.0), Role.KNIGHT, "fight"], [P(4.2, 0, -9.0), Role.RANGER, "shoot"], [P(3.6, 0, -13.5), Role.MAGE, "cast"],
			[P(6.4, 0, -2.0), Role.RANGER, "aim"], [P(1.0, 1.6, -4.0), Role.KNIGHT, "fight"], [P(6.0, 3.2, -19.5), Role.RANGER, "shoot"],
			[P(13.0, 3.3 * 1.15 + 0.2, -4.6), Role.RANGER, "aim"], [P(19.0, 3.3 * 1.35 + 0.2, -16.6), Role.MAGE, "cast"],
			[P(10.6, 3.3 * 1.1 + 0.2, -22.8), Role.RANGER, "shoot"], [P(8.4, 0, -16.0), Role.HEALER, "cast"],
			[P(5.8, 0, -7.5), Role.KNIGHT, "block"], [P(7.4, 0, -11.0), Role.RANGER, "shoot"], [P(3.4, 3.2, -18.0), Role.KNIGHT, "fight"],
			[P(8.0, 0, 0.5), Role.RANGER, "shoot"]]:
		_fighter(0, s[1], s[0], west, s[2])
	# The heroes up front: placed by screen position in place_heroes().
	hero_knight = _fighter(1, Role.KNIGHT, P(-3, 0, 12), P(4, 0, -4), "fight", 1.0, 3)
	hero_ranger = _fighter(0, Role.RANGER, P(4, 0, 12), P(-4, 0, -4), "aim", 1.0, 3)
	var wizard = _fighter(1, Role.MAGE, P(-5.6, 0, 6.5), P(3, 0, -4), "cast", 1.0, 3)
	var leaper = _fighter(0, Role.MAGE, P(8.5, 3.4, -3.0), P(-4, 0, -4), "leap", 1.0, 3)
	if leaper.anim and leaper.anim.has_animation("Jump_Idle"):
		leaper.hold("Jump_Idle")
	# The leaping mage's staff orb glows green.
	game._add_light(P(8.0, 5.4, -3.0), Color(0.35, 1.0, 0.5), 2.0, 5.0).reparent(self, true)
	var _w = wizard


func place_heroes(cam: Camera3D, vp: Vector2) -> void:
	## Puts the two big heroes at fixed screen spots, whatever the aspect.
	for pair in [[hero_knight, Vector2(0.37, 1.0), P(3, 0, -6), 0.35], [hero_ranger, Vector2(0.85, 1.0), P(-6, 0, -6), -0.2]]:
		var p: Vector2 = vp * pair[1]
		var o := cam.project_ray_origin(p)
		var d := cam.project_ray_normal(p)
		var pos: Vector3 = o + d * ((0.0 - o.y) / d.y) if absf(d.y) > 0.001 else o + d * 6.0
		var m = pair[0]
		m.global_position = pos
		m.scale = Vector3.ONE * 1.8
		var aim: Vector3 = pair[2]
		m.look_at(Vector3(aim.x, pos.y, aim.z), Vector3.UP, true)
		m.rotation.y += pair[3]


# --- Arrows and spells ------------------------------------------------------------------

func _projectiles() -> void:
	var shaft := _mat(Color(0.6, 0.42, 0.25))
	var feather := _mat(Color(0.95, 0.95, 0.9))
	var rr := RandomNumberGenerator.new()
	rr.seed = 9
	for i in 16:
		# Arrows both ways over the stream.
		var east := i % 2 == 0
		var a := Node3D.new()
		add_child(a)
		var body := MeshInstance3D.new()
		body.mesh = _cyl(0.025, 0.025, 1.0, 5)
		body.material_override = shaft
		body.rotation.x = PI / 2.0
		a.add_child(body)
		var head := MeshInstance3D.new()
		head.mesh = _cyl(0.0, 0.07, 0.2, 5)
		head.material_override = game._iron()
		head.rotation.x = -PI / 2.0
		head.position.z = -0.58
		a.add_child(head)
		var fl := MeshInstance3D.new()
		fl.mesh = _box(Vector3(0.14, 0.02, 0.22))
		fl.material_override = feather
		fl.position.z = 0.45
		a.add_child(fl)
		var z0 := rr.randf_range(-22, 2)
		var from := P(-9 if east else 9, rr.randf_range(3, 8), z0) if not east else P(-10, rr.randf_range(4, 9), z0)
		var to := P(10, rr.randf_range(2, 6), z0 + rr.randf_range(-4, 4)) if east else P(-10, rr.randf_range(3, 8), z0 + rr.randf_range(-4, 4))
		shots.append([a, from, to, rr.randf_range(2.0, 4.0), rr.randf_range(1.6, 2.4), rr.randf(), false])
	# Blue Human bolts toward the forest, green elven magic toward the walls, fireballs.
	for i in 9:
		var kind := i % 3
		var col: Color = [Color(0.35, 0.65, 1.0), Color(0.3, 1.0, 0.45), Color(1.0, 0.5, 0.12)][kind]
		var n := Node3D.new()
		add_child(n)
		var orb := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.28 if kind == 2 else 0.2
		s.height = s.radius * 2.0
		orb.mesh = s
		orb.material_override = _mat(col.lightened(0.4), 3.0)
		n.add_child(orb)
		var trail := MeshInstance3D.new()
		trail.mesh = _cyl(s.radius * 0.9, 0.0, 2.4, 8)
		var tm := _mat(col, 2.0)
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.albedo_color = Color(col.r, col.g, col.b, 0.7)
		trail.material_override = tm
		trail.rotation.x = PI / 2.0
		trail.position.z = 1.2
		n.add_child(trail)
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 1.5
		light.omni_range = 4.0
		n.add_child(light)
		var z0 := rr.randf_range(-20, 0)
		var from: Vector3
		var to: Vector3
		if kind == 1:
			from = P(rr.randf_range(6, 12), rr.randf_range(3, 7), z0)
			to = P(rr.randf_range(-12, -8), rr.randf_range(4, 9), z0 - 3)
		else:
			from = P(rr.randf_range(-12, -8), rr.randf_range(4, 9), z0)
			to = P(rr.randf_range(6, 12), rr.randf_range(1, 5), z0 + 2)
		shots.append([n, from, to, rr.randf_range(1.0, 2.5), rr.randf_range(1.8, 2.8), rr.randf(), true])


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	if crown:
		crown.rotation.y = t * 0.5
		crown.position.y = crown.position.y + sin(t * 1.6) * 0.002
	if beam:
		beam.scale = Vector3.ONE * (1.0 + sin(t * 2.0) * 0.05)
	for s in shots:
		var k := fmod(t / s[4] + s[5], 1.0)
		var from: Vector3 = s[1]
		var to: Vector3 = s[2]
		var p := from.lerp(to, k) + Vector3(0, sin(k * PI) * s[3], 0)
		var ahead := from.lerp(to, minf(k + 0.02, 1.0)) + Vector3(0, sin(minf(k + 0.02, 1.0) * PI) * s[3], 0)
		var n: Node3D = s[0]
		n.global_position = p
		if ahead.distance_to(p) > 0.001:
			n.look_at(ahead, Vector3.UP)
		n.visible = k > 0.04 and k < 0.96
	for f in fighters:
		var m = f[0]
		if t > f[2]:
			match f[1]:
				"fight":
					m.attack()
					f[2] = t + randf_range(0.9, 1.8)
				"shoot":
					m.play_once("2H_Ranged_Shoot")
					f[2] = t + randf_range(1.2, 2.2)
				"cast":
					m.play_once("Spellcast_Shoot")
					f[2] = t + randf_range(1.4, 2.6)
				_:
					f[2] = t + 99.0
		m.update_locomotion(false)
