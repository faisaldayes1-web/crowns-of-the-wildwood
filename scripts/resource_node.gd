extends Node3D
## A lumber tree or an ore deposit (Economy, 2026-10-09). Stand next to it
## and press the interact key to chop or mine one unit at a time; it gives
## a few units, then a felled tree regrows from its stump and a spent deposit
## grows its ore back. economy.gd owns the gathering itself.

const Stats = preload("res://scripts/stats.gd")

var game
var kind := "wood"          # "wood" or "ore"
var stock := 0
var regrow_left := 0.0
var elf_side := true        # which half of the map it stands on (sets the look)
var full: Node3D            # the standing tree / the ore crystals
var spent: Node3D           # the stump with its sapling / nothing extra for ore
var sapling: Node3D
var bar: Node3D             # work progress over the node while someone gathers
var bar_fill: MeshInstance3D
var prompt: Label3D
var shake := 0.0


func setup(p_game, p_kind: String, pos: Vector3) -> void:
	game = p_game
	kind = p_kind
	position = pos
	elf_side = pos.x < 0.0
	stock = max_stock()
	var r := RandomNumberGenerator.new()
	r.seed = absi(int(pos.x * 31.0 + pos.z * 17.0)) + (7 if kind == "ore" else 0)
	rotation.y = r.randf() * TAU
	# Solid, like every other tree and boulder: walkers go round it.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55 if kind == "wood" else 0.9
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	body.add_child(shape)
	add_child(body)
	full = Node3D.new()
	add_child(full)
	spent = Node3D.new()
	add_child(spent)
	if kind == "wood":
		_build_tree(r)
	else:
		_build_deposit(r)
	_build_bar()
	prompt = Label3D.new()
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.font_size = 30
	prompt.pixel_size = 0.0105
	prompt.outline_size = 9
	prompt.modulate = Color(1.0, 0.95, 0.8)
	prompt.position.y = 4.4 if kind == "wood" else 2.6
	prompt.visible = false
	add_child(prompt)
	_refresh()


func max_stock() -> int:
	return Stats.ECONOMY.tree_stock if kind == "wood" else Stats.ECONOMY.ore_stock


func available() -> bool:
	return stock > 0


func in_reach(u) -> bool:
	var offset: Vector3 = u.global_position - global_position
	return absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < Stats.ECONOMY.reach


func take_one() -> bool:
	## One unit comes off: true if there was one to take.
	if stock <= 0:
		return false
	stock -= 1
	shake = 0.35
	if stock == 0:
		regrow_left = Stats.ECONOMY.regrow
		if kind == "wood":
			game.sfx.play("door_break", global_position, -8.0, 0.1)
			game.spawn_splash(global_position + Vector3(0, 1.5, 0), Color(0.35, 0.6, 0.25), 40, 5.0, 1.0, true)
		else:
			game.spawn_splash(global_position + Vector3(0, 0.8, 0), Color(0.95, 0.7, 0.3), 24, 4.0, 0.8, true)
	_refresh()
	return true


func set_progress(frac: float) -> void:
	bar.visible = frac > 0.0
	bar_fill.scale.x = maxf(frac, 0.01)
	bar_fill.position.x = -0.6 * (1.0 - frac)


func _process(delta: float) -> void:
	if stock <= 0:
		regrow_left -= delta
		if sapling:
			# The sapling grows back into the tree's spot.
			var k := clampf(1.0 - regrow_left / Stats.ECONOMY.regrow, 0.0, 1.0)
			sapling.scale = Vector3.ONE * (0.25 + 0.75 * k)
		if regrow_left <= 0.0:
			stock = max_stock()
			game.spawn_ring(global_position, 1.4, Color(0.6, 1.0, 0.5) if kind == "wood" else Color(1.0, 0.8, 0.35), 0.6)
			_refresh()
	if shake > 0.0:
		shake = maxf(shake - delta, 0.0)
		full.rotation.z = sin(shake * 60.0) * shake * 0.12
	var p = game.player
	var show: bool = p != null and is_instance_valid(p) and not p.dead and p.is_player and in_reach(p) and game.playing
	prompt.visible = show
	if show:
		prompt.text = game.economy.node_prompt(self, p) if game.economy else ""


func _refresh() -> void:
	full.visible = stock > 0
	spent.visible = stock <= 0
	if kind == "ore" and stock > 0:
		# The deposit's crystals thin out as it is mined.
		var shown := 0
		for c in full.get_children():
			if c.has_meta("crystal"):
				c.visible = shown < 2 + stock * 2
				shown += 1


# --- Looks ----------------------------------------------------------------------

func _mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, height: float, sides: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


func _build_tree(r: RandomNumberGenerator) -> void:
	## A stout broadleaf with an axe-scarred trunk, a chopping block with an
	## axe in it and a few cut logs: a working tree, read from the camera.
	var bark: StandardMaterial3D = game._pbr("bark", 0.5, Color(0.95, 0.88, 0.8))
	var cut := _mat(Color(0.86, 0.68, 0.42), 0.9)
	var leaf_a := Color(0.36, 0.66, 0.3) if elf_side else Color(0.3, 0.52, 0.22)
	var leaf_b := Color(0.5, 0.78, 0.36) if elf_side else Color(0.42, 0.6, 0.26)
	# Trunk, flared roots and a pale notch where it has been cut into.
	_mesh(full, _cyl(0.32, 0.46, 2.6, 9), Vector3(0, 1.3, 0), bark)
	for k in 4:
		var a := TAU * k / 4.0 + r.randf() * 0.4
		_mesh(full, _cyl(0.05, 0.18, 0.9, 6), Vector3(cos(a) * 0.38, 0.22, sin(a) * 0.38), bark, Vector3(sin(a) * 1.1, 0, -cos(a) * 1.1))
	var notch := BoxMesh.new()
	notch.size = Vector3(0.36, 0.22, 0.12)
	_mesh(full, notch, Vector3(0, 0.75, 0.36), cut)
	# Canopy: four faceted leaf blobs, the top one lighter.
	for k in 4:
		var a := TAU * k / 3.0 + r.randf() * 0.5
		var off := Vector3(cos(a) * 0.75, 0, sin(a) * 0.75) if k < 3 else Vector3.ZERO
		var rad := 1.15 if k < 3 else 1.3
		var blob := _mesh(full, game._rock_mesh(r.randi(), rad, 0.18), Vector3(0, 3.0 if k < 3 else 3.75, 0) + off,
			_mat(leaf_a if k < 3 else leaf_b, 0.9))
		blob.scale = Vector3(1.0, 0.8, 1.0)
	# The chopping block, its axe and a stack of cut logs beside the tree.
	var block := _mesh(self, _cyl(0.3, 0.32, 0.42, 9), Vector3(1.25, 0.21, 0.35), bark)
	_mesh(block, _cyl(0.29, 0.29, 0.02, 9), Vector3(0, 0.22, 0), cut)
	var axe := Node3D.new()
	axe.position = Vector3(1.25, 0.5, 0.35)
	axe.rotation = Vector3(0.0, 0.6, 0.5)
	add_child(axe)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.06, 0.75, 0.06)
	_mesh(axe, handle, Vector3(0, 0.32, 0), _mat(Color(0.55, 0.38, 0.22)))
	var head := BoxMesh.new()
	head.size = Vector3(0.26, 0.16, 0.05)
	_mesh(axe, head, Vector3(0.08, 0.02, 0), _mat(Color(0.7, 0.72, 0.76), 0.35, 0.8))
	for k in 3:
		var log := _mesh(self, _cyl(0.14, 0.14, 0.9, 8), Vector3(-1.1, 0.14 + (0.24 if k == 2 else 0.0), 0.5 + (k % 2) * 0.28 - (0.14 if k == 2 else 0.0)),
			bark, Vector3(0, 0, PI / 2.0))
		_mesh(log, _cyl(0.13, 0.13, 0.92, 8), Vector3.ZERO, cut, Vector3.ZERO, Vector3(0.9, 1.0, 0.9))
	# Felled: a stump with a fresh cut and a sapling growing back.
	_mesh(spent, _cyl(0.38, 0.46, 0.5, 9), Vector3(0, 0.25, 0), bark)
	_mesh(spent, _cyl(0.37, 0.37, 0.02, 9), Vector3(0, 0.51, 0), cut)
	sapling = Node3D.new()
	sapling.position = Vector3(0.5, 0, -0.3)
	spent.add_child(sapling)
	_mesh(sapling, _cyl(0.04, 0.06, 0.8, 5), Vector3(0, 0.4, 0), bark)
	_mesh(sapling, game._rock_mesh(r.randi(), 0.35, 0.2), Vector3(0, 0.9, 0), _mat(leaf_b, 0.9))


func _build_deposit(r: RandomNumberGenerator) -> void:
	## Grey boulders split open on veins of ore: warm gold-orange metal on
	## the Elves' half, ruddy iron on the Humans', with a pick left in it.
	var rock: StandardMaterial3D = game._stone(Color(0.72, 0.7, 0.68), 0.4)
	var ore_col := Color(1.0, 0.72, 0.28) if elf_side else Color(0.95, 0.55, 0.3)
	var ore := _mat(ore_col, 0.3, 0.75)
	ore.emission_enabled = true
	ore.emission = ore_col
	ore.emission_energy_multiplier = 0.35
	var rocks := [[Vector3(0, 0.45, 0), 0.85], [Vector3(0.75, 0.3, 0.35), 0.55], [Vector3(-0.6, 0.28, 0.45), 0.5], [Vector3(-0.2, 0.25, -0.7), 0.45]]
	for rk in rocks:
		var m := _mesh(self, game._rock_mesh(r.randi(), rk[1], 0.25), rk[0], rock)
		m.scale = Vector3(1.0, 0.8, 1.0)
	# Ore crystals: blunt prisms in clusters out of the rocks' tops and gaps.
	for k in 8:
		var a := TAU * k / 8.0 + r.randf() * 0.5
		var d := 0.25 + r.randf() * 0.45
		var h := 0.35 + r.randf() * 0.35
		var c := _mesh(full, _cyl(0.04, 0.11 + r.randf() * 0.05, h, 5), Vector3(cos(a) * d, 0.55 + r.randf() * 0.35, sin(a) * d), ore,
			Vector3(sin(a) * 0.5, r.randf() * TAU, -cos(a) * 0.5))
		c.set_meta("crystal", true)
	# A pick leaning on the deposit.
	var pick := Node3D.new()
	pick.position = Vector3(0.95, 0.45, -0.45)
	pick.rotation = Vector3(0.2, 0.9, -0.45)
	add_child(pick)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.06, 0.85, 0.06)
	_mesh(pick, handle, Vector3.ZERO, _mat(Color(0.55, 0.38, 0.22)))
	var head := _mesh(pick, _cyl(0.02, 0.045, 0.6, 6), Vector3(0, 0.4, 0), _mat(Color(0.6, 0.62, 0.66), 0.35, 0.8), Vector3(0, 0, PI / 2.0))
	head.scale = Vector3(1, 1, 1)
	# Spent: a few dull stubs where the crystals were.
	for k in 3:
		var a := TAU * k / 3.0
		_mesh(spent, _cyl(0.05, 0.08, 0.12, 5), Vector3(cos(a) * 0.35, 0.82, sin(a) * 0.35), _mat(ore_col.darkened(0.6), 0.9))


func _build_bar() -> void:
	# Tilted to face the fixed camera, like the soldiers' overhead bars.
	bar = Node3D.new()
	bar.top_level = true
	add_child(bar)
	bar.global_position = global_position + Vector3(0, 3.9 if kind == "wood" else 2.1, 0)
	bar.rotation_degrees.x = -55.0
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 0.16)
	back.mesh = q
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.05, 0.04, 0.03, 0.9)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.no_depth_test = true
	bm.render_priority = 4
	back.material_override = bm
	bar.add_child(back)
	bar_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.2, 0.09)
	bar_fill.mesh = fq
	bar_fill.position.z = 0.003
	var fm := bm.duplicate()
	fm.albedo_color = Color(0.95, 0.75, 0.3) if kind == "ore" else Color(0.55, 0.85, 0.35)
	fm.render_priority = 5
	bar_fill.material_override = fm
	bar.add_child(bar_fill)
	bar.visible = false
