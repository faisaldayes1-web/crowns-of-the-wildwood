extends SceneTree

const Stats = preload("res://scripts/stats.gd")
## The end-of-match "next goal" tile: the level-10 unlocks first, then rank titles.
## Run: tools/tests/isolated.sh --headless --path . --script tools/progress_goal_test.gd
## claude-faisal3, task cf-crowns-onboard-1104x.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	check(Stats.next_goal(1)[0] == "Moonlit at Lv 10", "a new account is pointed at the level-10 unlocks")
	check(Stats.next_goal(9)[0] == "Moonlit at Lv 10", "level 9 still points at them")
	check(Stats.next_goal(10)[0] == "Lv 15: Warlord", "level 10 points at the next rank")
	check(Stats.next_goal(49)[0] == "Lv 50: Immortal", "level 49 points at the top rank")
	check(Stats.next_goal(50)[0] == "Top rank reached", "the top level has no goal left")
	check(Stats.account_level(8999) == 9 and Stats.account_level(9000) == 10, "level 10 starts at 9000 XP")
	for g in [Stats.next_goal(1), Stats.next_goal(10), Stats.next_goal(50)]:
		check(g[0].length() <= 18, "'%s' fits the reward tile" % g[0])
	print("progress goal test: %d failure(s)" % fails)
	quit(fails)
