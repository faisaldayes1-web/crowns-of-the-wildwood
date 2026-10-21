extends SceneTree
## Agent: Codex-faisal. Isolated save-write regression; no player profiles touched.
const SaveFile = preload("res://scripts/save_file.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	var directory := "user://save-write-test-%d" % Time.get_ticks_usec()
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "create isolated fixture")
	var path := directory + "/progress.cfg"
	var original := ConfigFile.new()
	original.set_value("profile", "account_xp", 1234)
	check(SaveFile.write(original, path) == OK, "first save succeeds")
	# A directory at the backup path deterministically prevents copying a file.
	check(DirAccess.make_dir_absolute(path + ".bak") == OK, "block backup destination")
	var updated := ConfigFile.new()
	updated.set_value("profile", "account_xp", 5678)
	print("EXPECT: engine copy error for blocked .bak fixture")
	check(SaveFile.write(updated, path) != OK, "failed backup is reported")
	var loaded := ConfigFile.new()
	check(loaded.load(path) == OK and loaded.get_value("profile", "account_xp") == 1234,
		"failed backup preserves original progress")
	check(not FileAccess.file_exists(path + ".tmp"), "failed backup cleans temporary save")
	DirAccess.remove_absolute(path + ".bak")
	check(SaveFile.write(updated, path) == OK, "retry succeeds after backup destination repaired")
	loaded.clear()
	check(loaded.load(path + ".bak") == OK and loaded.get_value("profile", "account_xp") == 1234,
		"successful retry backs up original progress")
	loaded.clear()
	check(loaded.load(path) == OK and loaded.get_value("profile", "account_xp") == 5678,
		"successful retry stores new progress")
	for file in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(directory)
	print("save write test: %d failure(s)" % failures)
	quit(1 if failures else 0)
