extends RefCounted
## Snow on the tops of Stonekeep's walls (claude-faisal/crowns-visual2
## 2026-11-04, Faisal: "the walls collect snow on their tops"). The castle
## kit records each merlon, coping and wall top it builds on the winter map
## (add); build() draws them all as two MultiMeshes (a soft lumpy cushion
## drooping over the edges), no colliders, no
## sun-shadow casting: one draw call for the whole map.

const SNOW := Color(0.93, 0.96, 1.0)


static func add(g, top_center: Vector3, size_xz: Vector2, rot_y: float) -> void:
	## A cap on a flat stone top at top_center (its top face), size_xz along
	## (x) and across (z) before rot_y.
	if g.season != "winter" or size_xz.x < 0.25 or size_xz.y < 0.2:
		return
	if not g.has_meta("snow_caps"):
		g.set_meta("snow_caps", [])
	g.get_meta("snow_caps").append([top_center, size_xz, rot_y])


static func _pillow() -> ArrayMesh:
	## A soft, lumpy snow cushion over a unit square (x, z in -0.5..0.5): flat
	## enough to sit flush on the stone, rounded and drooping a little over
	## every edge, with a few lumps so no two read as a machined slab.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 8
	var pts := []
	for j in n + 1:
		for i in n + 1:
			var u := float(i) / n - 0.5
			var v := float(j) / n - 0.5
			var edge := pow(pow(absf(u) * 2.0, 4.0) + pow(absf(v) * 2.0, 4.0), 0.25)   # rounded-square rim
			var y := (1.0 - pow(edge, 3.0)) * (0.8 + 0.2 * sin(u * 17.0 + v * 9.0) * cos(v * 13.0 - u * 5.0))
			if edge >= 1.0:
				y = -0.45                                    # the rim droops over the edge
			var pull := 1.0 / maxf(edge, 1.0)              # corners pulled in: a rounded outline
			pts.append(Vector3(u * 1.12 * pull, y, v * 1.12 * pull))
	# Smooth normals from the height grid (flat facets read as a pyramid).
	var nrms := []
	for j in n + 1:
		for i in n + 1:
			var l: Vector3 = pts[j * (n + 1) + maxi(i - 1, 0)]
			var r: Vector3 = pts[j * (n + 1) + mini(i + 1, n)]
			var dn: Vector3 = pts[maxi(j - 1, 0) * (n + 1) + i]
			var up: Vector3 = pts[mini(j + 1, n) * (n + 1) + i]
			var gx := (r.y - l.y) / maxf(r.x - l.x, 0.001) * 0.12
			var gz := (up.y - dn.y) / maxf(up.z - dn.z, 0.001) * 0.12
			nrms.append(Vector3(-gx, 1.0, -gz).normalized())
	for j in n:
		for i in n:
			var ids := [j * (n + 1) + i, j * (n + 1) + i + 1, (j + 1) * (n + 1) + i,
				j * (n + 1) + i + 1, (j + 1) * (n + 1) + i + 1, (j + 1) * (n + 1) + i]
			for k in ids:
				st.set_normal(nrms[k])
				st.add_vertex(pts[k])
	return st.commit()


static func build(g) -> void:
	if not g.has_meta("snow_caps"):
		return
	var caps: Array = g.get_meta("snow_caps")
	g.remove_meta("snow_caps")
	if caps.is_empty():
		return
	# Matte, the ground snow's own tone (the reviewers: glossy white caps read
	# as porcelain plates).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.9, 0.98)
	mat.roughness = 1.0
	mat.metallic_specular = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # (one-sided cushion, seen from above and the sides)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _pillow()
	mm.instance_count = caps.size()
	for i in caps.size():
		var c: Vector3 = caps[i][0]
		var s: Vector2 = caps[i][1]
		var h := clampf(minf(s.x, s.y) * 0.3, 0.1, 0.2)
		var yaw: float = caps[i][2] + (PI if i % 2 == 1 else 0.0)   # (lumps differ cap to cap)
		var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s.x, h, s.y))
		mm.set_instance_transform(i, Transform3D(b, c + Vector3(0, 0.01, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WallSnow"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta("no_batch", true)
	g.add_child(mmi)
