extends RefCounted
## The end-of-match screen: the result on a carved wooden header, then three
## slate panels framed in gold (your match and accolades, an animated XP
## tally that fills the account bar, and the MVP with each side's best), and
## a full scoreboard on Tab. game.gd takes a snapshot when the match ends
## (capture), banks bonus_xp() on the account, and hud.gd calls draw() every
## frame while the match is over. Numbers (accolades, XP) live in stats.gd.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

const WOOD := Color(0.47, 0.29, 0.14)
const WOOD_DARK := Color(0.27, 0.16, 0.08)
const SLATE := Color(0.12, 0.12, 0.14, 0.97)
const GOLD := Color(1.0, 0.8, 0.25)
const GOLD_DARK := Color(0.62, 0.44, 0.12)
const CREAM := Color(0.97, 0.93, 0.8)
const GREY := Color(0.62, 0.62, 0.66)
const GREEN := Color(0.33, 0.72, 0.25)
const LEAF := Color(0.36, 0.7, 0.3)
const XP := Color(1.0, 0.7, 0.2)

# XP lines in the tally: [source key, label, icon].
const SOURCES := [["combat", "Combat", "sword"], ["takedowns", "Takedowns", "might"], ["crown", "Crown", "crown"],
	["siege", "Siege", "hammer"], ["support", "Support", "mend"]]

var game
var me = null                 # the player's unit (or the MVP in a bot demo)
var team := 0                 # whose side "victory" is told from
var winner := -1
var started := 0.0            # seconds (engine clock) the screen opened
var xp_before := 0            # account XP before this match
var xp_after := 0
var lines: Array = []         # [label, icon, xp] in tally order
var accolades: Array = []     # earned Stats.ACCOLADES entries
var mvp = null
var main_role: int = Role.BASE
var show_board := false
var skip_to := -1.0           # a key press jumps the animation to its end
var _levels_rung := 0         # level-up chimes already played during the bar fill
var continue_rect := Rect2()
var board_rect := Rect2()


func capture(g, unit, winner_team: int) -> void:
	## Snapshot the match the moment it ends.
	game = g
	winner = winner_team
	me = unit
	if "--debug-end" in OS.get_cmdline_user_args() and unit:
		_debug_fill(g, unit)
	mvp = null
	for u in g.units:
		if mvp == null or g.unit_score(u) > g.unit_score(mvp):
			mvp = u
	if me == null:
		me = mvp
	team = me.team if me else 0
	main_role = _main_role(me) if me else Role.BASE
	accolades = earned(g, me) if me else []
	lines = []
	if me:
		for s in SOURCES:
			var n: int = me.xp_sources.get(s[0], 0)
			if n > 0:
				lines.append([s[1], s[2], n])
	var acc_xp := 0
	for a in accolades:
		acc_xp += a.xp
	if acc_xp > 0:
		lines.append(["Accolades", "upgrade", acc_xp])
	var result := "draw" if winner < 0 else ("win" if winner == team else "loss")
	lines.append([{"win": "Victory", "draw": "Draw", "loss": "Played to the end"}[result], "crown" if result == "win" else "guard",
		Stats.MATCH_BONUS[result]])
	started = Time.get_ticks_msec() / 1000.0


func _debug_fill(g, u) -> void:
	## Renders of the screen (--debug-end): a busy match for the player, and
	## --debug-end-xp=N as the account XP before it.
	u.kills = 9
	u.deaths = 3
	u.assists = 6
	u.captures = 1
	u.damage_dealt = 21
	u.healing = 2
	u.best_streak = 5
	u.peak_level = 5
	u.giant_kills = 1
	u.mastery = {Role.KNIGHT: 4}
	u.variants = {Role.KNIGHT: 0}
	u.xp_sources = {"combat": 210, "takedowns": 450, "crown": 125, "siege": 46, "support": 16}
	show_board = "--debug-end-board" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug-end-xp="):
			g.account_xp = int(arg.trim_prefix("--debug-end-xp="))


func bonus_xp() -> int:
	## Accolade XP, banked on the account with the match XP and the result bonus.
	var n := 0
	for a in accolades:
		n += a.xp
	return n


func set_account(before: int, after: int) -> void:
	xp_before = before
	xp_after = after
	_levels_rung = 0


static func earned(g, u) -> Array:
	## The accolades a unit earned this match (stats.gd ACCOLADES).
	var out: Array = []
	var most_kills := 0
	for o in g.units:
		if o != u:
			most_kills = maxi(most_kills, o.kills)
	var promoted := false
	for r in u.variants:
		promoted = true
	for a in Stats.ACCOLADES:
		var ok := false
		match a.key:
			"crown": ok = u.captures >= 1
			"slayer": ok = u.giant_kills >= 1
			"medic": ok = u.healing >= a.need
			"breaker": ok = u.xp_sources.get("siege", 0) >= a.need
			"streak": ok = u.best_streak >= a.need
			"wingman": ok = u.assists >= a.need
			"untouchable": ok = u.deaths == 0 and u.kills >= a.need
			"top": ok = u.kills >= a.need and u.kills > most_kills
			"promoted": ok = promoted
		if ok:
			out.append(a)
	return out


static func _main_role(u) -> int:
	## The class the unit put the most rank points into, else what it is now.
	var best := -1
	var role: int = u.role if u.role != Role.BASE else u.last_role
	for r in u.mastery:
		if u.mastery[r] > best:
			best = u.mastery[r]
			role = r
	return role


func elapsed() -> float:
	var t := Time.get_ticks_msec() / 1000.0 - started
	return maxf(t, skip_to) if skip_to >= 0.0 else t


func _tally_end() -> float:
	return 0.9 + lines.size() * 0.32 + 0.4


func done() -> bool:
	return elapsed() >= _tally_end() + 2.0


func skip() -> void:
	skip_to = _tally_end() + 2.0


# --- Drawing ------------------------------------------------------------------

func draw(h) -> void:
	var t := elapsed()
	var sz: Vector2 = h.size
	var cx := sz.x / 2.0
	h.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.02, 0.04, 0.7))
	# Warm torchlight vignette from the top.
	for i in 6:
		h.draw_rect(Rect2(0, 0, sz.x, 40 + i * 26), Color(0.9, 0.55, 0.2, 0.025))
	_header(h, cx, t)
	if show_board:
		# Two team blocks (title, header, a row per fighter) plus the frame.
		var rows: int = game.units.size()
		var r := Rect2(cx - 345, 150, 690, minf(2 * 56 + rows * 22 + 2 * 18 + 50, sz.y - 150 - 70))
		_panel(h, r, "SCOREBOARD")
		h._draw_scoreboard_table(Rect2(r.position + Vector2(16, 28), Vector2(r.size.x - 32, r.size.y - 40)))
	else:
		var top := 150.0
		var bottom := sz.y - 70.0
		var gap := 16.0
		var side_w := 360.0
		var mid_w := minf(420.0, sz.x - 2 * side_w - 4 * gap)
		var x0 := cx - mid_w / 2.0 - gap - side_w
		_you_panel(h, Rect2(x0, top, side_w, bottom - top), t)
		_xp_panel(h, Rect2(cx - mid_w / 2.0, top, mid_w, bottom - top), t)
		_mvp_panel(h, Rect2(cx + mid_w / 2.0 + gap, top, side_w, bottom - top), t)
	_buttons(h, cx, sz.y - 50)


func _header(h, cx: float, t: float) -> void:
	var outcome := "DRAW"
	var tone := Color(0.75, 0.75, 0.8)
	if winner >= 0:
		outcome = "VICTORY!" if winner == team else "DEFEAT"
		tone = GOLD.lerp(Color.WHITE, 0.25) if winner == team else Color(0.95, 0.55, 0.45)
	var pop := clampf(t / 0.45, 0.0, 1.0)
	var s := 0.7 + 0.3 * ease_out_back(pop)
	var w := 440.0 * s
	var hh := 70.0 * s
	var c := Vector2(cx, 62)
	# Leaf sprigs either side of the plank, like the menu headers.
	for side in [-1.0, 1.0]:
		for k in 3:
			var a: float = (-0.6 + 0.6 * k) * side
			var p: Vector2 = c + Vector2(side * (w / 2.0 + 6), -4 + k * 6)
			_leaf(h, p, Vector2(cos(a) * side, sin(a)).normalized(), 22 * s, LEAF.darkened(0.12 * k))
	var plank := Rect2(c - Vector2(w, hh) / 2.0, Vector2(w, hh))
	_wood(h, plank, 14, 4)
	h._text(Vector2(plank.position.x, c.y + 15 * s), outcome, int(44 * s), tone, HORIZONTAL_ALIGNMENT_CENTER, plank.size.x, 8)
	# The two crests, the winner's lit, the loser's dimmed.
	for side in 2:
		var x: float = cx + (-1 if side == 0 else 1) * 360.0
		var lit: bool = winner < 0 or winner == side
		var rect := Rect2(Vector2(x - 48, 14), Vector2(96, 96))
		if lit and winner >= 0:
			h.draw_circle(rect.get_center(), 50 + 4 * sin(t * 3.0), Color(1.0, 0.8, 0.3, 0.18))
		if not h._card("logo_elves" if side == 0 else "logo_humans", rect, true, not lit):
			h._icon("crest_forest" if side == 0 else "crest_kingdom", rect.get_center(), 22, Color.WHITE, not lit)
	var mins := int(game.match_clock()) / 60
	var secs := int(game.match_clock()) % 60
	var sub := "%s  %d  -  %d  %s     ·     %d:%02d%s" % [Stats.FACTIONS[0].name, game.score[0], game.score[1], Stats.FACTIONS[1].name,
		mins, secs, "  overtime" if game.overtime else ""]
	var sw: float = h._text_width(sub, 16) + 40
	var strip := Rect2(cx - sw / 2.0, 104, sw, 28)
	h._plate(strip, Color(0.1, 0.08, 0.07, 0.9), GOLD_DARK, 14, 2)
	h._text(Vector2(strip.position.x, strip.position.y + 20), sub, 16, CREAM, HORIZONTAL_ALIGNMENT_CENTER, strip.size.x, 3)


func _you_panel(h, r: Rect2, t: float) -> void:
	_panel(h, r, "YOUR MATCH")
	if me == null:
		return
	var a := clampf((t - 0.3) / 0.4, 0.0, 1.0)
	var pc := r.position + Vector2(56, 74)
	h._class_card(pc, 36, me.team, main_role)
	h._text(pc + Vector2(48, -6), me.display_name, 20, GOLD if me.is_player else CREAM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 110, 4)
	var cls: String = Stats.FACTIONS[me.team].roles[main_role] if main_role < Stats.FACTIONS[me.team].roles.size() else "Soldier"
	var vi: int = me.variants.get(main_role, -1)
	if vi >= 0:
		cls = Stats.VARIANTS[main_role][vi].name
	h._text(pc + Vector2(48, 16), "%s  ·  %s" % [Stats.FACTIONS[me.team].name, cls], 13, GREY, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 110, 2)
	var stats := [["KILLS", me.kills], ["DEATHS", me.deaths], ["ASSISTS", me.assists], ["CAPTURES", me.captures],
		["DAMAGE", me.damage_dealt], ["HEALING", me.healing], ["BEST STREAK", me.best_streak], ["PEAK LEVEL", me.peak_level]]
	var gw := (r.size.x - 36) / 4.0
	for i in stats.size():
		var cell := Rect2(r.position + Vector2(18 + (i % 4) * gw, 126 + (i / 4) * 58), Vector2(gw - 6, 52))
		h._plate(cell, Color(0.2, 0.18, 0.17, 0.95), Color(0.35, 0.28, 0.18), 8, 1)
		h._text(Vector2(cell.position.x, cell.position.y + 30), str(int(round(stats[i][1] * a))), 22, CREAM, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 3)
		h._text(Vector2(cell.position.x, cell.position.y + 45), stats[i][0], 8, GREY, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 1)
	var y := r.position.y + 258
	h._text(Vector2(r.position.x + 18, y), "ACCOLADES", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	y += 10
	if accolades.is_empty():
		h._text(Vector2(r.position.x + 18, y + 22), "None this time. Capture, heal, or topple a giant.", 12, GREY, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 2)
		return
	var room := int((r.end.y - y - 8) / 42.0)
	for i in mini(accolades.size(), room):
		var acc: Dictionary = accolades[i]
		var appear := clampf((t - 0.9 - i * 0.18) / 0.3, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var row := Rect2(Vector2(r.position.x + 18 + (1.0 - appear) * 30.0, y + 4 + i * 42), Vector2(r.size.x - 36, 38))
		h._plate(row, Color(0.3, 0.22, 0.1, 0.9 * appear), GOLD_DARK, 8, 1)
		h._icon(acc.icon, row.position + Vector2(20, 19), 7, Color.WHITE)
		h._text(row.position + Vector2(40, 17), acc.name, 14, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		h._text(row.position + Vector2(40, 31), acc.desc, 10, CREAM.darkened(0.15), HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 100, 1)
		h._text(Vector2(row.position.x, row.position.y + 24), "+%d XP" % acc.xp, 13, XP, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 10, 2)


func _xp_panel(h, r: Rect2, t: float) -> void:
	_panel(h, r, "EXPERIENCE")
	var y := r.position.y + 44
	var total := 0
	for i in lines.size():
		var start := 0.9 + i * 0.32
		var k := clampf((t - start) / 0.28, 0.0, 1.0)
		if k <= 0.0:
			break
		var line: Array = lines[i]
		var shown := int(round(line[2] * k))
		total += shown
		var row := Rect2(r.position + Vector2(18, y - r.position.y + i * 32), Vector2(r.size.x - 36, 28))
		if i % 2 == 0:
			h.draw_rect(row, Color(1, 1, 1, 0.035))
		h._icon(line[1], row.position + Vector2(14, 14), 6, Color.WHITE)
		h._text(row.position + Vector2(32, 19), line[0], 14, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		h._text(Vector2(row.position.x, row.position.y + 19), "+%d" % shown, 15, XP, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 8, 2)
	var ty := y + lines.size() * 32 + 6
	h.draw_line(Vector2(r.position.x + 18, ty), Vector2(r.end.x - 18, ty), GOLD_DARK, 2.0)
	h._text(Vector2(r.position.x + 18, ty + 30), "TOTAL", 16, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	h._text(Vector2(r.position.x, ty + 31), "+%d XP" % total, 24, XP.lerp(Color.WHITE, 0.2), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 26, 4)
	if game.demo and me and not me.is_player:
		h._text(Vector2(r.position.x, ty + 70), "(bot match: nothing is banked)", 12, GREY, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
		return
	# The account bar fills from where it was to where it is now, ringing at each level.
	var fill := clampf((t - _tally_end()) / 1.6, 0.0, 1.0)
	var xp_now := int(lerpf(xp_before, xp_after, ease_out(fill)))
	var level := Stats.account_level(xp_now)
	var before_level := Stats.account_level(xp_before)
	if level - before_level > _levels_rung:
		_levels_rung = level - before_level
		game.sfx.ui("level_up")
	var span: Array = Stats.account_span(xp_now)
	var by := ty + 64
	var badge := Vector2(r.position.x + 52, by + 30)
	var flash := level > before_level and fill > 0.0
	h.draw_circle(badge, 36, GOLD_DARK)
	h.draw_circle(badge, 33, GOLD if not flash else GOLD.lerp(Color.WHITE, 0.3 + 0.2 * sin(t * 8.0)))
	h.draw_circle(badge, 28, WOOD_DARK)
	h._text(Vector2(badge.x - 30, badge.y - 6), "LEVEL", 9, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 60, 1)
	h._text(Vector2(badge.x - 30, badge.y + 16), str(level), 24, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 60, 3)
	var bx := r.position.x + 100
	var bw := r.end.x - 20 - bx
	h._text(Vector2(bx, by + 10), Stats.rank_title(level).to_upper(), 16, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	if flash:
		h._text(Vector2(bx, by + 10), "LEVEL UP!", 16, Color(0.6, 1.0, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, bw, 3)
	var bar := Rect2(Vector2(bx, by + 20), Vector2(bw, 20))
	h._bar(bar, (float(span[0]) / span[1]) if span[1] > 0 else 1.0, XP)
	h._text(Vector2(bar.position.x, bar.position.y + 15), ("%d / %d XP" % [span[0], span[1]]) if span[1] > 0 else "MAX LEVEL", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 2)
	h._text(Vector2(bx, by + 60), _next_goal(level, span), 11, CREAM.darkened(0.1), HORIZONTAL_ALIGNMENT_LEFT, bw, 2)
	if level >= Stats.UNLOCK_LEVEL and before_level < Stats.UNLOCK_LEVEL:
		var u := Rect2(Vector2(r.position.x + 18, by + 76), Vector2(r.size.x - 36, 34))
		h._plate(u, Color(0.25, 0.12, 0.3, 0.95), GOLD, 8, 2)
		h._text(Vector2(u.position.x, u.position.y + 22), "UNLOCKED: Rogue, Shadowborn look, Moonlit Wildwood", 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, u.size.x, 2)


func _next_goal(level: int, span: Array) -> String:
	if span[1] < 0:
		return "Top of the ranks."
	if level < Stats.UNLOCK_LEVEL:
		return "Level %d unlocks the Rogue, the Shadowborn look and the Moonlit Wildwood." % Stats.UNLOCK_LEVEL
	for entry in Stats.RANK_TITLES:
		if entry[0] > level:
			return "Next rank: %s at level %d." % [entry[1], entry[0]]
	return "%d XP to level %d." % [span[1] - span[0], level + 1]


func _mvp_panel(h, r: Rect2, t: float) -> void:
	_panel(h, r, "MATCH MVP")
	if mvp == null:
		return
	var c := r.position + Vector2(r.size.x / 2.0, 92)
	h.draw_circle(c, 52 + 3 * sin(t * 2.5), Color(1.0, 0.8, 0.3, 0.15))
	h._class_card(c, 42, mvp.team, _main_role(mvp))
	h._crown(c + Vector2(0, -54), 1.3)
	h._text(Vector2(r.position.x, c.y + 66), mvp.display_name + ("  (you)" if mvp.is_player and mvp.display_name != "You" else ""), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
	h._text(Vector2(r.position.x, c.y + 84), "%s  ·  %d score" % [Stats.FACTIONS[mvp.team].name, game.unit_score(mvp)], 12, GREY, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
	h._text(Vector2(r.position.x, c.y + 102), "%d kills  ·  %d assists  ·  %d captures" % [mvp.kills, mvp.assists, mvp.captures], 12, CREAM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
	# Each side's best three by score.
	var y := c.y + 122
	for side in 2:
		var members: Array = game.units.filter(func(u): return u.team == side)
		members.sort_custom(func(a, b): return game.unit_score(a) > game.unit_score(b))
		var tc: Color = Stats.FACTIONS[side].color
		h._text(Vector2(r.position.x + 18, y + 14), Stats.FACTIONS[side].name.to_upper(), 11, tc.lightened(0.45), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		y += 18
		for i in mini(3, members.size()):
			var u = members[i]
			if y + 20 > r.end.y - 6:
				break
			var row := Rect2(Vector2(r.position.x + 18, y), Vector2(r.size.x - 36, 20))
			h.draw_rect(row, tc.darkened(0.7) if not u.is_player else Color(0.45, 0.35, 0.1, 0.6))
			h._text(row.position + Vector2(8, 15), "%d. %s" % [i + 1, u.display_name], 12, GOLD if u.is_player else CREAM, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 70, 2)
			h._text(Vector2(row.position.x, row.position.y + 15), str(game.unit_score(u)), 12, XP, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 8, 2)
			y += 22
		y += 4


func _buttons(h, cx: float, y: float) -> void:
	# Tab: the full scoreboard, on a wooden button; the green one goes on.
	board_rect = Rect2(cx - 300, y - 22, 200, 44)
	_wood(h, board_rect, 10, 3)
	h._keycap(board_rect.position + Vector2(30, 22), h._k("scoreboard"), 40)
	h._text(Vector2(board_rect.position.x + 54, board_rect.position.y + 29), "SUMMARY" if show_board else "SCOREBOARD", 15, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	continue_rect = Rect2(cx - 80, y - 26, 380, 52)
	var ready := done()
	var fill := GREEN if ready else GREEN.darkened(0.45)
	for side in [-1.0, 1.0]:
		var tip: float = continue_rect.position.x - 14 if side < 0 else continue_rect.end.x + 14
		var base_x: float = continue_rect.position.x + 6 if side < 0 else continue_rect.end.x - 6
		h.draw_colored_polygon(PackedVector2Array([Vector2(base_x, y - 22), Vector2(tip, y), Vector2(base_x, y + 22)]), GOLD_DARK)
	h._plate(continue_rect, fill, GOLD, 10, 3)
	h.draw_rect(Rect2(continue_rect.position + Vector2(6, 5), Vector2(continue_rect.size.x - 12, 16)), Color(1, 1, 1, 0.12))
	h._keycap(continue_rect.position + Vector2(36, 26), h._k("restart"), 44)
	h._text(Vector2(continue_rect.position.x + 40, continue_rect.position.y + 35), "CONTINUE" if ready else "SKIP", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, continue_rect.size.x - 40, 5)


func _panel(h, r: Rect2, title: String) -> void:
	h._plate(r, SLATE, GOLD_DARK, 12, 3)
	var tw: float = h._text_width(title, 15) + 44
	var tab := Rect2(Vector2(r.position.x + r.size.x / 2.0 - tw / 2.0, r.position.y - 14), Vector2(tw, 30))
	_wood(h, tab, 8, 2)
	h._text(Vector2(tab.position.x, tab.position.y + 21), title, 15, GOLD.lerp(Color.WHITE, 0.2), HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 4)


func _wood(h, r: Rect2, radius: int, border: int) -> void:
	## A carved plank: warm wood with grain lines inside a gold rim.
	h._plate(r, WOOD, GOLD, radius, border)
	var inner := r.grow(-border - 3)
	var n := maxi(2, int(inner.size.y / 12.0))
	for i in range(1, n):
		var y := inner.position.y + inner.size.y * i / float(n)
		h.draw_line(Vector2(inner.position.x + 4, y), Vector2(inner.end.x - 4, y), WOOD_DARK.lerp(WOOD, 0.4), 1.0)
	h.draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.35)), Color(1, 0.9, 0.7, 0.08))
	for x in [inner.position.x + 6, inner.end.x - 6]:
		h.draw_circle(Vector2(x, r.get_center().y), 2.5, GOLD_DARK)


func _leaf(h, base: Vector2, dir: Vector2, length: float, color: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		pts.append(base + dir * length * k + side * sin(k * PI) * length * 0.32)
	for i in range(11, 0, -1):
		var k := i / 12.0
		pts.append(base + dir * length * k - side * sin(k * PI) * length * 0.32)
	h.draw_colored_polygon(pts, color)
	h.draw_line(base, base + dir * length * 0.9, color.darkened(0.3), 1.2)


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func ease_out_back(x: float) -> float:
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
