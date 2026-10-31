extends RefCounted
## Static batching for the match world (claude-faisallaptop, 2026-10-16 lag pass).
##
## The world is built from ~8,800 separate scenery meshes (every block,
## cylinder, plank and prop is its own mesh with its own material copy), and
## each is a draw call in the main pass plus one per sun-shadow cascade it
## touches: ~9,800 draws a frame, which kept the CPU at 14+ ms a frame on an
## RTX 5080 while the GPU idled at 3 ms. This pass merges the scenery that
## never moves into one mesh per (material, map cell):
##   1. Identical materials (same class and every stored property, textures
##      by identity) collapse to one.
##   2. Every static MeshInstance3D surface is appended, in world space, to the
##      bucket for its material, vertex format, shadow mode, layers and
##      CELL x CELL metre map cell (so frustum and shadow culling still work).
##   3. The original node keeps its place, children and collider but loses its
##      mesh (the old one is kept in meta "batched_mesh").
## Left alone: anything under a script (units, gates, monarchs, turrets,
## resource nodes...), anything under a node with meta "no_batch" (clouds,
## water wheels, the fortify barrier), materials with meta "no_batch" (ones
## the game recolours live, e.g. Ember Pass's Fire Objective ring), skinned or morphing meshes, mirrored
## transforms, see-through materials and overlays, and shader materials that
## use their object space (only the world-space lava and leaves merge).
## "--no-batch" turns it off for A/B tests.

const CELL := 24.0
const MAX_VERTS := 200000   # a bucket this big starts a new mesh

# Shader materials that only read world-space positions (MODEL_MATRIX * VERTEX),
# so merging into one world-space mesh draws them the same. The leaves also
# need world_gradient on (their local-height gradient would change).
# (Water and waterfalls are see-through, so they stay separate for sorting.)
const WORLD_SPACE_SHADERS := ["res://assets/shaders/lava.gdshader"]
const LEAF_SHADERS := ["res://assets/shaders/leaf.gdshader", "res://assets/shaders/leaf_soft.gdshader"]


static func _skip_subtree(n: Node, top: Node) -> bool:
	var p := n
	while p and p != top:
		if p.get_script() != null or p.has_meta("no_batch"):
			return true
		p = p.get_parent()
	return false


static func _mergeable_material(m: Material) -> bool:
	if m == null or m.has_meta("no_batch"):   # a material the game changes later
		return false
	if m is BaseMaterial3D:
		if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and m.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			return false
		if m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or m.grow or m.use_point_size:
			return false
		if m.uv1_triplanar and not m.uv1_world_triplanar:
			return false
		if m.uv2_triplanar and not m.uv2_world_triplanar:
			return false
		return true
	if m is ShaderMaterial and m.shader:
		var path: String = m.shader.resource_path
		if path in WORLD_SPACE_SHADERS:
			return true
		if path in LEAF_SHADERS:
			return m.get_shader_parameter("world_gradient") == true
	return false


static func _props(o: Object, cache: Dictionary) -> Array:
	## The stored property names of o's class (asked once per class).
	var key := "_props|" + o.get_class() + ("|" + str(o.shader.get_instance_id()) if o is ShaderMaterial else "")
	var names: Array = cache.get(key, [])
	if names.is_empty():
		for p in o.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and not p.name in ["resource_name", "resource_path", "resource_local_to_scene", "material"]:
				names.append(p.name)
		cache[key] = names
	return names


static func _sig(o: Object, cache: Dictionary) -> String:
	## Every stored property of a material or primitive mesh (resources by
	## identity), so equal ones can share.
	var parts := PackedStringArray([o.get_class()])
	if o is ShaderMaterial:
		parts.append(str(o.shader.get_instance_id()))
	for name in _props(o, cache):
		var v = o.get(name)
		parts.append(str(v.get_instance_id()) if v is Object else str(v))
	return "|".join(parts)


# claude-faisal/stutter 2026-10-30: every surface_get_arrays /
# get_mesh_arrays is a GPU read-back that stalls the renderer until the GPU
# is idle (1-4 ms each on an RTX 4090, far more on an integrated GPU), and
# behind the title each one was a dropped frame. run() now reads none in a
# normal game: primitives are worked out on the CPU from a unit shape, and
# the unit shapes and the imported models' surfaces come from
# BAKED (tools/bake_batch_cache.gd), the read-backs saved at build time.
# Anything not in it (a model changed since the bake) is still read back, so
# the output never changes. readbacks counts them (tools/title_stutter_probe.gd).
const BAKED := "res://assets/batch_cache.res"
static var readbacks := 0
static var readback_usec := 0
static var readback_kinds := {}   # mesh class (and file, for imported ones) -> read-backs
static var record = null   # tools/bake_batch_cache.gd: a Dictionary collecting every keyed read-back
static var _baked = null   # BAKED's arrays (key -> surface arrays), loaded once
static var verify_misses = null   # tools/batch_cache_test.gd: an Array of keys whose baked arrays differ from the read-back


static func load_baked() -> void:
	## Starts loading BAKED on a thread (game.gd, when the world starts
	## building behind the title); _baked_arrays() picks it up.
	if _baked == null and record == null and ResourceLoader.exists(BAKED):
		ResourceLoader.load_threaded_request(BAKED)


static func _baked_arrays(key: String) -> Array:
	if record != null:   # baking: read everything back
		return []
	if _baked == null:
		_baked = {}
		if ResourceLoader.exists(BAKED):
			if ResourceLoader.load_threaded_get_status(BAKED) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_request(BAKED)
			var res = ResourceLoader.load_threaded_get(BAKED)
			if res != null and res.has_meta(&"arrays"):
				_baked = res.get_meta(&"arrays")
	return _baked.get(key, [])


static func _read_back(mesh: Mesh, s: int, key := "") -> Array:
	if key != "":
		var b := _baked_arrays(key)
		# (An imported model's entry must still fit it: same vertex and index counts.)
		if not b.is_empty() and (mesh is PrimitiveMesh or (
				(b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == mesh.surface_get_array_len(s)
				and (0 if b[Mesh.ARRAY_INDEX] == null else (b[Mesh.ARRAY_INDEX] as PackedInt32Array).size()) == mesh.surface_get_array_index_len(s))):
			if verify_misses != null:
				var fresh: Array = (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(s)
				for i in Mesh.ARRAY_MAX:
					if fresh[i] != b[i]:
						verify_misses.append("%s (array %d)" % [key, i])
						break
			return b
	var t := Time.get_ticks_usec()
	var a: Array = (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(s)
	readbacks += 1
	var kind := mesh.get_class() + (" " + mesh.resource_path.get_file().get_slice("::", 0) if mesh.resource_path != "" else "")
	readback_kinds[kind] = readback_kinds.get(kind, 0) + 1
	readback_usec += Time.get_ticks_usec() - t
	if record != null and key != "":
		record[key] = a
	return a


static func _arrays(mesh: Mesh, s: int, cache: Dictionary) -> Array:
	## A surface's vertex arrays, read once per mesh (props share theirs
	## between every copy). Generated meshes keep a CPU copy (kept_mesh),
	## primitives are worked out from a unit shape (_scaled_primitive) and
	## imported models' surfaces come from BAKED.
	var key := "%d|%d" % [mesh.get_instance_id(), s]
	var a: Array = cache.get(key, [])
	if a.is_empty():
		if mesh is PrimitiveMesh:
			# Equal primitives (the same box or sphere made again) share one copy.
			var pkey := _sig(mesh, cache)
			a = cache.get(pkey, [])
			if a.is_empty():
				a = _scaled_primitive(mesh)
				if a.is_empty():
					a = _read_back(_lighter(mesh), 0)
				cache[pkey] = a
		elif s == 0 and mesh.has_meta(&"batch_arrays"):
			a = mesh.get_meta(&"batch_arrays")   # kept_mesh: no GPU read-back
		else:
			a = _read_back(mesh, s, "res|%s|%d" % [mesh.resource_path, s] if mesh.resource_path != "" else "")
		cache[key] = a
	return a


static var _unit_shapes := {}   # grid key -> the arrays of a unit primitive


static func _unit_shape(key: String, make: Callable) -> Array:
	## (A new primitive is a renderer mesh and a queued build: made only once,
	## and only when BAKED does not have it.)
	var a: Array = _unit_shapes.get(key, [])
	if a.is_empty():
		a = _baked_arrays("unit|" + key)
		if a.is_empty():
			a = _read_back(make.call(), 0, "unit|" + key)
		_unit_shapes[key] = a
	return a


static func kept_mesh(st: SurfaceTool) -> ArrayMesh:
	## st's mesh, keeping a CPU copy of its arrays for run(), which otherwise
	## reads every generated mesh back from the GPU at match start (~1 ms
	## each). run() drops the copy once it has merged the mesh.
	var arrays := st.commit_to_arrays()
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.set_meta(&"batch_arrays", arrays)
	return m


static func _scaled_primitive(mesh: PrimitiveMesh) -> Array:
	## claude-faisal3 2026-10-29 loading pass: ~1,500 unique boxes and
	## cylinders were read back from the GPU at match start (~0.4 ms each).
	## A box is its unit box scaled; a cylinder is its unit cylinder with each
	## ring moved to its height and radius and the side normals recomputed as
	## Godot makes them (scene/resources/3d/primitive_meshes.cpp, 4.3). Index,
	## UV and tangent arrays are the unit shape's. tools/batch_primitive_test.gd
	## checks them against the read-back. [] = not one of these: read it back.
	if mesh.flip_faces or mesh.add_uv2:
		return []
	if mesh is BoxMesh:
		var b: BoxMesh = mesh
		var t := _unit_shape("box|%d|%d|%d" % [b.subdivide_width, b.subdivide_height, b.subdivide_depth], func() -> PrimitiveMesh:
			var unit := BoxMesh.new()
			unit.subdivide_width = b.subdivide_width
			unit.subdivide_height = b.subdivide_height
			unit.subdivide_depth = b.subdivide_depth
			return unit)
		if t.is_empty():
			return []
		var out := t.duplicate()
		out[Mesh.ARRAY_VERTEX] = Transform3D(Basis.from_scale(b.size), Vector3.ZERO) * (t[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		return out
	if mesh is CylinderMesh:
		var c: CylinderMesh = mesh
		if c.height <= 0.0:
			return []
		var segs := c.radial_segments
		var rings := c.rings
		if segs >= 48:   # as _lighter
			segs = clampi(int(12.0 + maxf(c.top_radius, c.bottom_radius) * 16.0), 12, 32)
			rings = mini(rings, 1)
		var top_cap := c.cap_top and c.top_radius > 0.0
		var bottom_cap := c.cap_bottom and c.bottom_radius > 0.0
		var t := _unit_shape("cyl|%d|%d|%s|%s" % [segs, rings, top_cap, bottom_cap], func() -> PrimitiveMesh:
			var unit := CylinderMesh.new()
			unit.top_radius = 1.0
			unit.bottom_radius = 1.0
			unit.height = 1.0
			unit.radial_segments = segs
			unit.rings = rings
			unit.cap_top = top_cap
			unit.cap_bottom = bottom_cap
			return unit)
		if t.is_empty():
			return []
		var tv: PackedVector3Array = t[Mesh.ARRAY_VERTEX]
		var tn: PackedVector3Array = t[Mesh.ARRAY_NORMAL]
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		verts.resize(tv.size())
		normals.resize(tv.size())
		var h := c.height
		var side_y := (c.bottom_radius - c.top_radius) / h
		for i in tv.size():
			var p := tv[i]
			if absf(tn[i].y) < 0.5:   # the side: ring v from the unit height
				var v := 0.5 - p.y
				var r := c.top_radius + (c.bottom_radius - c.top_radius) * v
				verts[i] = Vector3(p.x * r, h * 0.5 - h * v, p.z * r)
				normals[i] = Vector3(p.x, side_y, p.z).normalized()
			elif tn[i].y > 0.0:   # the top cap
				verts[i] = Vector3(p.x * c.top_radius, h * 0.5, p.z * c.top_radius)
				normals[i] = tn[i]
			else:
				verts[i] = Vector3(p.x * c.bottom_radius, h * -0.5, p.z * c.bottom_radius)
				normals[i] = tn[i]
		var out := t.duplicate()
		out[Mesh.ARRAY_VERTEX] = verts
		out[Mesh.ARRAY_NORMAL] = normals
		return out
	# claude-faisal/stutter 2026-10-30: spheres, prisms, planes and quads are
	# their unit shape stretched along the axes (Godot builds each vertex as
	# a per-axis multiple of its size, primitive_meshes.cpp, 4.3), so their
	# normals are the unit's divided by the stretch, renormalised; tori keep
	# their unit's normals, UVs and tangents and only move each ring.
	if mesh is SphereMesh:
		var sp: SphereMesh = _lighter(mesh)
		if sp.radius <= 0.0 or sp.height <= 0.0:
			return []
		var hemi := sp.is_hemisphere
		var t := _unit_shape("sph|%d|%d|%s" % [sp.radial_segments, sp.rings, hemi], func() -> PrimitiveMesh:
			var unit := SphereMesh.new()
			unit.radius = 1.0
			unit.height = 1.0 if hemi else 2.0
			unit.radial_segments = sp.radial_segments
			unit.rings = sp.rings
			unit.is_hemisphere = hemi
			return unit)
		return _stretched(t, Vector3(sp.radius, sp.height * (1.0 if hemi else 0.5), sp.radius), Vector3.ZERO)
	if mesh is PrismMesh:
		var pr: PrismMesh = mesh
		if pr.size.x <= 0.0 or pr.size.y <= 0.0 or pr.size.z <= 0.0:
			return []
		var t := _unit_shape("prism|%s|%d|%d|%d" % [pr.left_to_right, pr.subdivide_width, pr.subdivide_height, pr.subdivide_depth], func() -> PrimitiveMesh:
			var unit := PrismMesh.new()
			unit.size = Vector3.ONE
			unit.left_to_right = pr.left_to_right
			unit.subdivide_width = pr.subdivide_width
			unit.subdivide_height = pr.subdivide_height
			unit.subdivide_depth = pr.subdivide_depth
			return unit)
		return _stretched(t, pr.size, Vector3.ZERO)
	if mesh is PlaneMesh:   # (QuadMesh is a PlaneMesh facing +Z)
		var pl: PlaneMesh = mesh
		if pl.size.x <= 0.0 or pl.size.y <= 0.0:
			return []
		var orient := pl.orientation
		var t := _unit_shape("plane|%s|%d|%d|%d" % [mesh.get_class(), orient, pl.subdivide_width, pl.subdivide_depth], func() -> PrimitiveMesh:
			var unit: PlaneMesh = QuadMesh.new() if mesh is QuadMesh else PlaneMesh.new()
			unit.size = Vector2.ONE
			unit.orientation = orient
			unit.subdivide_width = pl.subdivide_width
			unit.subdivide_depth = pl.subdivide_depth
			return unit)
		var st := Vector3(pl.size.x, 1.0, pl.size.y)   # FACE_Y: x across, z down the size
		if orient == PlaneMesh.FACE_Z:
			st = Vector3(pl.size.x, pl.size.y, 1.0)
		elif orient == PlaneMesh.FACE_X:
			st = Vector3(1.0, pl.size.y, pl.size.x)
		return _stretched(t, st, pl.center_offset)
	if mesh is TorusMesh:
		var to: TorusMesh = _lighter(mesh)
		var lo := minf(to.inner_radius, to.outer_radius)
		var hi := maxf(to.inner_radius, to.outer_radius)
		if lo <= 0.0 or hi - lo <= 0.0:
			return []
		var t := _unit_shape("torus|%d|%d" % [to.rings, to.ring_segments], func() -> PrimitiveMesh:
			var unit := TorusMesh.new()
			unit.inner_radius = 0.5
			unit.outer_radius = 1.0
			unit.rings = to.rings
			unit.ring_segments = to.ring_segments
			return unit)
		if t.is_empty():
			return []
		var tv: PackedVector3Array = t[Mesh.ARRAY_VERTEX]
		var tn: PackedVector3Array = t[Mesh.ARRAY_NORMAL]
		var verts := PackedVector3Array()
		verts.resize(tv.size())
		var radius := (hi - lo) * 0.5
		var centre := lo + radius
		for i in tv.size():
			# The ring's direction from the unit vertex, its angle from the normal.
			var d := Vector2(tv[i].x, tv[i].z).normalized()
			var n := tn[i]
			var r := centre + (n.x * d.x + n.z * d.y) * radius
			verts[i] = Vector3(d.x * r, n.y * radius, d.y * r)
		var out := t.duplicate()
		out[Mesh.ARRAY_VERTEX] = verts
		return out
	return []


static func _stretched(t: Array, stretch: Vector3, offset: Vector3) -> Array:
	## Unit arrays t stretched per axis and moved: normals divided by the
	## stretch and renormalised, tangents multiplied by it (UVs as they are).
	if t.is_empty():
		return []
	var out := t.duplicate()
	out[Mesh.ARRAY_VERTEX] = Transform3D(Basis.from_scale(stretch), offset) * (t[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var inv := Vector3(1.0 / stretch.x, 1.0 / stretch.y, 1.0 / stretch.z)
	var tn: PackedVector3Array = t[Mesh.ARRAY_NORMAL]
	var normals := PackedVector3Array()
	normals.resize(tn.size())
	for i in tn.size():
		normals[i] = (tn[i] * inv).normalized()
	out[Mesh.ARRAY_NORMAL] = normals
	if t[Mesh.ARRAY_TANGENT] != null:
		var tt: PackedFloat32Array = t[Mesh.ARRAY_TANGENT]
		var tangents := tt.duplicate()
		for k in range(0, tt.size(), 4):
			var v := (Vector3(tt[k], tt[k + 1], tt[k + 2]) * stretch).normalized()
			tangents[k] = v.x
			tangents[k + 1] = v.y
			tangents[k + 2] = v.z
		out[Mesh.ARRAY_TANGENT] = tangents
	return out


static func _lighter(mesh: PrimitiveMesh) -> PrimitiveMesh:
	## Spheres, cylinders and rings left at Godot's default 64 segments (a
	## 64x32 sphere is 4,096 triangles: 248 of them were half the world's
	## triangles, drawn again in every shadow cascade and split-screen pane)
	## are rebuilt with a segment count for their size. Explicitly lighter
	## ones are kept as they are.
	if mesh is SphereMesh and mesh.radial_segments >= 48:
		var m: SphereMesh = mesh.duplicate()
		m.radial_segments = clampi(int(16.0 + mesh.radius * 16.0), 16, 32)
		m.rings = m.radial_segments / 2
		return m
	if mesh is CylinderMesh and mesh.radial_segments >= 48:
		var m: CylinderMesh = mesh.duplicate()
		m.radial_segments = clampi(int(12.0 + maxf(mesh.top_radius, mesh.bottom_radius) * 16.0), 12, 32)
		m.rings = mini(mesh.rings, 1)
		return m
	if mesh is TorusMesh and mesh.rings >= 48:
		var m: TorusMesh = mesh.duplicate()
		m.rings = 32
		m.ring_segments = mini(mesh.ring_segments, 12)
		return m
	return mesh


static func run(game: Node3D) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var canon := {}       # material sig -> the one material kept
	var canon_of := {}    # material instance id -> canonical material
	var buckets := {}     # key -> {mat, items: [[arrays, xform, verts]], shadow, layers, gi}
	var cache := {}
	var batched: Array[MeshInstance3D] = []
	var skipped := 0
	var seen := 0
	for n in game.find_children("*", "MeshInstance3D", true, false):
		seen += 1
		if seen % 4 == 0:
			# (Built behind the title, the batch waits a frame between slices
			# so the menus stay smooth; at a match start this never waits.
			# Checked every 4 meshes: every 64 let a slice run 85-130 ms on
			# the read-backs, the title's worst hitches. The check itself
			# costs nothing until the slice is used up.)
			await _slice(game)
		if not is_instance_valid(n):   # freed by the live menus while the batch waited
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.skin != null or mi.material_overlay != null:
			continue
		if mi.transparency > 0.0 or mi.visibility_range_end > 0.0 or mi.visibility_range_begin > 0.0:
			skipped += 1
			continue
		if (mi.mesh is ArrayMesh and mi.mesh.get_blend_shape_count() > 0) or _skip_subtree(mi, game):
			skipped += 1
			continue
		var xf := mi.global_transform
		if xf.basis.determinant() <= 0.0:
			skipped += 1
			continue
		var surfaces := []
		var ok := true
		for s in mi.mesh.get_surface_count():
			if mi.mesh is ArrayMesh and mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				ok = false
				break
			var m: Material = mi.get_active_material(s)
			if not _mergeable_material(m):
				ok = false
				break
			var arrays := _arrays(mi.mesh, s, cache)
			if arrays[Mesh.ARRAY_BONES] != null or arrays[Mesh.ARRAY_CUSTOM0] != null:
				ok = false
				break
			var fmt := 0
			for a in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
				if arrays[a] != null:
					fmt |= 1 << a
			surfaces.append([m, arrays, fmt])
		if not ok or surfaces.is_empty():
			skipped += 1
			continue
		var center := xf * mi.mesh.get_aabb().get_center()
		var cell := Vector2i(floori(center.x / CELL), floori(center.z / CELL))
		for sf in surfaces:
			var m: Material = sf[0]
			var cm: Material = canon_of.get(m.get_instance_id())
			if cm == null:
				var sig := _sig(m, cache)
				cm = canon.get(sig)
				if cm == null:
					cm = m
					canon[sig] = m
				canon_of[m.get_instance_id()] = cm
			var key := "%d|%d|%d|%d|%d|%d" % [cm.get_instance_id(), sf[2], mi.cast_shadow, mi.layers, cell.x, cell.y]
			var b: Dictionary = buckets.get(key, {})
			if b.is_empty():
				b = {"mat": cm, "fmt": sf[2], "items": [], "shadow": mi.cast_shadow, "layers": mi.layers, "gi": mi.gi_mode}
				buckets[key] = b
			b.items.append([sf[1], xf])
		batched.append(mi)
	var t_collect := Time.get_ticks_msec() - t0
	var holder := Node3D.new()
	holder.name = "StaticBatch"
	holder.set_meta("no_batch", true)
	game.add_child(holder)
	var made := 0
	for key in buckets:
		await _slice(game)
		var b: Dictionary = buckets[key]
		var start := 0
		while start < b.items.size():
			start = _emit(holder, b, start)
			made += 1
	# Only now, with every mesh copied, do the originals let go of theirs.
	# (Behind the title, 256 a frame: all 8,500 at once was a 55 ms frame.)
	for k in batched.size():
		if k % 256 == 255:
			await _slice(game)
		var mi = batched[k]
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		mi.mesh.remove_meta(&"batch_arrays")   # merged: free the CPU copy
		mi.set_meta("batched_mesh", mi.mesh)
		mi.mesh = null
	var info := {"nodes": batched.size(), "skipped": skipped, "materials_in": canon_of.size(), "materials_out": canon.size(),
		"meshes_out": made, "ms": Time.get_ticks_msec() - t0}
	print("BATCH merged %d scenery meshes (%d left alone) into %d meshes; %d materials became %d; %d ms (%d ms reading meshes)" % [
		info.nodes, info.skipped, info.meshes_out, info.materials_in, info.materials_out, info.ms, t_collect])
	print("BATCH read-backs %d (%d ms)" % [readbacks, readback_usec / 1000])
	return info


static func _slice(game: Node) -> void:
	if game.has_method("_world_build_frame"):   # (the title diorama batches itself too)
		await game._world_build_frame()


static func _emit(holder: Node3D, b: Dictionary, start: int) -> int:
	## One world-space mesh from b.items[start...], up to MAX_VERTS vertices;
	## returns the first item it did not take.
	var fmt: int = b.fmt
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var i := start
	while i < b.items.size():
		var arrays: Array = b.items[i][0]
		var xf: Transform3D = b.items[i][1]
		var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if i > start and verts.size() + src.size() > MAX_VERTS:
			break
		var base := verts.size()
		verts.append_array(xf * src)
		var nb := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
		if fmt & (1 << Mesh.ARRAY_NORMAL):
			normals.append_array(nb * (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array))
		if fmt & (1 << Mesh.ARRAY_TANGENT):
			var t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var at := tangents.size()
			tangents.append_array(t)
			for k in range(0, t.size(), 4):
				var v := (xf.basis * Vector3(t[k], t[k + 1], t[k + 2])).normalized()
				tangents[at + k] = v.x
				tangents[at + k + 1] = v.y
				tangents[at + k + 2] = v.z
		if fmt & (1 << Mesh.ARRAY_COLOR):
			colors.append_array(arrays[Mesh.ARRAY_COLOR])
		if fmt & (1 << Mesh.ARRAY_TEX_UV):
			uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		if fmt & (1 << Mesh.ARRAY_TEX_UV2):
			uv2s.append_array(arrays[Mesh.ARRAY_TEX_UV2])
		var idx = arrays[Mesh.ARRAY_INDEX]
		var at_i := indices.size()
		if idx == null:
			indices.resize(at_i + src.size())
			for k in src.size():
				indices[at_i + k] = base + k
		else:
			var ii: PackedInt32Array = idx
			indices.append_array(ii)
			if base > 0:
				for k in ii.size():
					indices[at_i + k] += base
		i += 1
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_INDEX] = indices
	if fmt & (1 << Mesh.ARRAY_NORMAL):
		out[Mesh.ARRAY_NORMAL] = normals
	if fmt & (1 << Mesh.ARRAY_TANGENT):
		out[Mesh.ARRAY_TANGENT] = tangents
	if fmt & (1 << Mesh.ARRAY_COLOR):
		out[Mesh.ARRAY_COLOR] = colors
	if fmt & (1 << Mesh.ARRAY_TEX_UV):
		out[Mesh.ARRAY_TEX_UV] = uvs
	if fmt & (1 << Mesh.ARRAY_TEX_UV2):
		out[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	mesh.surface_set_material(0, b.mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = b.shadow
	mi.layers = b.layers
	mi.gi_mode = b.gi
	holder.add_child(mi)
	return i


static func particles_to_gpu(game: Node3D) -> int:
	## The world's ambient particle systems (fireflies, chimney and campfire
	## smoke, embers, falling leaves) ran on the CPU: ~70 of them were ~2 ms
	## of the main thread a frame. The long-lived ones become GPU particles
	## (GPUParticles3D.convert_from_particles keeps every setting). One-shot
	## bursts and anything on a unit or other scripted thing stay as they
	## are. Forward+ only; the web's Compatibility renderer keeps the CPU
	## ones. Returns how many it converted.
	if RenderingServer.get_rendering_device() == null or DisplayServer.get_name() == "headless":
		return 0
	var done := 0
	for n in game.find_children("*", "CPUParticles3D", true, false):
		# (Behind the title, a few a frame: each new GPU particle material is
		# a shader to build; at a match start this never waits.)
		await _slice(game)
		if not is_instance_valid(n):
			continue
		var cp := n as CPUParticles3D
		if cp.one_shot or not cp.emitting or _skip_subtree(cp, game):
			continue
		var gp := GPUParticles3D.new()
		gp.convert_from_particles(cp)
		gp.name = cp.name
		gp.transform = cp.transform
		gp.visible = cp.visible
		gp.cast_shadow = cp.cast_shadow
		gp.layers = cp.layers
		# Culling box: where the CPU one's particles are now, with room to drift.
		var box: AABB = cp.get_aabb()
		gp.visibility_aabb = box.grow(3.0) if box.size.length() > 0.01 else AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
		var parent := cp.get_parent()
		parent.add_child(gp)
		parent.move_child(gp, cp.get_index())
		gp.restart()
		if gp.preprocess <= 0.0:
			gp.preprocess = gp.lifetime   # start full, as the CPU one already was
		parent.remove_child(cp)
		cp.queue_free()
		done += 1
	return done
