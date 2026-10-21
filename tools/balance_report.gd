extends SceneTree
## Agent: Codex-faisal. Effective unranked balance data, not balance changes.
## godot --headless --path . --script tools/balance_report.gd -- --out=<new.json>
## No output argument: print JSON after BALANCE_REPORT. Never overwrites a file.
const Stats = preload("res://scripts/stats.gd")
const UnitScript = preload("res://scripts/unit.gd")


func _init() -> void:
	var rows := []
	for team in Stats.FACTIONS.size():
		for role in Stats.Role.values():
			# Do not attach to the scene: no models, input, saves or match needed.
			var unit = UnitScript.new()
			unit.team = team
			unit.role = role
			var attack: Dictionary = unit.attack_stats()
			var abilities := []
			for index in unit.abilities().size():
				var ability: Dictionary = unit.ability(index)
				abilities.append({"name": ability.name, "cost": ability.cost,
					"cooldown_seconds": ability.cooldown})
			rows.append({"faction": Stats.FACTIONS[team].name,
				"class": Stats.FACTIONS[team].roles[role], "role_id": role,
				"movement_speed": Stats.FACTIONS[team].speed * unit.stats().speed * unit.vigor_speed(),
				"regen_multiplier": Stats.FACTIONS[team].regen_mult,
				"attack": attack.attack_name, "attack_cost": attack.cost,
				"attack_cooldown_seconds": attack.cooldown, "abilities": abilities})
			unit.free()
	var levels := []
	var cumulative := 0
	for level in range(1, Stats.ACCOUNT_MAX_LEVEL + 1):
		levels.append({"level": level, "total_xp": cumulative})
		cumulative += Stats.account_level_cost(level)
	var report := {"schema_version": 1, "agent": "Codex-faisal", "scope":
		"Unranked base kits only; no promotions, equipment, buffs or combat outcomes. No balance changes.",
		"source_sha256": {"stats.gd": FileAccess.get_sha256("res://scripts/stats.gd"),
			"unit.gd": FileAccess.get_sha256("res://scripts/unit.gd")},
		"match": {"regulation_seconds": Stats.MATCH_TIME, "overtime_seconds": Stats.OVERTIME,
			"captures_to_win": Stats.CAPTURES_TO_WIN, "dodge_cooldown_seconds": Stats.DODGE_COOLDOWN},
		"classes": rows, "account_levels": levels}
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	var encoded := JSON.stringify(report, "\t", true, true)
	if output.is_empty():
		print("BALANCE_REPORT\n", encoded)
	elif FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
		printerr("Output exists; choose a new file: ", output)
		quit(1)
		return
	else:
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write report: ", output)
			quit(1)
			return
		file.store_string(encoded + "\n")
		file.flush()
		var result := file.get_error()
		file.close()
		if result != OK:
			printerr("Cannot finish report: ", error_string(result))
			quit(1)
			return
		print("Balance report: ", output)
	quit()
