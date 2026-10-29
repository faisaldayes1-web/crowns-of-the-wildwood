extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Headless checks for the save file (scripts/save_file.gd) and the account's
## progress surviving: a restart, a damaged save, RESET TO DEFAULT on the
## controls, and a progress code carried to another device. Run from the
## project root, through the wrapper (it refuses the real user dir):
##     tools/tests/isolated.sh --headless --path . --script tools/save_test.gd

const SaveFile = preload("res://scripts/save_file.gd")
const PATH := "user://controls.cfg"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	if not Isolated.ok("tools/save_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	# --- SaveFile on its own ---------------------------------------------
	var t := "user://save_test.cfg"
	var a := ConfigFile.new()
	a.set_value("profile", "account_xp", 1234)
	check(SaveFile.write(a, t) == OK and not FileAccess.file_exists(t + ".tmp"), "a save is written and no .tmp is left")
	a.set_value("profile", "account_xp", 2000)
	SaveFile.write(a, t)
	var b := ConfigFile.new()
	check(SaveFile.read(b, t) == OK and b.get_value("profile", "account_xp") == 2000, "the newest save loads")
	var f := FileAccess.open(t, FileAccess.WRITE)
	f.store_string("[profile\naccount_xp=garbage{{{")
	f.close()
	b = ConfigFile.new()
	check(SaveFile.read(b, t) == OK and b.get_value("profile", "account_xp") == 1234, "a damaged save falls back to the .bak")
	for p in [t, t + ".bak"]:
		DirAccess.remove_absolute(p)
	# Codes.
	a = ConfigFile.new()
	a.set_value("profile", "account_xp", 5100)
	a.set_value("profile", "account_gold", 777)
	a.set_value("profile", "owned_items", ["hat:2", "cape:1"])
	a.set_value("settings", "hero_hat", 2)
	a.set_value("settings", "hero_name", "Faisal")
	a.set_value("settings", "sound_volume", 0.3)
	var code := SaveFile.export_code(a)
	check(code.begins_with(SaveFile.CODE_PREFIX) and code.length() < 600, "a progress code is short text (%d chars)" % code.length())
	var data := SaveFile.parse_code("  " + code + "\n")
	check(not data.is_empty(), "the code reads back (spaces and new lines ignored)")
	check(SaveFile.parse_code(code.substr(0, code.length() - 12) + "AAAA" + code.right(8)).is_empty(), "an altered code is refused")
	check(SaveFile.parse_code("hello").is_empty() and SaveFile.parse_code("").is_empty(), "text that is not a code is refused")
	var c := ConfigFile.new()
	c.set_value("settings", "sound_volume", 0.9)
	c.set_value("profile", "account_xp", 10)
	SaveFile.apply_code(c, data)
	check(c.get_value("profile", "account_xp") is int and c.get_value("profile", "account_xp") == 5100 and c.get_value("profile", "account_gold") == 777,
		"applying a code restores XP and gold as whole numbers")
	check(Array(c.get_value("profile", "owned_items")) == ["hat:2", "cape:1"] and c.get_value("settings", "hero_hat") == 2 and c.get_value("settings", "hero_name") == "Faisal",
		"applying a code restores store items and looks")
	check(is_equal_approx(c.get_value("settings", "sound_volume"), 0.9), "a code leaves the device's own settings alone")

	# --- The real game ------------------------------------------------------
	DirAccess.remove_absolute(PATH)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.account_xp = 4321
	game.account_gold = 950
	game.account_chests = 3
	game.owned_items = ["hat:2"]
	game.hero_hat = 2
	game._save_settings()
	game.account_xp = 0
	game.account_gold = 0
	game.account_chests = 0
	game.owned_items = []
	game.hero_hat = 0
	game._load_controls()
	check(game.account_xp == 4321 and game.account_gold == 950 and game.account_chests == 3 and game.hero_hat == 2,
		"level XP, gold, chests and worn items come back after a restart")
	game._reset_controls()
	game.account_xp = 0
	game._load_controls()
	check(game.account_xp == 4321 and game.account_gold == 950, "RESET TO DEFAULT on the controls keeps the progress")
	# A damaged save on start.
	game._save_settings()
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[profile]\naccount_xp=\"unfinished")
	f.close()
	game.account_xp = 0
	game._load_controls()
	check(game.account_xp == 4321, "a damaged save loads the backup copy")
	game._save_settings()
	# Carry it to another device.
	var moved: String = game.export_progress()
	for p in [PATH, PATH + ".bak"]:
		DirAccess.remove_absolute(p)
	game.account_xp = 0
	game.account_gold = 0
	game.owned_items = []
	game.hero_hat = 0
	check(not game.import_progress("CROWNS1-nonsense-123"), "IMPORT refuses a bad code")
	check(game.import_progress(moved), "IMPORT takes a good code")
	check(game.account_xp == 4321 and game.account_gold == 950 and game.owned_items == ["hat:2"] and game.hero_hat == 2,
		"the imported progress is in the game")
	game.account_xp = 0
	game._load_controls()
	check(game.account_xp == 4321, "the imported progress is saved")
	# SAV-02: an unreadable current-player file must leave controls.cfg's
	# embedded progress intact, including after the next autosave/restart.
	var recovery_id: String = game.profile_id
	for damage in ["", "\u0000".repeat(900), "@@garbage\n", "[settings]\nhero_name=\"Broken\"\n"]:
		game._save_settings()
		game._flush_save()
		var player_path: String = game.profile_path(recovery_id)
		DirAccess.remove_absolute(player_path + ".bak")
		f = FileAccess.open(player_path, FileAccess.WRITE)
		f.store_string(damage)
		f.close()
		game.account_xp = 0
		game.account_gold = 0
		game._load_controls()
		check(game.account_xp == 4321 and game.account_gold == 950 and game.hero_hat == 2,
			"corrupt player file recovers embedded progress (%d bytes)" % damage.length())
		game._save_settings()
		game.account_xp = 0
		game._load_controls()
		check(game.account_xp == 4321 and game.profile_id == recovery_id,
			"recovered player progress survives autosave and restart")
	# SAV-01: a valid device backup keeps the selected player, not a new p2.
	for damage in ["", "\u0000".repeat(900), "@@garbage\n"]:
		game._save_settings()
		game._save_settings()
		game._flush_save()
		var good_backup := FileAccess.get_file_as_bytes(PATH + ".bak")
		f = FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(damage)
		f.close()
		game.account_xp = 0
		game._load_controls()
		game._ensure_profile()
		check(game.account_xp == 4321 and game.profile_id == recovery_id,
			"corrupt controls recovers selected player (%d bytes)" % damage.length())
		game._save_settings()
		game._flush_save()
		check(FileAccess.get_file_as_bytes(PATH + ".bak") == good_backup,
			"recovery autosave never rotates corrupt controls over good backup")

	# --- Named players --------------------------------------------------------
	var first: String = game.profile_id
	check(first != "" and FileAccess.file_exists(game.profile_path(first)), "progress belongs to a player with their own file")
	game.hero_name = "Faisal"
	game._save_settings()
	var sam: String = game.new_profile("Sam")
	check(game.profile_id == sam and game.hero_name == "Sam" and game.account_xp == 0 and game.account_gold == 0 and game.hero_hat == 0 and game.owned_items.is_empty(),
		"a NEW PLAYER starts at level 1 with no gold, items or look")
	game.account_gold = 50
	game.account_xp = 900
	game._save_settings()
	game.switch_profile(first)
	check(game.hero_name == "Faisal" and game.account_xp == 4321 and game.account_gold == 950 and game.hero_hat == 2, "switching back brings Faisal's level, gold and hat")
	var faisal_code: String = game.export_progress()
	game.switch_profile(sam)
	check(game.account_gold == 50 and game.account_xp == 900, "Sam's progress was saved apart")
	game.account_gold = 0
	game._load_controls()
	check(game.profile_id == sam and game.account_gold == 50, "a restart carries on as the last player")
	var names: Array = game.list_profiles().map(func(p): return p.name)
	check(names.has("Faisal") and names.has("Sam"), "PLAYERS lists everyone on the device (%s)" % ", ".join(names))
	var sam_code: String = game.export_progress()
	check(SaveFile.parse_code(sam_code).settings.get("hero_name") == "Sam", "a progress code carries the player's name")
	check(not game.delete_profile(sam), "the player playing now cannot be deleted")
	check(game.delete_profile(first) and not FileAccess.file_exists(game.profile_path(first)), "another player can be deleted")
	check(game.import_progress(faisal_code) and game.hero_name == "Faisal" and game.profile_id != sam and game.account_xp == 4321,
		"importing a code adds that player next to the others")
	game.queue_free()
	await frames(2)
	# (No clean-up: the whole user dir is a throwaway one.)
	print("save test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
