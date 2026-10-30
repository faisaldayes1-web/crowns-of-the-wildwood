extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Headless checks for the ending, LEGEND OF THE WILDWOOD (scripts/legend.gd):
## it is due once per player at the legend level, the "seen" flag saves with
## that player's profile, the skip button fast-forwards then skips, and the
## credits roll is built from menu.gd CREDITS. Run through the wrapper:
##     tools/tests/isolated.sh --headless --path . --script tools/legend_test.gd

const Legend = preload("res://scripts/legend.gd")
const Stats = preload("res://scripts/stats.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func xp_for(level: int) -> int:
	var xp := 0
	for l in range(1, level):
		xp += Stats.account_level_cost(l)
	return xp


func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _init() -> void:
	if not Isolated.ok("tools/legend_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.hero_name = "Faisal"
	game.account_xp = xp_for(Legend.LEGEND_LEVEL) - 1
	game.legend_seen = false
	check(game.account_level() == Legend.LEGEND_LEVEL - 1 and not game.legend_due(), "not due one XP short of level %d" % Legend.LEGEND_LEVEL)
	game.account_xp += 1
	check(game.account_level() == Legend.LEGEND_LEVEL and game.legend_due(), "due on reaching level %d" % Legend.LEGEND_LEVEL)
	game.legend_sides = [1, 4]
	game.legend_classes = [9, 2, 0, 5, 0, 0, 0]
	var facts: Dictionary = Legend.hero_facts(game)
	check(facts.name == "Faisal" and facts.faction == "Humans" and facts["class"] == "Mage", "the story names the hero, side and favourite class (%s, %s, %s)" % [facts.name, facts.faction, facts["class"]])

	# Once per player: starting it marks it seen and that is saved.
	game.start_legend("full")
	check(game.legend != null and game.legend.mode == "full" and game.legend_seen, "the ending starts and marks itself seen")
	check(not game.legend_due(), "not due again once seen")
	var seg: Array = game.legend.segment()
	check(game.legend.segs[seg[0]][0] == "title", "it opens on the title card")
	game.legend.input(key(KEY_ENTER))
	check(game.legend.segs[game.legend.segment()[0]][0] == "beat", "Enter goes on to the first beat")
	# Skip: first press fast-forwards, second closes it.
	game.legend.input(key(KEY_ESCAPE))
	check(game.legend != null and game.legend.ff and not game.legend.done, "the first Esc fast-forwards")
	var t0: float = game.legend.t
	game.legend.tick(1.0)
	check(is_equal_approx(game.legend.t - t0, Legend.FAST), "fast-forward plays at %dx" % int(Legend.FAST))
	var shown = game.legend
	game.legend.input(key(KEY_ESCAPE))
	check(shown.done and game.legend == null, "the second Esc skips to the end")
	# A pad's B does the same.
	game.start_legend("full")
	var pb := InputEventJoypadButton.new()
	pb.button_index = JOY_BUTTON_B
	pb.pressed = true
	game.legend.input(pb)
	shown = game.legend
	game.legend.input(pb)
	check(shown.done and game.legend == null, "pad B fast-forwards then skips")
	# Left to play, it ends by itself.
	game.start_legend("full")
	shown = game.legend
	for i in 200:
		if game.legend == null:
			break
		game.legend.tick(1.0)
	check(shown.done and game.legend == null, "played through, it ends on its own (%.0f s)" % shown.total())

	game._save_settings()
	game._flush_save()
	game.legend_seen = false
	game.legend_sides = [0, 0]
	game._load_controls()
	check(game.legend_seen and game.legend_sides == [1, 4] and game.legend_classes[3] == 5, "the seen flag and tallies come back after a restart")
	var first: String = game.profile_id
	game.new_profile("Sam")
	game.account_xp = xp_for(Legend.LEGEND_LEVEL + 2)
	check(not game.legend_seen and game.legend_due(), "another player gets their own ending")
	game._save_settings()
	game.switch_profile(first)
	check(game.legend_seen and not game.legend_due(), "switching back: Faisal has already seen it")
	var moved: String = game.export_progress()
	game.legend_seen = false
	check(game.import_progress(moved) and game.legend_seen, "a progress code carries the seen flag")

	# Roll credits only: no story, the roll comes from menu.gd CREDITS.
	game.start_legend("roll")
	check(game.legend.segs.size() == 2 and game.legend.segs[0][0] == "roll", "ROLL CREDITS plays just the roll and the thanks")
	var items: Array = game.legend._roll_items(Vector2(1280, 720))
	var roles: Array = items.filter(func(it): return it[0] == "role").map(func(it): return it[1])
	check(roles == preload("res://scripts/menu.gd").CREDITS.map(func(c): return c[0]), "the roll lists every CREDITS heading (%d)" % roles.size())
	game.legend.press_next()
	check(game.legend.segs[game.legend.segment()[0]][0] == "thanks", "next jumps from the roll to the thanks")
	game.legend.press_next()
	check(game.legend == null, "next on the thanks returns to the title")

	game.queue_free()
	await frames(2)
	print("legend test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
