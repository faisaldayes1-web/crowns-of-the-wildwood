extends Control
## In-match HUD plus the title and end screens, drawn in code after the UI
## mockup: logo top-left, score and timer up top, team rosters with portraits
## down each side, the player's portrait, hearts, energy and ability slots at
## the bottom, and the objective card bottom-right. Reskin by editing here.

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
const RED := Color(0.85, 0.2, 0.2)
const STEEL := Color(0.75, 0.77, 0.82)
const LEAF := Color(0.3, 0.62, 0.3)

var game
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	if not game.playing and not game.game_over:
		_draw_title()
		return
	_draw_logo(Vector2(18, 12), 0.72)
	_draw_scoreboard()
	_draw_roster(0, Vector2(14, 112))
	_draw_roster(1, Vector2(size.x - 254, 112))
	_draw_objective()
	if game.player:
		_draw_player_panel(game.player)
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
		"bash", "guard":
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
			else:
				draw_arc(c, 1.3 * s, 0, TAU, 32, Color(color, 0.7), 2.0)
		"volley":
			for ang in [-0.45, 0.0, 0.45]:
				var d := Vector2(sin(ang), -cos(ang))
				var tip := c + d * s * 1.1
				draw_line(c - d * s * 0.9, tip, color, 2.5)
				var side := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([tip + d * 0.3 * s, tip + side * 0.25 * s, tip - side * 0.25 * s]), color)
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
		"blessing":
			draw_circle(c, 0.5 * s, color)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 0.7 * s, c + Vector2(cos(a), sin(a)) * 1.2 * s, color, 2.5)
		"smite":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.15 * s, -1.2 * s), c + Vector2(0.5 * s, -1.2 * s),
				c + Vector2(0.1 * s, -0.2 * s), c + Vector2(0.6 * s, -0.2 * s), c + Vector2(-0.4 * s, 1.2 * s),
				c + Vector2(-0.1 * s, 0.1 * s), c + Vector2(-0.6 * s, 0.1 * s)]), color)
		"dodge":
			for dx in [-0.9, -0.1, 0.7]:
				draw_polyline(PackedVector2Array([c + Vector2(dx * s - 0.3 * s, -0.8 * s), c + Vector2(dx * s + 0.3 * s, 0),
					c + Vector2(dx * s - 0.3 * s, 0.8 * s)]), color, 3.0)
		"crown":
			_crown(c, s / 10.0, color)
		"sword":
			draw_line(c + Vector2(-0.8 * s, 0.8 * s), c + Vector2(0.7 * s, -0.7 * s), color, 3.5)
			draw_line(c + Vector2(-0.3 * s, -0.2 * s), c + Vector2(0.2 * s, 0.3 * s), GOLD, 3.0)
			draw_circle(c + Vector2(-0.85 * s, 0.85 * s), 0.18 * s, GOLD)
		"flag":
			draw_line(c + Vector2(-0.8 * s, -1.0 * s), c + Vector2(-0.8 * s, 1.0 * s), color, 2.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8 * s, -1.0 * s), c + Vector2(0.9 * s, -0.5 * s),
				c + Vector2(-0.8 * s, 0.0)]), color)


func _keycap(center: Vector2, key: String, w: float = 30.0) -> void:
	var rect := Rect2(center - Vector2(w / 2.0, 10), Vector2(w, 20))
	_plate(rect, CREAM, Color(0.5, 0.4, 0.25), 5, 1)
	_text(rect.position + Vector2(0, 15), key, 12, Color(0.15, 0.12, 0.1), HORIZONTAL_ALIGNMENT_CENTER, w, 0)


func _slot(origin: Vector2, size_px: float, icon: String, color: Color, key: String, label: String,
		remaining: float, total: float, usable: bool) -> void:
	var rect := Rect2(origin, Vector2(size_px, size_px))
	var ready := remaining <= 0.0 and usable
	_plate(rect, INK_LIGHT, GOLD if ready else Color(0.35, 0.33, 0.4), 9, 2)
	_icon(icon, rect.get_center(), size_px * 0.28, color if ready else color.darkened(0.45))
	if remaining > 0.0:
		var frac := clampf(remaining / maxf(total, 0.01), 0.0, 1.0)
		var inner := rect.grow(-3)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * frac)), Color(0, 0, 0, 0.65))
		_text(rect.position + Vector2(0, size_px * 0.62), ("%.1f" % remaining) if remaining < 10.0 else str(ceili(remaining)),
			16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size_px)
	elif not usable:
		draw_rect(rect.grow(-3), Color(0.5, 0.1, 0.1, 0.35))
	_keycap(Vector2(rect.get_center().x, rect.end.y + 4), key, 34 if key.length() > 2 else 26)
	_text(Vector2(rect.position.x - 20, rect.end.y + 30), label, 10, Color(0.85, 0.85, 0.85),
		HORIZONTAL_ALIGNMENT_CENTER, size_px + 40)


func _draw_logo(pos: Vector2, scale: float) -> void:
	var big := int(40 * scale)
	var small := int(15 * scale)
	var w := _text_width("CROWNS", big)
	_crown(pos + Vector2(w / 2.0, 10 * scale), 1.3 * scale)
	_text(pos + Vector2(0, 46 * scale), "CROWNS", big, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	_text(pos + Vector2(w / 2.0 - 60 * scale, 62 * scale), "OF THE", small, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 120 * scale, 3)
	_text(pos + Vector2(-6 * scale, 96 * scale), "WILDWOOD", int(34 * scale), LEAF.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	# Little leaves either side of the word.
	for side in [-1.0, 1.0]:
		var lx: float = pos.x + (w / 2.0) + side * (w / 2.0 + 14 * scale)
		var ly := pos.y + 86 * scale
		draw_colored_polygon(PackedVector2Array([Vector2(lx, ly), Vector2(lx + side * 14 * scale, ly - 8 * scale),
			Vector2(lx + side * 10 * scale, ly + 6 * scale)]), LEAF)


# --- In-match panels ---------------------------------------------------------

func _draw_scoreboard() -> void:
	var cx := size.x / 2.0
	_hex(Vector2(cx - 165, 36), 140, 50, _team_color(0).darkened(0.25), GOLD)
	_hex(Vector2(cx + 165, 36), 140, 50, _team_color(1).darkened(0.25), GOLD)
	_plate(Rect2(cx - 85, 10, 170, 54), INK, GOLD_DARK, 8, 2)
	_crown(Vector2(cx - 205, 36), 1.5)
	_crown(Vector2(cx + 205, 36), 1.5)
	_text(Vector2(cx - 185, 48), str(game.score[0]), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 60)
	_text(Vector2(cx + 125, 48), str(game.score[1]), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 60)
	var left := maxf(game.time_left, 0.0)
	var urgent := left < 60.0 and int(left * 2.0) % 2 == 0
	_text(Vector2(cx - 85, 49), "%02d:%02d" % [int(left) / 60, int(left) % 60], 34,
		Color(1, 0.4, 0.3) if urgent else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 170)
	_plate(Rect2(cx - 95, 66, 190, 22), INK, GOLD_DARK, 6, 1)
	_text(Vector2(cx - 95, 82), "CAPTURE THE CROWN", 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 190, 2)


func _draw_roster(team: int, origin: Vector2) -> void:
	var row := 0
	var tc := _team_color(team)
	for u in game.units:
		if u.team != team:
			continue
		var rect := Rect2(origin + Vector2(0, row * 54), Vector2(240, 48))
		_plate(rect, tc.darkened(0.7) if not u.is_player else Color(0.3, 0.24, 0.08, 0.95),
			GOLD if u.is_player else tc.darkened(0.2), 10, 2)
		_portrait(rect.position + Vector2(26, 24), 15, team, u.role, u.dead)
		var name: String = u.role_name()
		_text(rect.position + Vector2(52, 19), name, 14, tc.lightened(0.45) if not u.is_player else GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		if u.is_player:
			_text(rect.position + Vector2(56 + _text_width(name, 14), 19), "YOU", 10, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
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
	var rect := Rect2(size.x - 286, size.y - 128, 272, 108)
	_plate(rect, INK, GOLD_DARK, 10, 2)
	_icon("flag", rect.position + Vector2(20, 20), 9, RED)
	_text(rect.position + Vector2(36, 25), "CAPTURE THE CROWN", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	draw_line(rect.position + Vector2(12, 34), rect.position + Vector2(260, 34), GOLD_DARK, 1.0)
	var lines := ["Break the enemy castle door", "Carry their monarch to your throne",
		"First to %d captures wins" % Stats.CAPTURES_TO_WIN]
	for i in lines.size():
		var y := 54 + i * 18
		draw_circle(rect.position + Vector2(18, y - 4), 3, GOLD)
		_text(rect.position + Vector2(28, y), lines[i], 12, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_player_panel(p) -> void:
	var w := 700.0
	var rect := Rect2(size.x / 2.0 - w / 2.0, size.y - 118, w, 104)
	_plate(rect, INK, GOLD_DARK, 14, 2)
	# Portrait in a framed square.
	var frame := Rect2(rect.position + Vector2(12, 10), Vector2(84, 84))
	_plate(frame, INK_LIGHT, GOLD, 12, 2)
	_portrait(frame.get_center(), 28, p.team, p.role, p.dead)
	# Name, hearts and energy.
	var x := rect.position.x + 110
	_text(Vector2(x, rect.position.y + 30), p.role_name().to_upper(), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(Vector2(x + _text_width(p.role_name().to_upper(), 20) + 10, rect.position.y + 30),
		Stats.FACTIONS[p.team].name.to_upper(), 11, _team_color(p.team).lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if p.dead:
		_hearts(Vector2(x + 16, rect.position.y + 58), 0, 0.85, 36)
		_text(Vector2(x, rect.position.y + 92), "Down! Back in %d" % ceili(p.respawn_timer), 16, Color(1, 0.6, 0.5))
	else:
		_hearts(Vector2(x + 16, rect.position.y + 58), p.hearts, 0.85, 36)
		var is_mana: bool = p.energy_kind() == "mana"
		var bar := Rect2(Vector2(x, rect.position.y + 76), Vector2(236, 18))
		_bar(bar, p.energy / p.energy_max(), MANA if is_mana else STAMINA)
		_text(bar.position + Vector2(0, 14), "%s  %d / %d" % ["MANA" if is_mana else "STAMINA", int(p.energy), int(p.energy_max())],
			12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 3)
	# Ability slots: Q, E, dodge, grab.
	var abil: Array = p.abilities()
	var sx := rect.position.x + 372
	var sy := rect.position.y + 8
	var slot := 56.0
	var gap := 76.0
	if abil.is_empty():
		for i in 2:
			_slot(Vector2(sx + i * gap, sy), slot, "", Color.WHITE, ["Q", "E"][i], "pick a class", 0.0, 1.0, false)
	else:
		for i in abil.size():
			var a: Dictionary = abil[i]
			_slot(Vector2(sx + i * gap, sy), slot, a.kind, Stats.ROLES[p.role].color.lightened(0.3), a.key, a.name,
				p.ability_timers[i], a.cooldown, p.energy >= a.cost and not p.dead and p.carrying == null)
	_slot(Vector2(sx + 2 * gap, sy), slot, "dodge", STAMINA, "SHIFT", "Dodge", p.dodge_cooldown, Stats.DODGE_COOLDOWN,
		not p.dead and p.carrying == null)
	_slot(Vector2(sx + 3 * gap, sy), slot, "crown", GOLD, "F", "Drop" if p.carrying else "Grab", 0.0, 1.0, not p.dead)


# --- Title and end screens -----------------------------------------------------

func _faction_card(rect: Rect2, team: int, key: String, pad: String, blurb: String) -> void:
	var tc := _team_color(team)
	_plate(rect, tc.darkened(0.72), tc.lightened(0.1), 14, 3)
	_portrait(rect.position + Vector2(rect.size.x / 2.0, 78), 44, team, Role.KNIGHT)
	_text(rect.position + Vector2(0, 160), Stats.FACTIONS[team].name.to_upper(), 30, tc.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 5)
	_text(rect.position + Vector2(0, 186), blurb, 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 3)
	_keycap(rect.position + Vector2(rect.size.x / 2.0 - 46, 220), key, 60)
	_text(rect.position + Vector2(rect.size.x / 2.0 - 10, 225), "or " + pad, 12, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.05, 0.8))
	var cx := size.x / 2.0
	_draw_logo(Vector2(cx - 120, 24), 1.5)
	_text(Vector2(cx - 300, 190), "Elves against Humans. Break the door, steal the monarch, carry them home.", 15, CREAM,
		HORIZONTAL_ALIGNMENT_CENTER, 600, 3)
	_text(Vector2(cx - 300, 222), "CHOOSE YOUR SIDE", 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 600, 3)
	_faction_card(Rect2(cx - 330, 240, 300, 250), 0, "1", "D-pad left", "Quicker on their feet")
	_faction_card(Rect2(cx + 30, 240, 300, 250), 1, "2", "D-pad right", "Recover stamina and mana faster")
	var rect := Rect2(cx - 330, 506, 660, 92)
	_plate(rect, INK, GOLD_DARK, 10, 2)
	_text(rect.position + Vector2(0, 22), "HOW TO PLAY", 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
	var lines := [
		"Move WASD or left stick  ·  Aim with the mouse or right stick  ·  Attack: left click or A",
		"Abilities Q and E (X, Y)  ·  Dodge Shift (B)  ·  Grab or drop the monarch F (RB)",
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
