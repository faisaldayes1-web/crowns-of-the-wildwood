extends SceneTree
## Headless checks for the STORE rules (scripts/store.gd):
##   godot --headless --path . --script tools/store_test.gd
## Prints PASS/FAIL lines and exits 1 on any failure.

const Stats = preload("res://scripts/stats.gd")
const Store = preload("res://scripts/store.gd")
const CharacterModel = preload("res://scripts/character_model.gd")


class FakeGame:
	extends RefCounted
	var account_gold := 0
	var account_chests := 0
	var owned_items: Array = []
	var hero_hair := 0
	var hero_trim := 0
	var hero_outfit := 0
	var hero_hat := 0
	var hero_cape := 0
	var hero_weapon := 0
	var banner_bg := 0
	var banner_emblem := 0
	var banner_frame := 0
	var main_menu = null
	var playing := false
	var saves := 0
	func _save_settings() -> void:
		saves += 1
	func toast(_t: String, _c: Color = Color.WHITE) -> void:
		pass


var failed := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed += 1


func _init() -> void:
	var g := FakeGame.new()
	# Catalogue sanity: every sold item points into its table, past the free entries, once.
	var seen := {}
	for it in Stats.STORE_ITEMS:
		var t: Array = Store.table(it[0])
		check(it[1] < t.size() and it[1] >= int(Store.KINDS[it[0]][2]) and Stats.RARITIES.has(it[2]) and not seen.has(Store.key(it[0], it[1])),
			"catalogue entry %s is valid" % Store.key(it[0], it[1]))
		seen[Store.key(it[0], it[1])] = true
	check(Store.owns(g, "hair", 0) and Store.owns(g, "hair", Stats.HERO_HAIR_FREE - 1), "free hair colours are owned")
	check(not Store.owns(g, "hair", Stats.HERO_HAIR_FREE), "store hair colour starts locked")
	# Buying.
	var copper := Store.item_for("hair", 6)
	check(not Store.buy(g, "hair", 6), "cannot buy with no gold")
	g.account_gold = Store.price(copper) + 50
	check(Store.buy(g, "hair", 6), "buys with enough gold")
	check(g.account_gold == 50 and Store.owns(g, "hair", 6) and g.hero_hair == 6, "gold spent, item owned and worn")
	check(not Store.buy(g, "hair", 6), "cannot buy twice")
	# Unowned gear is taken off on load.
	g.hero_hat = 3
	Store.drop_unowned(g)
	check(g.hero_hat == 0 and g.hero_hair == 6, "drop_unowned takes off unbought gear only")
	# Chests: each gives a new item until all are owned, then gold.
	g.account_chests = Stats.STORE_ITEMS.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var got := {}
	for k in Stats.STORE_ITEMS.size() - 1:
		var it := Store.open_chest(g, rng)
		check(not it.is_empty() and not got.has(Store.key(it[0], it[1])), "chest %d gives a new item" % (k + 1))
		got[Store.key(it[0], it[1])] = true
	var gold0 := g.account_gold
	var last := Store.open_chest(g, rng)
	check(last.is_empty() and g.account_gold == gold0 + Stats.CHEST_GOLD, "chest with everything owned pays gold")
	check(g.account_chests == 0 and Store.open_chest(g, rng).is_empty() and g.account_gold == gold0 + Stats.CHEST_GOLD, "no chest, nothing given")
	# Try-on preview dictionary.
	var c := Store.wear({"hair": Color.RED}, "hat", 2)
	check(c.get("hat", "") == "straw", "try-on adds the hat")
	check(not Store.wear(c, "hat", 0).has("hat"), "try-on of None removes it")
	# The model builds with every piece of gear on (no script errors).
	for role in [Stats.Role.BASE, Stats.Role.KNIGHT, Stats.Role.MAGE]:
		for hat in range(1, Stats.HERO_HATS.size()):
			var m := CharacterModel.new()
			root.add_child(m)
			m.setup(hat % 2, role, "", {"body": "rogue", "hat": Stats.HERO_HATS[hat][1], "cape": Stats.HERO_CAPES[1 + hat % (Stats.HERO_CAPES.size() - 1)][1],
				"outfit": 1 + hat % (Stats.HERO_OUTFITS.size() - 1), "weapon": 1 + hat % (Stats.WEAPON_SKINS.size() - 1), "trim": Color(0.2, 0.6, 0.3)}, 2)
			check(m.get_child_count() > 0, "model builds: role %d hat %s" % [role, Stats.HERO_HATS[hat][0]])
			m.free()
	print("STORE TEST: %s (%d failed)" % ["OK" if failed == 0 else "FAILED", failed])
	quit(1 if failed else 0)
