extends SceneTree
## Agent: Codex-faisal3/prince-ci, independent regression for code-only allocation maintenance.
## Run through tools/tests/isolated.sh --headless --path . --script tools/unit_allocation_test.gd.
## The web branch below is controlled policy simulation, not an actual web-export test.
const Isolated = preload("res://tools/tests/isolated.gd")
const Unit = preload("res://scripts/unit.gd")
const Stats = preload("res://scripts/stats.gd")
var failures := 0
var assertions := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func _init() -> void:
	if not Isolated.ok("tools/unit_allocation_test.gd"):
		quit(2)
		return
	run.call_deferred()

func run() -> void:
	check_attacks()
	check_plan_policy()
	print("UNIT_ALLOCATION_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func check_attacks() -> void:
	var unit := Unit.new()
	for team in 2:
		for role in Stats.Role.values():
			for rank in 4:
				for buff_case in ["none", "Might-active", "Might-expired", "other-active"]:
					unit.team = team
					unit.role = role
					unit.ranks = {role: [rank, 0, 0, 0]}
					unit._stats_cache = Stats.kit(team, role)
					var before: Dictionary = unit.stats().duplicate(true)
					unit.buff = "Might" if buff_case.begins_with("Might") else "Haste"
					unit.buff_timer = 2.0 if buff_case.ends_with("active") else 0.0
					var expected: Dictionary = before.duplicate()
					if rank > 0:
						expected.cooldown = before.cooldown * (1.0 - Stats.RANK_COOLDOWN_CUT * rank)
						# Rank effects retain the established base-attack grow-key contract.
						for key in ["distance", "radius", "duration", "haste", "splash", "heal_radius", "root"]:
							if rank >= 2 and before.has(key):
								expected[key] = before[key] * (1.0 + Stats.RANK_EFFECT_BOOST)
						if rank >= 2 and before.has("arrows"):
							expected.arrows = before.arrows + 2
						if rank >= 3:
							for key in ["heal", "gate_damage"]:
								if before.has(key): expected[key] = before[key] + 1
							for key in ["distance", "radius", "splash", "heal_radius"]:
								if before.has(key): expected[key] = before[key] * (1.0 + Stats.RANK_EFFECT_BOOST * 1.5)
					expected.cost = Stats.BASE_ATTACK_COST
					if expected.attack in ["arrow", "spell"]:
						expected.cooldown *= Stats.RANGED_ATTACK_SLOW
					if buff_case == "Might-active": expected.damage += 1
					var result: Dictionary = unit.attack_stats()
					var tag := "team%d role%d rank%d %s" % [team, role, rank, buff_case]
					check(result == expected, tag + " complete stats equal")
					check(unit.stats() == before, tag + " class cache unchanged")
					result.damage = -999
					result.cooldown = -999.0
					result.cost = -999.0
					check(unit.stats() == before, tag + " returned scalar edits isolated")
					check(unit.attack_stats() == expected, tag + " repeat call has no stacked buff or slowdown")
	unit.free()
	print("CHECKED attack stats: both teams, seven roles, ranks 0-3, four buff states; scalar aliasing/repeat checks")

func check_plan_policy() -> void:
	# Exercise the actual production branch without constructing the unrelated 3D match.
	# Only platform/tick inputs are replaced; _bot_plan state transitions stay verbatim.
	var source := FileAccess.get_file_as_string("res://scripts/unit.gd")
	var start := source.find('\t\tif OS.has_feature("web") and not _bot_plan.is_empty()')
	var end := source.find("\n\t\tmove = plan.move", start)
	check(start >= 0 and end > start, "actual bot decision block located")
	if start < 0 or end <= start: return
	var branch := source.substr(start, end - start)
	branch = branch.replace('OS.has_feature("web")', "web_mode")
	branch = branch.replace("Engine.get_physics_frames()", "tick")
	branch = branch.replace("get_index()", "0")
	var lines := branch.split("\n")
	for i in lines.size():
		if lines[i].begins_with("\t"): lines[i] = lines[i].substr(1)
	var harness := GDScript.new()
	harness.source_code = "extends RefCounted\nvar web_mode := false\nvar tick := 0\nvar calls := 0\nvar _bot_plan: Dictionary = {}\nfunc _bot_think(_delta: float) -> Dictionary:\n\tcalls += 1\n\treturn {\"move\": Vector3(calls, 0, 0), \"aim\": Vector3.FORWARD, \"attack\": true, \"ability\": calls, \"block\": calls % 2 == 0}\nfunc decide(delta: float) -> Dictionary:\n\tvar plan: Dictionary\n" + "\n".join(lines) + "\n\treturn plan\n"
	var error := harness.reload()
	check(error == OK, "production decision block harness compiles")
	if error != OK: return
	for web in [false, true]:
		var bot = harness.new()
		bot.web_mode = web
		for tick in 6:
			bot.tick = tick
			var plan: Dictionary = bot.decide(1.0 / 60.0)
			var expected_calls: int = floori(tick / 2.0) + 1 if web else tick + 1
			var tag := ("web-policy" if web else "native") + " tick%d" % tick
			check(bot.calls == expected_calls, tag + " fresh think cadence")
			check(plan.move == Vector3(expected_calls, 0, 0) and plan.attack and plan.aim == Vector3.FORWARD, tag + " movement/aim/attack retained")
			check(plan.block == (expected_calls % 2 == 0), tag + " block retained")
			check(plan.has("ability") == (not web or tick % 2 == 0), tag + " one-off ability only on fresh decision")
			if plan.has("ability"): check(plan.ability == expected_calls, tag + " fresh ability identity")
			if web:
				check(bot._bot_plan.is_empty() == (tick % 2 == 1), tag + " repeat consumed exactly once")
				check(not bot._bot_plan.has("ability"), tag + " cached repeat never stores ability")
		# Start on a repeat-phase tick with no cache: a fresh thought is required.
		var empty = harness.new()
		empty.web_mode = web
		empty.tick = 1
		check(empty.decide(0.016).has("ability") and empty.calls == 1, "empty-cache odd tick thinks fresh, web=%s" % web)
	print("CHECKED native/web-policy production branch: cadence, movement, aim, block, ability and cache lifecycle")
