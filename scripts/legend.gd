extends RefCounted
## LEGEND OF THE WILDWOOD: the game's ending. Crowns is match-based with an
## account level, so the "end" is the account first reaching level 20 (the
## LEVEL_20 Steam achievement, scripts/steam.gd). After that match's summary
## a short full-screen ceremony plays once per player profile: a title card,
## three beats about the hero's journey, the credits roll (menu.gd CREDITS,
## the one list of credits) and "Thank you for playing", then the title.
## It can be watched again from PROGRESS ("WATCH THE LEGEND"), and the
## title's CREDITS page plays just the roll ("ROLL CREDITS").
##
## Controls: Enter / Space / Right / pad A go to the next part; Esc, a click
## or pad B / Start fast-forward on the first press and skip on the second.
## Drawn through the HUD (hud.gd calls draw()); game.gd routes input here and
## holds the menus still while it runs. Testing: `-- --debug-legend`
## (`=roll` for the roll only, `--debug-legend-at=<seconds>` to seek).
## claude-faisal/ending 2026-10-30.

const Stats = preload("res://scripts/stats.gd")
const MainMenu = preload("res://scripts/menu.gd")

# ============================================================================
# PLACEHOLDER (Faisal to decide): every story line, the level it unlocks at
# and the music. Tokens filled in from the player's profile:
#   {name}    the hero's name          {faction} Elves / Humans (most played)
#   {realm}   Forest / Kingdom         {class}   most played class (Knight...)
#   {level}   the account level now
# See C:/Games/ORY-Candidates/Crowns/fix-ending/DECISIONS.md.
const LEGEND_LEVEL := 20          # matches the LEVEL_20 achievement
const MUSIC := "menu"             # assets/music track (only the menu theme is wired)
const TITLE := "LEGEND OF THE WILDWOOD"
const TITLE_SUB := "The tale of {name} of the {faction}"
const BEATS := [
	# art: key art behind the beat; show: what stands beside the text
	# ("crest" the faction crest, "class" the favourite class card, "crown").
	{"art": "loading_2", "show": "crest", "lines": [
		"When the two crowns were raised over the Wildwood,",
		"{name} took up the banner of the {faction}.",
		"Doors fell. Crowns were stolen. Crowns came home."]},
	{"art": "loading_1", "show": "class", "lines": [
		"Most often {name} fought as a {class},",
		"and the {realm} still tells of it:",
		"of raids at dusk and last stands at the throne."]},
	{"art": "splash", "show": "crown", "lines": [
		"Twenty seasons on, the Wildwood remembers.",
		"Today it names {name}",
		"a Legend of the Wildwood."]},
]
const CREDITS_TITLE := "CREDITS"
const THANKS := "THANK YOU FOR PLAYING"
const THANKS_SUB := "The Wildwood will remember {name}."
# ============================================================================

const TITLE_TIME := 6.0
const BEAT_TIME := 8.0
const THANKS_TIME := 9.0          # then back to the title on its own
const ROLL_SPEED := 62.0          # credits roll, screen pixels a second
const FADE := 0.8
const FAST := 4.0                 # fast-forward speed

var game
var mode := "full"                # "full" (the whole ceremony) or "roll" (credits only)
var t := 0.0                      # seconds into the sequence
var ff := false                   # fast-forwarding (the first skip press)
var hint_time := 0.0              # how long the "press again to skip" note stays
var done := false
var hold := false                # renders: the clock stands still (--debug-legend-hold)
var pad := false                  # the last press came from a gamepad (hints follow it)
var segs: Array = []              # [kind, duration, beat index]
var tex := {}
var font_title: Font
var return_rect := Rect2()        # RETURN TO TITLE on the last card
var _roll_h := 900.0              # height of the roll's content (measured when drawn)
var _laid_out_h := -1.0
var facts := {}


func _init(g, m: String = "full") -> void:
	game = g
	mode = m
	font_title = load("res://assets/ui/fonts/LilitaOne-Regular.ttf")
	for k in ["loading_1:res://assets/ui/loading_1.jpg", "loading_2:res://assets/ui/loading_2.jpg",
			"splash:res://assets/ui/splash.png", "logo:res://assets/ui/logo.png",
			"crest_0:res://assets/ui/cards/crest_elf.png", "crest_1:res://assets/ui/cards/crest_human.png",
			"crown:res://assets/ui/menu/icon_crown.png", "plaque:res://assets/ui/menu/plaque.png",
			"wood:res://assets/ui/menu/btn_wood.png", "wood_hi:res://assets/ui/menu/btn_wood_hi.png"]:
		var p: PackedStringArray = k.split(":", true, 1)
		if ResourceLoader.exists(p[1]):
			tex[p[0]] = load(p[1])
	facts = hero_facts(g)
	var card := "res://assets/ui/cards/%s_%s.png" % [["elf", "human"][facts.team], facts.class_key]
	if ResourceLoader.exists(card):
		tex["card"] = load(card)
	pad = g.pad_active or g.cursor_shown or Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--debug-pad="))
	_build_segments()


static func hero_facts(g) -> Dictionary:
	## The hero's name, most played side and class from the profile's tallies
	## (game.legend_sides / legend_classes, counted after every match).
	var sides: Array = g.legend_sides if g.legend_sides.size() == 2 else [0, 0]
	var team: int = 1 if int(sides[1]) > int(sides[0]) else 0
	if int(sides[0]) == 0 and int(sides[1]) == 0 and g.lobby_sides.size() > 0:
		team = clampi(int(g.lobby_sides[0]), 0, 1)
	var best := 0
	var role := 0
	for r in range(1, mini(g.legend_classes.size(), Stats.FACTIONS[team].roles.size())):   # the unclassed hero is not a class
		if int(g.legend_classes[r]) > best:
			best = int(g.legend_classes[r])
			role = r
	var role_name: String = Stats.FACTIONS[team].roles[role] if role > 0 else "hero"
	return {"name": g.player_name(), "team": team, "faction": Stats.FACTIONS[team].name, "realm": Stats.FACTIONS[team].realm,
		"class": role_name, "class_key": role_name.to_lower() if role > 0 else "base", "level": g.account_level()}


func fill(s: String) -> String:
	return s.format({"name": facts.name, "faction": facts.faction, "realm": facts.realm, "class": facts["class"], "level": facts.level})


func _build_segments() -> void:
	segs = []
	if mode == "full":
		segs.append(["title", TITLE_TIME, -1])
		for i in BEATS.size():
			segs.append(["beat", BEAT_TIME, i])
	segs.append(["roll", _roll_time(), -1])
	segs.append(["thanks", THANKS_TIME, -1])


func _roll_time() -> float:
	var hh: float = maxf(_laid_out_h, 720.0)
	return (hh + _roll_h) / ROLL_SPEED


func total() -> float:
	var s := 0.0
	for g in segs:
		s += g[1]
	return s


func segment() -> Array:
	## [index, seconds into it] of the part on screen.
	var s := 0.0
	for i in segs.size():
		if t < s + segs[i][1] or i == segs.size() - 1:
			return [i, t - s]
		s += segs[i][1]
	return [segs.size() - 1, 0.0]


func seg_start(i: int) -> float:
	var s := 0.0
	for k in mini(i, segs.size()):
		s += segs[k][1]
	return s


# --- Input ------------------------------------------------------------------------

func tick(delta: float) -> void:
	if tour_dir != "":
		_tour()
		return
	if done or hold:
		return
	t += delta * (FAST if ff else 1.0)
	hint_time = maxf(hint_time - delta, 0.0)
	if t >= total():
		finish()


# Renders (--debug-legend-tour=<dir>): one run steps through every part and
# saves a screenshot of each: [part, seconds into it, "ff" / "pad" / ""].
const TOUR := [[0, 3.0, ""], [1, 4.5, ""], [2, 4.5, ""], [3, 4.5, ""], [4, 7.0, ""], [4, 15.0, ""], [5, 4.0, ""],
	[2, 4.5, "ff"], [1, 4.5, "pad"], [5, 4.0, "pad"]]
var tour_dir := ""
var _tour_i := 0
var _tour_f := 0


func _tour() -> void:
	_tour_f += 1
	if _tour_i >= TOUR.size():
		return
	var stop: Array = TOUR[_tour_i] if mode == "full" else [[0, 6.0, ""], [1, 4.0, ""]][mini(_tour_i, 1)]
	if _tour_f == 1:
		t = seg_start(stop[0]) + stop[1]
		ff = stop[2] == "ff"
		hint_time = 3.0 if ff else 0.0
		pad = stop[2] == "pad"
	elif _tour_f == 20:
		var path := "%s/%s_%02d_%s_part%d%s.png" % [tour_dir, mode, _tour_i, segs[stop[0]][0], stop[0], ("_" + stop[2]) if stop[2] != "" else ""]
		game.get_viewport().get_texture().get_image().save_png(path)
		print("LEGEND shot ", path)
		_tour_i += 1
		_tour_f = 0
		if _tour_i >= (TOUR.size() if mode == "full" else 2):
			game.legend_tour_done(tour_dir)


func press_next() -> void:
	## Enter / Space / pad A: on to the next part; on the last card, home.
	var at := segment()
	if segs[at[0]][0] == "thanks" or at[0] >= segs.size() - 1:
		finish()
		return
	t = seg_start(at[0] + 1)
	game.sfx.ui("ui_click", -6.0)


func press_skip() -> void:
	## Esc / click / pad B: the first press fast-forwards, the second skips.
	if segs[segment()[0]][0] == "thanks" or ff:
		finish()
		return
	ff = true
	hint_time = 3.5
	game.sfx.ui("ui_click", -6.0)


func finish() -> void:
	if done:
		return
	done = true
	game.legend_finished()


func input(event: InputEvent) -> void:
	## From hud._input while the legend is on screen.
	if done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		pad = false
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT, KEY_D:
				press_next()
			KEY_ESCAPE, KEY_BACKSPACE:
				press_skip()
	elif event is InputEventJoypadButton and event.pressed:
		pad = true
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_DPAD_RIGHT or event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			press_next()
		elif event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START:
			press_skip()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pad = false
		if return_rect.size.x > 0.0 and return_rect.has_point(event.position):
			finish()
		else:
			press_skip()


# --- Drawing ----------------------------------------------------------------------

var h   # the HUD this frame


func draw(hud) -> void:
	h = hud
	var sz: Vector2 = h.size
	if not is_equal_approx(_laid_out_h, sz.y):
		# The roll's length depends on the screen height and the wrapped credits.
		var keep_into := segment()
		_laid_out_h = sz.y
		_roll_h = _measure_roll(sz)
		_build_segments()
		t = seg_start(keep_into[0]) + minf(keep_into[1], segs[keep_into[0]][1])
	return_rect = Rect2()
	h.draw_rect(Rect2(Vector2.ZERO, sz), Color.BLACK)
	var at := segment()
	var seg: Array = segs[at[0]]
	var lt: float = at[1]
	var a := clampf(minf(lt / FADE, (seg[1] - lt) / FADE), 0.0, 1.0)
	match seg[0]:
		"title": _draw_title(sz, lt, a)
		"beat": _draw_beat(sz, seg[2], lt, a)
		"roll": _draw_roll(sz, lt, clampf(lt / FADE, 0.0, 1.0))
		"thanks": _draw_thanks(sz, lt, clampf(lt / FADE, 0.0, 1.0))
	_draw_hints(sz)


func _art(name: String, sz: Vector2, lt: float, a: float, dim: float) -> void:
	## Key art covering the screen, drifting in slowly, dimmed for the text.
	var tx: Texture2D = tex.get(name)
	if tx == null:
		return
	var ts := tx.get_size()
	var k := maxf(sz.x / ts.x, sz.y / ts.y) * (1.04 + lt * 0.006)
	var r := Rect2((sz - ts * k) / 2.0, ts * k)
	h.draw_texture_rect(tx, r, false, Color(dim, dim, dim, a))
	# A dark band behind the text and soft vignettes top and bottom.
	_vgrad(Rect2(0, 0, sz.x, sz.y * 0.3), Color(0, 0, 0, 0.75 * a), Color(0, 0, 0, 0))
	_vgrad(Rect2(0, sz.y * 0.7, sz.x, sz.y * 0.3), Color(0, 0, 0, 0), Color(0, 0, 0, 0.8 * a))


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	h.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _ttext(pos: Vector2, text: String, size: int, color: Color, a: float, width: float = -1.0, outline: int = 7) -> void:
	## Title-face lettering, centred in `width` from pos.x, faded by `a`.
	var f: Font = font_title if font_title else h.font
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
	if outline > 0:
		h.draw_string_outline(f, pos + Vector2(0, 3), text, align, width, size, outline, Color(0, 0, 0, 0.5 * a))
		h.draw_string_outline(f, pos, text, align, width, size, outline, Color(0.12, 0.07, 0.03, a))
	h.draw_string(f, pos, text, align, width, size, Color(color, color.a * a))


func _btext(pos: Vector2, text: String, size: int, color: Color, a: float, width: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	## Body text with an outline, faded by `a`.
	h.draw_string_outline(h.font, pos, text, align, width, size, 4, Color(0.03, 0.02, 0.02, 0.9 * a))
	h.draw_string(h.font, pos, text, align, width, size, Color(color, color.a * a))


func _fit(f: Font, text: String, size: int, width: float) -> int:
	while size > 10 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


func _wrap(f: Font, text: String, size: int, width: float) -> Array:
	var out: Array = []
	var line := ""
	for w in text.split(" "):
		var trial: String = w if line == "" else line + " " + w
		if line != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = w
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


func _nine(name: String, r: Rect2, l: float, tp: float, rr: float, b: float, mod: Color) -> void:
	var tx: Texture2D = tex.get(name)
	if tx == null:
		h.draw_rect(r, Color(0.3, 0.2, 0.1, mod.a))
		return
	var ts := tx.get_size()
	var xs := [0.0, l, ts.x - rr, ts.x]
	var ys := [0.0, tp, ts.y - b, ts.y]
	var kx := minf(1.0, r.size.x / (l + rr))
	var ky := minf(1.0, r.size.y / (tp + b))
	var dx := [r.position.x, r.position.x + l * kx, r.end.x - rr * kx, r.end.x]
	var dy := [r.position.y, r.position.y + tp * ky, r.end.y - b * ky, r.end.y]
	for i in 3:
		for j in 3:
			var dst := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			if dst.size.x > 0.5 and dst.size.y > 0.5:
				h.draw_texture_rect_region(tx, dst, Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j]), mod)


func _rule(c: Vector2, w: float, a: float) -> void:
	## A thin gold rule with a diamond in the middle.
	var gold := Color(1.0, 0.82, 0.4, 0.85 * a)
	h.draw_line(c - Vector2(w / 2.0, 0), c - Vector2(14, 0), gold, 2.0)
	h.draw_line(c + Vector2(14, 0), c + Vector2(w / 2.0, 0), gold, 2.0)
	h.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(8, 0), c + Vector2(0, 7), c + Vector2(-8, 0)]), gold)


func _draw_title(sz: Vector2, lt: float, a: float) -> void:
	_art("loading_1", sz, lt, a, 0.42)
	var cx := sz.x / 2.0
	var cy := sz.y * 0.46
	# No crown icon here: it sat on top of the key art's own logo.
	var w := minf(sz.x - 120.0, 1100.0)
	var fs := _fit(font_title, TITLE, 68, w)
	_ttext(Vector2(cx - w / 2.0, cy), TITLE, fs, Color(1.0, 0.84, 0.42), a, w, 9)
	_rule(Vector2(cx, cy + 34), minf(w, 620.0), a)
	var sub := fill(TITLE_SUB)
	_ttext(Vector2(cx - w / 2.0, cy + 82), sub, _fit(font_title, sub, 30, w), Color(0.96, 0.93, 0.86), a, w, 6)


func _draw_beat(sz: Vector2, i: int, lt: float, a: float) -> void:
	var beat: Dictionary = BEATS[i]
	_art(beat.art, sz, lt, a, 0.38)
	# Picture on the left, story on the right; the pair centred (on 21:9 too).
	var group_w := minf(sz.x - 140.0, 1060.0)
	var pic_w := 250.0 if beat.show != "crown" else 200.0
	var gap := 48.0
	var text_w := group_w - pic_w - gap
	var x0 := (sz.x - group_w) / 2.0
	var cy := sz.y * 0.5
	var pic: Texture2D = null
	match beat.show:
		"crest": pic = tex.get("crest_%d" % facts.team)
		"class": pic = tex.get("card", tex.get("crest_%d" % facts.team))
		"crown": pic = tex.get("crown")
	if pic:
		var ps := pic.get_size()
		var k := minf(pic_w / ps.x, 340.0 / ps.y)
		var pr := Rect2(Vector2(x0 + (pic_w - ps.x * k) / 2.0, cy - ps.y * k / 2.0), ps * k)
		var rise := (1.0 - clampf(lt / 1.2, 0.0, 1.0)) * 16.0
		pr.position.y += rise
		if beat.show == "crown":
			for g in 5:   # a warm glow behind the crown
				h.draw_circle(pr.get_center(), pic_w * (0.5 + g * 0.12), Color(1.0, 0.75, 0.3, 0.07 * a))
		h.draw_texture_rect(pic, pr, false, Color(1, 1, 1, a))
	var tx := x0 + pic_w + gap
	var lines: Array = []
	for s in beat.lines:
		lines.append(fill(s))
	var fs := 30
	for s in lines:
		fs = mini(fs, _fit(font_title, s, 30, text_w))
	var line_h := fs * 1.55
	var y := cy - (lines.size() - 1) * line_h / 2.0 + fs * 0.35
	# The beat's heading: chapter number in small gold caps.
	_ttext(Vector2(tx, y - line_h - 10), "%s" % ["I", "II", "III", "IV", "V"][mini(i, 4)], 22, Color(1.0, 0.8, 0.38), a, -1.0, 5)
	for k in lines.size():
		# Each line arrives a beat after the last.
		var la := clampf((lt - 0.5 - k * 1.1) / 0.7, 0.0, 1.0) * a
		_ttext(Vector2(tx, y + k * line_h), lines[k], fs, Color(0.97, 0.94, 0.87), la, -1.0, 6)


func _roll_items(sz: Vector2) -> Array:
	## [kind, text, size, height] rows of the roll, from menu.gd CREDITS.
	var w := minf(sz.x - 200.0, 900.0)
	var out: Array = [["head", CREDITS_TITLE, 0, 120.0]]
	for c in MainMenu.CREDITS:
		out.append(["role", c[0], 26, 40.0])
		var lines: Array = _wrap(h.font, c[1], 20, w) if h else [c[1]]
		for line in lines:
			out.append(["name", line, 20, 30.0])
		out.append(["gap", "", 0, 46.0])
	return out


func _measure_roll(sz: Vector2) -> float:
	var s := 0.0
	for it in _roll_items(sz):
		s += it[3]
	return s


func _draw_roll(sz: Vector2, lt: float, a: float) -> void:
	_art("splash", sz, lt * 0.3, a, 0.22)
	h.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.35 * a))
	var cx := sz.x / 2.0
	var w := minf(sz.x - 200.0, 900.0)
	var y := sz.y + 20.0 - lt * ROLL_SPEED
	for it in _roll_items(sz):
		var row_y: float = y
		y += it[3]
		if row_y < -140.0 or row_y > sz.y + 60.0:
			continue
		# Rows fade in at the bottom edge and out at the top.
		var ea := clampf(minf((row_y + 20.0) / 90.0, (sz.y - row_y) / 90.0), 0.0, 1.0) * a
		match it[0]:
			"head":
				var pr := Rect2(cx - 210, row_y, 420, 64)
				_nine("plaque", pr, 110, 24, 110, 24, Color(1, 1, 1, ea))
				_ttext(Vector2(pr.position.x, row_y + 44), it[1], 32, Color(1.0, 0.86, 0.45), ea, pr.size.x, 7)
			"role":
				_ttext(Vector2(cx - w / 2.0, row_y + 28), it[1], _fit(font_title, it[1], it[2], w), Color(1.0, 0.8, 0.38), ea, w, 5)
			"name":
				_btext(Vector2(cx - w / 2.0, row_y + 22), it[1], it[2], Color(0.95, 0.93, 0.88), ea, w)


func _draw_thanks(sz: Vector2, lt: float, a: float) -> void:
	_art("loading_2", sz, lt, a, 0.3)
	h.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.25 * a))
	var cx := sz.x / 2.0
	# The key art already carries the logo; a second one on top read as a double image.
	var logo: Texture2D = tex.get("logo")
	var top := sz.y * 0.16
	if logo:
		top += minf(440.0, sz.x - 160.0) * logo.get_height() / float(logo.get_width())
	var w := minf(sz.x - 120.0, 1000.0)
	var ty := top + 96.0
	_ttext(Vector2(cx - w / 2.0, ty), THANKS, _fit(font_title, THANKS, 58, w), Color(1.0, 0.84, 0.42), a, w, 9)
	_rule(Vector2(cx, ty + 30), minf(w, 520.0), a)
	var sub := fill(THANKS_SUB)
	_ttext(Vector2(cx - w / 2.0, ty + 76), sub, _fit(font_title, sub, 26, w), Color(0.96, 0.93, 0.86), a, w, 6)
	# RETURN TO TITLE: a click, A, Enter, B or Esc all go back.
	var ba := clampf((lt - 1.2) / 0.6, 0.0, 1.0)
	var label := "RETURN TO TITLE"
	var br := Rect2(cx - 150, minf(ty + 120.0, sz.y - 120.0), 300, 52)
	var hover: bool = br.has_point(h.get_local_mouse_position()) and not pad
	_nine("wood_hi" if hover or pad else "wood", br.grow(2) if hover else br, 20, 20, 20, 20, Color(1, 1, 1, ba))
	_ttext(Vector2(br.position.x, br.get_center().y + 9), label, 24, Color(1, 0.97, 0.9), ba, br.size.x, 5)
	if ba > 0.0:
		return_rect = br


func _draw_hints(sz: Vector2) -> void:
	## Bottom-right: what the buttons do, named for the device in use.
	var next_k := "Enter" if not pad else _pad("ui_confirm")
	var back_k := "Esc" if not pad else _pad("ui_back")
	var kind: String = segs[segment()[0]][0]
	var text := ""
	if kind == "thanks":
		text = "%s  back to the title" % next_k
	elif ff:
		text = ">> FAST FORWARD   ·   %s again to skip" % back_k if hint_time > 0.0 else ">> FAST FORWARD   ·   %s skip" % back_k
	else:
		text = "%s  next   ·   %s  fast-forward / skip" % [next_k, back_k]
	_btext(Vector2(24, sz.y - 22), text, 15, Color(0.92, 0.9, 0.84, 0.85), 1.0, sz.x - 48, HORIZONTAL_ALIGNMENT_RIGHT)


func _pad(action: String) -> String:
	var kind: String = game.pad_kind(game.local_pad(0)) if game.has_method("pad_kind") else "xbox"
	return game.pad_label(action, kind)
