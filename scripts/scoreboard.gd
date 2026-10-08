extends RefCounted
## The scoreboard: the Tab overlay during a match, the pause menu tab and the
## end-of-match board all draw through here. Columns run SCORE, then K, D, A,
## CAPS and DMG; each side is a slate block under a team band with its crest,
## captures and kills, best score first. hud.gd passes itself in as `h` for
## its drawing helpers (plates, text, icons, cards).

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

const SLATE := Color(0.12, 0.12, 0.14, 0.97)
const ROW := Color(1, 1, 1, 0.035)
const GOLD := Color(1.0, 0.8, 0.25)
const GOLD_DARK := Color(0.62, 0.44, 0.12)
const CREAM := Color(0.97, 0.93, 0.8)
const GREY := Color(0.62, 0.62, 0.66)
const WOOD := Color(0.47, 0.29, 0.14)
const WOOD_DARK := Color(0.27, 0.16, 0.08)
const DEAD := Color(1.0, 0.55, 0.45)

# The stat columns: [header, x as a fraction of the table width].
const COLS := [["SCORE", 0.53], ["K", 0.645], ["D", 0.725], ["A", 0.805], ["CAPS", 0.885], ["DMG", 0.96]]


static func draw_overlay(h) -> void:
	## Tab during a match: the board in a gold-framed slate panel under the
	## HUD's score bar, titled on a wooden tab.
	var game = h.game
	if "--debug-score-fill" in OS.get_cmdline_user_args() and not game.has_meta("score_filled"):
		_debug_fill(game)
	h.draw_rect(Rect2(Vector2.ZERO, h.size), Color(0.03, 0.02, 0.04, 0.5))
	var rows: int = game.units.size()
	var w := minf(820.0, h.size.x - 40.0)
	var table_h := table_height(rows, 30.0)
	# The score and clock stay on the HUD's top bar; the board sits below it.
	var rect := Rect2(h.size.x / 2.0 - w / 2.0, 84.0, w, table_h + 54.0)
	h._plate(rect, SLATE, GOLD_DARK, 14, 3)
	var tw: float = h._text_width("SCOREBOARD", 16) + 48
	var tab := Rect2(Vector2(rect.get_center().x - tw / 2.0, rect.position.y - 15), Vector2(tw, 32))
	wood(h, tab, 8, 2)
	h._text(Vector2(tab.position.x, tab.position.y + 23), "SCOREBOARD", 16, GOLD.lerp(Color.WHITE, 0.2), HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 4)
	draw_table(h, Rect2(rect.position + Vector2(18, 22), Vector2(rect.size.x - 36, table_h)), true)
	h._text(Vector2(rect.position.x, rect.end.y - 12), "Score: kill %d · assist %d · capture %d · heart healed %d · heart of damage %d · rank point %d" % [Stats.SCORE_KILL,
		Stats.SCORE_ASSIST, Stats.SCORE_CAPTURE, Stats.SCORE_HEAL, Stats.SCORE_DAMAGE, Stats.SCORE_UPGRADE], 10, GREY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


static func table_height(rows: int, row_h: float) -> float:
	## Column header + two team bands + every row + the gap between teams.
	return 22.0 + 2.0 * 38.0 + rows * row_h + 12.0


static func draw_table(h, rect: Rect2, live: bool = false) -> void:
	## Both sides, best score first. live adds hearts, respawn timers and
	## the crown carrier; the end board shows each fighter's peak level.
	var game = h.game
	var units: Array = game.units
	var row_h := clampf((rect.size.y - table_height(units.size(), 0.0)) / maxf(units.size(), 1.0), 22.0, 34.0)
	var x0 := rect.position.x
	var w := rect.size.x
	var best := 1
	for u in units:
		best = maxi(best, game.unit_score(u))
	# Column headers, once, over both teams.
	var y := rect.position.y
	h._text(Vector2(x0 + 52, y + 14), "PLAYER", 10, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	for c in COLS:
		h._text(Vector2(x0 + w * c[1] - 30, y + 14), c[0], 10, GOLD if c[0] == "SCORE" else GREY, HORIZONTAL_ALIGNMENT_CENTER, 60, 1)
	y += 22.0
	for t in 2:
		var members: Array = units.filter(func(u): return u.team == t)
		members.sort_custom(func(a, b): return game.unit_score(a) > game.unit_score(b))
		y = _team(h, t, members, Rect2(x0, y, w, 38.0 + members.size() * row_h), row_h, best, live) + 12.0


static func _team(h, t: int, members: Array, block: Rect2, row_h: float, best: int, live: bool) -> float:
	var game = h.game
	var tc: Color = Stats.FACTIONS[t].color
	var leading: bool = game.score[t] > game.score[1 - t]
	h._plate(block, tc.darkened(0.78), GOLD if leading else tc.darkened(0.2), 10, 2)
	# Team band: crest, name, capture crowns, kills.
	var band := Rect2(block.position + Vector2(2, 2), Vector2(block.size.x - 4, 34))
	h.draw_rect(band, tc.darkened(0.45))
	h.draw_rect(Rect2(band.position, Vector2(band.size.x, 2)), tc.lightened(0.2))
	if not h._card("crest_elf" if t == 0 else "crest_human", Rect2(band.position + Vector2(8, 2), Vector2(30, 30))):
		h._icon("crest_forest" if t == 0 else "crest_kingdom", band.position + Vector2(23, 17), 9, Color.WHITE)
	h._text(band.position + Vector2(46, 24), Stats.FACTIONS[t].name.to_upper(), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	var name_w: float = h._text_width(Stats.FACTIONS[t].name.to_upper(), 17)
	if leading:
		h._text(band.position + Vector2(58 + name_w, 23), "LEADING", 10, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var kills := 0
	for u in members:
		kills += u.kills
	var right := band.end.x - 12
	h._text(Vector2(band.position.x, band.position.y + 23), "%d KILLS" % kills, 12, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, right - band.position.x, 2)
	var cx: float = right - h._text_width("%d KILLS" % kills, 12) - 22
	for i in Stats.CAPTURES_TO_WIN:
		h._crown(Vector2(cx - i * 26, band.position.y + 17), 0.9, GOLD if i < game.score[t] else Color(0.3, 0.28, 0.25))
	# One row per fighter.
	for i in members.size():
		var u = members[i]
		var r := Rect2(Vector2(block.position.x + 4, band.end.y + 2 + i * row_h), Vector2(block.size.x - 8, row_h - 2))
		_row(h, u, i, r, tc, best, live)
	return block.end.y


static func _row(h, u, place: int, r: Rect2, tc: Color, best: int, live: bool) -> void:
	var game = h.game
	var score: int = game.unit_score(u)
	var dim: bool = live and u.dead
	if u.is_player:
		h.draw_rect(r, Color(0.5, 0.38, 0.1, 0.55))
		h.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), GOLD)
	elif place % 2 == 0:
		h.draw_rect(r, ROW)
	# A faint bar behind the row, as long as this score against the best.
	h.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.5 * float(score) / best, r.size.y)), Color(tc.r, tc.g, tc.b, 0.12))
	var mid := r.position.y + r.size.y / 2.0
	var text_y := mid + 5.0
	var fs := 13 if r.size.y >= 26 else 12
	h._text(Vector2(r.position.x + 8, text_y), str(place + 1), 11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	# Class badge.
	var badge := Vector2(r.position.x + 34, mid)
	var br := minf(r.size.y * 0.42, 12.0)
	h.draw_circle(badge, br + 1.5, GOLD_DARK if not dim else Color(0.3, 0.3, 0.3))
	h.draw_circle(badge, br, tc.darkened(0.5))
	var role: int = u.role if not (u.dead and u.role == Role.BASE) else u.last_role
	var icon: String = u.variant().get("icon", h._class_icon(role)) if role == u.role and role != Role.BASE else h._class_icon(role)
	h._icon(icon, badge, br * 0.55, Color.WHITE, dim)
	# Name, then class and level (or the respawn count while dead).
	var nx := r.position.x + 52
	var name_col := CREAM if not u.is_player else GOLD
	if dim:
		name_col = name_col.darkened(0.45)
	var label: String = u.display_name
	if u.veteran == 2:
		label = "☠ " + label
	elif u.veteran == 1:
		label = "★ " + label
	var two_lines := r.size.y >= 28
	h._text(Vector2(nx, (mid - 1.0) if two_lines else text_y), label, fs, name_col, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var after: float = nx + h._text_width(label, fs) + 8
	if u.carrying:
		h._crown(Vector2(after + 8, mid - 5 if two_lines else mid), 0.6)
		after += 22
	var lv: int = u.level if live else u.peak_level
	var sub := "%s  ·  Lv %d" % [u.role_name(), lv]
	if dim:
		sub = "back in %ds" % ceili(u.respawn_timer)
	if two_lines:
		h._text(Vector2(nx, mid + 11), sub, 10, DEAD if dim else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	else:
		h._text(Vector2(after, text_y), sub, 10, DEAD if dim else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if live and not u.dead and two_lines:
		var hx: float = r.position.x + r.size.x * 0.46 - Stats.MAX_HEARTS * 11.0
		h._hearts(Vector2(hx, mid), u.hearts, 0.28, 11.0)
	# Stats: score in a gold pill, then K, D, A, CAPS, DMG.
	var values := [score, u.kills, u.deaths, u.assists, u.captures, u.damage_dealt]
	for c in COLS.size():
		var cx: float = r.position.x - 4 + (r.size.x + 8) * COLS[c][1]
		if c == 0:
			var pill := Rect2(Vector2(cx - 30, mid - minf(r.size.y * 0.4, 11.0)), Vector2(60, minf(r.size.y * 0.8, 22.0)))
			h._plate(pill, Color(0.22, 0.16, 0.06, 0.95), GOLD_DARK if not u.is_player else GOLD, 8, 1)
			h._text(Vector2(pill.position.x, text_y), str(values[c]), 14, GOLD.lerp(Color.WHITE, 0.2), HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 2)
		else:
			var col := Color.WHITE if values[c] > 0 else GREY.darkened(0.2)
			if dim:
				col = col.darkened(0.4)
			h._text(Vector2(cx - 30, text_y), str(values[c]), fs, col, HORIZONTAL_ALIGNMENT_CENTER, 60, 2)


static func wood(h, r: Rect2, radius: int, border: int) -> void:
	## A carved plank: warm wood with grain lines inside a gold rim.
	h._plate(r, WOOD, GOLD, radius, border)
	var inner := r.grow(-border - 3)
	var n := maxi(2, int(inner.size.y / 12.0))
	for i in range(1, n):
		var y := inner.position.y + inner.size.y * i / float(n)
		h.draw_line(Vector2(inner.position.x + 4, y), Vector2(inner.end.x - 4, y), WOOD_DARK.lerp(WOOD, 0.4), 1.0)
	h.draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.35)), Color(1, 0.9, 0.7, 0.08))


static func _debug_fill(game) -> void:
	## Renders (--debug-score --debug-score-fill): a mid-match spread of stats.
	game.set_meta("score_filled", true)
	var i := 0
	for u in game.units:
		i += 1
		u.kills = (i * 7) % 11
		u.deaths = (i * 5) % 7
		u.assists = (i * 3) % 9
		u.damage_dealt = u.kills * 2 + (i * 13) % 9
		u.captures = 1 if i == 3 else 0
		u.level = 1 + (i * 3) % 6
	game.score = [1, 0]
	if game.units.size() > 4:
		game.units[4].dead = true
		game.units[4].respawn_timer = 6.0
