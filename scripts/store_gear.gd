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
					var tinted := Color.from_hsv(target.h, target.s * 0.75, v, p.a)
					img.set_pixel(x, y, p.lerp(tinted, 0.8))


static func skin_weapon(mat: StandardMaterial3D, look: Array) -> void:
	var col: Color = look[1]
	mat.albedo_color = mat.albedo_color * Color(col.r * 1.15, col.g * 1.15, col.b * 1.15)
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
		# The Wildwood collection: soft, rounded storybook shapes in the
		# overhaul's warm foliage and autumn ramps.
		"acorn":
			var cup := SphereMesh.new()
			cup.radius = 0.53
			cup.height = 0.6
			cup.is_hemisphere = true
			cup.radial_segments = 16
			cup.rings = 6
			_add(att, cup, _mat(Color(0.56, 0.37, 0.2), outline), Vector3(0, 0.6, 0))
			# Scaly rows of the cup.
			var scale_mat := _mat(Color(0.45, 0.28, 0.15), null)
			for row in 2:
				for k in 12:
					var a := TAU * (k + row * 0.5) / 12.0
					var rr := 0.5 - row * 0.12
					_add(att, _ball(0.08, 5), scale_mat, Vector3(cos(a) * rr, 0.66 + row * 0.16, sin(a) * rr), Vector3.ZERO, Vector3(1, 0.6, 1))
			_add(att, _cyl(0.035, 0.06, 0.22, 6), _mat(Color(0.4, 0.26, 0.14), outline), Vector3(0.04, 1.0, 0), Vector3(0, 0, -0.35))
			_add(att, _ball(0.12, 6), _mat(Color(0.48, 0.72, 0.3), outline), Vector3(0.2, 0.98, 0.05), Vector3(0, 0.4, -0.9), Vector3(1.0, 0.25, 0.55))
		"toadstool":
			var red := _mat(Color(0.86, 0.2, 0.15), outline)
			_add(att, _ball(0.62, 14), red, Vector3(0, 0.84, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
			_add(att, _cyl(0.56, 0.5, 0.06, 16), _mat(Color(0.98, 0.9, 0.76), null), Vector3(0, 0.66, 0))
			var spot := _mat(Color(1.0, 0.97, 0.9), null)
			var spots := [Vector2(0, 0.0), Vector2(0.5, 0.9), Vector2(2.1, 0.8), Vector2(3.6, 0.85), Vector2(5.0, 0.75), Vector2(1.3, 0.45), Vector2(4.2, 0.45)]
			for sp in spots:
				var ang: float = sp.x
				var lat: float = sp.y   # 0 top, 1 rim
				var dir := Vector3(cos(ang) * sin(lat * 1.35), cos(lat * 1.35), sin(ang) * sin(lat * 1.35))
				var pos := Vector3(dir.x * 0.62, 0.84 + dir.y * 0.34, dir.z * 0.62)
				_add(att, _ball(0.07 + 0.03 * (1.0 - lat), 6), spot, pos, Vector3.ZERO, Vector3(1, 0.5, 1))
		"autumn":
			# A gilded band with a ring of autumn leaves standing up.
			_add(att, _torus(0.42, 0.48), _metal(GOLD, outline), Vector3(0, 0.66, 0), Vector3(0.08, 0, 0))
			var cols := [Color(0.95, 0.45, 0.12), Color(0.85, 0.22, 0.12), Color(1.0, 0.75, 0.2)]
			for k in 11:
				var a := TAU * k / 11.0
				var p := Vector3(cos(a) * 0.47, 0.82, sin(a) * 0.47)
				_add(att, _ball(0.12, 6), _mat(cols[k % 3], outline if k % 2 == 0 else null, 0.25), p, Vector3(0, -a, 0.25), Vector3(0.3, 1.5, 0.75))
			_add(att, _ball(0.07, 8), _mat(Color(0.9, 0.2, 0.15), null, 1.0), Vector3(0, 0.7, 0.49))
		"antlers":
			var bark := _mat(Color(0.6, 0.42, 0.26), outline)
			_add(att, _torus(0.42, 0.49), bark, Vector3(0, 0.66, 0), Vector3(0.08, 0, 0))
			for sx in [-1.0, 1.0]:
				var root := Node3D.new()
				root.position = Vector3(sx * 0.36, 0.72, -0.05)
				root.rotation = Vector3(-0.15, 0, -sx * 0.45)
				att.add_child(root)
				_add(root, _cyl(0.035, 0.06, 0.6, 6), bark, Vector3(0, 0.3, 0))
				_add(root, _cyl(0.025, 0.045, 0.32, 6), bark, Vector3(sx * 0.12, 0.42, 0.02), Vector3(0, 0, -sx * 0.7))
				_add(root, _cyl(0.02, 0.04, 0.28, 6), bark, Vector3(-sx * 0.08, 0.6, 0), Vector3(0, 0, sx * 0.55))
				_add(root, _cyl(0.02, 0.035, 0.22, 6), bark, Vector3(sx * 0.02, 0.68, 0), Vector3(0.2, 0, -sx * 0.2))
				_add(root, _ball(0.1, 6), _mat(Color(0.5, 0.76, 0.3), null), Vector3(sx * 0.2, 0.55, 0.04), Vector3(0, 0, sx * 0.8), Vector3(1, 0.3, 0.6))
			for k in 3:
				_add(att, _ball(0.055, 6), _mat(Color(0.85, 0.12, 0.15), null, 0.4), Vector3(-0.12 + k * 0.12, 0.7, 0.47))
		"sovereign":
			# The legendary crown: tall gilded leaf points, a river-blue heart
			# stone and fireflies circling it.
			var gold := _metal(GOLD, outline)
			_add(att, _cyl(0.5, 0.46, 0.16, 18), gold, Vector3(0, 0.7, 0))
			for k in 8:
				var a := TAU * k / 8.0
				var tall := 1.6 if k % 2 == 0 else 1.15
				_add(att, _ball(0.12, 6), gold, Vector3(cos(a) * 0.47, 0.84 + 0.06 * tall, sin(a) * 0.47), Vector3(0, -a, 0.15), Vector3(0.35, tall, 0.8))
			_add(att, _ball(0.11, 10), _mat(Color(0.3, 0.7, 1.0), null, 2.0), Vector3(0, 0.74, 0.5))
			for sx in [-1.0, 1.0]:
				_add(att, _ball(0.06, 8), _mat(Color(0.35, 0.85, 0.4), null, 1.2), Vector3(sx * 0.36, 0.74, 0.35))
			att.add_child(_fireflies(Vector3(0, 1.0, 0), 0.6, 8))


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
		"moss": col = Color(0.32, 0.5, 0.24)
		"autumn": col = Color(0.74, 0.32, 0.12)
		"river": col = Color(0.18, 0.42, 0.82)
		"firefly": col = Color(0.08, 0.17, 0.22)
	var mat := _mat(col, outline)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var long: float = {"royal": 1.05, "firefly": 1.08, "moss": 0.72}.get(style, 0.95)
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
		"moss":
			# Soft moss tufts along the hem and round the collar.
			var greens := [Color(0.42, 0.66, 0.28), Color(0.55, 0.75, 0.3), Color(0.3, 0.52, 0.22)]
			for k in 9:
				var u := (k / 8.0) * 2.0 - 1.0
				_add(root, _ball(0.09, 6), _mat(greens[k % 3], null), _on_cloth(u, 1.0, long) + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.1, 0.8, 0.8))
			_add(root, _torus(0.2, 0.32), _mat(greens[0], outline), Vector3(0, 0.03, 0.12), Vector3.ZERO, Vector3(1.1, 0.9, 0.9))
		"autumn":
			# A hem of falling leaves in the autumn ramp.
			var cols := [Color(1.0, 0.72, 0.2), Color(0.95, 0.45, 0.12), Color(0.8, 0.2, 0.12)]
			for k in 9:
				var u := (k / 8.0) * 2.0 - 1.0
				_add(root, _ball(0.11, 6), _mat(cols[k % 3], outline if k % 2 == 0 else null), _on_cloth(u, 1.0, long) + Vector3(0, -0.04, -0.02), Vector3(0.3, 0, u * 0.6 + 0.3 * (k % 2)), Vector3(0.75, 1.3, 0.25))
			for k in 4:
				_add(root, _ball(0.08, 6), _mat(cols[(k + 1) % 3], null), _on_cloth(-0.6 + k * 0.4, 0.55 + 0.12 * (k % 2), long), Vector3(0.3, 0, k), Vector3(0.7, 1.2, 0.25))
			_add(root, _ball(0.08, 6), _mat(Color(1.0, 0.72, 0.2), null), Vector3(0, -0.02, 0.2), Vector3.ZERO, Vector3(1.2, 1.2, 0.5))
		"river":
			# A shimmering wave hem and foam flecks, like the overhaul's river.
			var hem := _cloth_mesh(0.95, 0.97, 0.12, 0.12, 0.22)
			var hem_root := Node3D.new()
			hem_root.position = Vector3(0, -long + 0.08, -0.215)
			root.add_child(hem_root)
			var wave := _mat(Color(0.45, 0.8, 1.0), null, 1.2)
			wave.cull_mode = BaseMaterial3D.CULL_DISABLED
			_add(hem_root, hem, wave, Vector3.ZERO)
			var foam := _mat(Color(0.92, 0.97, 1.0), null, 0.6)
			for k in 7:
				var u := (k / 6.0) * 2.0 - 1.0
				_add(root, _ball(0.05, 6), foam, _on_cloth(u, 0.8 - 0.06 * (k % 2), long), Vector3.ZERO, Vector3(1.4, 0.7, 0.6))
		"firefly":
			# Night cloth sewn with glowing motes, a gilded leaf clasp, and
			# fireflies drifting off it.
			var hem := _cloth_mesh(0.95, 0.97, 0.08, 0.12, 0.22)
			var hem_root := Node3D.new()
			hem_root.position = Vector3(0, -long + 0.05, -0.215)
			root.add_child(hem_root)
			var gm := _metal(GOLD, null)
			gm.cull_mode = BaseMaterial3D.CULL_DISABLED
			_add(hem_root, hem, gm, Vector3.ZERO)
			var glow := _mat(Color(0.8, 1.0, 0.45), null, 2.5)
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for k in 16:
				_add(root, _ball(0.028 + rng.randf() * 0.02, 5), glow, _on_cloth(rng.randf_range(-0.85, 0.85), rng.randf_range(0.12, 0.88), long))
			_add(root, _ball(0.1, 6), _metal(GOLD, outline), Vector3(0, -0.02, 0.2), Vector3(0, 0, 0.6), Vector3(1.4, 0.7, 0.4))
			var ff := _fireflies(Vector3(0, -long * 0.5, -0.4), 0.55, 10)
			root.add_child(ff)
		"leaf":
			var leaf := _mat(Color(0.42, 0.75, 0.32), outline)
			for k in 7:
				var u := (k / 6.0) * 2.0 - 1.0
				var p := Vector3(u * 0.46, -long - 0.02, -0.12 * (1.0 - u * u) - 0.22)
				_add(root, _ball(0.1, 6), leaf, p, Vector3(0.3, 0, u * 0.4), Vector3(0.7, 1.4, 0.25))
			_add(root, _torus(0.2, 0.3), leaf, Vector3(0, 0.03, 0.12), Vector3.ZERO, Vector3(1.1, 0.8, 0.9))


static func _on_cloth(u: float, v: float, long: float) -> Vector3:
	## A point just outside the cape sheet (_cloth_mesh(0.62, 0.95, long, 0.12,
	## 0.22)): u -1..1 across, v 0 (collar) .. 1 (hem).
	var w := lerpf(0.62, 0.95, v)
	return Vector3(u * w / 2.0, -long * v, -0.12 * (1.0 - u * u) - 0.22 * v * v - 0.03)


static func _fireflies(pos: Vector3, radius: float, n: int) -> CPUParticles3D:
	## Warm green-gold fireflies drifting round a point (Legendary Wildwood gear).
	var p := CPUParticles3D.new()
	p.name = "Fireflies"
	p.amount = n
	p.lifetime = 2.4
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, 0.08, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(0.6, 0.5))
	fade.add_point(Vector2(0.8, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = fade
	p.mesh = _ball(0.04, 5)
	p.material_override = _mat(Color(0.85, 1.0, 0.45), null, 3.0)
	return p


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


# --- Rarity auras -------------------------------------------------------------
# Epic and Legendary items sparkle when worn, in the menus and in a match, so
# the expensive ones read as special at a glance: violet motes for Epic, gold
# for Legendary (more of them, bigger, with a slow twinkle). Hats sparkle round
# the head, capes and armour round the back and chest, weapon skins round the
# sword hand. CPUParticles3D, a dozen or two each, so the web build keeps up.

const AURA := {"epic": [Color(0.82, 0.55, 1.0), 10, 0.32], "legendary": [Color(1.0, 0.8, 0.25), 24, 0.45]}


static func tier(kind: String, i: int) -> String:
	## The item's rarity ("" when it is free).
	for it in Stats.STORE_ITEMS:
		if it[0] == kind and it[1] == i:
			return it[2]
	return ""


static func worn_tiers(custom: Dictionary) -> Array:
	## [[kind, rarity], ...] for the Epic and Legendary items in `custom`.
	var out: Array = []
	for kind in ["hat", "cape", "outfit", "weapon"]:
		if not custom.has(kind):
			continue
		var i := -1
		var v = custom[kind]
		if v is int:
			i = v
		else:
			var table: Array = Stats.HERO_HATS if kind == "hat" else Stats.HERO_CAPES
			for n in table.size():
				if table[n][1] == v:
					i = n
		var t := tier(kind, i)
		if AURA.has(t):
			out.append([kind, t])
	return out


static func aura(skeleton: Skeleton3D, custom: Dictionary, bare: bool) -> void:
	if skeleton == null:
		return
	for w in worn_tiers(custom):
		var kind: String = w[0]
		if kind == "hat" and not bare:
			continue   # a class hat covers it
		var spot: Array = {"hat": ["head", Vector3(0, 0.75, 0), 0.45], "cape": ["chest", Vector3(0, 0.1, -0.35), 0.45],
			"outfit": ["chest", Vector3(0, 0.0, 0), 0.5], "weapon": ["handslot.r", Vector3.ZERO, 0.35]}[kind]
		if skeleton.find_bone(spot[0]) < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = spot[0]
		skeleton.add_child(att)
		att.add_child(_motes(AURA[w[1]], spot[1], spot[2], w[1] == "legendary"))


static func _motes(look: Array, offset: Vector3, radius: float, big: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "RarityAura"
	p.amount = int(look[1])
	p.lifetime = 1.6
	p.position = offset
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6 if big else 1.1
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.25, 1.0))
	fade.add_point(Vector2(0.7, 0.8))
	fade.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(look[2])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _spark_texture()
	mat.no_depth_test = false
	quad.material = mat
	p.mesh = quad
	var col: Color = look[0]
	var grad := Gradient.new()
	grad.set_color(0, Color(col.lightened(0.55), 1.0))
	grad.set_color(1, Color(col, 0.0))
	grad.add_point(0.35, Color(col.lightened(0.3), 0.9))
	p.color_ramp = grad
	return p


static var _spark: Texture2D


static func _spark_texture() -> Texture2D:
	## A soft four-point star, made once.
	if _spark:
		return _spark
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0) / (n / 2.0)
			var core := clampf(1.0 - d.length() * 1.6, 0.0, 1.0)
			var rays := clampf(1.0 - absf(d.x) * 9.0, 0.0, 1.0) * clampf(1.0 - absf(d.y), 0.0, 1.0) \
				+ clampf(1.0 - absf(d.y) * 9.0, 0.0, 1.0) * clampf(1.0 - absf(d.x), 0.0, 1.0)
			var a := clampf(core + rays * 0.8, 0.0, 1.0)
			# A dim, darker halo round the star so it still reads on pale stone.
			var halo := clampf(1.0 - d.length() * 1.15, 0.0, 1.0) * 0.55
			var v := lerpf(0.3, 1.0, a)
			img.set_pixel(x, y, Color(v, v, v, maxf(a, halo)))
	_spark = ImageTexture.create_from_image(img)
	return _spark
