extends RefCounted
## The end-of-match screen: the result on a carved wooden header, then three
## slate panels framed in gold (your match and accolades, an animated XP
## tally that fills the account bar, and the MVP with each side's best), and
## a full scoreboard on Tab. game.gd takes a snapshot when the match ends
## (capture), banks bonus_xp() on the account, and hud.gd calls draw() every
## frame while the match is over. Numbers (accolades, XP) live in stats.gd.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role
const Scoreboard = preload("res://scripts/scoreboard.gd")

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
const SOURCES := [["combat", "Combat", "vanguard"], ["takedowns", "Takedowns", "takedown"], ["crown", "Crown", "crown"],
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
var result := "loss"          # "win" | "draw" | "loss", from the player's side
var reward_gold := 0          # match rewards (Stats.MATCH_GOLD / MATCH_SHARDS)
var reward_shards := 0


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
	result = "draw" if winner < 0 else ("win" if winner == team else "loss")
	reward_gold = Stats.MATCH_GOLD[result]
	reward_shards = Stats.MATCH_SHARDS[result]
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
# Laid out to Faisal's reference (reference-renders/match-summary-target-
# 2026-10-08.png) on the 1280x720 canvas: the HUD's score bands and crest
# shields flank a torn-banner plank with the result, a "Match Time" pill
# under it, then three slate panels on wooden title tabs (your match, the
# experience tally with rewards, the scoreboard) and the two buttons.

const TILE := Color(0.14, 0.13, 0.14, 0.96)
const TILE_EDGE := Color(0.3, 0.27, 0.24)
const ROW := Color(1, 1, 1, 0.04)
const ACC_FILL := Color(0.3, 0.21, 0.09, 0.95)
const PANEL := Color(0.1, 0.1, 0.11, 0.96)


func draw(h) -> void:
	var t := elapsed()
	var sz: Vector2 = h.size
	var cx := sz.x / 2.0
	h.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.02, 0.04, 0.5))
	_header(h, cx, t)
	var top := 178.0
	var bottom := sz.y - 84.0
	if show_board:
		var rows: int = game.units.size()
		var r := Rect2(cx - 390, top, 780, minf(Scoreboard.table_height(rows, 30.0) + 44.0, bottom - top))
		_panel(h, r, "SCOREBOARD")
		h._draw_scoreboard_table(Rect2(r.position + Vector2(16, 28), Vector2(r.size.x - 32, r.size.y - 40)))
	else:
		_you_panel(h, Rect2(cx - 609, top, 413, bottom - top), t)
		_xp_panel(h, Rect2(cx - 181, top, 362, bottom - top), t)
		_board_panel(h, Rect2(cx + 195, top, 421, bottom - top), t)
	_buttons(h, cx, sz.y - 44)


func _bold(h, pos: Vector2, text: String, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 3) -> void:
	## Rounded bold lettering (the top bar's face) with a dark outline.
	var f: Font = h.bar_font if h.bar_font else h.font
	if outline > 0:
		h.draw_string_outline(f, pos, text, align, width, fs, outline, Color(0.05, 0.04, 0.06, 0.8))
	h.draw_string(f, pos, text, align, width, fs, col)


func _header(h, cx: float, t: float) -> void:
	var outcome := "DRAW"
	var face := Color(0.85, 0.85, 0.9)
	var drop := Color(0.45, 0.45, 0.5)
	var cloth := Color(0.55, 0.55, 0.6)
	if winner >= 0:
		outcome = "VICTORY!" if winner == team else "DEFEAT"
		face = Color(1.0, 0.85, 0.3) if winner == team else Color(0.98, 0.45, 0.4)
		drop = Color(0.75, 0.45, 0.08) if winner == team else Color(0.6, 0.1, 0.1)
		cloth = Color(0.85, 0.6, 0.12) if winner == team else Color(0.68, 0.1, 0.1)
	var pop := clampf(t / 0.45, 0.0, 1.0)
	var s := 0.8 + 0.2 * ease_out_back(pop)
	var bar_y := 48.0
	# The two score bands and crest shields, like the HUD's top bar.
	for side in 2:
		var dir := -1.0 if side == 0 else 1.0
		var band := Rect2(Vector2(cx - 295.0 if side == 0 else cx + 105.0, bar_y), Vector2(190, 46))
		h._score_band(band, h.SCORE_BANDS[side])
		var mid := cx + dir * 200.0
		_bold(h, Vector2(mid - 60, bar_y + 18), Stats.FACTIONS[side].name.to_upper(), 14, Color(1.0, 0.95, 0.86), HORIZONTAL_ALIGNMENT_CENTER, 120, 4)
		_bold(h, Vector2(mid - 60, bar_y + 42), str(game.score[side]), 26, Color(1.0, 0.95, 0.84), HORIZONTAL_ALIGNMENT_CENTER, 120, 5)
		h._crest_shield(Vector2(cx + dir * 320.0, bar_y + 24), 62.0, 76.0, side)
	# Torn cloth either side of the plank, then the plank itself.
	var plank := Rect2(Vector2(cx - 100 * s, 36 + (68 - 68 * s) / 2.0), Vector2(200 * s, 68 * s))
	for side in [-1.0, 1.0]:
		var x0: float = cx + side * 98.0 * s
		var py := plank.position.y
		var pe := plank.end.y
		# A tattered tail hanging off each end of the plank.
		var pts := PackedVector2Array([Vector2(x0, py + 4), Vector2(x0 + side * 30, py + 8), Vector2(x0 + side * 38, py + 28),
			Vector2(x0 + side * 32, pe + 4), Vector2(x0 + side * 27, pe + 30), Vector2(x0 + side * 19, pe + 10),
			Vector2(x0 + side * 12, pe + 36), Vector2(x0 + side * 4, pe + 12), Vector2(x0, pe - 2)])
		h.draw_colored_polygon(pts, cloth.darkened(0.3))
		var inner := PackedVector2Array()
		for q in pts:
			inner.append(q.lerp(Vector2(x0 + side * 16, plank.get_center().y + 10), 0.15))
		h.draw_colored_polygon(inner, cloth)
		h.draw_line(Vector2(x0 + side * 8, py + 12), Vector2(x0 + side * 14, pe + 20), cloth.darkened(0.2), 1.5)
		pts.append(pts[0])
		h.draw_polyline(pts, Color(0.15, 0.05, 0.05, 0.8), 1.5)
	_wood(h, plank, 10, 3)
	# Steel spikes nailed through the plank ends.
	for side in [-1.0, 1.0]:
		var sx: float = cx + side * 96.0 * s
		for yy in [plank.position.y + 12, plank.end.y - 12]:
			h.draw_colored_polygon(PackedVector2Array([Vector2(sx, yy - 6), Vector2(sx + side * 16, yy), Vector2(sx, yy + 6)]), Color(0.7, 0.72, 0.78))
			h.draw_circle(Vector2(sx, yy), 3.0, Color(0.85, 0.87, 0.92))
	h._title_text(Vector2(plank.position.x, plank.position.y + 50 * s), outcome, int(38 * s), face, drop, Color(0.12, 0.04, 0.04), plank.size.x)
	# Match time pill.
	var mins := int(game.match_clock()) / 60
	var secs := int(game.match_clock()) % 60
	var pill := Rect2(Vector2(cx - 90, 113), Vector2(180, 28))
	h._plate(pill, Color(0.08, 0.07, 0.07, 0.95), Color(0.45, 0.32, 0.12), 12, 2)
	_bold(h, Vector2(pill.position.x + 14, pill.position.y + 20), "Match Time", 13, Color(0.75, 0.72, 0.68), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_bold(h, Vector2(pill.position.x, pill.position.y + 20), "%d:%02d%s" % [mins, secs, "+" if game.overtime else ""], 15, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, pill.size.x - 14, 2)


func _tile(h, r: Rect2) -> void:
	h._plate(r, TILE, TILE_EDGE, 8, 1)


func _you_panel(h, r: Rect2, t: float) -> void:
	_panel(h, r, "YOUR MATCH")
	if me == null:
		return
	var a := clampf((t - 0.3) / 0.4, 0.0, 1.0)
	var stats := [["KILLS", me.kills, "vanguard"], ["DEATHS", me.deaths, "skull"], ["ASSISTS", me.assists, "assist"], ["CAPTURES", me.captures, "flag"],
		["DAMAGE", me.damage_dealt, "burst"], ["HEALING", me.healing, "potion"], ["BEST STREAK", me.best_streak, "fireball"], ["PEAK LEVEL", me.peak_level, "rank"]]
	var gw := (r.size.x - 32.0 + 9.0) / 4.0
	for i in stats.size():
		var cell := Rect2(r.position + Vector2(16 + (i % 4) * gw, 30 + (i / 4) * 86), Vector2(gw - 9, 77))
		_tile(h, cell)
		h._icon(stats[i][2], cell.position + Vector2(cell.size.x / 2.0, 22), 9.5, Color.WHITE)
		_bold(h, Vector2(cell.position.x, cell.position.y + 56), str(int(round(stats[i][1] * a))), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 3)
		_bold(h, Vector2(cell.position.x, cell.position.y + 70), stats[i][0], 9, Color(0.85, 0.83, 0.8), HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 2)
	var y := r.position.y + 214.0
	_bold(h, Vector2(r.position.x + 16, y), "ACCOLADES", 14, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	y += 8
	if accolades.is_empty():
		h._text(Vector2(r.position.x + 16, y + 22), "None this time. Capture, heal, or topple a giant.", 12, GREY, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 2)
		return
	var room := int((r.end.y - y - 6) / 44.0)
	for i in mini(accolades.size(), room):
		var acc: Dictionary = accolades[i]
		var appear := clampf((t - 0.9 - i * 0.18) / 0.3, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var row := Rect2(Vector2(r.position.x + 12 + (1.0 - appear) * 30.0, y + i * 44), Vector2(r.size.x - 24, 38))
		h._plate(row, Color(ACC_FILL.r, ACC_FILL.g, ACC_FILL.b, ACC_FILL.a * appear), GOLD_DARK, 7, 1)
		var sq := Rect2(row.position + Vector2(4, 4), Vector2(30, 30))
		h._plate(sq, Color(0.42, 0.3, 0.12), Color(0.7, 0.52, 0.2), 5, 1)
		h._icon(acc.icon, sq.get_center(), 7.0, Color.WHITE)
		_bold(h, row.position + Vector2(44, 17), acc.name, 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		h._text(row.position + Vector2(44, 31), acc.desc, 10, CREAM, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 120, 1)
		_bold(h, Vector2(row.position.x, row.position.y + 24), "+%d XP" % acc.xp, 14, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 12, 2)


func _xp_panel(h, r: Rect2, t: float) -> void:
	_panel(h, r, "EXPERIENCE")
	var y := r.position.y + 26.0
	var total := 0
	for i in lines.size():
		var start := 0.9 + i * 0.32
		var k := clampf((t - start) / 0.28, 0.0, 1.0)
		if k <= 0.0:
			break
		var line: Array = lines[i]
		var shown := int(round(line[2] * k))
		total += shown
		var row := Rect2(Vector2(r.position.x + 12, y + i * 29), Vector2(r.size.x - 24, 27))
		if i % 2 == 0:
			h.draw_rect(row, ROW)
		h._icon(line[1], row.position + Vector2(16, 13.5), 7.0, Color.WHITE)
		_bold(h, row.position + Vector2(36, 18), line[0], 13, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_bold(h, Vector2(row.position.x, row.position.y + 19), "+%d" % shown, 15, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 10, 2)
	var ty := r.position.y + 26.0 + 7 * 29.0 + 6.0
	h.draw_line(Vector2(r.position.x + 14, ty), Vector2(r.end.x - 14, ty), Color(0.5, 0.36, 0.14), 2.0)
	_bold(h, Vector2(r.position.x + 18, ty + 32), "TOTAL", 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var total_s := "+%d XP" % total
	var f: Font = h.bar_font if h.bar_font else h.font
	var tw: float = f.get_string_size(total_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	h._icon("xp", Vector2(r.end.x - 24 - tw - 20, ty + 24), 8.0, Color.WHITE)
	_bold(h, Vector2(r.position.x, ty + 33), total_s, 24, GOLD.lerp(Color.WHITE, 0.15), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18, 4)
	# The account bar between its two level pills, filling after the tally.
	var fill := clampf((t - _tally_end()) / 1.6, 0.0, 1.0)
	var xp_now := int(lerpf(xp_before, xp_after, ease_out(fill)))
	var level := Stats.account_level(xp_now)
	var before_level := Stats.account_level(xp_before)
	if level - before_level > _levels_rung:
		_levels_rung = level - before_level
		game.sfx.ui("level_up")
	var span: Array = Stats.account_span(xp_now)
	var by := ty + 52.0
	var left_pill := Rect2(Vector2(r.position.x + 16, by), Vector2(56, 22))
	var right_pill := Rect2(Vector2(r.end.x - 72, by), Vector2(56, 22))
	for p in [left_pill, right_pill]:
		h._plate(p, Color(0.1, 0.09, 0.08, 0.96), Color(0.5, 0.36, 0.14), 6, 1)
	_bold(h, Vector2(left_pill.position.x, by + 16), "Lv %d" % level, 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, left_pill.size.x, 2)
	_bold(h, Vector2(right_pill.position.x, by + 16), "Lv %d" % mini(level + 1, Stats.ACCOUNT_MAX_LEVEL), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, right_pill.size.x, 2)
	var bar := Rect2(Vector2(left_pill.end.x + 8, by + 1), Vector2(right_pill.position.x - left_pill.end.x - 16, 20))
	h._plate(bar, Color(0.08, 0.07, 0.07), Color(0.5, 0.36, 0.14), 8, 1)
	var frac: float = (float(span[0]) / span[1]) if span[1] > 0 else 1.0
	var inner := bar.grow(-3)
	if frac > 0.0:
		var fw := Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y))
		h._plate(fw, Color(1.0, 0.72, 0.15), Color(0.85, 0.55, 0.1), 6, 1)
		h.draw_rect(Rect2(fw.position + Vector2(2, 2), Vector2(maxf(fw.size.x - 4, 0.0), 5)), Color(1, 1, 0.8, 0.35))
	_bold(h, Vector2(bar.position.x, by + 15), ("%d / %d XP" % [span[0], span[1]]) if span[1] > 0 else "MAX LEVEL", 10, Color(0.15, 0.1, 0.03) if frac > 0.5 else CREAM, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 0)
	if level > before_level and fill > 0.0:
		_bold(h, Vector2(r.position.x, by - 6), "LEVEL UP!", 12, Color(0.6, 1.0, 0.55), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
	# Rewards.
	var ry := by + 46.0
	h._icon("xp", Vector2(r.position.x + 28, ry - 5), 6.0, Color.WHITE)
	_bold(h, Vector2(r.position.x + 44, ry), "REWARDS", 14, Color(0.9, 0.88, 0.84), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var banked: bool = not (game.demo and me and not me.is_player)
	var rewards := [["+%d Gold" % reward_gold, "coin", GOLD], ["+%d Shards" % reward_shards, "shard", Color(0.45, 0.75, 1.0)],
		["Match Chest", "chest", Color.WHITE], ["Ranked (Locked)", "lock", Color(0.6, 0.6, 0.64)]]
	var gw := (r.size.x - 32.0 + 6.0) / 4.0
	for i in rewards.size():
		var cell := Rect2(Vector2(r.position.x + 16 + i * gw, ry + 10), Vector2(gw - 6, 72))
		_tile(h, cell)
		var dim: bool = i == 3
		h._icon(rewards[i][1], cell.position + Vector2(cell.size.x / 2.0, 28), 11.0 if i < 3 else 9.0, Color.WHITE, dim)
		_bold(h, Vector2(cell.position.x, cell.position.y + 64), rewards[i][0], 9 if i == 3 else 10, rewards[i][2], HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 2)
	if not banked:
		h._text(Vector2(r.position.x, ry + 96), "(bot match: nothing is banked)", 10, GREY, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)


const BOARD_COLS := [["SCORE", 0.32], ["K", 0.43], ["D", 0.52], ["A", 0.61], ["CAP", 0.705], ["DMG", 0.8], ["PING", 0.905]]


func _board_panel(h, r: Rect2, _t: float) -> void:
	_panel(h, r, "SCOREBOARD")
	var block_h := (r.size.y - 36.0) / 2.0
	for side in 2:
		var members: Array = game.units.filter(func(u): return u.team == side)
		members.sort_custom(func(a, b): return game.unit_score(a) > game.unit_score(b))
		var block := Rect2(Vector2(r.position.x + 7, r.position.y + 14 + side * (block_h + 8)), Vector2(r.size.x - 14, block_h))
		var tc: Color = h.SCORE_BANDS[side]
		h._plate(block, tc.darkened(0.6), tc.darkened(0.15), 8, 1)
		var row_h := minf(34.0, (block.size.y - 34.0) / maxf(members.size(), 1.0))
		_bold(h, block.position + Vector2(12, 23), Stats.FACTIONS[side].name.to_upper(), 15, Color(1.0, 0.95, 0.88), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		for c in BOARD_COLS:
			var cx: float = block.position.x + block.size.x * c[1]
			_bold(h, Vector2(cx - 30, block.position.y + 21), c[0], 9, Color(0.9, 0.85, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 60, 2)
		h.draw_line(block.position + Vector2(8, 34), Vector2(block.end.x - 8, block.position.y + 34), Color(1, 1, 1, 0.12), 1.0)
		for i in members.size():
			var u = members[i]
			var row := Rect2(Vector2(block.position.x + 4, block.position.y + 36 + i * row_h), Vector2(block.size.x - 8, row_h - 2))
			if u.is_player:
				h._plate(row, Color(0.5, 0.36, 0.1, 0.95), GOLD, 6, 1)
			elif i % 2 == 1:
				h.draw_rect(row, Color(0, 0, 0, 0.12))
			var ty: float = row.get_center().y + 5.0
			_bold(h, row.position + Vector2(8, ty - row.position.y), "%d." % (i + 1), 11, Color(0.85, 0.82, 0.78), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			_bold(h, row.position + Vector2(26, ty - row.position.y), u.display_name, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, block.size.x * 0.32 - 60, 2)
			var values := [str(game.unit_score(u)), str(u.kills), str(u.deaths), str(u.assists), str(u.captures), str(u.damage_dealt), _ping(u)]
			for c in BOARD_COLS.size():
				var cx: float = block.position.x + block.size.x * BOARD_COLS[c][1]
				var col := GOLD if c == 0 else Color(0.95, 0.93, 0.9)
				_bold(h, Vector2(cx - 30, ty), values[c], 12, col, HORIZONTAL_ALIGNMENT_CENTER, 60, 2)


static func _ping(u) -> String:
	## Bots and couch players have no network trip; online play fills this in.
	return "—" if not u.is_player else "0"


func _buttons(h, cx: float, y: float) -> void:
	# Tab: the full scoreboard, on a wooden button; the green one goes on.
	board_rect = Rect2(cx - 598, y - 21, 172, 42)
	_wood(h, board_rect, 8, 3)
	h._keycap(board_rect.position + Vector2(34, 21), h._k("scoreboard"), 40)
	_bold(h, Vector2(board_rect.position.x + 62, board_rect.position.y + 27), "SUMMARY" if show_board else "SCOREBOARD", 14, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	continue_rect = Rect2(cx - 134, y - 24, 268, 48)
	var ready := done()
	var fill := Color(0.36, 0.72, 0.22) if ready else Color(0.36, 0.72, 0.22).darkened(0.4)
	for side in [-1.0, 1.0]:
		var base := Vector2(continue_rect.position.x if side < 0 else continue_rect.end.x, y + 4)
		for k in 2:
			_leaf(h, base + Vector2(side * 2, 2 - k * 10), Vector2(side, -0.35 - k * 0.5).normalized(), 20 - k * 4, LEAF.darkened(0.15 * k))
	h._plate(continue_rect, fill, Color(0.75, 0.55, 0.18), 8, 3)
	h.draw_rect(Rect2(continue_rect.position + Vector2(6, 5), Vector2(continue_rect.size.x - 12, 14)), Color(1, 1, 1, 0.14))
	h._keycap(continue_rect.position + Vector2(34, 24), h._k("restart"), 40)
	_bold(h, Vector2(continue_rect.position.x + 50, continue_rect.position.y + 32), "CONTINUE" if ready else "SKIP", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, continue_rect.size.x - 60, 4)


func _panel(h, r: Rect2, title: String) -> void:
	h._plate(r, PANEL, Color(0.55, 0.38, 0.14), 10, 3)
	h.draw_rect(r.grow(-5), Color(0.4, 0.28, 0.1, 0.35), false, 1.0)
	var tw: float = 222.0
	var tab := Rect2(Vector2(r.position.x + r.size.x / 2.0 - tw / 2.0, r.position.y - 16), Vector2(tw, 32))
	_wood(h, tab, 7, 2)
	_bold(h, Vector2(tab.position.x, tab.position.y + 22), title, 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 3)


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
