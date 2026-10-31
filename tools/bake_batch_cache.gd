extends SceneTree
## Bakes assets/batch_cache.res (claude-faisal/stutter, 2026-10-30): the
## surface arrays scripts/static_batch.gd would otherwise read back from the
## GPU while the world is batched behind the title, i.e. the unit primitives
## and every imported model surface it merges. One map per run, merged into
## the file (the first run with --reset starts it over):
##   for m in 0 1 2 3 4; do godot --headless --path . --script tools/bake_batch_cache.gd -- --demo --map=$m [--reset]; done
## Re-run after changing or adding a model in the world;
## tools/batch_cache_test.gd fails while the bake is out of date (a stale or
## missing entry is read back in the game, so it never looks wrong).

const StaticBatch = preload("res://scripts/static_batch.gd")
const OUT := "res://assets/batch_cache.res"
const PRELOAD := "res://assets/world_preload.res"   # the files the world loads (game.gd _preload_world)


func _init() -> void:
	StaticBatch.record = {}
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	_finish.call_deferred(game)


func _finish(game) -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while not game.playing and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 3:
		await process_frame
	var arrays := {}
	if not "--reset" in OS.get_cmdline_user_args() and ResourceLoader.exists(OUT):
		var old = load(OUT)
		if old != null and old.has_meta(&"arrays"):
			arrays = old.get_meta(&"arrays")
	var added := 0
	for k in StaticBatch.record:
		if not arrays.has(k):
			added += 1
		arrays[k] = StaticBatch.record[k]
	var res := Resource.new()
	res.set_meta(&"arrays", arrays)
	var err := ResourceSaver.save(res, OUT, ResourceSaver.FLAG_COMPRESS)
	print("BAKE %d read-backs this map, %d new, %d entries; save %s" % [StaticBatch.record.size(), added, arrays.size(), error_string(err)])
	# The files the match world loads while it builds (scenes, textures,
	# shaders): game.gd starts loading them on threads behind the title.
	# (One list per map: meta "map_<Stats.MAPS index>".)
	var pre := Resource.new()
	if not "--reset" in OS.get_cmdline_user_args() and ResourceLoader.exists(PRELOAD):
		var old = load(PRELOAD)
		if old != null:
			for k in old.get_meta_list():
				pre.set_meta(k, old.get_meta(k))
	var files := {}
	for n in game.find_children("*", "", true, false):
		if n.scene_file_path != "":
			files[n.scene_file_path] = true
		if n is GeometryInstance3D:
			var mats: Array = [n.material_override, n.material_overlay]
			if n is MeshInstance3D:
				var mesh: Mesh = n.mesh if n.mesh != null else n.get_meta("batched_mesh", null)
				if mesh != null:
					_file(mesh, files)
					for i in mesh.get_surface_count():
						mats.append(n.get_surface_override_material(i) if i < n.get_surface_override_material_count() else null)
						mats.append(mesh.surface_get_material(i))
			for m in mats:
				_material_files(m, files)
	var keep := PackedStringArray()
	for f in files:
		if ResourceLoader.exists(f):
			keep.append(f)
	keep.sort()
	pre.set_meta(StringName("map_%d" % game.map_variant), keep)
	var err2 := ResourceSaver.save(pre, PRELOAD)
	print("BAKE preload map %d: %d files; save %s" % [game.map_variant, keep.size(), error_string(err2)])
	quit(0 if err == OK and err2 == OK and game.playing else 1)


func _file(r: Resource, files: Dictionary) -> void:
	if r != null and r.resource_path != "":
		files[r.resource_path.get_slice("::", 0)] = true


func _material_files(m: Material, files: Dictionary) -> void:
	if m == null:
		return
	_file(m, files)
	if m is ShaderMaterial and m.shader:
		_file(m.shader, files)
		for u in m.shader.get_shader_uniform_list():
			var v = m.get_shader_parameter(u.name)
			if v is Texture:
				_file(v, files)
	elif m is BaseMaterial3D:
		for p in m.get_property_list():
			if p.name.ends_with("_texture"):
				var v = m.get(p.name)
				if v is Texture:
					_file(v, files)
	if m.next_pass:
		_material_files(m.next_pass, files)
