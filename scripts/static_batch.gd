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


static func _arrays(mesh: Mesh, s: int, cache: Dictionary) -> Array:
	## A surface's vertex arrays. Primitive meshes rebuild theirs on the CPU;
	## ArrayMesh surfaces live on the GPU and are read back once per mesh
	## (props share theirs between every copy).
	var key := "%d|%d" % [mesh.get_instance_id(), s]
	var a: Array = cache.get(key, [])
	if a.is_empty():
		if mesh is PrimitiveMesh:
			# Equal primitives (the same box or sphere made again) share one copy.
			var pkey := _sig(mesh, cache)
			a = cache.get(pkey, [])
			if a.is_empty():
				a = _lighter(mesh).get_mesh_arrays()
				cache[pkey] = a
		else:
			a = mesh.surface_get_arrays(s)
		cache[key] = a
	return a


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
	for n in game.find_children("*", "MeshInstance3D", true, false):
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
		var b: Dictionary = buckets[key]
		var start := 0
		while start < b.items.size():
			start = _emit(holder, b, start)
			made += 1
	# Only now, with every mesh copied, do the originals let go of theirs.
	for mi in batched:
		mi.set_meta("batched_mesh", mi.mesh)
		mi.mesh = null
	var info := {"nodes": batched.size(), "skipped": skipped, "materials_in": canon_of.size(), "materials_out": canon.size(),
		"meshes_out": made, "ms": Time.get_ticks_msec() - t0}
	print("BATCH merged %d scenery meshes (%d left alone) into %d meshes; %d materials became %d; %d ms (%d ms reading meshes)" % [
		info.nodes, info.skipped, info.meshes_out, info.materials_in, info.materials_out, info.ms, t_collect])
	return info


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
