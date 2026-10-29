extends SceneTree
## Agent: Codex-faisal3. SAV-01/02 regression, no scenes/rendering required.
## tools/tests/isolated.sh --headless --path . --script tools/save_recovery_test.gd

const Isolated = preload("res://tools/tests/isolated.gd")
const SaveFile = preload("res://scripts/save_file.gd")
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func put(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if text == "<NUL>":
		var zeros := PackedByteArray()
		zeros.resize(900)
		file.store_buffer(zeros)
	else:
		file.store_string(text)
	file.close()


func fixture(xp: int = 530) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "account_xp", xp)
	cfg.set_value("profile", "account_gold", 600)
	cfg.set_value("profile", "owned_items", ["hat:2"])
	cfg.set_value("settings", "hero_name", "Recovery Hero")
	return cfg


func _init() -> void:
	if not Isolated.ok("tools/save_recovery_test.gd"):
		quit(2)
		return
	var directory := "user://save-recovery-%d" % Time.get_ticks_usec()
	check(DirAccess.make_dir_recursive_absolute(directory + "/profiles") == OK, "create isolated fixture")
	var corruption := {
		"empty": "",
		"nul": "<NUL>",
		"garbage": "@@garbage\n",
		"parse-error": "[profile]\naccount_xp=\"unfinished",
		"unrelated": "[unrelated]\nvalue=530\n",
		"missing-xp": "[profile]\naccount_gold=600\n",
		"wrong-xp-type": "[profile]\naccount_xp=\"530\"\n",
		"negative-xp": "[profile]\naccount_xp=-1\n"
	}
	for kind in ["controls.cfg", "profiles/p1.cfg"]:
		for label in corruption:
			var path: String = directory + "/" + kind
			# Start each case independently, with a good 530 XP backup.
			put(path, fixture().encode_to_text())
			check(SaveFile.write(fixture(900), path) == OK, kind + " seed " + label)
			var backup := FileAccess.get_file_as_bytes(path + ".bak")
			put(path, corruption[label])
			var loaded := ConfigFile.new()
			loaded.set_value("profile", "account_xp", 9999)
			check(SaveFile.read(loaded, path) == OK and loaded.get_value("profile", "account_xp", -1) == 530,
				kind + " recovers " + label)
			check(SaveFile.write(loaded, path) == OK and FileAccess.get_file_as_bytes(path + ".bak") == backup,
				kind + " keeps good backup after " + label)
			check(SaveFile.read(loaded, path) == OK and loaded.get_value("profile", "account_gold", -1) == 600,
				kind + " recovered save survives restart " + label)

	var path := directory + "/controls.cfg"
	var cfg := fixture()
	cfg.set_value("profiles", "current", "p1")
	check(SaveFile.write(cfg, path) == OK, "write device save with selected player")
	var good := FileAccess.get_file_as_string(path)
	check(good.begins_with("[save]"), "metadata is first so truncation cannot downgrade to legacy")
	check(not cfg.has_section("save"), "write does not mutate caller")
	for label in ["magic", "version", "digest", "truncated", "altered", "required-key"]:
		var damaged := good
		match label:
			"magic": damaged = damaged.replace(SaveFile.SAVE_MAGIC, "OTHER-SAVE")
			"version": damaged = damaged.replace("version=1", "version=999")
			"digest": damaged = damaged.replace("digest=", "missing_digest=")
			"truncated": damaged = damaged.left(damaged.find("[profiles]"))
			"altered": damaged = damaged.replace("account_xp=530", "account_xp=0")
			"required-key": damaged = damaged.replace("account_xp=530", "other_xp=530")
		put(path + ".bak", good)
		put(path, damaged)
		var loaded := ConfigFile.new()
		check(SaveFile.read(loaded, path) == OK and loaded.get_value("profiles", "current", "") == "p1"
			and loaded.get_value("profile", "account_xp", -1) == 530, "new save rejects " + label + " and uses backup")
		put(path + ".bak", damaged)
		check(SaveFile.read(loaded, path) != OK and loaded.get_sections().is_empty(),
			"two bad copies clear stale state: " + label)

	put(path, fixture().encode_to_text())
	var loaded := ConfigFile.new()
	check(SaveFile.read(loaded, path) == OK, "legacy XP/looks save loads without metadata")
	put(path, "[settings]\nsound_volume=0.5\n")
	check(SaveFile.read(loaded, path) == OK, "legacy settings-only device save loads")
	put(directory + "/profiles/only-settings.cfg", "[settings]\nhero_name=\"Broken\"\n")
	check(SaveFile.read(loaded, directory + "/profiles/only-settings.cfg") != OK,
		"settings-only player file is rejected")
	var device := fixture()
	var empty := ConfigFile.new()
	SaveFile.use_profile(device, empty)
	check(device.get_value("profile", "account_xp", -1) == 530
		and device.get_value("settings", "hero_name", "") == "Recovery Hero", "empty profile cannot erase embedded recovery copy")
	SaveFile.use_profile(device, fixture(800))
	check(device.get_value("profile", "account_xp", -1) == 800, "valid profile still replaces embedded copy")
	var before := FileAccess.get_file_as_bytes(path)
	var backup := FileAccess.get_file_as_bytes(path + ".bak")
	check(SaveFile.write(empty, path) != OK and FileAccess.get_file_as_bytes(path) == before
		and FileAccess.get_file_as_bytes(path + ".bak") == backup, "invalid write leaves primary and backup untouched")
	check(not FileAccess.file_exists(path + ".tmp"), "invalid write leaves no temporary file")
	# Keep fixture files in this throwaway directory for failed-run diagnosis.
	print("save recovery test: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
