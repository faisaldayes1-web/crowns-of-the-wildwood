extends SceneTree
## Texture memory census of a running match: every texture reachable from the
## scene (materials, mesh surfaces, GUI, sub-viewports) with its size and the
## memory it takes on the GPU (mipmaps included), biggest first.
##     godot --path . --script tools/tex_census.gd -- --play --seed=7 [--map=2]

var seen := {}
var rows: Array = []


func _bpp(fmt: int) -> float:
	match fmt:
		Image.FORMAT_DXT1, Image.FORMAT_ETC2_RGB8, Image.FORMAT_ETC, Image.FORMAT_RGTC_R: return 0.5
		Image.FORMAT_DXT3, Image.FORMAT_DXT5, Image.FORMAT_BPTC_RGBA, Image.FORMAT_RGTC_RG, Image.FORMAT_ETC2_RGBA8, Image.FORMAT_ASTC_4x4: return 1.0
		Image.FORMAT_L8, Image.FORMAT_R8: return 1.0
		Image.FORMAT_LA8, Image.FORMAT_RG8: return 2.0
		Image.FORMAT_RGB8: return 4.0  # padded to RGBA on upload
		Image.FORMAT_RGBA8: return 4.0
		Image.FORMAT_RGBAH: return 8.0
		Image.FORMAT_RGBAF: return 16.0
	return 4.0


func _add(t: Texture, where: String) -> void:
	if t == null or seen.has(t):
		return
	seen[t] = true
	var w: int = t.get_width()
	var h: int = t.get_height()
	var fmt := -1
	var mips := false
	if t is Texture2D and not (t is ViewportTexture):
		var img: Image = t.get_image()
		if img:
			fmt = img.get_format()
			mips = img.has_mipmaps()
	var bytes: float = w * h * _bpp(fmt) * (1.333 if mips else 1.0)
	rows.append([bytes, "%s %dx%d fmt=%d mips=%s  %s" % [t.resource_path.get_file() if t.resource_path != "" else t.get_class(), w, h, fmt, mips, where]])


func _mat(m: Material, where: String) -> void:
	if m == null or seen.has(m):
		return
	seen[m] = true
	for p in m.get_property_list():
		var v = m.get(p.name)
		if v is Texture:
			_add(v, where)
	if m is ShaderMaterial:
		for u in RenderingServer.get_shader_parameter_list(m.shader.get_rid()) if m.shader else []:
			var v = m.get_shader_parameter(u.name)
			if v is Texture:
				_add(v, where)
	if m.next_pass:
		_mat(m.next_pass, where)


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 120:
		await process_frame
	for n in root.find_children("*", "", true, false):
		var where: String = n.get_class()
		if n is GeometryInstance3D:
			_mat(n.material_override, where)
			_mat(n.material_overlay, where)
		if n is MeshInstance3D and n.mesh:
			for s in n.mesh.get_surface_count():
				_mat(n.mesh.surface_get_material(s), where)
				_mat(n.get_surface_override_material(s), where)
		if n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			for s in n.multimesh.mesh.get_surface_count():
				_mat(n.multimesh.mesh.surface_get_material(s), where)
		if n is GPUParticles3D or n is CPUParticles3D:
			pass
		if n is CanvasItem:
			_mat(n.material, where)
			for p in ["texture", "texture_normal", "texture_pressed", "texture_hover", "icon", "texture_under", "texture_over", "texture_progress"]:
				if p in n and n.get(p) is Texture:
					_add(n.get(p), where)
		if n is SubViewport:
			rows.append([n.size.x * n.size.y * 4.0 * 2.0, "SubViewport %dx%d %s" % [n.size.x, n.size.y, n.get_path()]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var tot := 0.0
	for r in rows:
		tot += r[0]
	print("CENSUS textures=%d total %.0f MB" % [rows.size(), tot / 1048576.0])
	for r in rows.slice(0, 60):
		print("CENSUS %7.2f MB  %s" % [r[0] / 1048576.0, r[1]])
	print("CENSUS texture mem monitor %.0f MB" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0))
	quit()
