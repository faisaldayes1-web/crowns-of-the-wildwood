extends Control
## In-match HUD plus the title, pause and rank menus, drawn in code after the
## UI references: the logo top-left, score and timer up top, team rosters with
## portraits down each side, a minimap bottom-left, the player's portrait,
## hearts, energy, experience and ability slots at the bottom, and the
## objective card bottom-right. Reskin by editing here.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

const INK := Color(0.09, 0.1, 0.15, 0.92)
const INK_LIGHT := Color(0.17, 0.19, 0.27, 0.96)
const GOLD := Color(1.0, 0.8, 0.25)
const GOLD_DARK := Color(0.62, 0.44, 0.12)
const CREAM := Color(0.97, 0.93, 0.8)
const GREY := Color(0.6, 0.6, 0.65)
const HEART := Color(0.93, 0.18, 0.25)
const HEART_EMPTY := Color(0.25, 0.22, 0.26)
const STAMINA := Color(0.4, 0.85, 0.3)
const MANA := Color(0.3, 0.6, 1.0)
const XP := Color(1.0, 0.7, 0.2)
const RED := Color(0.85, 0.2, 0.2)
const STEEL := Color(0.75, 0.77, 0.82)
const LEAF := Color(0.3, 0.62, 0.3)
const GRASS := Color(0.36, 0.55, 0.28)
const DIRT := Color(0.62, 0.52, 0.36)

const TABS := ["OVERVIEW", "CLASSES", "CONTROLS"]

var game
var font: Font
var logo: Texture2D
# Where buttons were drawn this frame, so game.gd can hit-test mouse clicks.
var rank_buttons: Array = []
var tab_buttons: Array = []
var close_button := Rect2()


func _ready() -> void:
	font = ThemeDB.fallback_font
	logo = load("res://assets/ui/logo.png")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if game:
		game.menu_tick()
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	rank_buttons = []
	tab_buttons = []
	close_button = Rect2()
	if not game.playing and not game.game_over:
		_draw_title()
		return
	_draw_logo(Rect2(14, 8, 200, 80))
	_draw_scoreboard()
	_draw_roster(0, Vector2(14, 118))
	_draw_roster(1, Vector2(size.x - 254, 118))
	_draw_map(Rect2(14, size.y - 126, 214, 96), false)
	_draw_objective()
	if game.player:
		_draw_player_panel(game.player)
	if game.rank_open and game.player:
		_draw_rank_menu(game.player)
	if game.menu_open:
		_draw_game_menu()
	if game.game_over:
		_draw_end()


# --- Drawing helpers ---------------------------------------------------------

func _team_color(team: int) -> Color:
	return Stats.FACTIONS[team].color


func _plate(rect: Rect2, fill: Color = INK, edge: Color = GOLD_DARK, radius: int = 10, border: int = 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = edge
	sb.shadow_size = 5
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(0, 2)
	draw_style_box(sb, rect)


func _text(pos: Vector2, text: String, font_size: int, color: Color = Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 4) -> void:
	if outline > 0:
		draw_string_outline(font, pos, text, align, width, font_size, outline, Color(0.05, 0.04, 0.06, 0.85))
	draw_string(font, pos, text, align, width, font_size, color)


func _paragraph(pos: Vector2, text: String, font_size: int, color: Color, width: float, line_h: float) -> float:
	## Word-wrapped text. Returns the height used.
	var lines := []
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if _text_width(trial, font_size) > width and line != "":
			lines.append(line)
			line = word
		else:
			line = trial
	if line != "":
		lines.append(line)
	for i in lines.size():
		_text(pos + Vector2(0, i * line_h), lines[i], font_size, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	return lines.size() * line_h


func _text_width(text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _heart(center: Vector2, scale: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		points.append(center + Vector2(x, -y) * scale)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(0.1, 0.03, 0.05, 0.8), 1.5)
	if color == HEART:
		draw_circle(center + Vector2(-5, -5) * scale, 3.0 * scale, Color(1, 1, 1, 0.45))


func _hearts(origin: Vector2, count: int, scale: float, spacing: float) -> void:
	for i in Stats.MAX_HEARTS:
		_heart(origin + Vector2(i * spacing, 0), scale, HEART if i < count else HEART_EMPTY)


func _crown(center: Vector2, scale: float, color: Color = GOLD) -> void:
	var p := PackedVector2Array([
		Vector2(-10, 6), Vector2(-12, -6), Vector2(-5, 0), Vector2(0, -9),
		Vector2(5, 0), Vector2(12, -6), Vector2(10, 6)])
	for i in p.size():
		p[i] = center + p[i] * scale
	draw_colored_polygon(p, color)
	draw_rect(Rect2(center + Vector2(-10, 6) * scale, Vector2(20, 3) * scale), color.darkened(0.25))
	for x in [-6.0, 0.0, 6.0]:
		draw_circle(center + Vector2(x, 2) * scale, 1.4 * scale, RED if x == 0.0 else Color(0.2, 0.5, 1.0))


func _bar(rect: Rect2, fraction: float, color: Color) -> void:
	_plate(rect, Color(0, 0, 0, 0.7), Color(0.05, 0.04, 0.06), 6, 1)
	var inner := rect.grow(-2)
	var w := inner.size.x * clampf(fraction, 0.0, 1.0)
	if w > 0.0:
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), color)
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y * 0.4)), Color(1, 1, 1, 0.25))


func _hex(center: Vector2, w: float, h: float, fill: Color, edge: Color) -> void:
	var p := PackedVector2Array([
		center + Vector2(-w / 2 + h / 3, -h / 2), center + Vector2(w / 2 - h / 3, -h / 2),
		center + Vector2(w / 2, 0), center + Vector2(w / 2 - h / 3, h / 2),
		center + Vector2(-w / 2 + h / 3, h / 2), center + Vector2(-w / 2, 0)])
	draw_colored_polygon(p, fill)
	p.append(p[0])
	draw_polyline(p, edge, 2.5)


func _arc_polygon(center: Vector2, radius: float, from: float, to: float, color: Color) -> void:
	var p := PackedVector2Array([center])
	for i in 25:
		var a := lerpf(from, to, i / 24.0)
		p.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(p, color)


func _portrait(c: Vector2, r: float, team: int, role: int, dead: bool = false) -> void:
	## A chibi face in a round gold frame: skin, hair, class headgear, elf ears.
	var elf := team == 0
	var skin := Color(0.97, 0.86, 0.74) if elf else Color(0.94, 0.78, 0.62)
	var hair := Color(0.93, 0.8, 0.4) if elf else Color(0.4, 0.25, 0.12)
	if role == Role.MAGE and elf:
		hair = Color(0.9, 0.9, 0.95)
	var cls: Color = Stats.ROLES[role].color.lerp(_team_color(team), 0.3)
	if dead:
		skin = skin.darkened(0.5)
		hair = hair.darkened(0.5)
		cls = cls.darkened(0.5)
	draw_circle(c, r + 4, GOLD_DARK)
	draw_circle(c, r + 2, GOLD if not dead else GREY)
	draw_circle(c, r, _team_color(team).darkened(0.55))
	if elf:
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(side * 0.7 * r, 0.05 * r),
				c + Vector2(side * 1.25 * r, -0.4 * r), c + Vector2(side * 0.8 * r, -0.4 * r)]), skin)
	draw_circle(c, r * 0.82, skin)
	match role:
		Role.KNIGHT:
			_arc_polygon(c, r * 0.95, PI, TAU, STEEL if not dead else STEEL.darkened(0.5))
			draw_rect(Rect2(c + Vector2(-0.95 * r, -0.28 * r), Vector2(1.9 * r, 0.16 * r)), Color(0.45, 0.47, 0.52))
			draw_rect(Rect2(c + Vector2(-0.08 * r, -1.25 * r), Vector2(0.16 * r, 0.4 * r)), _team_color(team))
		Role.RANGER:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1.0 * r, -0.1 * r), c + Vector2(1.0 * r, -0.1 * r),
				c + Vector2(0.1 * r, -1.45 * r)]), cls.darkened(0.2))
		Role.MAGE:
			_arc_polygon(c, r * 0.9, PI, TAU, hair)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.75 * r, -0.55 * r), c + Vector2(0.75 * r, -0.55 * r),
				c + Vector2(0.2 * r, -1.75 * r)]), cls)
			var brim := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				brim.append(c + Vector2(cos(a) * 1.25 * r, -0.55 * r + sin(a) * 0.22 * r))
			draw_colored_polygon(brim, cls.darkened(0.15))
		Role.HEALER:
			_arc_polygon(c, r * 0.98, PI, TAU, CREAM if not dead else GREY)
			draw_rect(Rect2(c + Vector2(-0.98 * r, -0.05 * r), Vector2(0.22 * r, 0.75 * r)), CREAM if not dead else GREY)
			draw_rect(Rect2(c + Vector2(0.76 * r, -0.05 * r), Vector2(0.22 * r, 0.75 * r)), CREAM if not dead else GREY)
			draw_rect(Rect2(c + Vector2(-0.98 * r, -0.12 * r), Vector2(1.96 * r, 0.1 * r)), GOLD)
		_:
			_arc_polygon(c, r * 0.9, PI, TAU, hair)
			draw_rect(Rect2(c + Vector2(-0.8 * r, -0.4 * r), Vector2(1.6 * r, 0.2 * r)), hair)
	var eye := Color(0.12, 0.1, 0.1)
	for side in [-1.0, 1.0]:
		draw_circle(c + Vector2(side * 0.3 * r, 0.12 * r), 0.1 * r, eye)
		draw_circle(c + Vector2(side * 0.3 * r - 0.03 * r, 0.09 * r), 0.03 * r, Color.WHITE)
	draw_arc(c + Vector2(0, 0.35 * r), 0.14 * r, 0.2, PI - 0.2, 8, eye, 1.5)
	if dead:
		draw_line(c + Vector2(-0.4 * r, -0.02 * r), c + Vector2(-0.2 * r, 0.22 * r), RED, 2.0)
		draw_line(c + Vector2(-0.2 * r, -0.02 * r), c + Vector2(-0.4 * r, 0.22 * r), RED, 2.0)


func _icon(kind: String, c: Vector2, s: float, color: Color) -> void:
	## Simple symbol for each ability or action.
	match kind:
		"bash", "guard", "block":
			var shield := PackedVector2Array([c + Vector2(-s, -0.8 * s), c + Vector2(s, -0.8 * s),
				c + Vector2(s, 0.1 * s), c + Vector2(0, s), c + Vector2(-s, 0.1 * s)])
			draw_colored_polygon(shield, color)
			var inner := PackedVector2Array()
			for p in shield:
				inner.append(c + (p - c) * 0.6)
			draw_colored_polygon(inner, color.lightened(0.4))
			if kind == "bash":
				for dy in [-0.4, 0.0, 0.4]:
					draw_line(c + Vector2(-1.75 * s, dy * s), c + Vector2(-1.3 * s, dy * s), Color(1, 1, 1, 0.8), 1.5)
			elif kind == "guard":
				draw_arc(c, 1.3 * s, 0, TAU, 32, Color(color, 0.7), 2.0)
			else:
				draw_line(c + Vector2(-0.5 * s, -0.1 * s), c + Vector2(0.5 * s, -0.1 * s), color.darkened(0.4), 2.5)
				draw_line(c + Vector2(0, -0.6 * s), c + Vector2(0, 0.5 * s), color.darkened(0.4), 2.5)
		"volley", "arrow":
			var angles := [-0.45, 0.0, 0.45] if kind == "volley" else [0.0]
			for ang in angles:
				var d := Vector2(sin(ang), -cos(ang))
				var tip := c + d * s * 1.1
				draw_line(c - d * s * 0.9, tip, color, 2.5)
				var side := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([tip + d * 0.3 * s, tip + side * 0.25 * s, tip - side * 0.25 * s]), color)
				if kind == "arrow":
					draw_line(c - d * s * 0.9, c - d * s * 0.9 + side * 0.3 * s - d * 0.2 * s, color, 2.0)
					draw_line(c - d * s * 0.9, c - d * s * 0.9 - side * 0.3 * s - d * 0.2 * s, color, 2.0)
		"trap":
			draw_arc(c, 0.75 * s, 0, TAU, 32, color, 3.5)
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_colored_polygon(PackedVector2Array([c + d * 0.95 * s + Vector2(-d.y, d.x) * 0.2 * s,
					c + d * 0.95 * s - Vector2(-d.y, d.x) * 0.2 * s, c + d * 1.35 * s]), color)
		"fireball":
			var flame := PackedVector2Array([c + Vector2(0, -1.3 * s), c + Vector2(0.45 * s, -0.5 * s),
				c + Vector2(0.9 * s, -0.2 * s), c + Vector2(0.75 * s, 0.6 * s), c + Vector2(0, 1.1 * s),
				c + Vector2(-0.75 * s, 0.6 * s), c + Vector2(-0.9 * s, -0.2 * s), c + Vector2(-0.4 * s, -0.4 * s)])
			draw_colored_polygon(flame, color)
			var core := PackedVector2Array()
			for p in flame:
				core.append(c + Vector2(0, 0.3 * s) + (p - c - Vector2(0, 0.3 * s)) * 0.5)
			draw_colored_polygon(core, Color(1, 0.9, 0.4))
		"blink":
			for dx in [-0.6, 0.2]:
				draw_polyline(PackedVector2Array([c + Vector2(dx * s - 0.4 * s, -0.9 * s), c + Vector2(dx * s + 0.4 * s, 0),
					c + Vector2(dx * s - 0.4 * s, 0.9 * s)]), color, 3.5)
			draw_circle(c + Vector2(-1.2 * s, 0), 0.18 * s, Color(color, 0.5))
		"blessing", "bolt":
			draw_circle(c, 0.5 * s, color)
			for i in 8:
				var a := TAU * i / 8.0 + (0.0 if kind == "blessing" else 0.2)
				draw_line(c + Vector2(cos(a), sin(a)) * 0.7 * s, c + Vector2(cos(a), sin(a)) * 1.2 * s, color, 2.5)
			if kind == "bolt":
				draw_circle(c, 0.25 * s, Color(1, 1, 1, 0.8))
		"smite":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.15 * s, -1.2 * s), c + Vector2(0.5 * s, -1.2 * s),
				c + Vector2(0.1 * s, -0.2 * s), c + Vector2(0.6 * s, -0.2 * s), c + Vector2(-0.4 * s, 1.2 * s),
				c + Vector2(-0.1 * s, 0.1 * s), c + Vector2(-0.6 * s, 0.1 * s)]), color)
		"mend":
			draw_rect(Rect2(c + Vector2(-0.3 * s, -1.0 * s), Vector2(0.6 * s, 2.0 * s)), color)
			draw_rect(Rect2(c + Vector2(-1.0 * s, -0.3 * s), Vector2(2.0 * s, 0.6 * s)), color)
			draw_circle(c, 0.22 * s, Color(1, 1, 1, 0.8))
		"dodge":
			for dx in [-0.9, -0.1, 0.7]:
				draw_polyline(PackedVector2Array([c + Vector2(dx * s - 0.3 * s, -0.8 * s), c + Vector2(dx * s + 0.3 * s, 0),
					c + Vector2(dx * s - 0.3 * s, 0.8 * s)]), color, 3.0)
		"crown":
			_crown(c, s / 10.0, color)
		"sword", "melee":
			draw_line(c + Vector2(-0.8 * s, 0.8 * s), c + Vector2(0.7 * s, -0.7 * s), color, 3.5)
			draw_line(c + Vector2(-0.3 * s, -0.2 * s), c + Vector2(0.2 * s, 0.3 * s), GOLD, 3.0)
			draw_circle(c + Vector2(-0.85 * s, 0.85 * s), 0.18 * s, GOLD)
		"fist":
			draw_circle(c, 0.7 * s, color)
			for dx in [-0.45, -0.15, 0.15, 0.45]:
				draw_rect(Rect2(c + Vector2(dx * s - 0.12 * s, -0.95 * s), Vector2(0.24 * s, 0.5 * s)), color.lightened(0.2))
		"flag":
			draw_line(c + Vector2(-0.8 * s, -1.0 * s), c + Vector2(-0.8 * s, 1.0 * s), color, 2.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8 * s, -1.0 * s), c + Vector2(0.9 * s, -0.5 * s),
				c + Vector2(-0.8 * s, 0.0)]), color)
		"vigor":
			_heart(c, s / 12.0, color)
			draw_line(c + Vector2(-1.1 * s, 0.1 * s), c + Vector2(-0.5 * s, 0.1 * s), Color.WHITE, 2.0)
			draw_line(c + Vector2(-0.5 * s, 0.1 * s), c + Vector2(-0.3 * s, -0.4 * s), Color.WHITE, 2.0)
			draw_line(c + Vector2(-0.3 * s, -0.4 * s), c + Vector2(0.0, 0.5 * s), Color.WHITE, 2.0)
			draw_line(c + Vector2(0.0, 0.5 * s), c + Vector2(0.3 * s, 0.1 * s), Color.WHITE, 2.0)
			draw_line(c + Vector2(0.3 * s, 0.1 * s), c + Vector2(1.1 * s, 0.1 * s), Color.WHITE, 2.0)


func _attack_icon(role: int) -> String:
	match Stats.ROLES[role].attack:
		"melee": return "sword" if role == Role.KNIGHT else "fist"
		"arrow": return "arrow"
		"spell": return "bolt"
		"heal": return "mend"
	return "sword"


func _keycap(center: Vector2, key: String, w: float = 30.0) -> void:
	var rect := Rect2(center - Vector2(w / 2.0, 10), Vector2(w, 20))
	_plate(rect, CREAM, Color(0.5, 0.4, 0.25), 5, 1)
	_text(rect.position + Vector2(0, 15), key, 12, Color(0.15, 0.12, 0.1), HORIZONTAL_ALIGNMENT_CENTER, w, 0)


func _slot(origin: Vector2, size_px: float, icon: String, color: Color, key: String, label: String,
		remaining: float, total: float, usable: bool, rank: int = 0, active: bool = false) -> void:
	var rect := Rect2(origin, Vector2(size_px, size_px))
	var ready := remaining <= 0.0 and usable
	_plate(rect, INK_LIGHT if not active else Color(0.3, 0.35, 0.5, 0.96), GOLD if ready else Color(0.35, 0.33, 0.4), 9, 2)
	_icon(icon, rect.get_center(), size_px * 0.28, color if ready else color.darkened(0.45))
	if remaining > 0.0:
		var frac := clampf(remaining / maxf(total, 0.01), 0.0, 1.0)
		var inner := rect.grow(-3)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * frac)), Color(0, 0, 0, 0.65))
		_text(rect.position + Vector2(0, size_px * 0.62), ("%.1f" % remaining) if remaining < 10.0 else str(ceili(remaining)),
			16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size_px)
	elif not usable:
		draw_rect(rect.grow(-3), Color(0.5, 0.1, 0.1, 0.35))
	# Rank pips along the top edge.
	for i in rank:
		draw_circle(rect.position + Vector2(8 + i * 8, 7), 2.6, GOLD)
	_keycap(Vector2(rect.get_center().x, rect.end.y + 4), key, maxf(26.0, _text_width(key, 12) + 12.0))
	_text(Vector2(rect.position.x - 20, rect.end.y + 30), label, 10, Color(0.85, 0.85, 0.85),
		HORIZONTAL_ALIGNMENT_CENTER, size_px + 40)


func _draw_logo(rect: Rect2) -> void:
	if logo:
		draw_texture_rect(logo, rect, false)


func _close(rect: Rect2) -> void:
	## An X button in a panel's top-right corner. Recorded for mouse clicks.
	close_button = Rect2(rect.end.x - 34, rect.position.y + 8, 26, 26)
	_plate(close_button, Color(0.45, 0.12, 0.12), GOLD_DARK, 6, 1)
	_text(close_button.position + Vector2(0, 19), "✕", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 26, 0)


# --- In-match panels ---------------------------------------------------------

func _draw_scoreboard() -> void:
	var cx := size.x / 2.0
	for t in 2:
		var dir := -1.0 if t == 0 else 1.0
		var c := Vector2(cx + dir * 175, 36)
		_hex(c, 160, 50, _team_color(t).darkened(0.25), GOLD)
		_crown(c + Vector2(dir * 55, 0), 1.3)
		_text(c + Vector2(-30 - dir * 12, -4), Stats.FACTIONS[t].realm.to_upper(), 11, _team_color(t).lightened(0.55), HORIZONTAL_ALIGNMENT_CENTER, 60, 2)
		_text(c + Vector2(-30 - dir * 12, 20), str(game.score[t]), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 60)
	_plate(Rect2(cx - 85, 10, 170, 54), INK, GOLD_DARK, 8, 2)
	var left := maxf(game.time_left, 0.0)
	var urgent := left < 60.0 and int(left * 2.0) % 2 == 0
	_text(Vector2(cx - 85, 49), "%02d:%02d" % [int(left) / 60, int(left) % 60], 34,
		Color(1, 0.4, 0.3) if urgent else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 170)
	_plate(Rect2(cx - 95, 66, 190, 22), INK, GOLD_DARK, 6, 1)
	_text(Vector2(cx - 95, 82), "CAPTURE THE CROWN", 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 190, 2)


func _draw_roster(team: int, origin: Vector2) -> void:
	var tc := _team_color(team)
	_plate(Rect2(origin - Vector2(0, 26), Vector2(240, 22)), tc.darkened(0.6), tc.darkened(0.1), 6, 1)
	_text(origin + Vector2(0, -10), "%s TEAM" % Stats.FACTIONS[team].name.to_upper(), 12, tc.lightened(0.55), HORIZONTAL_ALIGNMENT_CENTER, 240, 2)
	var row := 0
	for u in game.units:
		if u.team != team:
			continue
		var rect := Rect2(origin + Vector2(0, row * 54), Vector2(240, 48))
		_plate(rect, tc.darkened(0.7) if not u.is_player else Color(0.3, 0.24, 0.08, 0.95),
			GOLD if u.is_player else tc.darkened(0.2), 10, 2)
		_portrait(rect.position + Vector2(26, 24), 15, team, u.role, u.dead)
		var name: String = u.role_name()
		_text(rect.position + Vector2(52, 19), name, 14, tc.lightened(0.45) if not u.is_player else GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		var nx: float = rect.position.x + 56 + _text_width(name, 14)
		if u.is_player:
			_text(Vector2(nx, rect.position.y + 19), "YOU", 10, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			nx += 28
		if u.level > 1:
			_text(Vector2(nx, rect.position.y + 19), "★%d" % u.level, 11, XP, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		if u.carrying:
			_crown(rect.position + Vector2(222, 16), 0.8)
		if u.dead:
			_text(rect.position + Vector2(52, 39), "back in %d" % ceili(u.respawn_timer), 12, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		else:
			_hearts(rect.position + Vector2(58, 33), u.hearts, 0.36, 15)
			_bar(Rect2(rect.position + Vector2(122, 28), Vector2(106, 10)), u.energy / u.energy_max(),
				MANA if u.energy_kind() == "mana" else STAMINA)
		row += 1


func _draw_objective() -> void:
	var rect := Rect2(size.x - 254, size.y - 128, 240, 108)
	_plate(rect, INK, GOLD_DARK, 10, 2)
	_icon("flag", rect.position + Vector2(20, 20), 9, RED)
	_text(rect.position + Vector2(36, 25), "CAPTURE THE CROWN", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	draw_line(rect.position + Vector2(12, 34), rect.position + Vector2(228, 34), GOLD_DARK, 1.0)
	var lines := ["Break the enemy castle door", "Carry their monarch to your throne",
		"First to %d captures wins" % Stats.CAPTURES_TO_WIN]
	for i in lines.size():
		var y := 54 + i * 18
		draw_circle(rect.position + Vector2(18, y - 4), 3, GOLD)
		_text(rect.position + Vector2(28, y), lines[i], 12, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_player_panel(p) -> void:
	var w := 740.0
	var rect := Rect2(size.x / 2.0 - w / 2.0, size.y - 126, w, 112)
	_plate(rect, INK, GOLD_DARK, 14, 2)
	# Portrait in a framed square with the level badge.
	var frame := Rect2(rect.position + Vector2(12, 10), Vector2(84, 84))
	_plate(frame, INK_LIGHT, GOLD, 12, 2)
	_portrait(frame.get_center(), 28, p.team, p.role, p.dead)
	_hex(frame.position + Vector2(8, 76), 34, 24, INK, GOLD)
	_text(frame.position + Vector2(-9, 81), str(p.level), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 34, 2)
	# Name, hearts and energy.
	var x := rect.position.x + 110
	_text(Vector2(x, rect.position.y + 28), p.role_name().to_upper(), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(Vector2(x + _text_width(p.role_name().to_upper(), 20) + 10, rect.position.y + 28),
		Stats.FACTIONS[p.team].name.to_upper(), 11, _team_color(p.team).lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if p.dead:
		_hearts(Vector2(x + 16, rect.position.y + 54), 0, 0.85, 36)
		_text(Vector2(x, rect.position.y + 86), "Down! Back in %d" % ceili(p.respawn_timer), 16, Color(1, 0.6, 0.5))
	else:
		_hearts(Vector2(x + 16, rect.position.y + 54), p.hearts, 0.85, 36)
		var is_mana: bool = p.energy_kind() == "mana"
		var bar := Rect2(Vector2(x, rect.position.y + 70), Vector2(236, 16))
		_bar(bar, p.energy / p.energy_max(), MANA if is_mana else STAMINA)
		_text(bar.position + Vector2(0, 13), "%s  %d / %d" % ["MANA" if is_mana else "STAMINA", int(p.energy), int(p.energy_max())],
			11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 3)
	# Experience this life.
	var span: Array = Stats.xp_span(p.level)
	var xp_bar := Rect2(Vector2(x, rect.position.y + 92), Vector2(236, 10))
	var frac := 1.0 if span[1] < 0 else float(p.xp - span[0]) / float(span[1] - span[0])
	_bar(xp_bar, frac, XP)
	var xp_text := "MAX LEVEL" if span[1] < 0 else "XP %d / %d" % [p.xp, span[1]]
	_text(xp_bar.position + Vector2(0, 9), xp_text, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, xp_bar.size.x, 2)
	if p.points > 0 and not p.dead:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		var badge := Rect2(rect.position + Vector2(236, 4), Vector2(112, 22))
		_plate(badge, Color(0.55, 0.4, 0.05, pulse), GOLD, 6, 1)
		_text(badge.position + Vector2(0, 16), "TAB  RANK UP  +%d" % p.points, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 2)
	# Slots: attack, Q, E, dodge, block (shield classes), grab.
	var abil: Array = p.abilities()
	var sx := rect.position.x + 352
	var sy := rect.position.y + 8
	var slot := 50.0
	var gap := 64.0
	var alive: bool = not p.dead and p.carrying == null
	var atk: Dictionary = p.attack_stats()
	_slot(Vector2(sx, sy), slot, _attack_icon(p.role), Stats.ROLES[p.role].color.lightened(0.3), "LMB", atk.attack_name,
		p.attack_timer, atk.cooldown, alive and p.energy >= atk.cost, p.rank(0))
	for i in 2:
		if i < abil.size():
			var a: Dictionary = p.ability(i)
			_slot(Vector2(sx + (i + 1) * gap, sy), slot, a.kind, Stats.ROLES[p.role].color.lightened(0.3), a.key, a.name,
				p.ability_timers[i], a.cooldown, p.energy >= a.cost and alive, p.rank(i + 1))
		else:
			_slot(Vector2(sx + (i + 1) * gap, sy), slot, "", Color.WHITE, ["Q", "E"][i], "pick a class", 0.0, 1.0, false)
	_slot(Vector2(sx + 3 * gap, sy), slot, "dodge", STAMINA, "SPACE", "Dodge", p.dodge_cooldown, Stats.DODGE_COOLDOWN,
		alive and p.energy >= Stats.DODGE_COST)
	if p.can_block():
		_slot(Vector2(sx + 4 * gap, sy), slot, "block", STEEL, "RMB", "Block", 0.0, 1.0, alive and p.energy > 0.0, 0, p.blocking)
	else:
		_slot(Vector2(sx + 4 * gap, sy), slot, "vigor", XP, "TAB", "Ranks", 0.0, 1.0, p.points > 0, p.rank(3))
	_slot(Vector2(sx + 5 * gap, sy), slot, "crown", GOLD, "F", "Drop" if p.carrying else "Grab", 0.0, 1.0, not p.dead)


# --- Map ---------------------------------------------------------------------

func _draw_map(rect: Rect2, detailed: bool) -> void:
	## The valley from above: castles, keeps, doors, road, orbs, everyone's
	## position. The minimap and the menu's overview share this.
	var hx: float = game.map_half.x
	var hz: float = game.map_half.y
	_plate(rect, GRASS.darkened(0.2), GOLD_DARK, 8, 2)
	var inner := rect.grow(-3)
	draw_rect(inner, GRASS)
	var m := func(p: Vector3) -> Vector2:
		return inner.position + Vector2((p.x + hx) / (2.0 * hx) * inner.size.x, (p.z + hz) / (2.0 * hz) * inner.size.y)
	var sx: float = inner.size.x / (2.0 * hx)
	var sz: float = inner.size.y / (2.0 * hz)
	var fx: float = game.CASTLE_X - game.CASTLE_DEPTH
	# Road and worn patches.
	draw_rect(Rect2(m.call(Vector3(-fx, 0, -2)), Vector2(2.0 * fx * sx, 4.0 * sz)), DIRT)
	draw_rect(Rect2(m.call(Vector3(-6, 0, -6)), Vector2(12 * sx, 12 * sz)), DIRT)
	# Groves (only on the big map).
	if detailed:
		for p in [Vector3(5, 0, 7), Vector3(10, 0, 12), Vector3(16, 0, 6), Vector3(8, 0, 17), Vector3(19, 0, 15),
				Vector3(23, 0, 10), Vector3(3, 0, 13), Vector3(14, 0, 19), Vector3(27, 0, 14)]:
			for q in [p, -p]:
				draw_circle(m.call(q), 2.2 * sx, LEAF.darkened(0.2))
		for p in [Vector3(38, 0, 17), Vector3(46, 0, 19), Vector3(52, 0, 16), Vector3(34, 0, 22)]:
			for q in [p, -p, Vector3(p.x, 0, -p.z), Vector3(-p.x, 0, p.z)]:
				draw_circle(m.call(q), 3.0 * sx, LEAF.darkened(0.3))
	for t in 2:
		var side := -1.0 if t == 0 else 1.0
		var tc := _team_color(t)
		var ox: float = side * (game.CASTLE_X - game.CASTLE_DEPTH)
		var bx: float = side * (game.CASTLE_X + game.CASTLE_DEPTH)
		var outer := Rect2(m.call(Vector3(minf(ox, bx), 0, -game.CASTLE_HALF_Z)),
			Vector2(2.0 * game.CASTLE_DEPTH * sx, 2.0 * game.CASTLE_HALF_Z * sz))
		draw_rect(outer, tc.darkened(0.55))
		draw_rect(outer, tc.lightened(0.1), false, 2.0)
		var kx: float = game._keep_x(t)
		var keep := Rect2(m.call(Vector3(minf(kx, bx), 0, -game.KEEP_HALF_Z)),
			Vector2(absf(bx - kx) * sx, 2.0 * game.KEEP_HALF_Z * sz))
		draw_rect(keep, tc.darkened(0.3))
		# Door: gold while standing, red once broken.
		var gate = game.gates[t]
		var door_color: Color = RED if gate.broken else GOLD
		draw_line(m.call(Vector3(ox, 0, -Stats.DOOR_HALF)), m.call(Vector3(ox, 0, Stats.DOOR_HALF)), door_color, 3.0)
		_crown(m.call(game.thrones[t]), 0.45 if not detailed else 0.9)
		if detailed:
			_text(outer.position + Vector2(0, -6), "%s CASTLE" % Stats.FACTIONS[t].name.to_upper(), 11, tc.lightened(0.5), HORIZONTAL_ALIGNMENT_CENTER, outer.size.x, 2)
	# Healing orbs that are up.
	for orb in game.heal_orbs:
		if orb.active:
			draw_circle(m.call(orb.global_position), 2.5 if not detailed else 4.0, Color(0.4, 1.0, 0.5))
	# Everyone.
	for u in game.units:
		if u.dead:
			continue
		var c: Vector2 = m.call(u.global_position)
		var r := 3.0 if not detailed else 5.0
		if u.is_player:
			draw_circle(c, r + 2.5, Color(1, 1, 0.3))
			var d := Vector2(u.facing.x, u.facing.z) * (r + 6.0)
			draw_line(c, c + d, Color(1, 1, 0.3), 2.0)
		draw_circle(c, r, _team_color(u.team).lightened(0.2))
		draw_arc(c, r, 0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
		if u.carrying:
			_crown(c + Vector2(0, -r - 5), 0.5)
	# Monarchs out of their thrones.
	for mon in game.monarchs:
		if mon.state != mon.State.HOME and mon.state != mon.State.CARRIED:
			_crown(m.call(mon.global_position), 0.6, Color(1, 0.5, 0.3))
	if detailed:
		_text(m.call(Vector3(0, 0, -hz + 2.5)), "CENTRAL CROSSING", 11, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, 2)


# --- Rank menu ---------------------------------------------------------------

func _rank_desc(p, track: int) -> String:
	var r: int = p.rank(track)
	if track == 3:
		return "+%d%% speed, +%d max %s, +%d%% regen per rank" % [int(Stats.VIGOR_SPEED * 100), int(Stats.VIGOR_ENERGY),
			p.energy_kind(), int(Stats.VIGOR_REGEN * 100)]
	var next := r + 1
	match next:
		1: return "Rank 1: cools down %d%% faster and costs %d%% less" % [int(Stats.RANK_COOLDOWN_CUT * 100), int(Stats.RANK_COST_CUT * 100)]
		2: return "Rank 2: bigger effect (range, radius, duration, more arrows)"
		3: return "Rank 3: one more heart of damage or healing"
	return "Maxed out"


func _draw_rank_menu(p) -> void:
	var rect := Rect2(size.x / 2.0 - 290, size.y / 2.0 - 200, 580, 356)
	_plate(rect, INK, GOLD, 14, 3)
	_close(rect)
	_text(rect.position + Vector2(0, 32), "RANK UP", 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 4)
	_text(rect.position + Vector2(0, 54), "Level %d  ·  %d point%s to spend  ·  experience is per life" % [p.level, p.points, "" if p.points == 1 else "s"],
		13, CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
	var icons := [_attack_icon(p.role), "", "", "vigor"]
	for i in 2:
		if i < p.abilities().size():
			icons[i + 1] = p.abilities()[i].kind
	for t in 4:
		var row := Rect2(rect.position + Vector2(16, 70 + t * 64), Vector2(rect.size.x - 32, 58))
		var available: bool = p.track_available(t)
		_plate(row, INK_LIGHT if available else Color(0.12, 0.12, 0.15, 0.9), GOLD_DARK if available else Color(0.3, 0.3, 0.3), 8, 1)
		var cls_color: Color = Stats.ROLES[p.role].color.lightened(0.3)
		if available:
			_icon(icons[t], row.position + Vector2(30, 29), 13, cls_color if t < 3 else XP)
		var name: String = p.track_name(t) if available else "No %s ability yet" % ["", "Q", "E", ""][t]
		_text(row.position + Vector2(60, 22), name, 15, Color.WHITE if available else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		for k in Stats.MAX_RANK:
			var c := row.position + Vector2(66 + k * 16, 36)
			draw_circle(c, 5.5, GOLD if k < p.rank(t) else Color(0.2, 0.2, 0.25))
			draw_arc(c, 5.5, 0, TAU, 12, GOLD_DARK, 1.0)
		if available:
			_text(row.position + Vector2(125, 40), _rank_desc(p, t), 10, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		var can: bool = available and p.points > 0 and p.rank(t) < Stats.MAX_RANK
		var button := Rect2(row.end.x - 118, row.position.y + 13, 106, 32)
		_plate(button, Color(0.2, 0.5, 0.25, 0.95) if can else Color(0.2, 0.2, 0.22, 0.9), GOLD if can else Color(0.35, 0.35, 0.4), 7, 1)
		var label := "RANK UP" if p.rank(t) < Stats.MAX_RANK else "MAXED"
		_text(button.position + Vector2(0, 21), label, 12, Color.WHITE if can else GREY, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 2)
		_keycap(button.position + Vector2(-16, 16), str(t + 1), 22)
		rank_buttons.append(button if can else Rect2())
	_text(rect.position + Vector2(0, rect.size.y - 12), "Press 1-4 or click to spend a point  ·  Tab closes", 11, GREY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


# --- Game menu ---------------------------------------------------------------

func _draw_game_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var rect := Rect2(size.x / 2.0 - 390, size.y / 2.0 - 250, 780, 500)
	_plate(rect, INK, GOLD, 16, 3)
	_close(rect)
	_text(rect.position + Vector2(0, 34), "GAME MENU", 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 4)
	# Tabs.
	for i in TABS.size():
		var tab := Rect2(rect.position + Vector2(24 + i * 130, 50), Vector2(122, 30))
		var on: bool = game.menu_tab == i
		_plate(tab, Color(0.3, 0.26, 0.12, 0.98) if on else INK_LIGHT, GOLD if on else GOLD_DARK, 8, 1)
		_text(tab.position + Vector2(0, 21), TABS[i], 13, GOLD if on else Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 2)
		tab_buttons.append(tab)
	var body := Rect2(rect.position + Vector2(24, 92), Vector2(rect.size.x - 48, rect.size.y - 130))
	match game.menu_tab:
		0: _menu_overview(body)
		1: _menu_classes(body)
		2: _menu_controls(body)
	_text(rect.position + Vector2(0, rect.size.y - 12), "Esc resumes  ·  ← → or A/D switch tabs  ·  Backspace quits to the title", 11, GREY,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


func _menu_overview(body: Rect2) -> void:
	_text(body.position + Vector2(0, 16), "THE WILDWOOD VALLEY", 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 3)
	var map_rect := Rect2(body.position + Vector2(0, 26), Vector2(body.size.x, body.size.x * 26.0 / 58.0))
	_draw_map(map_rect, true)
	var y := map_rect.end.y + 22
	var legend := [["Yellow ring: you", Color(1, 1, 0.3)], ["Green dots: healing orbs", Color(0.4, 1.0, 0.5)],
		["Gold line: standing door", GOLD], ["Red line: broken door", RED]]
	for i in legend.size():
		var x: float = body.position.x + 10 + i * (body.size.x / legend.size())
		draw_circle(Vector2(x, y - 4), 5, legend[i][1])
		_text(Vector2(x + 12, y), legend[i][0], 11, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_text(body.position + Vector2(0, y + 26), "Break the enemy door, carry their monarch home. Class stations are inside your keep.", 12, GREY,
		HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 2)


func _menu_classes(body: Rect2) -> void:
	var team: int = game.player_team
	var roles := [Role.KNIGHT, Role.RANGER, Role.MAGE, Role.HEALER]
	var cw := (body.size.x - 3 * 10) / 4.0
	for i in roles.size():
		var role: int = roles[i]
		var s: Dictionary = Stats.ROLES[role]
		var card := Rect2(body.position + Vector2(i * (cw + 10), 0), Vector2(cw, body.size.y))
		var mine: bool = game.player and game.player.role == role
		_plate(card, INK_LIGHT, GOLD if mine else GOLD_DARK, 10, 2)
		_portrait(card.position + Vector2(cw / 2.0, 44), 26, team, role)
		_text(card.position + Vector2(0, 92), Stats.FACTIONS[team].roles[role].to_upper(), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, cw, 3)
		_text(card.position + Vector2(0, 108), ("uses %s" % s.energy).to_upper(), 10, MANA if s.energy == "mana" else STAMINA, HORIZONTAL_ALIGNMENT_CENTER, cw, 2)
		var y := 128.0
		var entries := [["LMB", s.attack_name, s.attack_desc, _attack_icon(role)]]
		for a in s.abilities:
			entries.append([a.key, a.name, a.desc, a.kind])
		if s.get("block", false):
			entries.append(["RMB", "Block", "Hold to stop hits from the front with your shield.", "block"])
		for e in entries:
			_icon(e[3], card.position + Vector2(18, y + 2), 7, s.color.lightened(0.3))
			_keycap(card.position + Vector2(cw - 26, y + 2), e[0], 34 if e[0].length() > 2 else 24)
			_text(card.position + Vector2(32, y + 6), e[1], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			y += 14.0
			y += _paragraph(card.position + Vector2(12, y + 10), e[2], 10, Color(0.8, 0.8, 0.8), cw - 24, 12.0) + 10.0
		if mine:
			_text(card.position + Vector2(0, card.size.y - 10), "YOUR CLASS", 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER, cw, 2)


func _menu_controls(body: Rect2) -> void:
	var cols := [["KEYBOARD AND MOUSE", [
			["WASD", "Move"], ["Mouse", "Aim"], ["Left click", "Base attack"], ["Right click", "Block (shield classes)"],
			["Q / E", "Class abilities"], ["Space", "Dodge"], ["F", "Grab or drop the monarch"],
			["Tab", "Rank menu"], ["Esc", "This menu"]]],
		["GAMEPAD", [
			["Left stick", "Move"], ["Right stick", "Aim"], ["A / RT", "Base attack"], ["LB / LT", "Block"],
			["X / Y", "Class abilities"], ["B", "Dodge"], ["RB", "Grab or drop the monarch"],
			["Back", "Rank menu, D-pad spends"], ["Start", "This menu"]]]]
	for c in cols.size():
		var x: float = body.position.x + c * body.size.x / 2.0
		_text(Vector2(x, body.position.y + 18), cols[c][0], 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, body.size.x / 2.0, 3)
		for i in cols[c][1].size():
			var y: float = body.position.y + 48 + i * 30
			_keycap(Vector2(x + 70, y), cols[c][1][i][0], 110)
			_text(Vector2(x + 140, y + 5), cols[c][1][i][1], 13, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_text(body.position + Vector2(0, body.size.y - 30), "You spawn as a villager. Step on a class station in your keep to become a Knight, Ranger, Mage or Healer.",
		11, GREY, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 2)
	_text(body.position + Vector2(0, body.size.y - 12), "Walk off the front of your castle wall to drop into the field. Dying resets your class and experience.",
		11, GREY, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 2)


# --- Title and end screens -----------------------------------------------------

func _faction_card(rect: Rect2, team: int, key: String, pad: String, blurb: String) -> void:
	var tc := _team_color(team)
	_plate(rect, tc.darkened(0.72), tc.lightened(0.1), 14, 3)
	_portrait(rect.position + Vector2(rect.size.x / 2.0, 70), 40, team, Role.KNIGHT)
	_text(rect.position + Vector2(0, 146), Stats.FACTIONS[team].name.to_upper(), 28, tc.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 5)
	_text(rect.position + Vector2(0, 170), blurb, 13, CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 3)
	_keycap(rect.position + Vector2(rect.size.x / 2.0 - 46, 200), key, 60)
	_text(rect.position + Vector2(rect.size.x / 2.0 - 10, 205), "or " + pad, 12, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.05, 0.8))
	var cx := size.x / 2.0
	_draw_logo(Rect2(cx - 260, 10, 520, 208))
	_text(Vector2(cx - 300, 236), "Elves against Humans. Break the door, steal the monarch, carry them home.", 15, CREAM,
		HORIZONTAL_ALIGNMENT_CENTER, 600, 3)
	_text(Vector2(cx - 300, 264), "CHOOSE YOUR SIDE", 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 600, 3)
	_faction_card(Rect2(cx - 330, 280, 300, 226), 0, "1", "D-pad left", "Quicker on their feet")
	_faction_card(Rect2(cx + 30, 280, 300, 226), 1, "2", "D-pad right", "Recover stamina and mana faster")
	var rect := Rect2(cx - 330, 520, 660, 92)
	_plate(rect, INK, GOLD_DARK, 10, 2)
	_text(rect.position + Vector2(0, 22), "HOW TO PLAY", 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
	var lines := [
		"Move WASD  ·  Aim with the mouse  ·  Left click attacks  ·  Right click blocks  ·  Space dodges",
		"Q and E are class abilities  ·  F grabs the monarch  ·  Tab opens the rank menu  ·  Esc opens the game menu",
		"You spawn as a villager: step on a class station in your keep to become a Knight, Ranger, Mage or Healer.",
	]
	for i in lines.size():
		_text(rect.position + Vector2(0, 44 + i * 18), lines[i], 12, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


func _ribbon(center: Vector2, w: float, h: float, color: Color) -> void:
	var p := PackedVector2Array([
		center + Vector2(-w / 2, -h / 2), center + Vector2(w / 2, -h / 2), center + Vector2(w / 2 + h * 0.5, 0),
		center + Vector2(w / 2, h / 2), center + Vector2(-w / 2, h / 2), center + Vector2(-w / 2 - h * 0.5, 0)])
	draw_colored_polygon(p, color.darkened(0.3))
	for i in p.size():
		p[i] = center + (p[i] - center) * Vector2(0.97, 0.8)
	draw_colored_polygon(p, color)


func _draw_end() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var cx := size.x / 2.0
	var winner: int = game.winner_team
	var outcome := "DRAW"
	var color := Color(0.5, 0.5, 0.55)
	if winner >= 0:
		outcome = "VICTORY!" if winner == game.player_team else "DEFEAT"
		color = Color(0.2, 0.5, 0.95) if winner == game.player_team else Color(0.6, 0.15, 0.15)
	_crown(Vector2(cx, 200), 3.0)
	_ribbon(Vector2(cx, 270), 420, 76, color)
	_text(Vector2(cx - 210, 286), outcome, 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 420, 6)
	_plate(Rect2(cx - 170, 330, 340, 90), INK, GOLD, 12, 2)
	_text(Vector2(cx - 170, 365), "%s %d   -   %d %s" % [Stats.FACTIONS[0].name, game.score[0], game.score[1], Stats.FACTIONS[1].name],
		24, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 340, 4)
	_text(Vector2(cx - 170, 400), "Press R or Enter to play again", 14, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 340, 3)
