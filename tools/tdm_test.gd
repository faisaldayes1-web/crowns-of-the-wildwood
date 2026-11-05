extends SceneTree
## Agent: claude-faisal/crowns-tdm 2026-11-04. Team Deathmatch on the real
## match: the mode flow from the battle start to a win, kill scoring and the
## kill feed, respawn waves, sudden death on a tie, split-screen locals and
## the SELECT MAP mode picker. Run it through tools/tests/isolated.sh:
##
##   tools/tests/isolated.sh --headless --path . --fixed-fps 60 --script tools/tdm_test.gd -- --play --mode=tdm --map=0
##   ... -- --play --mode=tdm --map=0 --tdm-case=sudden
##   ... -- --play --mode=tdm --map=0 --couch=2 --tdm-case=split
##   tools/tests/isolated.sh --headless --path . --script tools/tdm_test.gd -- --tdm-case=menu
const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")
var game
var failures := 0
var case := "target"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + detail)
	if not ok:
		failures += 1


func frames(count: int = 3) -> void:
	for i in count:
		await process_frame


func done() -> void:
	print("tdm test (%s): %d failure(s)" % [case, failures])
	quit(1 if failures > 0 else 0)


func run() -> void:
	if not Isolated.ok("tdm_test"):
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tdm-case="):
			case = arg.trim_prefix("--tdm-case=")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if case == "menu":
		await menu_case()
		done()
		return
	var deadline := Time.get_ticks_msec() + 240000
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			check(false, "match loaded (run with --play)")
			done()
			return
		await process_frame
	# Nobody fights on their own: the test lands every blow itself.
	for u in game.units:
		u.set_physics_process(false)
	game.score = [0, 0]
	check(game.is_tdm(), "the match is Team Deathmatch")
	check(game.time_left == Stats.TDM_TIME, "the clock starts at TDM_TIME (%s)" % game.time_left)
	check(game.prep_left > 0.0 and game.prep_left <= Stats.TDM_PREP, "a short warm-up before the fight (%s s)" % game.prep_left)
	for m in game.monarchs:
		check(not m.visible, "%s hidden" % m.title)
	# The warm-up ends: the barrier falls and both doors with it.
	game.prep_left = 0.02
	await frames(5)
	check(game.prep_left == 0.0, "the battle began")
	for g in game.gates:
		check(not g.is_intact(), "team %d door is down" % g.team)
	var obj: Dictionary = game.objective_target()
	check(str(obj.get("label", "")).contains("kills"), "the compass points at the enemy (%s)" % obj.get("label", ""))
	# The crown cannot be taken.
	var p = game.player
	var their = game.monarchs[1 - p.team]
	p.global_position = their.global_position
	game.try_interact(p)
	check(p.carrying == null, "no crown pickup in a deathmatch")
	check(game.score == [0, 0], "nothing scored before the first kill")
	if case == "split":
		await split_case()
	elif case == "sudden":
		await sudden_case()
	else:
		await target_case()
	done()


func foe_of(team: int, skip: Array = []):
	for u in game.units:
		if u.team != team and not u.dead and not u.downed and not u in skip and not u.is_player:
			return u
	for u in game.units:
		if u.team != team and not u.dead and not u.downed and not u in skip:
			return u
	return null


func knock_out(victim, attacker) -> void:
	## Out of the sanctuary and every protection, then one blow too many.
	victim.global_position = Vector3(0, 0, 8.0 if victim.team == 0 else -8.0)
	victim.spawn_protect = 0.0
	victim.dodge_timer = 0.0
	victim.guard_timer = 0.0
	victim.revive_protect = 0.0
	victim.blocking = false
	victim.hearts = 1
	victim.take_damage(5, attacker, attacker.global_position if attacker else Vector3.INF)


func kill(victim, attacker) -> void:
	knock_out(victim, attacker)
	if victim.downed:
		victim._die(attacker)


func target_case() -> void:
	var p = game.player
	var t: int = p.team
	var victim = foe_of(t)
	var feed_before: int = game.kill_feed.size()
	kill(victim, p)
	check(game.score[t] == 1 and game.score[1 - t] == 0, "a kill scores one for the killer's side (%s)" % str(game.score))
	check(game.kill_feed.size() > feed_before and game.kill_feed[-1].victim == victim.display_name, "the kill is in the kill feed")
	check(victim.dead, "the victim is dead")
	await respawn_check(victim)
	# A turret, trap or lava kill (no fighter credited) scores too.
	var v2 = foe_of(t)
	kill(v2, null)
	check(game.score[t] == 2, "a kill with no fighter credited still scores (%s)" % str(game.score))
	# Own-team deaths do not score for that side.
	var mate = null
	for u in game.units:
		if u.team == t and not u.is_player and not u.dead:
			mate = u
			break
	kill(mate, foe_of(t, [v2]))
	check(game.score[1 - t] == 1 and game.score[t] == 2, "the other side scores its own kills (%s)" % str(game.score))
	# The kill target ends it.
	game.score[t] = Stats.TDM_KILLS_TO_WIN - 1
	kill(foe_of(t), p)
	check(game.game_over, "reaching the kill target ends the match")
	check(game.winner_team == t, "the side that reached it wins")
	check(game.summary != null, "the results screen is made")
	await frames(10)
	check(not game.playing, "the match stopped")


func respawn_check(victim) -> void:
	victim.set_physics_process(true)
	var wait: float = victim.respawn_timer
	check(wait >= Stats.TDM_RESPAWN_MIN - 0.05 and wait <= Stats.TDM_RESPAWN_MIN + Stats.TDM_WAVE + 0.05,
		"respawn waits for the next wave (%.2f s)" % wait)
	var wave_at: float = game.match_played + wait
	check(absf(fmod(wave_at + 0.001, Stats.TDM_WAVE)) < 0.1, "the wave lands on a %d s boundary (%.2f)" % [int(Stats.TDM_WAVE), wave_at])
	var deadline := Time.get_ticks_msec() + 30000
	while victim.dead and Time.get_ticks_msec() < deadline:
		await physics_frame
	check(not victim.dead, "the victim respawned")
	check(absf(game.match_played - wave_at) < 0.5, "respawned on the wave (at %.2f, wave %.2f)" % [game.match_played, wave_at])
	victim.set_physics_process(false)


func sudden_case() -> void:
	var p = game.player
	var t: int = p.team
	game.score = [4, 4]
	game.time_left = 0.02
	await frames(5)
	check(game.tdm_sudden, "a tie at full time goes to sudden death")
	check(not game.game_over, "sudden death keeps the match on")
	check(absf(game.time_left - Stats.TDM_SUDDEN) < 1.0, "sudden death runs TDM_SUDDEN seconds (%s)" % game.time_left)
	kill(foe_of(t), p)
	check(game.game_over and game.winner_team == t, "the next kill wins")
	check(game.match_clock() >= int(Stats.TDM_TIME), "the match clock counts sudden death (%d)" % game.match_clock())


func split_case() -> void:
	check(game.couch_players == 2, "two local players")
	check(game.locals.size() == 2 and game.locals.all(func(u): return u != null and u.is_player), "both locals are players")
	check(game.panes.size() == 2, "the screen is split (%d panes)" % game.panes.size())
	var second = game.locals[1]
	var t: int = second.team
	# Player 2 knocks out a foe; then player 1's side (or player 2) loses one.
	kill(foe_of(t), second)
	check(game.score[t] == 1, "player 2's kill scores for their side (%s)" % str(game.score))
	kill(second, foe_of(t))
	check(second.dead, "player 2 died")
	check(game.score[1 - t] >= 1, "player 2's death scores for the other side (%s)" % str(game.score))
	await respawn_check(second)
	# Let the bots play a while: the squad planner hunts in a deathmatch.
	for u in game.units:
		u.set_physics_process(true)
	await frames(90)
	var hunting := 0
	var jobs := []
	var bots: Array = game.units.filter(func(u): return not u.is_player and not u.dead)
	for u in bots:
		jobs.append(u.bot_job)
		if u.bot_job in ["hunt", "support", "fire"]:
			hunting += 1
	check(hunting == bots.size() and hunting > 0, "every living bot plays the deathmatch (%s)" % str(jobs))
	# The player's Defend! call still pulls bots home in a deathmatch.
	var t1: int = game.player.team
	game.team_command[t1] = "defend"
	game.command_timer[t1] = 5.0
	game._plan_bots(t1)
	var defending: int = game.units.filter(func(u): return u.team == t1 and not u.is_player and not u.dead and u.bot_job == "defend").size()
	check(defending >= 1, "Defend! pulls %d bot(s) home" % defending)


func menu_case() -> void:
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or not game.world_ready:
		if Time.get_ticks_msec() > deadline:
			check(false, "the title loaded")
			return
		await process_frame
	await frames(5)
	game.main_menu._press("play", null)
	await frames(3)
	check(game.main_menu.screen == "map", "PLAY opens SELECT MAP (%s)" % game.main_menu.screen)
	game.main_menu._press("game_mode", "tdm")
	check(game.game_mode == "tdm", "the GAME MODE picker sets Team Deathmatch")
	game.main_menu._press("game_mode", "nonsense")
	check(game.game_mode == "tdm", "an unknown mode is ignored")
	var cfg := ConfigFile.new()
	var mode_saved := ""
	if cfg.load("user://controls.cfg") == OK:
		mode_saved = str(cfg.get_value("settings", "game_mode", ""))
	check(mode_saved == "tdm", "the pick is saved (%s)" % mode_saved)
	game.main_menu._press("game_mode", "crowns")
	check(game.game_mode == "crowns" and not game.is_tdm(), "and back to Crown Raid")
