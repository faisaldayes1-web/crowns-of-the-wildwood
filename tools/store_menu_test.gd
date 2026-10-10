extends SceneTree
## Clicks through the STORE headlessly, the way a player would: opens it
## from the title, visits every tab, buys an item, wears and takes it off,
## opens a Match Chest, and checks a locked choice in Create Your Character
## opens the store on it. Run from the project root:
##     godot --headless --path . --script tools/store_menu_test.gd

const Stats = preload("res://scripts/stats.gd")
const Store = preload("res://scripts/store.gd")

var fails := 0
var game
var hud


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func tap_id(id: String, arg = null) -> bool:
	for b in hud.menu_buttons:
		if b[1] == id and (arg == null or b[2] == arg):
			game.touch_tap = b[0].get_center()
			await frames(3)
			return true
	return false


func _init() -> void:
	var cfg := "user://controls.cfg"
	var backup := FileAccess.get_file_as_bytes(cfg) if FileAccess.file_exists(cfg) else PackedByteArray()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(5)
	hud = game.hud
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1280, 720)
	game.owned_items = []
	game.account_gold = 700
	game.account_chests = 1
	await frames(3)
	var m = game.main_menu
	check(await tap_id("store"), "the title has a STORE button")
	check(m.screen == "store", "STORE opens the store")
	for t in Store.TABS.size():
		await tap_id("store_tab", t)
		check(m.store.tab == t and not m.store.pick.is_empty(), "tab %s opens with an item on show" % Store.TABS[t][0])
	# Buy a 600-gold item with 700 gold.
	await tap_id("store_tab", 3)
	var crown := Store.item_for("hat", 4)   # Flower Crown, rare: 600
	check(await tap_id("store_pick", crown), "an item card can be picked")
	check(m.store.preview_custom().get("hat", "") == "flowers", "the picked hat is tried on the hero")
	check(await tap_id("store_buy"), "BUY is shown for an item not owned")
	check(game.account_gold == 100 and Store.owns(game, "hat", 4) and game.hero_hat == 4, "BUY spends the gold, owns and wears it")
	check(await tap_id("store_unequip"), "TAKE OFF is shown for a worn hat")
	check(game.hero_hat == 0, "TAKE OFF takes it off")
	check(await tap_id("store_equip"), "EQUIP is shown for an owned item not worn")
	check(game.hero_hat == 4, "EQUIP wears it again")
	# Too poor: no BUY.
	await tap_id("store_pick", Store.item_for("hat", 7))
	var gold: int = game.account_gold
	await tap_id("store_buy")
	check(game.account_gold == gold and not Store.owns(game, "hat", 7), "BUY does nothing without the gold")
	# A chest.
	check(await tap_id("store_chest"), "the chest OPEN button is shown")
	check(game.account_chests == 0 and not m.store.reveal.is_empty() and game.owned_items.size() == 2, "OPEN uses the chest and adds an item")
	m.store.reveal[1] = -100.0   # let the opening finish
	game.touch_tap = Vector2(640, 360)
	await frames(3)
	check(m.store.reveal.is_empty() and m.screen == "store", "a tap closes the reveal")
	# Saved.
	var c := ConfigFile.new()
	c.load(cfg)
	check(int(c.get_value("profile", "account_gold", -1)) == game.account_gold and Array(c.get_value("profile", "owned_items", [])).size() == 2, "gold and items are saved")
	# A locked colour in Create Your Character opens the store on it.
	m.go("character")
	m.char_tab = 1
	await frames(3)
	var locked := -1
	for i in range(Stats.HERO_HAIR_FREE, Stats.HERO_HAIR.size()):
		if not Store.owns(game, "hair", i):
			locked = i
			break
	await tap_id("hair", locked)
	check(m.screen == "store" and m.store.pick == Store.item_for("hair", locked), "a locked hair colour opens the store on it")
	m.back()
	await frames(2)
	check(m.screen == "title", "BACK leaves the store")
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg + ".bak"))   # else the next run loads this test's settings from the backup
	else:
		var f := FileAccess.open(cfg, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	print("store menu: %d failure(s)" % fails)
	quit(1 if fails else 0)
