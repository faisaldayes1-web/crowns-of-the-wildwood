extends RefCounted
## Snow on the tops of Stonekeep's walls (claude-faisal/crowns-visual2
## 2026-11-04, Faisal: "the walls collect snow on their tops"). The castle
## kit records each merlon, coping and wall top it builds on the winter map
## (add); build() draws them all as two MultiMeshes (a thin slab a little
## proud of the stone and a soft rounded mound on it), no colliders, no
## sun-shadow casting: two draw calls for the whole map.

const SNOW := Color(0.93, 0.96, 1.0)


static func add(g, top_center: Vector3, size_xz: Vector2, rot_y: float) -> void:
	## A cap on a flat stone top at top_center (its top face), size_xz along
	## (x) and across (z) before rot_y.
	if g.season != "winter" or size_xz.x < 0.25 or size_xz.y < 0.2:
		return
	if not g.has_meta("snow_caps"):
		g.set_meta("snow_caps", [])
	g.get_meta("snow_caps").append([top_center, size_xz, rot_y])


static func build(g) -> void:
	if not g.has_meta("snow_caps"):
		return
	var caps: Array = g.get_meta("snow_caps")
	g.remove_meta("snow_caps")
	if caps.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW
	mat.roughness = 0.85
	mat.rim_enabled = true
	mat.rim = 0.35
	var slab := BoxMesh.new()
	slab.size = Vector3.ONE
	var mound := SphereMesh.new()
	mound.radius = 0.5
	mound.height = 1.0
	mound.radial_segments = 12
	mound.rings = 4
	var meshes := [slab, mound]
	for kind in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[kind]
		mm.instance_count = caps.size()
		for i in caps.size():
			var c: Vector3 = caps[i][0]
			var s: Vector2 = caps[i][1]
			var b := Basis(Vector3.UP, caps[i][2])
			var xf: Transform3D
			if kind == 0:
				# Slab: 6 cm thick, 4 cm proud of each face.
				xf = Transform3D(b * Basis.from_scale(Vector3(s.x + 0.08, 0.06, s.y + 0.08)), c + Vector3(0, 0.03, 0))
			else:
				# Mound: a soft dome a little inside the slab's edge.
				var h := clampf(minf(s.x, s.y) * 0.32, 0.06, 0.16)
				# (a flattened sphere centred on the slab: its upper half shows)
				xf = Transform3D(b * Basis.from_scale(Vector3(s.x * 0.96, h * 2.0, s.y * 0.9)), c + Vector3(0, 0.05, 0))
			mm.set_instance_transform(i, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "WallSnow"
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_meta("no_batch", true)
		g.add_child(mmi)
