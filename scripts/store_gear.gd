extends RefCounted
## The STORE's wearable gear, built on a character model (character_model.gd):
## hats on the bare unclassed head, capes and long scarves on every class,
## the armour tint painted into the skin's metal cells and the weapon skin
## on the held weapons. Looks only (Stats.HERO_HATS / HERO_CAPES /
## HERO_OUTFITS / WEAPON_SKINS).

const Stats = preload("res://scripts/stats.gd")

const GOLD := Color(0.98, 0.8, 0.25)


static func without_outfit(custom: Dictionary) -> Dictionary:
	var c := custom.duplicate()
	c.erase("outfit")
	return c


static func in_gear(node: Node, root: Node, gear_names: Array) -> bool:
	## Whether a mesh hangs under one of the model's gear (weapon / shield) nodes.
	var n := node
	while n and n != root:
		if String(n.name) in gear_names:
			return true
		n = n.get_parent()
	return false


static func tint_metal(img: Image, cells: Dictionary, target: Color) -> void:
	## The armour tint: every grey (metal) cell of the 8x4 palette grid that is
	## not hair, skin or trim takes the tint's hue, keeping its shading.
	var cw: int = img.get_width() / 8
	var ch: int = img.get_height() / 4
	var skip: Array = []
	for part in cells:
		skip.append_array(cells[part])
	for row in 4:
		for col in 8:
			if Vector2i(col, row) in skip:
				continue
			var x0 := col * cw
			var y0 := row * ch
			var probe := img.get_pixel(x0 + cw / 2, y0 + ch / 2)
			if probe.s > 0.16 or probe.v < 0.25:
				continue   # leather, cloth, gold or the dark eye cell
			for y in range(y0, y0 + ch):
				for x in range(x0, x0 + cw):
					var p := img.get_pixel(x, y)
					var v := clampf(p.v * (0.55 + target.v * 0.6), 0.0, 1.0)
					img.set_pixel(x, y, Color.from_hsv(target.h, target.s * 0.8, v, p.a))


static func skin_weapon(mat: StandardMaterial3D, look: Array) -> void:
	var col: Color = look[1]
	mat.albedo_color = mat.albedo_color * Color(col.r * 1.3, col.g * 1.3, col.b * 1.3)
	mat.metallic = 0.45
	mat.roughness = 0.4
	if float(look[2]) > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = float(look[2])


static func dress(model: Node3D, inst: Node3D, skeleton: Skeleton3D, custom: Dictionary, cloth: Color, outline: Material, bare: bool) -> void:
	var hat: String = custom.get("hat", "")
	if hat != "" and bare:
		var att := BoneAttachment3D.new()
		att.bone_name = "head"
		skeleton.add_child(att)
		_hat(att, hat, outline)
	var cape: String = custom.get("cape", "")
	if cape == "":
		return
	var body := _bone_node(skeleton, "chest")
	if body == null:
		return
	if cape == "scarf":
		_scarf(body, cloth, outline)
		return
	# A STORE cape replaces the pack's own capes.
	for name in ["Knight_Cape", "Rogue_Cape"]:
		var own := inst.find_child(name, true, false)
		if own:
			own.visible = false
	_cape(body, cape, cloth, outline)


static func _bone_node(skeleton: Skeleton3D, bone: String) -> Node3D:
	## A node that follows `bone`, with model-space coordinates.
	var b := skeleton.find_bone(bone)
	if b < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skeleton.add_child(att)
	var n := Node3D.new()
	n.transform = skeleton.get_bone_global_rest(b).affine_inverse()
	att.add_child(n)
	return n


static func _mat(col: Color, outline: Material, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.rim_enabled = true
	m.rim = 0.3
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	if outline:
		m.next_pass = outline
	return m


static func _metal(col: Color, outline: Material) -> StandardMaterial3D:
	var m := _mat(col, outline)
	m.metallic = 0.7
	m.roughness = 0.3
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scale
	parent.add_child(m)
	return m


static func _cyl(top: float, bottom: float, height: float, sides: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


static func _ball(r: float, sides: int = 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = sides
	s.rings = maxi(sides / 2, 3)
	return s


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 18
	t.ring_segments = 8
	return t


# --- Hats (head-bone space: the crown's band sits at y 0.78, radius 0.42) -------------

static func _hat(att: Node3D, style: String, outline: Material) -> void:
	match style:
		"cap":
			# A soft feathered cap tipped to one side.
			var felt := _mat(Color(0.72, 0.18, 0.16), outline)
			var root := Node3D.new()
			root.position = Vector3(0, 0.74, 0)
			root.rotation = Vector3(0.05, 0, -0.12)
			att.add_child(root)
			_add(root, _cyl(0.4, 0.5, 0.3), felt, Vector3(0, 0.12, 0))
			_add(root, _ball(0.4), felt, Vector3(0, 0.26, 0), Vector3.ZERO, Vector3(1, 0.45, 1))
			_add(root, _cyl(0.52, 0.52, 0.05, 14), _mat(Color(0.5, 0.1, 0.1), outline), Vector3(0, -0.02, 0))
			var feather := _mat(Color(1.0, 0.96, 0.86), outline)
			_add(root, _ball(0.12, 6), feather, Vector3(0.36, 0.32, -0.12), Vector3(0.0, 0.0, -0.7), Vector3(0.5, 3.0, 0.25))
			_add(root, _ball(0.08, 6), _mat(GOLD, null), Vector3(0.44, 0.12, -0.04))
		"straw":
			var straw := _mat(Color(0.9, 0.76, 0.45), outline)
			_add(att, _cyl(0.86, 0.9, 0.05, 18), straw, Vector3(0, 0.7, 0))
			_add(att, _cyl(0.36, 0.44, 0.34, 14), straw, Vector3(0, 0.88, 0))
			_add(att, _cyl(0.45, 0.45, 0.09, 14), _mat(Color(0.75, 0.2, 0.18), null), Vector3(0, 0.76, 0))
		"circlet", "flowers":
			var green := _mat(Color(0.3, 0.6, 0.25), outline)
			_add(att, _torus(0.4, 0.5), green, Vector3(0, 0.66, 0), Vector3(0.08, 0, 0))
			var cols := [Color(0.42, 0.75, 0.32)] if style == "circlet" else [Color(1.0, 0.6, 0.75), Color(1.0, 0.98, 0.95), Color(1.0, 0.86, 0.3), Color(0.75, 0.6, 1.0)]
			for k in 10:
				var a := TAU * k / 10.0
				var p := Vector3(cos(a) * 0.46, 0.7 + sin(a) * 0.035, sin(a) * 0.46)
				if style == "circlet":
					_add(att, _ball(0.1, 6), green if k % 2 else _mat(cols[0], null), p + Vector3(0, 0.06, 0), Vector3(0, -a, 0.6), Vector3(0.5, 1.4, 0.25))
				else:
					_add(att, _ball(0.09, 6), _mat(cols[k % cols.size()], null), p + Vector3(0, 0.05, 0))
					_add(att, _ball(0.04, 5), _mat(Color(1.0, 0.85, 0.2), null), p + Vector3(0, 0.1, 0))
		"wizard":
			var cloth := _mat(Color(0.3, 0.2, 0.6), outline)
			_add(att, _cyl(0.84, 0.88, 0.05, 18), cloth, Vector3(0, 0.72, 0))
			var cone := Node3D.new()
			cone.position = Vector3(0, 0.74, 0)
			cone.rotation = Vector3(-0.22, 0, 0.05)
			att.add_child(cone)
			_add(cone, _cyl(0.24, 0.48, 0.5, 14), cloth, Vector3(0, 0.25, 0))
			_add(cone, _cyl(0.0, 0.24, 0.55, 14), cloth, Vector3(0.03, 0.75, -0.06), Vector3(-0.3, 0, 0))
			_add(cone, _cyl(0.49, 0.49, 0.08, 14), _mat(GOLD, null), Vector3(0, 0.06, 0))
			_add(cone, _ball(0.09, 6), _mat(Color(1.0, 0.9, 0.4), null, 1.5), Vector3(0, 0.3, 0.46))
		"horns":
			var steel := _metal(Color(0.62, 0.65, 0.72), outline)
			var dome := SphereMesh.new()
			dome.radius = 0.52
			dome.height = 0.52
			dome.is_hemisphere = true
			dome.radial_segments = 14
			dome.rings = 5
			_add(att, dome, steel, Vector3(0, 0.6, 0))
			_add(att, _cyl(0.54, 0.54, 0.08, 14), _metal(Color(0.5, 0.4, 0.3), null), Vector3(0, 0.62, 0))
			var horn := _mat(Color(0.95, 0.9, 0.78), outline)
			for sx in [-1.0, 1.0]:
				_add(att, _cyl(0.0, 0.11, 0.5, 8), horn, Vector3(sx * 0.6, 0.98, 0), Vector3(0, 0, -sx * 0.75))
		"gold":
			var gold := _metal(GOLD, outline)
			_add(att, _torus(0.42, 0.47), gold, Vector3(0, 0.64, 0), Vector3(0.1, 0, 0))
			for k in 5:
				var a := PI / 2.0 + (k - 2) * 0.42
				_add(att, _cyl(0.0, 0.05, 0.16, 6), gold, Vector3(cos(a) * 0.45, 0.76, sin(a) * 0.45))
			var gem := _mat(Color(0.2, 0.75, 0.4), null, 1.2)
			_add(att, _ball(0.08, 8), gem, Vector3(0, 0.7, 0.48))


# --- Capes and the long scarf (model space; the back is -Z) -------------------------------

static func _cloth_mesh(top_w: float, bottom_w: float, height: float, bulge: float, flare: float) -> ArrayMesh:
	## A curved sheet hanging from y = 0 down to -height, wrapped round the
	## back (z bows out to -bulge at the middle) and swinging back by `flare`
	## at the hem. Both faces are built so it reads from any side.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 6
	var rows := 4
	var grid: Array = []
	for j in rows + 1:
		var v := float(j) / rows
		var w := lerpf(top_w, bottom_w, v)
		var line: Array = []
		for i in cols + 1:
			var u := float(i) / cols * 2.0 - 1.0
			var x := u * w / 2.0
			var z := -bulge * (1.0 - u * u) - flare * v * v
			# A gentle wave along the hem.
			var y := -height * v + (sin(u * PI * 1.5) * 0.03 * v)
			line.append(Vector3(x, y, z))
		grid.append(line)
	for side in [1, -1]:
		for j in rows:
			for i in cols:
				var a: Vector3 = grid[j][i]
				var b: Vector3 = grid[j][i + 1]
				var c: Vector3 = grid[j + 1][i + 1]
				var d: Vector3 = grid[j + 1][i]
				if side > 0:
					for p in [a, b, c, a, c, d]:
						st.add_vertex(p)
				else:
					for p in [a, c, b, a, d, c]:
						st.add_vertex(p + Vector3(0, 0, 0.012))
	st.generate_normals()
	return st.commit()


static func _cape(body: Node3D, style: String, cloth: Color, outline: Material) -> void:
	var col := cloth
	match style:
		"leaf": col = Color(0.27, 0.55, 0.25)
		"royal": col = cloth if cloth.s > 0.25 else Color(0.62, 0.1, 0.16)
		"ember": col = Color(0.35, 0.08, 0.06)
	var mat := _mat(col, outline)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var long := 1.05 if style == "royal" else 0.95
	var root := Node3D.new()
	root.position = Vector3(0, 1.12, -0.26)
	body.add_child(root)
	_add(root, _cloth_mesh(0.62, 0.95, long, 0.12, 0.22), mat, Vector3.ZERO)
	# Clasps at the shoulders.
	for sx in [-1.0, 1.0]:
		_add(root, _ball(0.07, 6), _metal(GOLD, null), Vector3(sx * 0.3, -0.02, 0.2))
	match style:
		"royal":
			# Ermine collar and a gold hem.
			_add(root, _torus(0.22, 0.34), _mat(Color(0.97, 0.95, 0.9), outline), Vector3(0, 0.04, 0.12), Vector3.ZERO, Vector3(1.15, 1.0, 0.95))
			var hem := _cloth_mesh(0.95, 0.97, 0.09, 0.12, 0.22)
			var hem_root := Node3D.new()
			hem_root.position = Vector3(0, -long + 0.06, -0.21)
			root.add_child(hem_root)
			var gm := _metal(GOLD, null)
			gm.cull_mode = BaseMaterial3D.CULL_DISABLED
			_add(hem_root, hem, gm, Vector3.ZERO)
		"ember":
			var hem := _cloth_mesh(0.95, 1.0, 0.16, 0.12, 0.22)
			var hem_root := Node3D.new()
			hem_root.position = Vector3(0, -long + 0.1, -0.215)
			root.add_child(hem_root)
			var em := _mat(Color(1.0, 0.45, 0.1), null, 2.2)
			em.cull_mode = BaseMaterial3D.CULL_DISABLED
			_add(hem_root, hem, em, Vector3.ZERO)
			var sparks := CPUParticles3D.new()
			sparks.amount = 10
			sparks.lifetime = 1.2
			sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			sparks.emission_box_extents = Vector3(0.45, 0.05, 0.1)
			sparks.direction = Vector3.UP
			sparks.initial_velocity_min = 0.3
			sparks.initial_velocity_max = 0.6
			sparks.gravity = Vector3(0, 0.4, 0)
			sparks.scale_amount_min = 0.03
			sparks.scale_amount_max = 0.06
			sparks.mesh = _ball(0.5, 4)
			sparks.material_override = _mat(Color(1.0, 0.6, 0.15), null, 3.0)
			sparks.position = Vector3(0, -long, -0.45)
			root.add_child(sparks)
		"leaf":
			var leaf := _mat(Color(0.42, 0.75, 0.32), outline)
			for k in 7:
				var u := (k / 6.0) * 2.0 - 1.0
				var p := Vector3(u * 0.46, -long - 0.02, -0.12 * (1.0 - u * u) - 0.22)
				_add(root, _ball(0.1, 6), leaf, p, Vector3(0.3, 0, u * 0.4), Vector3(0.7, 1.4, 0.25))
			_add(root, _torus(0.2, 0.3), leaf, Vector3(0, 0.03, 0.12), Vector3.ZERO, Vector3(1.1, 0.8, 0.9))


static func _scarf(body: Node3D, cloth: Color, outline: Material) -> void:
	## A long knitted scarf: a thick wrap and two tails streaming behind.
	var mat := _mat(cloth, outline)
	var stripe := _mat(cloth.lightened(0.45), null)
	_add(body, _torus(0.24, 0.45), mat, Vector3(0, 1.18, 0.0), Vector3.ZERO, Vector3(1.0, 0.6, 0.94))
	_add(body, _torus(0.42, 0.455), stripe, Vector3(0, 1.18, 0.0), Vector3.ZERO, Vector3(1.0, 0.8, 0.94))
	for k in 2:
		var x := -0.08 + k * 0.17
		for seg in 4:
			var p := Vector3(x, 1.08 - seg * 0.16, -0.36 - seg * 0.09)
			var box := BoxMesh.new()
			box.size = Vector3(0.16, 0.2, 0.05)
			_add(body, box, stripe if seg == 3 else mat, p, Vector3(0.5 + seg * 0.08, 0.0, (k - 0.5) * 0.25))
