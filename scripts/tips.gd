class_name Tips
extends RefCounted
## First-match tips (claude-faisal3, task cf-crowns-onboard-1104x): one short
## line per local player, shown in that player's own pane with the keys or
## buttons of the device they hold. A tip clears the moment its thing is done,
## or after TIP_SECONDS if it is ignored, or when the player holds Dodge for
## SKIP_HOLD seconds; once every local player has been through the list the
## flag is saved and the tips stay away (Settings > Tips brings them back).
## State lives in the unit's meta, so unit.gd and the netcode are untouched.

const Stats = preload("res://scripts/stats.gd")

const TIP_SECONDS := 12.0
const SKIP_HOLD := 1.0
const MOVE_DONE_M := 5.0
const STEPS := ["move", "class", "attack", "ability", "goal"]


static func _state(u) -> Dictionary:
	if not u.has_meta("tips"):
		u.set_meta("tips", {"step": 0, "shown": 0.0, "start": u.global_position, "skip": 0.0, "over": false})
	return u.get_meta("tips")


static func active(game, u) -> bool:
	return u != null and game.tips_on and not game.tips_done and not game.demo and not _state(u).over


static func _move_keys(game, u) -> String:
	if game.on_pad(u):
		return "LEFT STICK"
	return "%s%s%s%s" % [game.key_label("move_up", u), game.key_label("move_left", u), game.key_label("move_down", u), game.key_label("move_right", u)]


static func text_for(game, u, step: String) -> String:
	match step:
		"move":
			return "Move: %s" % _move_keys(game, u)
		"class":
			return "Pick a class: stand by a hat in your castle and press %s" % game.key_label("interact", u)
		"attack":
			return "Attack: %s" % _words(game.key_label("attack", u))
		"ability":
			# (claude-faisallaptop/crowns-tutorial-visual: Q and E stay locked
			# until a class hat is on, so a plain soldier is told where they come from.)
			if u.role == Stats.Role.BASE:
				return "Dodge: %s. Put on a class hat to unlock %s and %s" % [_words(game.key_label("dodge", u)), game.key_label("ability_1", u), game.key_label("ability_2", u)]
			return "Abilities: %s and %s, dodge: %s" % [game.key_label("ability_1", u), game.key_label("ability_2", u), _words(game.key_label("dodge", u))]
		"goal":
			if game.is_tdm():
				return "Defeat the other team: first to %d kills wins" % Stats.TDM_KILLS_TO_WIN
			return "Break their gate and vault lock, steal the Crown, carry it home"
	return ""


static func _words(key: String) -> String:
	## Mouse buttons in words, as the HOW TO PLAY cards say them.
	return key.replace("LMB", "Left Click").replace("RMB", "Right Click")


static func _done(game, u, st: Dictionary, step: String) -> bool:
	match step:
		"move":
			return Vector2(u.global_position.x - st.start.x, u.global_position.z - st.start.z).length() >= MOVE_DONE_M
		"class":
			return u.role != Stats.Role.BASE
		"attack":
			return u.damage_dealt > 0 or u.attack_timer > 0.0
		"ability":
			return u.ability_timers[0] > 0.0 or u.ability_timers[1] > 0.0 or u.dodge_timer > 0.0
		"goal":
			return false   # read for a few seconds, then on its own
	return true


static func current(game, u, delta: float) -> String:
	## The tip this player sees right now ("" for none); advances their list.
	## Called once per frame per pane, only while that pane draws.
	if not active(game, u):
		return ""
	var st := _state(u)
	if u.dead or u.downed or game.menu_open or game.guide_open or game.rank_open or game.game_over or game.prep_left > 0.0:
		return ""
	var action := StringName(u.act_prefix + "dodge")
	st.skip = st.skip + delta if InputMap.has_action(action) and Input.is_action_pressed(action) else 0.0
	if st.skip >= SKIP_HOLD:
		_finish(game, u, st)
		return ""
	while st.step < STEPS.size():
		var step: String = STEPS[st.step]
		st.shown += delta
		if _done(game, u, st, step) or st.shown >= (TIP_SECONDS if step != "goal" else 7.0):
			st.step += 1
			st.shown = 0.0
			continue
		return text_for(game, u, step)
	_finish(game, u, st)
	return ""


static func _finish(game, u, st: Dictionary) -> void:
	st.over = true
	for l in game.locals:
		if l != null and not _state(l).over:
			return
	game.tips_done = true
	game._save_settings()
