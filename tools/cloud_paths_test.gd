extends SceneTree
## Steam Cloud readiness: the user dir is the one docs/steam.md gives Auto-Cloud
## (Godot/app_userdata/<project name>), a save leaves only controls.cfg and
## profiles/<id>.cfg (plus their .bak / .tmp siblings), and nothing is written
## outside user://. Run:
##     tools/tests/isolated.sh --headless --path . --script tools/cloud_paths_test.gd
## Runs only in a throwaway user dir. Agent: claude-faisal3 2026-11-04.

const Isolated = preload("res://tools/tests/isolated.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func files_under(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(files_under(dir.path_join(sub)))
	return out


func _init() -> void:
	if not Isolated.ok("tools/cloud_paths_test.gd"):
		quit(2)
		return
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 400:
		if g.main_menu and not g.get("menus_warming"):
			break
		await process_frame
	g._save_controls()
	var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	var project_name: String = ProjectSettings.get_setting("application/config/name")
	check(user_dir.to_lower().ends_with(("app_userdata/" + project_name).to_lower()), "user dir ends in app_userdata/%s (%s)" % [project_name, user_dir])
	var docs := FileAccess.get_file_as_string("res://docs/steam.md")
	check(docs.contains("Godot/app_userdata/" + project_name), "docs/steam.md names that Auto-Cloud subdirectory")
	check(not ProjectSettings.get_setting("application/config/use_custom_user_dir", false), "no custom user dir (it would move the Auto-Cloud path)")
	var files := files_under("user://")
	check(files.has("user://controls.cfg"), "controls.cfg is written at the user dir root")
	var stray := files.filter(func(f): return not f.begins_with("user://logs/") and not (f.ends_with(".cfg") or f.ends_with(".cfg.bak") or f.ends_with(".cfg.tmp")))
	check(stray.is_empty(), "every saved file is a .cfg (or .bak / .tmp sibling): %s" % str(stray))
	var nested := files.filter(func(f): return f.begins_with("user://") and f.count("/") > 3)
	check(nested.is_empty(), "no save is nested deeper than profiles/<id>.cfg: %s" % str(nested))
	print("cloud paths test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
