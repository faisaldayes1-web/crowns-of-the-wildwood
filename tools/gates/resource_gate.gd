extends SceneTree
## CI gate (claude-faisal/crowns-gates 2026-11-04): nothing the game names is
## missing. Walks every scene, resource, script and shader under res://:
##   * each ext_resource a .tscn / .tres points at exists;
##   * each literal "res://..." path a script names (load, preload, art
##     tables) exists, as a file or a folder (paths built with % or + are not
##     literals and are left to the runtime checks);
##   * every .tscn and .tres loads, and every scene can be instantiated.
## The per-map runtime side (null meshes, textures, shaders in the built world
## and the menus) is in tools/gates/perf_gate.gd, which runs with a renderer.
## Run from the project root:
##   tools/tests/isolated.sh --headless --path . --script tools/gates/resource_gate.gd

const SKIP_DIRS := ["res://.godot", "res://.git", "res://server", "res://docs", "res://evidence", "res://build"]   # (build/ is where tools write their output)
const KINDS := ["tscn", "tres", "gd", "gdshader", "material", "import"]

var failures := 0
var files: Array = []
var checked_paths := 0


func fail(what: String) -> void:
	failures += 1
	print("FAIL ", what)


func _walk(dir: String) -> void:
	if dir in SKIP_DIRS:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	for sub in d.get_directories():
		_walk(dir.path_join(sub))
	for f in d.get_files():
		if f.get_extension() in KINDS:
			files.append(dir.path_join(f))


func _exists(path: String) -> bool:
	path = path.split("::")[0]
	if ResourceLoader.exists(path) or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		return true
	# An imported file may be named with its .import (the source stays out of exports).
	return FileAccess.file_exists(path + ".import")


func _init() -> void:
	_walk("res://")
	files.sort()
	var ext_re := RegEx.create_from_string("\\[ext_resource[^\\]]*path=\"(res://[^\"]+)\"")
	var lit_re := RegEx.create_from_string("\"(res://[^\"%{}+]*)\"")
	var scenes := 0
	var resources := 0
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		var ext: String = path.get_extension()
		if ext in ["tscn", "tres"]:
			for m in ext_re.search_all(text):
				checked_paths += 1
				if not _exists(m.get_string(1)):
					fail("%s: ext_resource %s is missing" % [path, m.get_string(1)])
		elif ext in ["gd", "gdshader"]:
			var ln := 0
			for line in text.split("\n"):
				ln += 1
				var code: String = line.split("#")[0] if not "\"#" in line else line
				for m in lit_re.search_all(code):
					var p := m.get_string(1)
					if p == "res://" or p.length() < 7:
						continue
					p = p.trim_suffix("/")
					var skipped := false
					for sd in SKIP_DIRS:
						if p.begins_with(sd):
							skipped = true
					if skipped:
						continue
					# A prefix that a script completes (`"res://assets/ui/icon_" + name`) is not a whole path.
					var after := code.substr(m.get_end(), 4).strip_edges()
					if after.begins_with("+") or after.begins_with("%"):
						continue
					checked_paths += 1
					if not _exists(p):
						fail("%s:%d: names %s, which is missing" % [path, ln, p])
	# Every imported asset (models, textures, sounds) still has its source and loads.
	var imported := 0
	for path in files:
		if path.get_extension() != "import":
			continue
		var src: String = path.trim_suffix(".import")
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK and cfg.get_value("remap", "importer", "") in ["skip", "keep"]:
			continue
		if not FileAccess.file_exists(src):
			fail("%s: its source %s is missing" % [path, src])
			continue
		imported += 1
		if ResourceLoader.load(src) == null:
			fail("%s does not load" % src)
	print("resource gate: %d imported assets loaded" % imported)
	for path in files:
		var ext: String = path.get_extension()
		if not ext in ["tscn", "tres"]:
			continue
		var res = ResourceLoader.load(path)
		if res == null:
			fail("%s does not load" % path)
			continue
		if res is PackedScene:
			scenes += 1
			if not res.can_instantiate():
				fail("%s cannot be instantiated" % path)
			# Every scene under scenes/ (the game's own, not imported kits) is built once.
			elif path.begins_with("res://scenes/") and path != "res://scenes/main.tscn":
				var n = res.instantiate()
				if n == null:
					fail("%s instantiates to null" % path)
				else:
					n.free()
		else:
			resources += 1
	print("resource gate: %d files, %d paths checked, %d scenes and %d resources loaded" % [files.size(), checked_paths, scenes, resources])
	print("resource gate: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
