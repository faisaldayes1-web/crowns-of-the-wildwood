extends Control
## In-match HUD plus the title, pause and rank menus, drawn in code after the
## UI references: the logo top-right, score and timer up top, team rosters with
## portraits down each side (hidden unless asked for), a minimap top-left, the player's portrait,
## hearts, energy, experience and ability slots at the bottom, and the
## chat on the left. Reskin by editing here.

const Stats = preload("res://scripts/stats.gd")
const Guide = preload("res://scripts/guide.gd")
const Monarch = preload("res://scripts/monarch.gd")
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

const TABS := ["MAP", "CLASSES", "UPGRADES", "SCOREBOARD", "CONTROLS", "SETTINGS"]

var game
var local_unit = null   # couch play: the local player this HUD belongs to (null = the main player)
var pane := false       # couch play: drawn inside one player's pane
var couch_buttons: Array = []   # title: [rect, "more"|"less"|"mode"]
var font: Font
var logo: Texture2D
var icons: Dictionary = {}  # kind -> Texture2D, painted icons from tools/make_icons.py
var cards: Dictionary = {}  # class portraits, crests and faction logos supplied by the project owner (assets/ui/cards)
# Where buttons were drawn this frame, so game.gd can hit-test mouse clicks.
var rank_buttons: Array = []
var variant_buttons: Array = []   # [rect, role, index]
var tab_buttons: Array = []
var tab_ids: Array = []
var bind_buttons: Array = []      # [rect, action]
var reset_button := Rect2()
var volume_sliders: Array = []   # [rect, "sound" | "music"] in the settings tab
var toggle_buttons: Array = []   # [rect, setting key] in the settings tab
var slot_prev: Dictionary = {}   # ability slot cooldowns last frame, for the ready flash
var slot_flash: Dictionary = {}  # ability slot -> seconds of ready flash left
var options_button := Rect2()
var close_button := Rect2()
var difficulty_buttons: Array = []  # [rect, name] on the title screen
var guide_buttons: Array = []       # [rect, "next" | "close" | topic index]
var chat_buttons: Array = []        # [rect, tab index]
var hero_buttons: Array = []        # [rect, "hair" | "trim" | "name", index]
var faction_buttons: Array = []     # [rect, team]
var title_buttons: Array = []       # [rect, tab] on the title screen


func _ready() -> void:
	font = ThemeDB.fallback_font
	logo = load("res://assets/ui/logo.png")
	# Every painted icon in assets/ui/icons (tools/make_icons.py).
	var dir := DirAccess.open("res://assets/ui/icons")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".png"):
				icons[file.trim_suffix(".png")] = load("res://assets/ui/icons/%s" % file)
			elif file.ends_with(".png.import"):
				var kind := file.trim_suffix(".png.import")
				if not icons.has(kind):
					icons[kind] = load("res://assets/ui/icons/%s.png" % kind)
	for key in ["crest_elf", "crest_human", "logo_elves", "logo_humans", "elf_base", "elf_knight", "elf_ranger", "elf_mage", "elf_healer",
			"human_base", "human_knight", "human_ranger", "human_mage", "human_healer"]:
		var path := "res://assets/ui/cards/%s.png" % key
		if ResourceLoader.exists(path):
			cards[key] = load(path)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if game:
		game.menu_tick()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if game and not pane:  # the panes would feed every key to the chat twice
		game.menu_input(event)


func _draw() -> void:
	if game == null:
		return
	rank_buttons = []
	variant_buttons = []
	tab_buttons = []
	tab_ids = []
	bind_buttons = []
	reset_button = Rect2()
	volume_sliders = []
	toggle_buttons = []
	options_button = Rect2()
	close_button = Rect2()
	difficulty_buttons = []
	guide_buttons = []
	chat_buttons = []
	hero_buttons = []
	faction_buttons = []
	title_buttons = []
	couch_buttons = []
	if not game.playing and not game.game_over:
		_draw_title()
		if game.menu_open:
			_draw_game_menu()
		return
	if game.couch_active and not pane:
		# Split screen: the panes draw their own players; this HUD, over the
		# whole window, keeps only what is shared (chat, guide, scoreboard,
		# pause menu, the end).
		if not game.guide_open:
			_draw_chat()
		if game.guide_open:
			_draw_guide()
		if game.scoreboard_open and not game.game_over:
			_draw_scoreboard_overlay()
		if game.menu_open:
			_draw_game_menu()
		if game.game_over:
			_draw_end()
		return
	_draw_screen_fx()
	_draw_logo(Rect2(size.x - 214, 8, 200, 80))
	_draw_scoreboard()
	if game.show_fps:
		_text(Vector2(size.x - 134, size.y - 152), "%d FPS" % Engine.get_frames_per_second(), 11, GREY, HORIZONTAL_ALIGNMENT_RIGHT, 120, 2)
	if game.rosters_visible and _me() and not pane:
		_draw_roster(_my_team(), Vector2(14, 130), true)
		_draw_roster(1 - _my_team(), Vector2(size.x - 214, 100), true)
	if not game.guide_open:
		# The minimap sits top-left; the objective card and HOW TO WIN list are
		# gone from the live HUD (the guide and the pause menu still carry them).
		_draw_map(Rect2(14, 8, 236, 110), false)
	_draw_toasts()
	if _me() and not game.guide_open:
		_draw_player_panel(_me())
	if game.killer_timer > 0.0 and _me() and _me().dead and not game.killer_card.is_empty():
		_draw_killer_card()
	if _me() and not _me().kill_banner.is_empty():
		_draw_kill_banner(_me())
	if not game.guide_open and not pane:
		_draw_kill_feed()
	if game.stolen_timer > 0.0:
		_draw_stolen_card()
	elif game.capture_timer > 0.0:
		_draw_capture_card()
	elif game.levelup_timer > 0.0:
		_draw_levelup_card()
	if pane:
		if local_unit:
			_text(Vector2(14, 136), "PLAYER %d" % (local_unit.local_index + 1), 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		if game.rank_open and game.rank_player == local_unit:
			_draw_rank_menu(local_unit)
		return
	if not game.guide_open:
		_draw_chat()
	if game.guide_open:
		_draw_guide()
	if game.scoreboard_open and not game.game_over:
		_draw_scoreboard_overlay()
	if game.rank_open and game.rank_player:
		_draw_rank_menu(game.rank_player)
	if game.menu_open:
		_draw_game_menu()
	if game.game_over:
		_draw_end()
	if game.cursor_shown:
		_draw_cursor()


func _mouse() -> Vector2:
	## The pointer the menus react to: the gamepad cursor while it drives them.
	return game.cursor if game.cursor_shown else get_local_mouse_position()


func nav_rects() -> Array:
	## Every button drawn this frame, for the gamepad cursor to jump between.
	var out: Array = []
	for list in [title_buttons, faction_buttons, hero_buttons, couch_buttons, tab_buttons, bind_buttons,
			difficulty_buttons, toggle_buttons, guide_buttons, chat_buttons, variant_buttons, volume_sliders]:
		for b in list:
			if b[0].size.x > 0.0:
				out.append(b[0])
	for r in rank_buttons:
		if r.size.x > 0.0:
			out.append(r)
	for r in [options_button, close_button, reset_button]:
		if r.size.x > 0.0:
			out.append(r)
	return out


func _draw_cursor() -> void:
	## A gold pointer where the gamepad cursor is.
	var c: Vector2 = game.cursor
	var pts := PackedVector2Array([c, c + Vector2(0, 22), c + Vector2(6, 17), c + Vector2(16, 16)])
	draw_colored_polygon(pts, Color(0.1, 0.08, 0.05, 0.9))
	var inner := PackedVector2Array([c + Vector2(2, 4), c + Vector2(2, 18), c + Vector2(6, 15), c + Vector2(12, 14)])
	draw_colored_polygon(inner, GOLD)
	draw_arc(c + Vector2(6, 10), 16.0, 0, TAU, 24, Color(1.0, 0.9, 0.5, 0.35), 2.0)


func _me():
	## The player this HUD is about.
	return local_unit if local_unit else game.player


func _my_team() -> int:
	return local_unit.team if local_unit else game.player_team


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
	# A soft sheen on the upper half and a thin inner line give the plates a bevelled, painted look.
	if rect.size.y > 30 and border >= 2:
		var inner := rect.grow(-border - 2)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(1, 1, 1, 0.045))
		draw_rect(inner, edge.darkened(0.3) if edge.v > 0.5 else edge.lightened(0.15), false, 1.0)


func _text(pos: Vector2, text: String, font_size: int, color: Color = Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 4) -> void:
	if outline > 0:
		draw_string_outline(font, pos, text, align, width, font_size, outline, Color(0.05, 0.04, 0.06, 0.85))
	draw_string(font, pos, text, align, width, font_size, color)


func _paragraph(pos: Vector2, text: String, font_size: int, color: Color, width: float, line_h: float, outline: int = 2) -> float:
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
		_text(pos + Vector2(0, i * line_h), lines[i], font_size, color, HORIZONTAL_ALIGNMENT_LEFT, -1, outline)
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


func _card_key(team: int, role: int) -> String:
	var names := {Role.BASE: "base", Role.KNIGHT: "knight", Role.RANGER: "ranger", Role.MAGE: "mage", Role.HEALER: "healer", Role.ENGINEER: "engineer", Role.ROGUE: "rogue"}
	return "%s_%s" % ["elf" if team == 0 else "human", names.get(role, "base")]


func _card(key: String, rect: Rect2, full: bool = true, dim: bool = false) -> bool:
	## Draw one of the supplied card images fitted inside rect. With full off
	## only the portrait part (the top of the card, above its name banner) is
	## used. Returns false if the art is missing so callers can fall back.
	if not cards.has(key):
		return false
	var tex: Texture2D = cards[key]
	var src := Rect2(Vector2.ZERO, tex.get_size())
	if not full:
		src.size.y *= 0.72
	var s := minf(rect.size.x / src.size.x, rect.size.y / src.size.y)
	var dst_size := src.size * s
	var dst := Rect2(rect.get_center() - dst_size / 2.0, dst_size)
	draw_texture_rect_region(tex, dst, src, Color(0.45, 0.45, 0.45) if dim else Color.WHITE)
	return true


func _class_card(c: Vector2, r: float, team: int, role: int, dead: bool = false) -> void:
	## The class portrait from the card sheet in a round gold frame; falls back
	## to the drawn chibi face when the art is missing.
	var key := _card_key(team, role)
	if not cards.has(key):
		_portrait(c, r, team, role, dead)
		return
	draw_circle(c, r + 4, GOLD_DARK)
	draw_circle(c, r + 2, GOLD if not dead else GREY)
	draw_circle(c, r, _team_color(team).darkened(0.55))
	# Clip the square art to the circle with a 16-gon fan of texture coords.
	var tex: Texture2D = cards[key]
	var ts := tex.get_size()
	var src := Rect2(Vector2(0, ts.y * 0.04), Vector2(ts.x, ts.x))
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var tint := Color(0.4, 0.4, 0.4) if dead else Color.WHITE
	for i in 24:
		var a := TAU * i / 24.0
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append((src.position + src.size * (Vector2(0.5, 0.5) + d * 0.5)) / ts)
		cols.append(tint)
	draw_polygon(pts, cols, uvs, tex)
	draw_arc(c, r, 0, TAU, 32, GOLD_DARK, 1.5)


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


func _icon(kind: String, c: Vector2, s: float, color: Color, dim: bool = false) -> void:
	## Painted icon when one exists (assets/ui/icons), else a simple vector symbol.
	if icons.has(kind):
		var px := s * 2.9
		draw_texture_rect(icons[kind], Rect2(c - Vector2(px, px) / 2.0, Vector2(px, px)), false,
			Color(0.45, 0.45, 0.5) if dim else Color.WHITE)
		return
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
		"hammer":
			draw_line(c + Vector2(-0.9 * s, 0.9 * s), c + Vector2(0.4 * s, -0.4 * s), color.darkened(0.3), 3.0)
			draw_rect(Rect2(c + Vector2(0.0, -1.0 * s), Vector2(1.0 * s, 0.6 * s)), color)
		"turret":
			draw_rect(Rect2(c + Vector2(-0.6 * s, 0.4 * s), Vector2(1.2 * s, 0.4 * s)), color.darkened(0.3))
			draw_rect(Rect2(c + Vector2(-0.12 * s, -0.4 * s), Vector2(0.24 * s, 0.8 * s)), color)
			draw_arc(c + Vector2(0, -0.45 * s), 0.7 * s, PI, TAU, 16, color, 2.5)
			draw_line(c + Vector2(0, -0.45 * s), c + Vector2(0, -1.2 * s), color, 2.0)
		"upgrade":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1.0 * s), c + Vector2(0.9 * s, 0.0), c + Vector2(0.35 * s, 0.0),
				c + Vector2(0.35 * s, 0.9 * s), c + Vector2(-0.35 * s, 0.9 * s), c + Vector2(-0.35 * s, 0.0), c + Vector2(-0.9 * s, 0.0)]), color)
		"overclock":
			draw_arc(c, 0.85 * s, 0, TAU, 24, color, 2.5)
			draw_line(c, c + Vector2(0, -0.6 * s), color, 2.5)
			draw_line(c, c + Vector2(0.45 * s, 0.2 * s), color, 2.5)
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


func _class_icon(role: int) -> String:
	match role:
		Role.KNIGHT: return "class_knight"
		Role.RANGER: return "class_ranger"
		Role.MAGE: return "class_mage"
		Role.HEALER: return "class_healer"
		Role.ENGINEER: return "class_engineer"
		Role.ROGUE: return "class_rogue"
	return "class_elf"


func _attack_icon(role: int, s: Dictionary = {}) -> String:
	if s.is_empty():
		s = Stats.kit(_my_team(), role)
	if s.get("drain", false):
		return "drain"
	if s.get("nature", false):
		return "bramble"
	if s.get("frost", false):
		return "frost"
	if s.get("fire", false):
		return "fireball"
	match s.attack:
		"melee": return "sword" if role == Role.KNIGHT else ("hammer" if role == Role.ENGINEER else ("dagger" if role == Role.ROGUE else "fist"))
		"arrow": return "arrow"
		"spell": return "bolt"
		"heal": return "mend"
	return "sword"


const PS_GLYPHS := {"Cross": Color(0.45, 0.62, 0.95), "Circle": Color(0.95, 0.4, 0.4), "Square": Color(0.95, 0.55, 0.8), "Triangle": Color(0.4, 0.85, 0.6)}
const XBOX_GLYPHS := {"A": Color(0.35, 0.75, 0.3), "B": Color(0.9, 0.3, 0.25), "X": Color(0.3, 0.55, 0.95), "Y": Color(0.95, 0.8, 0.2)}

func _keycap(center: Vector2, key: String, w: float = 30.0) -> void:
	## A cream keycap for keys and mouse buttons; PlayStation face buttons
	## are drawn as the shapes on the pad, Xbox face buttons as coloured
	## letters on a dark button.
	if PS_GLYPHS.has(key):
		var c: Color = PS_GLYPHS[key]
		draw_circle(center, 10.5, Color(0.12, 0.12, 0.15))
		draw_arc(center, 10.5, 0, TAU, 24, Color(0.45, 0.45, 0.5), 1.0)
		match key:
			"Cross":
				draw_line(center + Vector2(-4.5, -4.5), center + Vector2(4.5, 4.5), c, 2.0)
				draw_line(center + Vector2(-4.5, 4.5), center + Vector2(4.5, -4.5), c, 2.0)
			"Circle":
				draw_arc(center, 5.0, 0, TAU, 20, c, 2.0)
			"Square":
				draw_rect(Rect2(center - Vector2(4.5, 4.5), Vector2(9, 9)), c, false, 2.0)
			"Triangle":
				draw_polyline(PackedVector2Array([center + Vector2(0, -5.5), center + Vector2(5.5, 4), center + Vector2(-5.5, 4), center + Vector2(0, -5.5)]), c, 2.0)
		return
	if XBOX_GLYPHS.has(key):
		draw_circle(center, 10.5, Color(0.12, 0.12, 0.15))
		draw_arc(center, 10.5, 0, TAU, 24, Color(0.45, 0.45, 0.5), 1.0)
		_text(center + Vector2(-10.5, 5), key, 12, XBOX_GLYPHS[key], HORIZONTAL_ALIGNMENT_CENTER, 21, 0)
		return
	var rect := Rect2(center - Vector2(w / 2.0, 10), Vector2(w, 20))
	_plate(rect, CREAM, Color(0.5, 0.4, 0.25), 5, 1)
	_text(rect.position + Vector2(0, 15), key, 12, Color(0.15, 0.12, 0.1), HORIZONTAL_ALIGNMENT_CENTER, w, 0)


func _k(action: String) -> String:
	## The keycap label for this HUD's player: keyboard, or pad names when
	## they hold one.
	return game.key_label(action, local_unit)


func _slot(origin: Vector2, size_px: float, icon: String, color: Color, key: String, label: String,
		remaining: float, total: float, usable: bool, rank: int = 0, active: bool = false, cost: float = 0.0, cost_color: Color = STAMINA) -> void:
	var rect := Rect2(origin, Vector2(size_px, size_px))
	var ready := remaining <= 0.0 and usable
	# A ring bursts out of the slot the moment a cooldown ends.
	var slot_id := key + label
	var was: float = slot_prev.get(slot_id, remaining)
	if was > 0.0 and remaining <= 0.0 and usable:
		slot_flash[slot_id] = 0.45
	slot_prev[slot_id] = remaining
	var fl: float = slot_flash.get(slot_id, 0.0)
	if fl > 0.0:
		slot_flash[slot_id] = fl - get_process_delta_time()
		var k := 1.0 - fl / 0.45
		draw_arc(rect.get_center(), size_px * (0.55 + 0.4 * k), 0, TAU, 32, Color(1.0, 0.9, 0.5, 1.0 - k), 3.0)
	_plate(rect, INK_LIGHT if not active else Color(0.3, 0.35, 0.5, 0.96), GOLD if ready else Color(0.35, 0.33, 0.4), 9, 2)
	_icon(icon, rect.get_center(), size_px * 0.3, color if ready else color.darkened(0.45), not ready)
	if remaining > 0.0:
		var frac := clampf(remaining / maxf(total, 0.01), 0.0, 1.0)
		var inner := rect.grow(-3)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * frac)), Color(0, 0, 0, 0.65))
		_text(rect.position + Vector2(0, size_px * 0.62), ("%.1f" % remaining) if remaining < 10.0 else str(ceili(remaining)),
			16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size_px)
	elif not usable:
		draw_rect(rect.grow(-3), Color(0.5, 0.1, 0.1, 0.35))
	# The energy cost in the bottom-left corner, so you can see which moves
	# are cheap bread-and-butter and which ones to spend sparingly.
	if cost > 0.0:
		var tag := Rect2(rect.position + Vector2(3, size_px - 15), Vector2(22, 12))
		draw_rect(tag, Color(0, 0, 0, 0.6))
		_text(tag.position + Vector2(0, 10), str(int(cost)), 9, cost_color if usable else cost_color.darkened(0.4), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 0)
	# Rank pips in the top-right corner.
	for i in rank:
		draw_circle(rect.end - Vector2(8 + i * 8, size_px - 8), 2.6, GOLD)
		draw_arc(rect.end - Vector2(8 + i * 8, size_px - 8), 2.6, 0, TAU, 10, Color(0.3, 0.2, 0.05), 1.0)
	_keycap(Vector2(rect.get_center().x, rect.end.y + 2), key, maxf(26.0, _text_width(key, 12) + 12.0))
	_text(Vector2(rect.position.x - 20, rect.end.y + 27), label, 10, GOLD.lerp(Color.WHITE, 0.6) if ready else Color(0.6, 0.6, 0.65),
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

func _draw_guide() -> void:
	## Talking to an NPC: a visual-novel box along the bottom with a big
	## portrait on the left, a name plate, the line (or the topic menu) on
	## parchment, and a Next marker. Drawn over the HUD.
	var team: int = _my_team()
	var showing_menu: bool = game.guide_page < 0 and game.guide_topic < 0
	var body: String
	if game.guide_topic >= 0:
		body = game.guide_answer(game.guide_topic)
	elif game.guide_page >= 0:
		body = Guide.INTRO[game.guide_page]
	else:
		body = "What would you like to know?"
	var box := Rect2(24, size.y - 206, minf(size.x - 48, 940), 182)
	var parch := Color(0.96, 0.92, 0.8, 0.98)
	var brown := Color(0.45, 0.3, 0.14)
	# Portrait: the guide's card art, large, standing behind the box.
	var port := Rect2(box.position + Vector2(-6, -330), Vector2(360, 360))
	draw_circle(port.get_center() + Vector2(0, 40), 150, Color(0, 0, 0, 0.25))
	if not _card(_card_key(team, Role.MAGE), port, false):
		_portrait(port.get_center(), 110, team, Role.MAGE)
	_plate(box, parch, brown, 14, 3)
	draw_rect(box.grow(-6), Color(0.6, 0.45, 0.2, 0.35), false, 1.0)
	# Name plate.
	var tag := Rect2(box.position + Vector2(120, -22), Vector2(260, 40))
	_plate(tag, Color(0.12, 0.1, 0.1, 0.98), GOLD, 10, 3)
	_text(tag.position + Vector2(0, 27), "Wildwood Guide", 18, CREAM, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 3)
	var tx: float = box.position.x + 40
	var tw: float = box.size.x - 80
	var ty: float = box.position.y + 52
	if showing_menu:
		_text(Vector2(tx, ty), body, 17, Color(0.2, 0.13, 0.06), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		var cols := 2
		var cw: float = (tw - 12) / cols
		for i in Guide.TOPICS.size():
			var row := Rect2(tx + (i % cols) * (cw + 12), ty + 14 + (i / cols) * 32, cw, 27)
			var hover: bool = row.has_point(_mouse())
			_plate(row, Color(0.9, 0.82, 0.64) if hover else Color(0.93, 0.87, 0.72), Color(0.7, 0.55, 0.3), 6, 1)
			_keycap(row.position + Vector2(16, 13), str(i + 1), 20)
			_text(row.position + Vector2(34, 19), Guide.TOPICS[i][0], 13, Color(0.2, 0.12, 0.05), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
			guide_buttons.append([row, str(i)])
	else:
		_paragraph(Vector2(tx, ty), body, 19, Color(0.18, 0.12, 0.06), tw, 26, 0)
	# Footer: Next / Back marker and Close.
	var next_label: String = "Back" if game.guide_topic >= 0 else ("Next" if game.guide_page >= 0 else "")
	if next_label != "":
		var nb := Rect2(box.end.x - 150, box.end.y - 36, 110, 24)
		var pulse := 2.0 * sin(Time.get_ticks_msec() / 250.0)
		draw_colored_polygon(PackedVector2Array([nb.end + Vector2(22, -6 + pulse), nb.end + Vector2(36, -6 + pulse), nb.end + Vector2(29, 4 + pulse)]), brown)
		_text(nb.position + Vector2(0, 17), "[%s]  %s" % [_k("interact"), next_label], 12, brown, HORIZONTAL_ALIGNMENT_RIGHT, nb.size.x, 0)
		guide_buttons.append([Rect2(nb.position, nb.size + Vector2(40, 0)), "next"])
	var cb := Rect2(box.end.x - 110, box.position.y + 10, 96, 22)
	_plate(cb, Color(0.5, 0.3, 0.2), GOLD_DARK, 6, 1)
	_text(cb.position + Vector2(0, 16), "[%s]  Close" % _k("menu"), 11, CREAM, HORIZONTAL_ALIGNMENT_CENTER, cb.size.x, 2)
	guide_buttons.append([cb, "close"])


func _paragraph_height(text: String, font_size: int, width: float, line_h: float) -> float:
	var lines := 1
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if _text_width(trial, font_size) > width and line != "":
			lines += 1
			line = word
		else:
			line = trial
	return lines * line_h


func _draw_tutorial() -> void:
	## HOW TO WIN: a small checklist under the logo until the first capture.
	var steps := ["Leave your castle", "Fight for the center", "Break the enemy gate", "Reach the Crown Vault",
		"Open the Crown Chest", "Steal the Crown", "Return it to your throne", "Capture twice to win"]
	var rect := Rect2(size.x - 214, 356 if game.rosters_visible else 100, 200, 30 + steps.size() * 18)
	_plate(rect, INK, GOLD_DARK, 8, 1)
	_icon("crown", rect.position + Vector2(16, 15), 7, GOLD)
	_text(rect.position + Vector2(30, 20), "HOW TO WIN", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in steps.size():
		var done: bool = game.tutorial[i]
		var y: float = rect.position.y + 38 + i * 18
		var box := Rect2(rect.position.x + 12, y - 9, 11, 11)
		draw_rect(box, Color(0.3, 0.6, 0.3) if done else Color(0.2, 0.2, 0.26))
		draw_rect(box, GOLD_DARK, false, 1.0)
		if done:
			draw_line(box.position + Vector2(2, 6), box.position + Vector2(5, 9), CREAM, 2.0)
			draw_line(box.position + Vector2(5, 9), box.position + Vector2(10, 2), CREAM, 2.0)
		_text(Vector2(rect.position.x + 30, y + 1), steps[i], 11, GREY if done else CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_scoreboard() -> void:
	var cx := size.x / 2.0
	for t in 2:
		var dir := -1.0 if t == 0 else 1.0
		var c := Vector2(cx + dir * 175, 36)
		_hex(c, 160, 50, _team_color(t).darkened(0.25), GOLD)
		if not _card("crest_elf" if t == 0 else "crest_human", Rect2(c + Vector2(dir * 55 - 22, -22), Vector2(44, 44))):
			_icon("crest_forest" if t == 0 else "crest_kingdom", c + Vector2(dir * 55, 0), 15, Color.WHITE)
		_text(c + Vector2(-30 - dir * 12, -4), Stats.FACTIONS[t].realm.to_upper(), 11, _team_color(t).lightened(0.55), HORIZONTAL_ALIGNMENT_CENTER, 60, 2)
		_text(c + Vector2(-30 - dir * 12, 20), str(game.score[t]), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 60)
	_plate(Rect2(cx - 85, 10, 170, 54), INK, GOLD_DARK, 8, 2)
	if game.prep_left > 0.0:
		# The fortify countdown takes the clock's place; the match clock waits.
		var pl: float = ceilf(game.prep_left)
		var pulse: bool = pl <= 5.0 and int(game.prep_left * 2.0) % 2 == 0
		_text(Vector2(cx - 85, 30), "FORTIFY", 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 170, 2)
		_text(Vector2(cx - 85, 56), "0:%02d" % int(pl), 28, Color(1, 0.85, 0.5) if pulse else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 170)
		var pw := 360.0
		_plate(Rect2(cx - pw / 2.0, 66, pw, 22), Color(0.25, 0.2, 0.05, 0.95), GOLD, 6, 1)
		_text(Vector2(cx - pw / 2.0, 82), "DIG IN: TURRETS · TRAPS · BARRICADES [%s] · %d KITS LEFT" % [_k("interact"), game.barricades_left[_my_team()]], 11,
			GOLD, HORIZONTAL_ALIGNMENT_CENTER, pw, 2)
		return
	var left := maxf(game.time_left, 0.0)
	var urgent := left < 60.0 and int(left * 2.0) % 2 == 0
	_text(Vector2(cx - 85, 49), "%02d:%02d" % [int(left) / 60, int(left) % 60], 34,
		Color(1, 0.4, 0.3) if urgent else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 170)
	if game.overtime:
		var ow := 330.0
		_plate(Rect2(cx - ow / 2.0, 66, ow, 22), Color(0.4, 0.1, 0.1, 0.95), Color(1, 0.5, 0.4), 6, 1)
		_text(Vector2(cx - ow / 2.0, 82), "OVERTIME · NO RESPAWNS · LAST TEAM OR NEXT CAPTURE WINS", 11, Color(1, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER, ow, 2)


func _draw_roster(team: int, origin: Vector2, compact: bool = false) -> void:
	var tc := _team_color(team)
	if compact:
		_draw_side_roster(team, origin)
		return
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
			nx += 24
		if not u.is_player and u.display_name != "":
			_text(Vector2(nx, rect.position.y + 19), u.display_name, 10, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		if u.carrying:
			_icon("crown", rect.position + Vector2(218, 16), 7, GOLD)
		elif u.role != Role.BASE:
			_icon(_class_icon(u.role), rect.position + Vector2(218, 16), 7, Color.WHITE)
		if u.dead:
			_text(rect.position + Vector2(52, 39), "back in %d" % ceili(u.respawn_eta()), 12, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		else:
			_hearts(rect.position + Vector2(58, 33), u.hearts, 0.36, 15)
			_bar(Rect2(rect.position + Vector2(122, 28), Vector2(106, 10)), u.energy / u.energy_max(),
				MANA if u.energy_kind() == "mana" else STAMINA)
		row += 1


func _draw_side_roster(team: int, origin: Vector2) -> void:
	## The always-on team column at the screen edge: portrait, class, hearts,
	## energy and a class icon per member, your team's colour on the left and
	## the enemy's on the right (the render's layout). N hides them.
	var tc := _team_color(team)
	var row := 0
	for u in game.units:
		if u.team != team:
			continue
		var rect := Rect2(origin + Vector2(0, row * 50), Vector2(200, 44))
		var fill: Color = Color(0.3, 0.24, 0.08, 0.94) if u.is_player else tc.darkened(0.68)
		fill.a = 0.94
		_plate(rect, fill, GOLD if u.is_player else tc.darkened(0.05), 10, 2)
		_class_card(rect.position + Vector2(22, 22), 15, team, u.role, u.dead)
		var name: String = u.role_name()
		_text(rect.position + Vector2(46, 17), name, 12, GOLD if u.is_player else CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		var nx: float = rect.position.x + 50 + _text_width(name, 12)
		if u.level > 1:
			_text(Vector2(nx, rect.position.y + 17), "★%d" % u.level, 10, XP, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			nx += 22
		var who: String = "You" if u.is_player else u.display_name
		if who != "":
			_text(Vector2(nx, rect.position.y + 17), who, 9, Color(0.78, 0.78, 0.82), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		if u.carrying:
			_icon("crown", rect.position + Vector2(183, 15), 6, GOLD)
		elif u.veteran > 0:
			_icon("xp", rect.position + Vector2(183, 15), 6, Color(1.0, 0.6, 0.25) if u.veteran == 2 else GOLD)
		elif u.role != Role.BASE:
			_icon(_class_icon(u.role), rect.position + Vector2(183, 15), 6, Color.WHITE)
		if u.dead:
			_text(rect.position + Vector2(46, 35), "back in %d" % ceili(u.respawn_eta()), 10, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		else:
			_hearts(rect.position + Vector2(52, 30), u.hearts, 0.3, 13)
			_bar(Rect2(rect.position + Vector2(112, 26), Vector2(78, 8)), u.energy / u.energy_max(),
				MANA if u.energy_kind() == "mana" else STAMINA)
		row += 1


func _draw_stolen_card() -> void:
	## CROWN STOLEN! A red card under the clock with the thief and a minimap
	## inset that shows where they are.
	var a := clampf(game.stolen_timer / 0.5, 0.0, 1.0)
	var pulse := 1.0 + 0.015 * sin(Time.get_ticks_msec() / 70.0)
	var rect := Rect2(size.x / 2.0 - 230 * pulse, 98, 460 * pulse, 78)
	_plate(rect, Color(0.55, 0.1, 0.08, 0.95 * a), Color(1.0, 0.82, 0.3, a), 12, 3)
	_icon("crown", rect.position + Vector2(34, 36), 16, Color(1, 0.85, 0.3, a))
	_text(rect.position + Vector2(64, 32), "CROWN STOLEN!", 24, Color(1, 0.95, 0.85, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	var thief = null
	for m in game.monarchs:
		if m.state == Monarch.State.CARRIED and m.carrier:
			thief = m.carrier
	if thief:
		var line: String = "%s (%s) has stolen the Crown! %s" % [thief.role_name(), Stats.FACTIONS[thief.team].name,
			"Stop them!" if thief.team != _my_team() else "Get them home!"]
		_text(rect.position + Vector2(64, 56), line, 12, Color(1, 0.9, 0.85, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_draw_map(Rect2(rect.end.x - 118, rect.position.y + 8, 108, 62), false)


func _draw_capture_card() -> void:
	## CAPTURE! A gold card under the clock when either team scores.
	var a := clampf(game.capture_timer / 0.5, 0.0, 1.0)
	var pulse := 1.0 + 0.015 * sin(Time.get_ticks_msec() / 70.0)
	var rect := Rect2(size.x / 2.0 - 230 * pulse, 98, 460 * pulse, 78)
	var ours: bool = game.capture_team == _my_team()
	var tc: Color = _team_color(game.capture_team)
	_plate(rect, Color(tc.r * 0.45, tc.g * 0.45, tc.b * 0.45, 0.95 * a), Color(1.0, 0.82, 0.3, a), 12, 3)
	_icon("crown", rect.position + Vector2(34, 36), 16, Color(1, 0.85, 0.3, a))
	_text(rect.position + Vector2(64, 32), "CAPTURE!" if ours else "THEY SCORED", 24, Color(1, 0.95, 0.85, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	var line := "The %s bring the crown home.  %d - %d, first to %d wins." % [Stats.FACTIONS[game.capture_team].name, game.score[0], game.score[1], Stats.CAPTURES_TO_WIN]
	_text(rect.position + Vector2(64, 56), line, 12, Color(1, 0.95, 0.9, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_card("logo_elves" if game.capture_team == 0 else "logo_humans", Rect2(rect.end.x - 74, rect.position.y + 7, 64, 64))


func _draw_levelup_card() -> void:
	var a := clampf(game.levelup_timer / 0.5, 0.0, 1.0)
	var rect := Rect2(size.x / 2.0 - 170, 98, 340, 78)
	_plate(rect, Color(0.45, 0.32, 0.06, 0.95 * a), Color(1.0, 0.85, 0.3, a), 12, 3)
	var p = _me()
	if p:
		_class_card(rect.position + Vector2(40, 39), 26, p.team, p.role)
	_text(rect.position + Vector2(84, 32), "LEVEL UP!", 24, Color(1, 0.95, 0.7, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(rect.position + Vector2(84, 54), "You are now Level %d   ·   +1 Perk Point (%s)" % [game.levelup_level, _k("rank_menu")], 12, Color(1, 0.95, 0.85, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_kill_feed() -> void:
	## The last few kills, under the logo at the right edge: killer, sword,
	## victim, each in their team's colour, fading out after a few seconds.
	var now: float = Time.get_ticks_msec() / 1000.0
	var y: float = 104.0
	var right: float = size.x - 18.0
	var shown := 0
	for i in range(game.kill_feed.size() - 1, -1, -1):
		var k: Dictionary = game.kill_feed[i]
		var age: float = now - k.time
		if age > 7.0 or shown >= 5:
			continue
		var a: float = 1.0 if age < 5.5 else clampf((7.0 - age) / 1.5, 0.0, 1.0)
		var slide: float = clampf(1.0 - age / 0.25, 0.0, 1.0) * 40.0
		var vw: float = _text_width(k.victim, 11)
		var kw: float = _text_width(k.killer, 11)
		var x: float = right + slide
		var kc: Color = _team_color(k.kteam).lightened(0.35)
		var vc: Color = _team_color(k.vteam).lightened(0.35)
		kc.a = a
		vc.a = a
		draw_rect(Rect2(x - kw - vw - 62, y - 9, kw + vw + 68, 18), Color(0.05, 0.05, 0.08, 0.45 * a))
		_text(Vector2(x - vw, y - 7), k.victim, 11, vc, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_icon(_class_icon(k.vrole), Vector2(x - vw - 10, y), 6, vc)
		_icon("sword", Vector2(x - vw - 28, y), 6, Color(1.0, 0.85, 0.3, a))
		_text(Vector2(x - vw - 46 - kw, y - 7), k.killer, 11, kc, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_icon(_class_icon(k.krole), Vector2(x - vw - 56 - kw, y), 6, kc)
		y += 20.0
		shown += 1


func _draw_kill_banner(p) -> void:
	## KILL! A gold-and-crimson card that punches in under the clock with the
	## victim's class and your streak, then slides away.
	var age: float = Time.get_ticks_msec() / 1000.0 - p.kill_banner.time
	if age < 0.0 or age > 2.4:
		return
	var pop: float = clampf(age / 0.18, 0.0, 1.0)
	var scale_k: float = 1.0 + (1.0 - pop) * 0.35   # lands big and settles
	var a: float = minf(pop * 2.0, 1.0) * (1.0 if age < 1.9 else clampf((2.4 - age) * 2.0, 0.0, 1.0))
	var streak: int = p.kill_banner.streak
	var title := "KILL!"
	var sub_color := Color(1.0, 0.9, 0.6, a)
	match streak:
		2: title = "DOUBLE KILL!"
		3: title = "TRIPLE KILL!"
		4: title = "QUAD KILL!"
		_:
			if streak >= 5:
				title = "RAMPAGE  x%d" % streak
				sub_color = Color(1.0, 0.6, 0.4, a)
	var w: float = (300.0 + maxf(_text_width(title, 26) - 120.0, 0.0)) * scale_k
	var rect := Rect2(size.x / 2.0 - w / 2.0, 112 - (1.0 - pop) * 24.0, w, 66 * scale_k)
	# The burst behind the card.
	draw_arc(rect.get_center(), 40.0 + age * 160.0, 0, TAU, 40, Color(1.0, 0.85, 0.3, maxf(0.5 - age * 1.2, 0.0)), 6.0)
	_plate(rect, Color(0.42, 0.08, 0.08, 0.94 * a), Color(1.0, 0.85, 0.3, a), 12, 3)
	_class_card(rect.position + Vector2(36 * scale_k, rect.size.y / 2.0), 22 * scale_k, p.kill_banner.team, p.kill_banner.role_id, true)
	_text(rect.position + Vector2(68 * scale_k, 30 * scale_k), title, int(26 * scale_k), Color(1.0, 0.95, 0.7, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(rect.position + Vector2(68 * scale_k, 50 * scale_k), "%s the %s  ·  +%d XP" % [p.kill_banner.victim, p.kill_banner.role, Stats.XP_KILL], int(12 * scale_k), sub_color, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_icon("sword", rect.end - Vector2(30 * scale_k, rect.size.y / 2.0), 12 * scale_k, Color(1.0, 0.85, 0.3, a))


func _draw_toasts() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var y := 100.0 if game.stolen_timer <= 0.0 and game.levelup_timer <= 0.0 else 184.0
	for t in game.toasts:
		var age: float = now - t.time
		if age > 2.6:
			continue
		var a := clampf((2.6 - age) / 0.5, 0.0, 1.0)
		var w := _text_width(t.text, 12) + 28
		var r := Rect2(size.x / 2.0 - w / 2.0, y, w, 22)
		_plate(r, Color(0.05, 0.06, 0.1, 0.8 * a), Color(t.color.r, t.color.g, t.color.b, 0.8 * a), 6, 1)
		_text(r.position + Vector2(0, 16), t.text, 12, Color(t.color.r, t.color.g, t.color.b, a), HORIZONTAL_ALIGNMENT_CENTER, w, 2)
		y += 26


func _draw_objective() -> void:
	var rect := Rect2(size.x - 254, size.y - 146, 240, 126)
	_plate(rect, INK, GOLD_DARK, 10, 2)
	var obj: Dictionary = game.objective_target() if (game.playing and not game.demo) else {}
	var step: int = obj.get("step", -2)
	var recovering: bool = step == -1
	_icon("flag", rect.position + Vector2(20, 20), 9, RED)
	_text(rect.position + Vector2(36, 25), "RECOVER OUR CROWN" if recovering else "CAPTURE THE CROWN", 14,
		Color(1.0, 0.55, 0.45) if recovering else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	draw_line(rect.position + Vector2(12, 34), rect.position + Vector2(228, 34), GOLD_DARK, 1.0)
	var dist := 0
	if not obj.is_empty() and _me():
		var to: Vector3 = obj.pos - _me().global_position
		to.y = 0.0
		dist = roundi(to.length())
	if recovering:
		_text(rect.position + Vector2(28, 54), obj.label, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_text(rect.position + Vector2(28, 72), "%d m away" % dist, 12, Color(1.0, 0.75, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_text(rect.position + Vector2(28, 96), "They need %d captures to win" % Stats.CAPTURES_TO_WIN, 11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		return
	var lines := ["Break the enemy castle door", "Break the lock on their Crown Vault", "Carry their monarch to your throne",
		"First to %d captures wins" % Stats.CAPTURES_TO_WIN]
	if step == 2 and not obj.is_empty():
		lines[2] = obj.label
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
	for i in lines.size():
		var y := 54 + i * 18
		var here: bool = i == step
		var done: bool = step >= 0 and i < step
		if here:
			# The current step: a pulsing gold chevron and the distance.
			var c := rect.position + Vector2(18, y - 4)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -5), c + Vector2(3, 0), c + Vector2(-3, 5)]), GOLD.lerp(Color.WHITE, pulse * 0.5))
			_text(rect.position + Vector2(28, y), lines[i], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			if dist > 0 and i < 3:
				_text(rect.position + Vector2(0, y), "%d m" % dist, 10, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 12, 2)
		else:
			draw_circle(rect.position + Vector2(18, y - 4), 3, Color(0.4, 0.75, 0.4) if done else GOLD_DARK)
			_text(rect.position + Vector2(28, y), lines[i], 12, Color(0.55, 0.6, 0.55) if done else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_player_panel(p) -> void:
	var w := 740.0
	var rect := Rect2(size.x / 2.0 - w / 2.0, size.y - 140, w, 128)
	_plate(rect, INK, GOLD_DARK, 14, 2)
	# Portrait in a framed square with the level badge.
	var frame := Rect2(rect.position + Vector2(12, 10), Vector2(84, 84))
	_plate(frame, INK_LIGHT, GOLD, 12, 2)
	if not _card(_card_key(p.team, p.role), frame.grow(-3), false, p.dead):
		_portrait(frame.get_center(), 28, p.team, p.role, p.dead)
	if p.buff != "" and p.buff_timer > 0.0:
		var bc: Color = Stats.BLESSING_KINDS[p.buff].color
		var badge := Rect2(rect.position + Vector2(12, -30), Vector2(230, 26))
		_plate(badge, bc.darkened(0.7), bc, 8, 2)
		_icon(Stats.BLESSING_KINDS[p.buff].icon, badge.position + Vector2(16, 13), 9, Color.WHITE)
		_text(badge.position + Vector2(32, 18), "BLESSING OF %s" % p.buff.to_upper(), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_text(badge.position + Vector2(0, 18), "%ds" % ceili(p.buff_timer), 11, bc.lightened(0.3), HORIZONTAL_ALIGNMENT_RIGHT, badge.size.x - 10, 2)
		draw_rect(Rect2(badge.position + Vector2(4, badge.size.y - 4), Vector2((badge.size.x - 8) * p.buff_timer / Stats.BLESSING_DURATION, 2)), bc)
	_hex(frame.position + Vector2(8, 76), 34, 24, INK, GOLD)
	_text(frame.position + Vector2(-9, 81), str(p.level), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 34, 2)
	# Name, hearts and energy.
	var x := rect.position.x + 110
	_text(Vector2(x, rect.position.y + 28), p.role_name().to_upper(), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	# Defender and spawn-protection indicators, left of the panel.
	if p.spawn_protect > 0.0 and not p.dead:
		var sp := Rect2(rect.position + Vector2(-8, -30), Vector2(150, 24))
		_plate(sp, Color(0.1, 0.25, 0.4, 0.95), Color(0.6, 0.85, 1.0), 8, 1)
		_icon("guard", sp.position + Vector2(14, 12), 7, Color.WHITE)
		_text(sp.position + Vector2(26, 17), "SPAWN PROTECTED  %d" % ceili(p.spawn_protect), 10, Color(0.85, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	elif p.home_defense and not p.dead:
		var hd := Rect2(rect.position + Vector2(-8, -30), Vector2(132, 24))
		_plate(hd, Color(0.1, 0.2, 0.35, 0.9), Color(0.5, 0.7, 1.0), 8, 1)
		_icon("guard", hd.position + Vector2(14, 12), 7, Color.WHITE)
		_text(hd.position + Vector2(26, 17), "DEFENDING HOME", 10, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var name_w := _text_width(p.role_name().to_upper(), 20)
	_text(Vector2(x + name_w + 10, rect.position.y + 28),
		Stats.FACTIONS[p.team].name.to_upper(), 11, _team_color(p.team).lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if p.role != Role.BASE:
		_icon(_class_icon(p.role), Vector2(x + name_w + 10 + _text_width(Stats.FACTIONS[p.team].name.to_upper(), 11) + 18, rect.position.y + 20), 8, Color.WHITE)
	if p.dead:
		_hearts(Vector2(x + 16, rect.position.y + 54), 0, 0.85, 36)
		if game.overtime:
			_text(Vector2(x, rect.position.y + 86), "Down for the rest of overtime", 16, Color(1, 0.6, 0.5))
		else:
			_text(Vector2(x, rect.position.y + 86), "Down! Back with the wave in %d" % ceili(p.respawn_eta()), 16, Color(1, 0.6, 0.5))
	else:
		_hearts(Vector2(x + 16, rect.position.y + 54), p.hearts, 0.85, 36)
		var is_mana: bool = p.energy_kind() == "mana"
		var bar := Rect2(Vector2(x, rect.position.y + 70), Vector2(236, 16))
		_bar(bar, p.energy / p.energy_max(), MANA if is_mana else STAMINA)
		_text(bar.position + Vector2(0, 13), "%s  %d / %d" % ["MANA" if is_mana else "STAMINA", int(p.energy), int(p.energy_max())],
			11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 3)
	_draw_xp_bar(p, Rect2(rect.position + Vector2(110, 104), Vector2(rect.size.x - 122, 14)))
	if p.points > 0 and not p.dead:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		var badge := Rect2(rect.position + Vector2(352, -30), Vector2(132, 24))
		_plate(badge, Color(0.55, 0.4, 0.05, pulse), GOLD, 8, 1)
		_icon("xp", badge.position + Vector2(14, 12), 7, Color.WHITE)
		_text(badge.position + Vector2(26, 17), "%s  RANK UP  +%d" % [_k("rank_menu"), p.points], 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if p.veteran > 0 and not p.dead:
		var vb := Rect2(rect.position + Vector2(rect.size.x - 236, -30), Vector2(224, 26))
		var vc := Color(1.0, 0.55, 0.2) if p.veteran == 2 else Color(1.0, 0.85, 0.3)
		_plate(vb, vc.darkened(0.7), vc, 8, 2)
		_icon("crown" if p.veteran == 2 else "xp", vb.position + Vector2(16, 13), 8, Color.WHITE)
		_text(vb.position + Vector2(30, 18), ("ELITE VETERAN · BOUNTY ON YOU" if p.veteran == 2 else "VETERAN") + "  ·  %d streak" % p.streak, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	elif p.streak >= 2 and not p.dead:
		_text(rect.position + Vector2(rect.size.x - 12, -8), "%d kill streak" % p.streak, 10, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, -1, 2)
	# Slots: attack, Q, E, dodge, block (shield classes), grab.
	var abil: Array = p.abilities()
	var sx := rect.position.x + 352
	var sy := rect.position.y + 8
	var slot := 50.0
	var gap := 64.0
	var alive: bool = not p.dead and p.carrying == null
	var atk: Dictionary = p.attack_stats()
	_slot(Vector2(sx, sy), slot, _attack_icon(p.role, atk), Stats.ROLES[p.role].color.lightened(0.3), _k("attack"), atk.attack_name,
		p.attack_timer, atk.cooldown, alive and p.energy >= atk.cost, p.rank(0), false, atk.cost, STAMINA if p.energy_kind() == "stamina" else MANA)
	for i in 2:
		if i < abil.size():
			var a: Dictionary = p.ability(i)
			_slot(Vector2(sx + (i + 1) * gap, sy), slot, a.get("icon", a.kind), Stats.ROLES[p.role].color.lightened(0.3), _k("ability_%d" % (i + 1)), a.name,
				p.ability_timers[i], a.cooldown, p.energy >= a.cost and alive, p.rank(i + 1), false, a.cost, STAMINA if p.energy_kind() == "stamina" else MANA)
		else:
			_slot(Vector2(sx + (i + 1) * gap, sy), slot, "", Color.WHITE, _k("ability_%d" % (i + 1)), "", 0.0, 1.0, false)
	_slot(Vector2(sx + 3 * gap, sy), slot, "dodge", STAMINA, _k("dodge"), "Dodge", p.dodge_cooldown, Stats.DODGE_COOLDOWN,
		alive and p.energy >= Stats.DODGE_COST)
	if p.can_block():
		_slot(Vector2(sx + 4 * gap, sy), slot, "block", STEEL, _k("block"), "Block", 0.0, 1.0, alive and p.energy > 0.0, 0, p.blocking)
	else:
		_slot(Vector2(sx + 4 * gap, sy), slot, "vigor", XP, _k("rank_menu"), "Perks", 0.0, 1.0, p.points > 0, p.rank(3))
	_slot(Vector2(sx + 5 * gap, sy), slot, "crown", GOLD, _k("interact"), "Drop" if p.carrying else "Grab", 0.0, 1.0, not p.dead)


func _draw_xp_bar(p, bar: Rect2) -> void:
	## Experience this life: a long gold bar with level ticks, a glow that grows
	## with progress and a pulse when a rank point is waiting to be spent.
	var span: Array = Stats.xp_span(p.level)
	var frac := 1.0 if span[1] < 0 else clampf(float(p.xp - span[0]) / float(span[1] - span[0]), 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var hot: bool = p.points > 0 and not p.dead
	var edge := GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 6.0)) if hot else GOLD_DARK
	# Glow behind the filled part.
	var fill_w := bar.size.x * frac
	if fill_w > 0.0:
		draw_rect(Rect2(bar.position - Vector2(2, 3), Vector2(fill_w + 4, bar.size.y + 6)), Color(1.0, 0.75, 0.25, 0.18 + 0.1 * sin(t * 3.0)))
	_plate(bar, Color(0.08, 0.07, 0.1, 0.95), edge, 7, 1)
	var inner := bar.grow(-2)
	if fill_w > 4.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = XP
		sb.set_corner_radius_all(5)
		var fill := Rect2(inner.position, Vector2(maxf(fill_w - 4.0, 6.0), inner.size.y))
		draw_style_box(sb, fill)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.45)), Color(1, 1, 1, 0.25))
		# A bright cap sweeping along the end of the fill.
		draw_rect(Rect2(fill.end.x - 3, fill.position.y, 3, fill.size.y), Color(1, 0.95, 0.7, 0.8))
	# Quarter ticks so progress reads at a glance.
	for i in range(1, 4):
		var tx := inner.position.x + inner.size.x * i / 4.0
		draw_line(Vector2(tx, inner.position.y + 2), Vector2(tx, inner.end.y - 2), Color(0, 0, 0, 0.35), 1.0)
	# Level badges at both ends and the numbers in the middle.
	_icon("xp", bar.position + Vector2(-2, bar.size.y / 2.0), 7, XP)
	_text(bar.position + Vector2(10, bar.size.y - 2), "LV %d" % p.level, 10, Color(0.15, 0.1, 0.05) if frac > 0.12 else CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	var xp_text := "MAX LEVEL" if span[1] < 0 else "%d / %d XP" % [p.xp, span[1]]
	if hot:
		xp_text += "   ·   %d RANK POINT%s READY" % [p.points, "" if p.points == 1 else "S"]
	_text(bar.position + Vector2(0, bar.size.y - 2), xp_text, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 2)
	if span[1] >= 0:
		_text(bar.position + Vector2(0, bar.size.y - 2), "LV %d " % (p.level + 1), 10, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 6, 2)
		draw_line(Vector2(bar.end.x, bar.position.y - 2), Vector2(bar.end.x, bar.end.y + 2), GOLD, 2.0)


# --- Map ---------------------------------------------------------------------

func _draw_map(rect: Rect2, detailed: bool) -> void:
	## The valley from above: forest, the river with its bridges and the Crown
	## Shrine island, roads and paths, ruins, castles with their cellars,
	## doors, potions, blessings, and everyone the team can see. Enemies show
	## only near a teammate, except Elite Veterans, who are always revealed.
	var hx: float = game.map_half.x
	var hz: float = game.map_half.y
	_plate(rect, GRASS.darkened(0.2), GOLD_DARK, 8, 2)
	var inner := rect.grow(-3)
	draw_rect(inner, GRASS)
	# Elven ground reads a touch bluer and deeper, human ground warmer.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x / 2.0, inner.size.y)), Color(0.2, 0.45, 0.35, 0.25))
	draw_rect(Rect2(inner.position + Vector2(inner.size.x / 2.0, 0), Vector2(inner.size.x / 2.0, inner.size.y)), Color(0.55, 0.5, 0.2, 0.18))
	var m := func(p: Vector3) -> Vector2:
		return inner.position + Vector2((p.x + hx) / (2.0 * hx) * inner.size.x, (p.z + hz) / (2.0 * hz) * inner.size.y)
	var sx: float = inner.size.x / (2.0 * hx)
	var sz: float = inner.size.y / (2.0 * hz)
	var fx: float = game.CASTLE_X - game.CASTLE_DEPTH
	var pt := Time.get_ticks_msec() / 1000.0
	# Forest.
	for t in game.map_trees:
		var r: float = (2.6 if t.y > 0.5 else 1.8) * sx
		if detailed:
			draw_circle(m.call(t) + Vector2(1, 1), r, Color(0, 0, 0, 0.2))
		draw_circle(m.call(t), r, LEAF.darkened(0.25 if t.y > 0.5 else 0.1))
	# Paths and the road.
	for p in game.map_paths:
		var a: Vector2 = m.call(p[0])
		var b: Vector2 = m.call(p[1])
		draw_line(a, b, DIRT.darkened(0.35), maxf(p[2] * sx, 1.5) + 2.0)
		draw_line(a, b, DIRT, maxf(p[2] * sx, 1.5))
	# Ruins and the shrine.
	for mark in game.map_marks:
		var c: Vector2 = m.call(mark[0])
		if mark[1] == "ruin":
			draw_rect(Rect2(c - Vector2(3.5, 2.5) * sx, Vector2(7, 5) * sx), Color(0.62, 0.6, 0.56))
		elif mark[1] == "barrow":
			draw_circle(c, 3.2 * sx, Color(0.4, 0.42, 0.4))
			draw_rect(Rect2(c - Vector2(1.2, 2.0) * sx, Vector2(2.4, 3.0) * sx), Color(0.3, 0.3, 0.3))
		elif mark[1] == "mill":
			draw_rect(Rect2(c - Vector2(2.0, 2.0) * sx, Vector2(4, 4) * sx), Color(0.6, 0.45, 0.3))
			draw_arc(c + Vector2(-signf(mark[0].x) * 2.6 * sx, 0), 1.8 * sx, 0, TAU, 8, Color(0.35, 0.25, 0.15), 1.0)
	# The river, the island and the bridges.
	draw_rect(Rect2(m.call(Vector3(-game.RIVER_HALF - 0.8, 0, -hz)), Vector2((2.0 * game.RIVER_HALF + 1.6) * sx, 2.0 * hz * sz)), Color(0.55, 0.75, 0.9))
	draw_rect(Rect2(m.call(Vector3(-game.RIVER_HALF, 0, -hz)), Vector2(2.0 * game.RIVER_HALF * sx, 2.0 * hz * sz)), Color(0.22, 0.48, 0.8))
	draw_circle(m.call(Vector3.ZERO), game.ISLAND_R * sx + 1.5, Color(0.45, 0.42, 0.36))
	draw_circle(m.call(Vector3.ZERO), game.ISLAND_R * sx, Color(0.75, 0.72, 0.64))
	for i in game.BRIDGES.size():
		if i == 1:
			continue
		var bz: float = game.BRIDGES[i]
		var half: float = game.BRIDGE_HALF[i]
		var br := Rect2(m.call(Vector3(-game.RIVER_HALF - 1.0, 0, bz - half)), Vector2((2.0 * game.RIVER_HALF + 2.0) * sx, 2.0 * half * sz))
		draw_rect(br, Color(0.6, 0.45, 0.3))
		draw_rect(br, Color(0.35, 0.25, 0.15), false, 1.0)
	_crown(m.call(Vector3.ZERO), 0.4 if not detailed else 0.8)
	for t in 2:
		var side := -1.0 if t == 0 else 1.0
		var tc := _team_color(t)
		var ox: float = side * fx
		var bx: float = side * (game.CASTLE_X + game.CASTLE_DEPTH)
		var outer := Rect2(m.call(Vector3(minf(ox, bx), 0, -game.CASTLE_HALF_Z)),
			Vector2(2.0 * game.CASTLE_DEPTH * sx, 2.0 * game.CASTLE_HALF_Z * sz))
		draw_rect(outer.grow(1.5), Color(0.3, 0.3, 0.32))
		draw_rect(outer, tc.darkened(0.55))
		draw_rect(outer, tc.lightened(0.1), false, 2.0)
		# Corner towers.
		for corner in [outer.position, outer.position + Vector2(outer.size.x, 0), outer.end, outer.position + Vector2(0, outer.size.y)]:
			draw_circle(corner, 2.5 if not detailed else 4.0, Color(0.55, 0.55, 0.58))
			draw_arc(corner, 2.5 if not detailed else 4.0, 0, TAU, 10, Color(0.2, 0.2, 0.22), 1.0)
		var kx: float = game._keep_x(t)
		var keep := Rect2(m.call(Vector3(minf(kx, bx), 0, -game.KEEP_HALF_Z)),
			Vector2(absf(bx - kx) * sx, 2.0 * game.KEEP_HALF_Z * sz))
		draw_rect(keep, tc.darkened(0.3))
		# The spawn cellar behind the keep.
		var cx: float = bx + side * game.CELLAR_DEPTH
		var cellar := Rect2(m.call(Vector3(minf(bx, cx), 0, -game.CELLAR_HALF_Z)), Vector2(game.CELLAR_DEPTH * sx, 2.0 * game.CELLAR_HALF_Z * sz))
		draw_rect(cellar, tc.darkened(0.7))
		draw_rect(cellar, tc.darkened(0.2), false, 1.0)
		# Door: gold while standing, red once broken.
		var gate = game.gates[t]
		var door_color: Color = RED if gate.broken else GOLD
		draw_line(m.call(Vector3(ox, 0, -Stats.DOOR_HALF)), m.call(Vector3(ox, 0, Stats.DOOR_HALF)), door_color, 3.0)
		_crown(m.call(game.thrones[t]), 0.45 if not detailed else 0.9)
		if detailed:
			_text(outer.position + Vector2(0, -6), "%s CASTLE" % Stats.FACTIONS[t].name.to_upper(), 11, tc.lightened(0.5), HORIZONTAL_ALIGNMENT_CENTER, outer.size.x, 2)
			_card("crest_elf" if t == 0 else "crest_human", Rect2(keep.position + Vector2(keep.size.x / 2.0 - 11, 2), Vector2(22, 22)))
			_text(cellar.position + Vector2(0, cellar.size.y + 12), "SPAWN", 9, tc.lightened(0.5), HORIZONTAL_ALIGNMENT_CENTER, cellar.size.x, 2)
	# Potions that are up, and any Blessing of Light on the field.
	for orb in game.heal_orbs:
		if orb.active:
			draw_circle(m.call(orb.global_position), 2.5 if not detailed else 4.0, Color(1.0, 0.35, 0.4))
	for b in game.blessings:
		if is_instance_valid(b):
			var bc: Vector2 = m.call(b.global_position)
			var br := 4.0 if not detailed else 7.0
			draw_circle(bc, br + 2.0, Color(1.0, 0.9, 0.5, 0.35 + 0.25 * sin(pt * 6.0)))
			_icon("xp", bc, br, GOLD)
	# Turrets: small diamonds in team colour (enemy ones once a teammate has seen them).
	var my_team: int = _my_team()
	for t in game.turrets:
		var tc: Vector2 = m.call(t.global_position)
		var tr := 3.0 if not detailed else 5.0
		var tcol: Color = _team_color(t.team)
		draw_colored_polygon(PackedVector2Array([tc + Vector2(0, -tr), tc + Vector2(tr, 0), tc + Vector2(0, tr), tc + Vector2(-tr, 0)]), tcol.lightened(0.2))
		draw_polyline(PackedVector2Array([tc + Vector2(0, -tr), tc + Vector2(tr, 0), tc + Vector2(0, tr), tc + Vector2(-tr, 0), tc + Vector2(0, -tr)]), Color(0, 0, 0, 0.6), 1.0)
	# Everyone we can see. Enemies show within 22 m of a living teammate;
	# Elite Veterans always show, with a pulsing bounty ring.
	var allies: Array = game.units.filter(func(u): return u.team == my_team and not u.dead)
	for u in game.units:
		if u.dead:
			continue
		var c: Vector2 = m.call(u.global_position)
		var r := 3.0 if not detailed else 5.0
		var enemy: bool = u.team != my_team
		if enemy and u.veteran < 2 and u.carrying == null:
			var seen := false
			for a in allies:
				if game._flat_dist(a.global_position, u.global_position) < 22.0:
					seen = true
					break
			if not seen:
				continue
		if u.is_player:
			draw_circle(c, r + 2.5, Color(1, 1, 0.3))
			var d := Vector2(u.facing.x, u.facing.z) * (r + 6.0)
			draw_line(c, c + d, Color(1, 1, 0.3), 2.0)
		if u.veteran >= 2:
			draw_arc(c, r + 3.0 + 1.5 * sin(pt * 5.0), 0, TAU, 16, Color(1, 0.3, 0.2) if enemy else GOLD, 2.0)
		elif u.veteran == 1:
			draw_arc(c, r + 2.0, 0, TAU, 12, Color(0.95, 0.75, 0.3), 1.5)
		var dot := Color(1.0, 0.25, 0.2) if enemy else Color(0.3, 1.0, 0.45)
		draw_circle(c, r, dot)
		draw_arc(c, r, 0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
		if u.carrying:
			_crown(c + Vector2(0, -r - 4), 0.35 if not detailed else 0.6)

func _rank_desc(p, track: int) -> String:
	var r: int = p.rank(track)
	if track == 3:
		if r >= Stats.MAX_RANK:
			return "Fully ranked"
		return "Next: +%d%% speed, +%d %s, +%d%% regen" % [int(Stats.VIGOR_SPEED * 100), int(Stats.VIGOR_ENERGY),
			p.energy_kind(), int(Stats.VIGOR_REGEN * 100)]
	var next := r + 1
	match next:
		1: return "Next: %d%% faster cooldown, %d%% cheaper" % [int(Stats.RANK_COOLDOWN_CUT * 100), int(Stats.RANK_COST_CUT * 100)]
		2: return "Next: bigger effect (range, radius, duration)"
		3: return "Next: one more heart of damage or healing"
	return "Fully ranked"


func _draw_rank_menu(p) -> void:
	var has_variants: bool = Stats.VARIANTS.has(p.role)
	var h := 494.0 if has_variants else 356.0
	var rect := Rect2(size.x / 2.0 - 290, size.y / 2.0 - h / 2.0 - 20, 580, h)
	_plate(rect, INK, GOLD, 14, 3)
	_close(rect)
	_text(rect.position + Vector2(0, 32), "SKILLS AND RANKS", 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 4)
	var pts_text := "%d point%s to spend" % [p.points, "" if p.points == 1 else "s"] if p.points > 0 else "no points yet: earn experience"
	_text(rect.position + Vector2(0, 54), "Level %d  ·  %s" % [p.level, pts_text], 13, GOLD if p.points > 0 else CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
	var track_icons := [_attack_icon(p.role, p.stats()), "", "", "vigor"]
	for i in 2:
		if i < p.abilities().size():
			track_icons[i + 1] = p.abilities()[i].get("icon", p.abilities()[i].kind)
	var cls_color: Color = Stats.ROLES[p.role].color.lightened(0.3)
	for t in 4:
		var row := Rect2(rect.position + Vector2(16, 70 + t * 64), Vector2(rect.size.x - 32, 58))
		var available: bool = p.track_available(t)
		var maxed: bool = p.rank(t) >= Stats.MAX_RANK
		var can: bool = available and p.points > 0 and not maxed
		_plate(row, INK_LIGHT if available else Color(0.12, 0.12, 0.15, 0.9), GOLD if can else (GOLD_DARK if available else Color(0.3, 0.3, 0.3)), 8, 1)
		# A framed icon square on the left.
		var box := Rect2(row.position + Vector2(8, 7), Vector2(44, 44))
		_plate(box, Color(0.08, 0.08, 0.12, 0.95), GOLD_DARK if available else Color(0.3, 0.3, 0.3), 7, 1)
		if available:
			_icon(track_icons[t], box.get_center(), 13, cls_color if t < 3 else XP)
		var name: String = p.track_name(t) if available else "No %s ability yet" % ["", "Q", "E", ""][t]
		_text(row.position + Vector2(64, 21), name, 15, Color.WHITE if available else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		# Rank as three segments beside the name, the next rank's effect below.
		for k in Stats.MAX_RANK:
			var seg := Rect2(row.position + Vector2(64 + k * 30, 28), Vector2(26, 8))
			var sb := StyleBoxFlat.new()
			sb.bg_color = GOLD if k < p.rank(t) else Color(0.2, 0.2, 0.25)
			sb.set_corner_radius_all(3)
			sb.border_color = GOLD_DARK if available else Color(0.3, 0.3, 0.3)
			sb.set_border_width_all(1)
			draw_style_box(sb, seg)
		_text(row.position + Vector2(160, 36), ("Rank %d / %d" % [p.rank(t), Stats.MAX_RANK]) if available else "", 10, GOLD if maxed else CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		if available:
			_text(row.position + Vector2(64, 51), _rank_desc(p, t), 10, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		# One button with its number key inside it.
		var button := Rect2(row.end.x - 128, row.position.y + 13, 116, 32)
		_plate(button, Color(0.2, 0.5, 0.25, 0.95) if can else Color(0.2, 0.2, 0.22, 0.9), GOLD if can else Color(0.35, 0.35, 0.4), 7, 1)
		var label := "RANK UP" if not maxed else "MAXED"
		if available and not maxed:
			_keycap(button.position + Vector2(20, 16), str(t + 1), 22)
			_text(button.position + Vector2(36, 21), label, 12, Color.WHITE if can else GREY, HORIZONTAL_ALIGNMENT_CENTER, button.size.x - 40, 2)
		else:
			_text(button.position + Vector2(0, 21), label if available else "", 12, GOLD if maxed else GREY, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 2)
		rank_buttons.append(button if can else Rect2())
	if has_variants:
		_promotion(p, Rect2(rect.position + Vector2(16, 70 + 4 * 64), Vector2(rect.size.x - 32, 124)))
	_text(rect.position + Vector2(0, rect.size.y - 12), ("D-pad spends a point  ·  %s / %s pick a promotion  ·  %s closes  ·  experience is per life" % [_k("rank_5"), _k("rank_6"), _k("rank_menu")]) if game.on_pad(local_unit) else ("1-4 or click spends a point  ·  5 / 6 picks a promotion  ·  %s closes  ·  experience is per life" % _k("rank_menu")), 11, GREY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


func _promotion(p, rect: Rect2) -> void:
	## The two variants of the player's class: pick one once enough rank
	## points have been spent in the class over the match.
	var role: int = p.role
	var unlocked: bool = p.variant_unlocked(role)
	var spent: int = p.mastery.get(role, 0)
	_text(rect.position + Vector2(0, 12), "PROMOTION", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var status := "Unlocked: choose a path" if unlocked else "Spend %d more point%s in this class to unlock (%d / %d, kept across lives)" % [
		Stats.VARIANT_UNLOCK - spent, "" if Stats.VARIANT_UNLOCK - spent == 1 else "s", spent, Stats.VARIANT_UNLOCK]
	_text(rect.position + Vector2(90, 12), status, 10, CREAM if unlocked else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var w := (rect.size.x - 10) / 2.0
	for i in 2:
		var v: Dictionary = Stats.VARIANTS[role][i]
		var card := Rect2(rect.position + Vector2(i * (w + 10), 20), Vector2(w, rect.size.y - 20))
		var chosen: bool = p.variants.get(role, -1) == i
		_plate(card, Color(0.3, 0.26, 0.12, 0.98) if chosen else (INK_LIGHT if unlocked else Color(0.12, 0.12, 0.15, 0.9)),
			GOLD if chosen else (GOLD_DARK if unlocked else Color(0.3, 0.3, 0.3)), 8, 2 if chosen else 1)
		_icon(v.icon, card.position + Vector2(24, 22), 12, Color.WHITE, not unlocked)
		_text(card.position + Vector2(48, 22), v.name.to_upper(), 14, GOLD if chosen else (Color.WHITE if unlocked else GREY), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		var tag := "CHOSEN" if chosen else ("%s: pick" % str(i + 5) if unlocked else "LOCKED")
		_text(card.position + Vector2(0, 22), tag, 10, GOLD if chosen else GREY, HORIZONTAL_ALIGNMENT_RIGHT, card.size.x - 10, 2)
		_paragraph(card.position + Vector2(10, 48), v.desc, 10, Color(0.85, 0.85, 0.85) if unlocked else GREY, card.size.x - 20, 12.0)
		var moves := "%s  ·  Q %s  ·  E %s" % [v.attack.get("attack_name", Stats.kit(_my_team(), role).attack_name), v.abilities[0].name, v.abilities[1].name]
		_text(card.position + Vector2(10, card.size.y - 8), moves, 10, CREAM if unlocked else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		if unlocked and not chosen and not p.dead:
			variant_buttons.append([card, role, i])


# --- Game menu ---------------------------------------------------------------

func _draw_game_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var rect := Rect2(size.x / 2.0 - 390, size.y / 2.0 - 250, 780, 500)
	_plate(rect, INK, GOLD, 16, 3)
	_close(rect)
	var in_match: bool = game.playing
	_text(rect.position + Vector2(0, 34), "PAUSED" if in_match else "OPTIONS", 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 4)
	# Tabs (only Classes and Controls before a match).
	var ids: Array = game.menu_tabs()
	var tw := minf(140.0, (rect.size.x - 40.0 - (ids.size() - 1) * 6.0) / ids.size())
	var x0: float = rect.position.x + (rect.size.x - ids.size() * (tw + 6)) / 2.0
	for i in ids.size():
		var tab := Rect2(Vector2(x0 + i * (tw + 6), rect.position.y + 50), Vector2(tw, 30))
		var on: bool = game.menu_tab == ids[i]
		_plate(tab, Color(0.3, 0.26, 0.12, 0.98) if on else INK_LIGHT, GOLD if on else GOLD_DARK, 8, 1)
		_text(tab.position + Vector2(0, 21), TABS[ids[i]], 13, GOLD if on else Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 2)
		tab_buttons.append(tab)
		tab_ids.append(ids[i])
	var body := Rect2(rect.position + Vector2(24, 92), Vector2(rect.size.x - 48, rect.size.y - 130))
	match game.menu_tab:
		0: _menu_overview(body)
		1: _menu_classes(body)
		2: _menu_my_class(body)
		5: _menu_settings(body)
		3: _menu_scoreboard(body)
		4: _menu_controls(body)
	var footer := "Esc resumes  ·  ← → switch tabs  ·  Backspace quits to the title" if in_match else "Esc closes  ·  ← → switch tabs"
	_text(rect.position + Vector2(0, rect.size.y - 12), footer, 11, GREY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


func _menu_overview(body: Rect2) -> void:
	_text(body.position + Vector2(0, 16), "THE WILDWOOD VALLEY", 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 3)
	var map_rect := Rect2(body.position + Vector2(0, 26), Vector2(body.size.x, body.size.x * 26.0 / 58.0))
	_draw_map(map_rect, true)
	var y := map_rect.end.y + 22
	var legend := [["Yellow ring: you", Color(1, 1, 0.3)], ["Red: enemies seen by your team", Color(1.0, 0.25, 0.2)], ["Red dots: potions", Color(1.0, 0.35, 0.4)], ["Gold stars: blessings", GOLD],
		["Pulsing ring: Elite Veteran bounty", Color(1, 0.5, 0.3)], ["Gold line: door", GOLD]]
	for i in legend.size():
		var x: float = body.position.x + 10 + (i % 3) * (body.size.x / 3.0)
		var ly: float = y + (i / 3) * 18
		draw_circle(Vector2(x, ly - 4), 5, legend[i][1])
		_text(Vector2(x + 12, ly), legend[i][0], 11, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_text(body.position + Vector2(0, y + 40), "Break the enemy door, smash the Crown Vault lock, carry their monarch home. Grab a class hat in your cellar.", 11, GREY,
		HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 2)


func _menu_classes(body: Rect2) -> void:
	var team: int = _my_team()
	var roles := [Role.KNIGHT, Role.RANGER, Role.MAGE, Role.HEALER, Role.ENGINEER, Role.ROGUE]
	var cw := (body.size.x - 5 * 8) / 6.0
	for i in roles.size():
		var role: int = roles[i]
		var s: Dictionary = Stats.kit(team, role)
		var card := Rect2(body.position + Vector2(i * (cw + 8), 0), Vector2(cw, body.size.y))
		var mine: bool = _me() and _me().role == role
		_plate(card, INK_LIGHT, GOLD if mine else GOLD_DARK, 10, 2)
		if not _card(_card_key(team, role), Rect2(card.position + Vector2(8, 6), Vector2(cw - 16, 80)), false):
			_portrait(card.position + Vector2(cw / 2.0, 44), 26, team, role)
		_icon(_class_icon(role), card.position + Vector2(cw - 20, 18), 9, Color.WHITE)
		_text(card.position + Vector2(0, 92), Stats.FACTIONS[team].roles[role].to_upper(), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, cw, 3)
		_text(card.position + Vector2(0, 108), ("uses %s" % s.energy).to_upper(), 10, MANA if s.energy == "mana" else STAMINA, HORIZONTAL_ALIGNMENT_CENTER, cw, 2)
		var y := 128.0
		var entries := [["LMB", s.attack_name, s.attack_desc, _attack_icon(role)]]
		for a in s.abilities:
			entries.append([a.key, a.name, a.desc, a.get("icon", a.kind)])
		if s.get("block", false):
			entries.append(["RMB", "Block", "Hold to stop hits from the front with your shield.", "block"])
		for e in entries:
			_icon(e[3], card.position + Vector2(20, y + 2), 8, s.color.lightened(0.3))
			_keycap(card.position + Vector2(cw - 26, y + 2), e[0], 34 if e[0].length() > 2 else 24)
			_text(card.position + Vector2(36, y + 6), e[1], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			y += 14.0
			y += _paragraph(card.position + Vector2(12, y + 10), e[2], 10, Color(0.8, 0.8, 0.8), cw - 24, 12.0) + 10.0
		if Stats.VARIANTS.has(role):
			var vs: Array = Stats.VARIANTS[role]
			_icon(vs[0].icon, card.position + Vector2(cw / 2.0 - 54, card.size.y - 30), 6, Color.WHITE)
			_icon(vs[1].icon, card.position + Vector2(cw / 2.0 + 54, card.size.y - 30), 6, Color.WHITE)
			_text(card.position + Vector2(0, card.size.y - 26), "%s  or  %s" % [vs[0].name, vs[1].name], 10, CREAM, HORIZONTAL_ALIGNMENT_CENTER, cw, 2)
		if mine:
			_text(card.position + Vector2(0, card.size.y - 10), "YOUR CLASS", 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER, cw, 2)
		else:
			_text(card.position + Vector2(0, card.size.y - 10), "promotions", 9, GREY, HORIZONTAL_ALIGNMENT_CENTER, cw, 2)


func _menu_controls(body: Rect2) -> void:
	## Every action with its keyboard/mouse and gamepad bindings. Click a
	## binding and press the new key or button; Esc cancels.
	var half := body.size.x / 2.0
	var per_col := ceili(game.REBINDABLE.size() / 2.0)
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
	var pad_kind: String = game.pad_kind(game.local_pad(0))
	for c in 2:
		var x: float = body.position.x + c * half
		_text(Vector2(x + 10, body.position.y + 14), "ACTION", 10, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_text(Vector2(x + 150, body.position.y + 14), "KEYBOARD / MOUSE", 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 120, 2)
		_text(Vector2(x + 282, body.position.y + 14), "DUALSENSE" if pad_kind == "ps" else "GAMEPAD", 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 80, 2)
		for k in per_col:
			var i: int = c * per_col + k
			if i >= game.REBINDABLE.size():
				break
			var action: String = game.REBINDABLE[i][0]
			var y: float = body.position.y + 40 + k * 29
			var row := Rect2(Vector2(x + 4, y - 14), Vector2(half - 14, 27))
			var hot: bool = game.rebinding == action
			_plate(row, Color(0.35, 0.3, 0.12, pulse) if hot else (INK_LIGHT if k % 2 == 0 else Color(0.14, 0.15, 0.22, 0.96)), GOLD if hot else Color(0.3, 0.3, 0.38), 6, 1)
			_text(Vector2(x + 14, y + 4), game.REBINDABLE[i][1], 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			var key_text: String = "PRESS A KEY…" if hot else game.binding_text(action, "key")
			_keycap(Vector2(x + 210, y), key_text, 124)
			_keycap(Vector2(x + 326, y), game.binding_text(action, "pad", pad_kind), 86)
			bind_buttons.append([row, action])
	reset_button = Rect2(body.end - Vector2(150, 30), Vector2(140, 24))
	_plate(reset_button, Color(0.4, 0.2, 0.15, 0.95), GOLD_DARK, 6, 1)
	_text(reset_button.position + Vector2(0, 17), "RESET TO DEFAULTS", 11, CREAM, HORIZONTAL_ALIGNMENT_CENTER, reset_button.size.x, 2)
	_text(body.position + Vector2(0, body.size.y - 22), "Click a row, then press the key, mouse button or gamepad button you want. Esc cancels. Bindings are saved.",
		11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_text(body.position + Vector2(0, body.size.y - 8), "Fixed: the mouse and right stick aim, the left stick moves, 1-6 or the D-pad spend perk points, Backspace quits a match. PS5 and Xbox pads work as they are; the Settings tab picks the button names.",
		11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _menu_settings(body: Rect2) -> void:
	## Sound, display toggles, bot difficulty and the team calls. Everything
	## here is saved.
	var x := body.position.x
	var y := body.position.y
	# Sound and music sliders: click or drag.
	_text(Vector2(x + 10, y + 22), "SOUND", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_text(Vector2(x + 330, y + 22), "MUSIC", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in 2:
		var slider := Rect2(Vector2(x + 70 + i * 320, y + 9), Vector2(190, 16))
		var value: float = game.sfx.sound_volume if i == 0 else game.sfx.music_volume
		_plate(slider, Color(0.08, 0.07, 0.1, 0.95), GOLD_DARK, 7, 1)
		var inner := slider.grow(-2)
		if value > 0.02:
			var sb := StyleBoxFlat.new()
			sb.bg_color = STAMINA if i == 0 else MANA
			sb.set_corner_radius_all(5)
			draw_style_box(sb, Rect2(inner.position, Vector2(inner.size.x * value, inner.size.y)))
		draw_circle(Vector2(inner.position.x + inner.size.x * value, slider.get_center().y), 7.0, CREAM)
		draw_arc(Vector2(inner.position.x + inner.size.x * value, slider.get_center().y), 7.0, 0, TAU, 16, GOLD_DARK, 1.5)
		_text(slider.end + Vector2(8, -3), "%d%%" % roundi(value * 100), 11, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		volume_sliders.append([slider, "sound" if i == 0 else "music"])
	draw_line(Vector2(x, y + 44), Vector2(body.end.x, y + 44), GOLD_DARK, 1.0)
	# Display toggles.
	_text(Vector2(x + 10, y + 66), "DISPLAY", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var toggles := [["Screen shake", game.screen_shake, "shake"], ["Damage numbers", game.damage_numbers, "numbers"],
		["FPS counter", game.show_fps, "fps"], ["Chat log", game.chat_visible, "chat"], ["Team rosters", game.rosters_visible, "rosters"]]
	for i in toggles.size():
		_toggle(Rect2(Vector2(x + 10 + i * 143, y + 76), Vector2(136, 34)), toggles[i][0], toggles[i][1], toggles[i][2])
	_text(Vector2(x + 10, y + 120), "%s and %s also toggle the chat log and the rosters in a match." % [_k("chat_toggle"), _k("roster_toggle")], 10, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	draw_line(Vector2(x, y + 128), Vector2(body.end.x, y + 128), GOLD_DARK, 1.0)
	# Bot difficulty: click, or Left/Right on the title screen.
	_text(Vector2(x + 10, y + 150), "BOTS", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.BOT_DIFFICULTIES.size():
		var name: String = Stats.BOT_DIFFICULTIES[i]
		var b := Rect2(Vector2(x + 70 + i * 96, y + 134), Vector2(90, 24))
		var on: bool = game.bot_difficulty == name
		_plate(b, Color(0.5, 0.38, 0.08, 0.95) if on else INK_LIGHT, GOLD if on else Color(0.3, 0.3, 0.38), 6, 1)
		_text(b.position + Vector2(0, 17), name.to_upper(), 11, Color.WHITE if on else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 2)
		difficulty_buttons.append([b, name])
	_text(Vector2(x + 370, y + 150), Stats.BOT_TUNING[game.bot_difficulty].desc, 11, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	draw_line(Vector2(x, y + 172), Vector2(body.end.x, y + 172), GOLD_DARK, 1.0)
	# Team calls.
	_text(Vector2(x + 10, y + 194), "TEAM CALLS", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var calls := [[_k("cmd_attack"), "ATTACK!", "everyone pushes the enemy door now, no waiting at the rally"],
		[_k("cmd_defend"), "DEFEND!", "three bots come home to hold the castle"],
		[_k("cmd_help"), "TO ME!", "the two nearest bots come to where you called"]]
	for i in calls.size():
		var cy: float = y + 212 + i * 26
		_keycap(Vector2(x + 34, cy - 4), calls[i][0], 40)
		_text(Vector2(x + 66, cy + 4), calls[i][1], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_text(Vector2(x + 150, cy + 4), calls[i][2], 11, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_text(Vector2(x + 10, y + 284), "Bots follow a call for %d seconds; rebind the keys in Controls." % int(Stats.COMMAND_TIME), 11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	draw_line(Vector2(x, y + 292), Vector2(body.end.x, y + 292), GOLD_DARK, 1.0)
	# Gamepad: rumble, button names and what is plugged in.
	_text(Vector2(x + 10, y + 314), "GAMEPAD", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_toggle(Rect2(Vector2(x + 10, y + 324), Vector2(136, 34)), "Rumble", game.rumble_on, "rumble")
	var style_names := {"auto": "AUTO", "xbox": "XBOX", "ps": "PLAYSTATION"}
	var style := Rect2(Vector2(x + 156, y + 324), Vector2(150, 34))
	_plate(style, INK_LIGHT, Color(0.3, 0.3, 0.38), 8, 1)
	_text(style.position + Vector2(0, 13), "BUTTON NAMES", 8, GREY, HORIZONTAL_ALIGNMENT_CENTER, style.size.x, 1)
	_text(style.position + Vector2(0, 28), style_names[game.pad_style], 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, style.size.x, 2)
	toggle_buttons.append([style, "pad_style"])
	var pads: Array = Input.get_connected_joypads()
	var plugged := "No gamepad connected. DualSense (PS5), DualShock and Xbox pads work over USB or Bluetooth; plug one in and press any button."
	if not pads.is_empty():
		var names: Array = []
		for d in pads:
			names.append(game.pad_title(d))
		plugged = "Connected: " + ", ".join(names) + ((". Player 1 holds the %s." % game.pad_title(game.local_pad(0))) if game.couch_players > 1 else ". Press any button on it to switch the hints to its names.")
	_paragraph(Vector2(x + 320, y + 332), plugged + " Settings are saved.", 10, CREAM, body.end.x - x - 330, 12.0)


func _toggle(rect: Rect2, label: String, on: bool, key: String) -> void:
	## A labelled on/off switch; recorded for mouse clicks.
	_plate(rect, Color(0.18, 0.3, 0.16, 0.96) if on else INK_LIGHT, GOLD if on else Color(0.3, 0.3, 0.38), 8, 1)
	_text(rect.position + Vector2(10, 21), label, 10, Color.WHITE if on else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var pill := Rect2(rect.end - Vector2(36, 24), Vector2(28, 14))
	_plate(pill, STAMINA if on else Color(0.3, 0.3, 0.35), GOLD_DARK, 7, 1)
	draw_circle(pill.position + Vector2(pill.size.x - 7 if on else 7, 7), 5.0, CREAM)
	toggle_buttons.append([rect, key])


func _draw_screen_fx() -> void:
	## Full-screen feedback under the HUD: a red vignette on your last heart
	## and a flash when you are hit.
	var p = _me()
	if p == null or p.dead or game.demo:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if p.hearts == 1:
		_vignette(Color(0.7, 0.05, 0.05, 0.26 + 0.12 * sin(t * 5.0)))
	elif p.hearts == 2:
		_vignette(Color(0.6, 0.1, 0.05, 0.1))
	if p.flash_timer > 0.0:
		_vignette(Color(0.9, 0.2, 0.15, 0.35 * p.flash_timer / 0.15))
		# Which way the hit came from: a red arc around you on that side.
		if p.last_hit_dir.length() > 0.1 and game.camera:
			var eye: Vector3 = p.global_position + Vector3(0, 1, 0)
			var c: Vector2 = game.camera.unproject_position(eye)
			var o: Vector2 = game.camera.unproject_position(eye - p.last_hit_dir * 2.0)
			var d2 := (o - c).normalized()
			var ang := d2.angle()
			var k: float = p.flash_timer / 0.15
			draw_arc(c, 96.0 + 20.0 * (1.0 - k), ang - 0.45, ang + 0.45, 18, Color(1.0, 0.25, 0.2, 0.85 * k), 7.0, true)


func _vignette(c: Color) -> void:
	var n := 8
	var depth := 110.0
	var w := depth / n
	for i in n:
		var d := w * i
		var col := Color(c.r, c.g, c.b, c.a * (1.0 - float(i) / n))
		draw_rect(Rect2(d + w / 2.0, d + w / 2.0, size.x - 2.0 * d - w, size.y - 2.0 * d - w), col, false, w + 0.5)


func _menu_my_class(body: Rect2) -> void:
	## The player's class, this life's ranks and the class's promotion paths.
	var p = _me()
	if p == null:
		_text(body.position + Vector2(0, body.size.y / 2.0), "Start a match to see your class.", 14, GREY, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 2)
		return
	# Left: who you are.
	var left := Rect2(body.position, Vector2(230, body.size.y))
	_plate(left, INK_LIGHT, GOLD_DARK, 10, 2)
	if not _card(_card_key(p.team, p.role), Rect2(left.position + Vector2(10, 6), Vector2(210, 100)), false, p.dead):
		_portrait(left.position + Vector2(115, 54), 34, p.team, p.role, p.dead)
	if p.role != Role.BASE:
		_icon(p.variant().get("icon", _class_icon(p.role)), left.position + Vector2(196, 26), 11, Color.WHITE)
	_text(left.position + Vector2(0, 114), p.role_name().to_upper(), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER, left.size.x, 4)
	var sub: String = Stats.FACTIONS[p.team].name if p.variant().is_empty() else "%s %s" % [Stats.FACTIONS[p.team].name, p.class_name_plain()]
	_text(left.position + Vector2(0, 130), sub.to_upper(), 10, _team_color(p.team).lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, left.size.x, 2)
	var s: Dictionary = p.stats()
	var facts := [["Level", "%d  (%d XP this life)" % [p.level, p.xp]], ["Points to spend", str(p.points)],
		["Energy", ("%s %d / %d" % [s.energy, int(p.energy), int(p.energy_max())]).capitalize()],
		["Hearts", "%d / %d" % [p.hearts, Stats.MAX_HEARTS]], ["Kills / deaths", "%d / %d" % [p.kills, p.deaths]],
		["Captures", str(p.captures)], ["Match score", str(game.unit_score(p))], ["Total upgrades", str(p.total_upgrades())]]
	for i in facts.size():
		var y: float = left.position.y + 156 + i * 20
		_text(Vector2(left.position.x + 14, y), facts[i][0], 11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_text(Vector2(left.position.x, y), facts[i][1], 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, left.size.x - 14, 2)
	if p.role == Role.BASE:
		_paragraph(left.position + Vector2(14, 328), "You are a villager. Grab a class hat in your cellar (press %s beside it) to pick a class." % _k("interact"), 10, CREAM, left.size.x - 28, 12.0)
	else:
		_text(left.position + Vector2(14, 332), s.attack_name, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_paragraph(left.position + Vector2(14, 348), s.attack_desc, 10, Color(0.8, 0.8, 0.8), left.size.x - 28, 12.0)
	# Middle: this life's ranks.
	var mid := Rect2(body.position + Vector2(240, 0), Vector2(220, body.size.y))
	_plate(mid, INK_LIGHT, GOLD_DARK, 10, 2)
	_text(mid.position + Vector2(0, 20), "RANKS THIS LIFE", 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, mid.size.x, 2)
	var track_icons := [_attack_icon(p.role, s), "", "", "vigor"]
	for i in 2:
		if i < p.abilities().size():
			track_icons[i + 1] = p.abilities()[i].get("icon", p.abilities()[i].kind)
	for t in 4:
		var y: float = mid.position.y + 50 + t * 58
		var available: bool = p.track_available(t)
		if available:
			_icon(track_icons[t], Vector2(mid.position.x + 28, y + 10), 11, Color.WHITE)
		_text(Vector2(mid.position.x + 52, y + 6), p.track_name(t) if available else "No %s ability yet" % ["", "Q", "E", ""][t], 12, Color.WHITE if available else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		for k in Stats.MAX_RANK:
			var c := Vector2(mid.position.x + 58 + k * 16, y + 22)
			draw_circle(c, 5.5, GOLD if k < p.rank(t) else Color(0.2, 0.2, 0.25))
			draw_arc(c, 5.5, 0, TAU, 12, GOLD_DARK, 1.0)
		if available:
			_text(Vector2(mid.position.x + 110, y + 26), "rank %d / %d" % [p.rank(t), Stats.MAX_RANK], 10, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_paragraph(mid.position + Vector2(14, mid.size.y - 70), "Each level gives a point. Ranks cut cooldowns and costs, then widen the effect, then add a heart. Experience resets when you die.", 10, Color(0.8, 0.8, 0.8), mid.size.x - 28, 12.0)
	_text(mid.position + Vector2(0, mid.size.y - 10), "%s opens the perk menu" % _k("rank_menu"), 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER, mid.size.x, 2)
	# Right: promotions, for this class or all of them.
	var right := Rect2(body.position + Vector2(470, 0), Vector2(body.size.x - 470, body.size.y))
	_plate(right, INK_LIGHT, GOLD_DARK, 10, 2)
	if Stats.VARIANTS.has(p.role):
		_text(right.position + Vector2(0, 20), "PROMOTION", 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, right.size.x, 2)
		var spent: int = p.mastery.get(p.role, 0)
		var unlocked: bool = p.variant_unlocked(p.role)
		_text(right.position + Vector2(0, 36), ("%d / %d points spent in this class  ·  unlocked" if unlocked else "%d / %d points spent in this class  ·  locked") % [spent, Stats.VARIANT_UNLOCK], 10, CREAM if unlocked else GREY, HORIZONTAL_ALIGNMENT_CENTER, right.size.x, 2)
		for i in 2:
			var v: Dictionary = Stats.VARIANTS[p.role][i]
			var card := Rect2(right.position + Vector2(10, 48 + i * 158), Vector2(right.size.x - 20, 150))
			var chosen: bool = p.variants.get(p.role, -1) == i
			_plate(card, Color(0.3, 0.26, 0.12, 0.98) if chosen else (INK if unlocked else Color(0.1, 0.1, 0.13, 0.9)), GOLD if chosen else (GOLD_DARK if unlocked else Color(0.3, 0.3, 0.3)), 8, 2 if chosen else 1)
			_icon(v.icon, card.position + Vector2(26, 24), 12, Color.WHITE, not unlocked)
			_text(card.position + Vector2(54, 24), v.name.to_upper(), 14, GOLD if chosen else (Color.WHITE if unlocked else GREY), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
			_text(card.position + Vector2(0, 24), "CHOSEN" if chosen else ("available" if unlocked else "locked"), 10, GOLD if chosen else GREY, HORIZONTAL_ALIGNMENT_RIGHT, card.size.x - 10, 2)
			var y: float = 50.0 + _paragraph(card.position + Vector2(10, 50), v.desc, 10, Color(0.85, 0.85, 0.85) if unlocked else GREY, card.size.x - 20, 12.0)
			var moves := [[_k("attack"), v.attack.get("attack_name", Stats.kit(p.team, p.role).attack_name)], [_k("ability_1"), v.abilities[0].name], [_k("ability_2"), v.abilities[1].name]]
			for m in moves.size():
				_keycap(card.position + Vector2(28, y + 14 + m * 19), moves[m][0], 34)
				_text(card.position + Vector2(52, y + 18 + m * 19), moves[m][1], 10, CREAM if unlocked else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			if unlocked and not chosen and not p.dead:
				var button := Rect2(card.end - Vector2(96, 30), Vector2(86, 22))
				_plate(button, Color(0.2, 0.5, 0.25, 0.95), GOLD, 6, 1)
				_text(button.position + Vector2(0, 15), "CHOOSE", 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 2)
				variant_buttons.append([button, p.role, i])
	else:
		_text(right.position + Vector2(0, 20), "TOTAL UPGRADES", 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, right.size.x, 2)
		_text(right.position + Vector2(0, 38), "Rank points spent per class this match. Three in a class unlock its two promotions.", 10, GREY, HORIZONTAL_ALIGNMENT_CENTER, right.size.x, 2)
		var roles := [Role.KNIGHT, Role.RANGER, Role.MAGE, Role.HEALER, Role.ENGINEER, Role.ROGUE]
		for i in roles.size():
			var role: int = roles[i]
			var row := Rect2(right.position + Vector2(10, 52 + i * 52), Vector2(right.size.x - 20, 48))
			_plate(row, INK, GOLD_DARK, 8, 1)
			_icon(_class_icon(role), row.position + Vector2(26, 24), 11, Color.WHITE)
			var spent: int = p.mastery.get(role, 0)
			_text(row.position + Vector2(50, 20), Stats.FACTIONS[p.team].roles[role].to_upper(), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
			_text(row.position + Vector2(0, 20), "%d / %d points" % [spent, Stats.VARIANT_UNLOCK], 10, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 12, 2)
			var vs: Array = Stats.VARIANTS[role]
			var chosen: int = p.variants.get(role, -1)
			var line := "%s  or  %s" % [vs[0].name, vs[1].name]
			if chosen >= 0:
				line = "Promoted: %s" % vs[chosen].name
			elif p.variant_unlocked(role):
				line = "Unlocked: choose in the perk menu as a %s" % Stats.FACTIONS[p.team].roles[role]
			_text(row.position + Vector2(50, 36), line, 10, GOLD if chosen >= 0 else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			_bar(Rect2(row.position + Vector2(50, 43), Vector2(row.size.x - 70, 7)), float(spent) / Stats.VARIANT_UNLOCK, XP)


func _menu_scoreboard(body: Rect2) -> void:
	_draw_scoreboard_table(Rect2(body.position + Vector2(40, 0), Vector2(body.size.x - 80, body.size.y)))


func _draw_scoreboard_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	var rect := Rect2(size.x / 2.0 - 400, size.y / 2.0 - 240, 800, 470)
	_plate(rect, INK, GOLD, 14, 3)
	_card("logo_elves", Rect2(rect.position + Vector2(16, 6), Vector2(70, 70)))
	_card("logo_humans", Rect2(rect.position + Vector2(rect.size.x - 86, 6), Vector2(70, 70)))
	_text(rect.position + Vector2(0, 30), "SCOREBOARD", 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 4)
	var left := maxf(game.time_left, 0.0)
	_text(rect.position + Vector2(0, 48), "%s %d  ·  %02d:%02d left  ·  %d %s" % [Stats.FACTIONS[0].realm, game.score[0], int(left) / 60, int(left) % 60, game.score[1], Stats.FACTIONS[1].realm], 12, CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
	_draw_scoreboard_table(Rect2(rect.position + Vector2(20, 78), Vector2(rect.size.x - 40, rect.size.y - 98)), true)
	_text(rect.position + Vector2(0, rect.size.y - 10), "Score = kills ×%d, assists ×%d, captures ×%d, hearts healed ×%d, damage ×%d, upgrades ×%d" % [Stats.SCORE_KILL, Stats.SCORE_ASSIST, Stats.SCORE_CAPTURE, Stats.SCORE_HEAL, Stats.SCORE_DAMAGE, Stats.SCORE_UPGRADE], 10, GREY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


func _draw_scoreboard_table(rect: Rect2, live: bool = false) -> void:
	## Both teams, best score first: class, level, score, kills, deaths,
	## captures, hearts healed, damage and total upgrades. The live (Tab)
	## version also shows everyone's hearts and respawn timers.
	var cols := [["PLAYER", 0.0, HORIZONTAL_ALIGNMENT_LEFT], ["CLASS", 150.0, HORIZONTAL_ALIGNMENT_LEFT], ["LV", 250.0, HORIZONTAL_ALIGNMENT_CENTER],
		["K", 296.0, HORIZONTAL_ALIGNMENT_CENTER], ["D", 336.0, HORIZONTAL_ALIGNMENT_CENTER], ["A", 376.0, HORIZONTAL_ALIGNMENT_CENTER],
		["CAPS", 420.0, HORIZONTAL_ALIGNMENT_CENTER], ["HEAL", 470.0, HORIZONTAL_ALIGNMENT_CENTER], ["DMG", 520.0, HORIZONTAL_ALIGNMENT_CENTER], ["UPG", 568.0, HORIZONTAL_ALIGNMENT_CENTER], ["SCORE", 614.0, HORIZONTAL_ALIGNMENT_CENTER]]
	if live:
		cols = [["PLAYER", 0.0, HORIZONTAL_ALIGNMENT_LEFT], ["CLASS", 122.0, HORIZONTAL_ALIGNMENT_LEFT], ["HEARTS", 220.0, HORIZONTAL_ALIGNMENT_LEFT], ["LV", 312.0, HORIZONTAL_ALIGNMENT_CENTER],
			["K", 354.0, HORIZONTAL_ALIGNMENT_CENTER], ["D", 392.0, HORIZONTAL_ALIGNMENT_CENTER], ["A", 430.0, HORIZONTAL_ALIGNMENT_CENTER],
			["CAPS", 472.0, HORIZONTAL_ALIGNMENT_CENTER], ["HEAL", 520.0, HORIZONTAL_ALIGNMENT_CENTER], ["DMG", 568.0, HORIZONTAL_ALIGNMENT_CENTER], ["UPG", 614.0, HORIZONTAL_ALIGNMENT_CENTER], ["SCORE", 664.0, HORIZONTAL_ALIGNMENT_CENTER]]
	var scale := rect.size.x / (710.0 if live else 660.0)
	var y := rect.position.y
	for t in 2:
		var tc := _team_color(t)
		var members: Array = game.units.filter(func(u): return u.team == t)
		members.sort_custom(func(a, b): return game.unit_score(a) > game.unit_score(b))
		var block := Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, 30 + 18 + members.size() * 22 + 8))
		_plate(block, tc.darkened(0.72), tc.darkened(0.1), 8, 1)
		if not _card("crest_elf" if t == 0 else "crest_human", Rect2(block.position + Vector2(6, 3), Vector2(28, 28))):
			_icon("crest_forest" if t == 0 else "crest_kingdom", block.position + Vector2(20, 16), 9, Color.WHITE)
		var kills := 0
		for u in members:
			kills += u.kills
		_text(block.position + Vector2(38, 21), "%s  ·  %s" % [Stats.FACTIONS[t].name.to_upper(), Stats.FACTIONS[t].realm.to_upper()], 13, tc.lightened(0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		_text(block.position + Vector2(0, 21), "%d capture%s  ·  %d kills" % [game.score[t], "" if game.score[t] == 1 else "s", kills], 11, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, block.size.x - 12, 2)
		for c in cols:
			_text(block.position + Vector2(12 + c[1] * scale, 44), c[0], 9, GREY, c[2], 40 if c[2] == HORIZONTAL_ALIGNMENT_CENTER else -1, 2)
		for i in members.size():
			var u = members[i]
			var ry: float = block.position.y + 52 + i * 22
			if u.is_player:
				draw_rect(Rect2(block.position.x + 4, ry - 2, block.size.x - 8, 21), Color(0.45, 0.35, 0.1, 0.5))
			var col := GOLD if u.is_player else Color.WHITE
			if u.dead:
				col = col.darkened(0.4)
			var values := [u.display_name, u.role_name(), str(u.level), str(u.kills), str(u.deaths), str(u.assists), str(u.captures), str(u.healing), str(u.damage_dealt), str(u.total_upgrades()), str(game.unit_score(u))]
			var score_col := 10
			if live:
				values.insert(2, "")
				score_col = 11
				var hx: float = block.position.x + 12 + cols[2][1] * scale
				if u.dead:
					_text(Vector2(hx, ry + 13), "back in %d" % ceili(u.respawn_eta()), 10, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
				else:
					_hearts(Vector2(hx + 6, ry + 9), u.hearts, 0.3, 13)
					if u.buff != "" and u.buff_timer > 0.0:
						_icon(Stats.BLESSING_KINDS[u.buff].icon, Vector2(hx + 70, ry + 9), 5, Color.WHITE)
				if u.role != Role.BASE:
					_icon(u.variant().get("icon", _class_icon(u.role)), Vector2(block.position.x + 12 + cols[1][1] * scale - 10, ry + 9), 5, Color.WHITE)
			if u.is_player:
				values[0] = values[0] + "  (you)"
			if u.veteran == 2:
				values[0] = "☠ " + values[0]
			elif u.veteran == 1:
				values[0] = "★ " + values[0]
			for c in cols.size():
				_text(Vector2(block.position.x + 12 + cols[c][1] * scale, ry + 13), values[c], 11, col if c != score_col else XP, cols[c][2], 40 if cols[c][2] == HORIZONTAL_ALIGNMENT_CENTER else -1, 2)
			if u.carrying:
				_icon("crown", Vector2(block.position.x + 12 + cols[1][1] * scale + _text_width(u.role_name(), 11) + 14, ry + 8), 5, GOLD)
		y = block.end.y + 10


func _draw_chat() -> void:
	## The chat log in the reference's style: each message is a row with the
	## speaker's portrait, their name in team colour, the match clock and the
	## line; while typing it sits in a panel with All/Team tabs and an input
	## box with a send arrow. Idle, recent rows fade out over the field.
	var top: float = 382.0 if game.rosters_visible else 130.0
	var rect := Rect2(14, top, 290, size.y - 166 - top)
	var now := Time.get_ticks_msec() / 1000.0
	var typing: bool = game.chat_open
	if not game.chat_visible and not typing:
		_text(Vector2(14, size.y - 132), "%s shows chat" % _k("chat_toggle"), 9, Color(0.7, 0.7, 0.75, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		return
	var tab_h := 34.0 if typing else 0.0
	var input_h := 34.0 if typing else 0.0
	var lines: Array = []
	for i in range(game.chat_log.size() - 1, -1, -1):
		var m: Dictionary = game.chat_log[i]
		var age: float = now - m.time
		if not typing and age > 14.0:
			break
		if typing and game.chat_tab == 1 and not m.team:
			continue
		lines.push_front(m)
		if lines.size() >= 12:
			break
	if lines.is_empty() and not typing:
		return
	if typing:
		_plate(rect, Color(0.05, 0.06, 0.1, 0.9), GOLD_DARK, 10, 2)
		# Tabs.
		var labels := ["All", "Team"]
		for i in labels.size():
			var tab := Rect2(rect.position + Vector2(10 + i * 92, 8), Vector2(84, 22))
			var on: bool = game.chat_tab == i
			_plate(tab, Color(0.16, 0.14, 0.1, 0.98) if on else Color(0.1, 0.11, 0.16, 0.9), GOLD if on else Color(0.3, 0.32, 0.4), 6, 1)
			_text(tab.position + Vector2(0, 16), labels[i], 12, CREAM if on else GREY, HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 1)
			chat_buttons.append([tab, str(i)])
		_text(rect.position + Vector2(0, 24), "Enter sends · Esc cancels", 9, GREY, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 10, 1)
	# Rows from the bottom up so the newest sits above the input.
	var y := rect.end.y - input_h - 8
	var tw: float = rect.size.x - 62
	for i in range(lines.size() - 1, -1, -1):
		var m: Dictionary = lines[i]
		var alpha := 1.0 if typing else clampf((14.0 - (now - m.time)) / 3.0, 0.0, 1.0)
		var named: bool = m.who != ""
		var body_h := _paragraph_height(m.text, 11, tw, 13.0)
		var h: float = maxf(36.0, body_h + (22.0 if named else 10.0))
		y -= h + 4
		if y < rect.position.y + tab_h + 4:
			break
		var row := Rect2(rect.position.x + 6, y, rect.size.x - 12, h)
		draw_rect(row, Color(0.08, 0.09, 0.14, (0.75 if typing else 0.6) * alpha))
		draw_rect(row, Color(0.3, 0.32, 0.4, 0.5 * alpha), false, 1.0)
		var col: Color = m.color
		col.a = alpha
		if named:
			var role: int = m.get("role", -1)
			var pteam: int = m.get("pteam", -1)
			if role >= 0 and pteam >= 0:
				_class_card(row.position + Vector2(20, 18), 13, pteam, role)
			else:
				draw_circle(row.position + Vector2(20, 18), 13, Color(0.2, 0.2, 0.26, alpha))
				_icon("crown", row.position + Vector2(20, 18), 7, Color(GOLD.r, GOLD.g, GOLD.b, alpha))
			var who: String = m.who + ("  [Team]" if m.team else "")
			_text(row.position + Vector2(40, 14), who, 11, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
			var clock: float = m.get("clock", 0.0)
			_text(row.position + Vector2(0, 14), "%02d:%02d" % [int(clock) / 60, int(clock) % 60], 9, Color(0.6, 0.62, 0.7, alpha), HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 8, 1)
			_paragraph(row.position + Vector2(40, 29), m.text, 11, Color(0.92, 0.92, 0.95, alpha), tw, 13.0, 1)
		else:
			_icon("crown", row.position + Vector2(20, h / 2.0), 6, Color(GOLD.r, GOLD.g, GOLD.b, 0.8 * alpha))
			_paragraph(row.position + Vector2(40, h / 2.0 + 4), m.text, 11, col, tw, 13.0, 1)
	if typing:
		var box := Rect2(rect.position + Vector2(8, rect.size.y - 30), Vector2(rect.size.x - 56, 24))
		_plate(box, Color(0.12, 0.13, 0.2, 0.98), GOLD_DARK, 6, 1)
		var caret := "|" if int(now * 2.5) % 2 == 0 else " "
		var shown: String = game.chat_text
		var placeholder: bool = shown == ""
		while _text_width(shown + caret, 11) > box.size.x - 12 and shown.length() > 1:
			shown = shown.substr(1)
		_text(box.position + Vector2(6, 16), ("Type a message..." if placeholder else shown) + ("" if placeholder else caret), 11,
			Color(0.55, 0.56, 0.62) if placeholder else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		var send := Rect2(box.end.x + 6, box.position.y, 34, 24)
		_plate(send, Color(0.5, 0.35, 0.12), GOLD, 6, 1)
		var c := send.get_center()
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -6), c + Vector2(8, 0), c + Vector2(-7, 6), c + Vector2(-3, 0)]), GOLD.lightened(0.3))
		_text(rect.position + Vector2(10, rect.size.y - 36), "/all talks to both teams  ·  %s hides the log" % _k("chat_toggle"), 9, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)


# --- Title and end screens -----------------------------------------------------

func _faction_card(rect: Rect2, team: int, key: String, pad: String, blurb: String) -> void:
	var tc := _team_color(team)
	_plate(rect, tc.darkened(0.72), tc.lightened(0.1), 14, 3)
	if not _card("logo_elves" if team == 0 else "logo_humans", Rect2(rect.position + Vector2(10, 6), Vector2(rect.size.x - 20, 156))):
		_portrait(rect.position + Vector2(rect.size.x / 2.0, 70), 40, team, Role.KNIGHT)
		_icon("crest_forest" if team == 0 else "crest_kingdom", rect.position + Vector2(rect.size.x - 34, 34), 12, Color.WHITE)
		_text(rect.position + Vector2(0, 146), Stats.FACTIONS[team].name.to_upper(), 28, tc.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 5)
	_paragraph(rect.position + Vector2(12, 172), blurb, 10, CREAM, rect.size.x - 24, 12.0)
	_keycap(rect.position + Vector2(rect.size.x / 2.0 - 46, 200), key, 60)
	_text(rect.position + Vector2(rect.size.x / 2.0 - 10, 205), "or " + pad, 12, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _chunky(rect: Rect2, fill: Color, selected: bool = false, hover: bool = false) -> void:
	## A chunky Fall Guys style button: thick dark outline, bright fill, a
	## pale highlight along the top, and a lift when selected or hovered.
	var r := rect
	if selected or hover:
		r = rect.grow(2)
	draw_rect(Rect2(r.position + Vector2(0, 5), r.size), Color(0.05, 0.05, 0.1, 0.5), true)  # drop shadow
	_plate(r, fill.lightened(0.12) if (selected or hover) else fill, Color(0.08, 0.06, 0.12), 16, 4)
	var hi := Rect2(r.position + Vector2(10, 5), Vector2(r.size.x - 20, minf(maxf(r.size.y * 0.22, 6), 14)))
	draw_rect(hi, Color(1, 1, 1, 0.22), true)


func _draw_banner(rect: Rect2, b: Dictionary, weapon: String = "") -> void:
	## A player banner (calling card): patterned background, frame, emblem,
	## name, title and account level. `weapon` adds a "killed you with" line.
	if b.is_empty():
		return
	var bg: Array = Stats.BANNER_BACKGROUNDS[clampi(b.bg, 0, Stats.BANNER_BACKGROUNDS.size() - 1)]
	var frame: Array = Stats.BANNER_FRAMES[clampi(b.frame, 0, Stats.BANNER_FRAMES.size() - 1)]
	var c1: Color = bg[1]
	var c2: Color = bg[2]
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color(0, 0, 0, 0.45))
	_plate(rect, c1, frame[1], 10, 3)
	var inner := rect.grow(-5)
	match bg[3]:
		"stripes":
			for i in range(0, int(inner.size.x / 18) + 2):
				var x: float = inner.position.x + i * 18 - 20
				var p := PackedVector2Array([Vector2(x, inner.end.y), Vector2(x + 8, inner.end.y), Vector2(x + 8 + inner.size.y * 0.6, inner.position.y), Vector2(x + inner.size.y * 0.6, inner.position.y)])
				for k in p.size():
					p[k].x = clampf(p[k].x, inner.position.x, inner.end.x)
				draw_colored_polygon(p, Color(c2, 0.35))
		"diamonds":
			for i in 7:
				var cx: float = inner.position.x + 14 + i * (inner.size.x / 6.5)
				var cy: float = inner.get_center().y + (12 if i % 2 == 0 else -12)
				var d := 9.0
				draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - d), Vector2(cx + d, cy), Vector2(cx, cy + d), Vector2(cx - d, cy)]), Color(c2, 0.4))
		"rays":
			var o := Vector2(inner.end.x - 10, inner.get_center().y)
			for i in 7:
				var a1: float = PI * 0.55 + i * 0.13
				var a2: float = a1 + 0.065
				var p := PackedVector2Array([o, o + Vector2(cos(a1), sin(a1)) * inner.size.x * 1.2, o + Vector2(cos(a2), sin(a2)) * inner.size.x * 1.2])
				for k in p.size():
					p[k] = Vector2(clampf(p[k].x, inner.position.x, inner.end.x), clampf(p[k].y, inner.position.y, inner.end.y))
				draw_colored_polygon(p, Color(c2, 0.35))
		"leaves":
			for i in 9:
				var cx: float = inner.position.x + 10 + i * (inner.size.x / 8.5)
				var cy: float = inner.position.y + 10 + (i * 37) % int(maxf(inner.size.y - 20, 1))
				draw_circle(Vector2(cx, cy), 7, Color(c2, 0.3))
				draw_circle(Vector2(cx + 5, cy - 4), 4, Color(c2, 0.3))
		_:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(c2, 0.25))
	var ec := rect.position + Vector2(34, rect.size.y / 2.0)
	draw_circle(ec, 24, Color(0.05, 0.05, 0.08, 0.7))
	draw_arc(ec, 24, 0, TAU, 32, frame[1], 2.0)
	_icon(Stats.BANNER_EMBLEMS[clampi(b.emblem, 0, Stats.BANNER_EMBLEMS.size() - 1)], ec, 13, Color.WHITE)
	var tc: Color = _team_color(b.get("team", 0)).lightened(0.5)
	_text(rect.position + Vector2(68, 26), b.name, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(rect.position + Vector2(68, 42), str(b.title).to_upper(), 10, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if weapon != "":
		_text(rect.position + Vector2(68, 56), "with %s" % weapon, 9, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var badge := rect.position + Vector2(rect.size.x - 28, rect.size.y / 2.0)
	draw_circle(badge, 17, Color(0.08, 0.06, 0.12))
	draw_circle(badge, 14, Color(0.95, 0.6, 0.2))
	_text(badge + Vector2(-14, 3), str(b.level), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 28, 2)
	_text(badge + Vector2(-14, 11), "LV", 6, tc, HORIZONTAL_ALIGNMENT_CENTER, 28, 1)


func _draw_killer_card() -> void:
	## "KILLED BY": the killer's banner drops in over the field while you are down.
	var k = game.killer_card.get("unit")
	if k == null or not is_instance_valid(k):
		return
	var cx := size.x / 2.0
	var slide: float = clampf((6.0 - game.killer_timer) * 4.0, 0.0, 1.0)
	var y: float = 160.0 - (1.0 - slide) * 60.0
	var rect := Rect2(cx - 170, y, 340, 70)
	_text(Vector2(cx - 170, y - 16), "KILLED BY", 13, Color(1.0, 0.5, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 340, 3)
	_draw_banner(rect, game.banner_for(k), game.killer_card.get("weapon", ""))


func _draw_banner_editor(origin: Vector2, w: float) -> void:
	## The banner editor on the HERO tab: a live preview and a row of
	## swatches for the background, emblem, frame and title.
	_text(origin + Vector2(0, 0), "YOUR BANNER  ·  the enemy sees it when you kill them", 11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var preview := Rect2(origin + Vector2(0, 8), Vector2(w, 64))
	var me := {"name": game.hero_name if game.hero_name.strip_edges() != "" else "You", "bg": game.banner_bg, "emblem": game.banner_emblem,
		"frame": game.banner_frame, "title": Stats.BANNER_TITLES[game.banner_title][1], "level": game.account_level(), "team": 0}
	_draw_banner(preview, me)
	var y := origin.y + 84
	var sw := 26.0
	# Background swatches.
	_text(Vector2(origin.x, y), "BACKGROUND", 9, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.BANNER_BACKGROUNDS.size():
		var b := Rect2(origin.x + 76 + i * (sw + 3), y - 11, sw, 18)
		var bg: Array = Stats.BANNER_BACKGROUNDS[i]
		_plate(b, bg[2].lerp(bg[1], 0.4), GOLD if i == game.banner_bg else Color(0.1, 0.1, 0.14), 4, 2 if i == game.banner_bg else 1)
		hero_buttons.append([b, "banner_bg", i])
	y += 26
	_text(Vector2(origin.x, y), "EMBLEM", 9, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.BANNER_EMBLEMS.size():
		var b := Rect2(origin.x + 76 + (i % 7) * (sw + 3), y - 11 + (i / 7) * 22, sw, 18)
		var locked: bool = Stats.BANNER_EMBLEMS[i] == "class_rogue" and not game.unlocked()
		_plate(b, INK_LIGHT if not locked else Color(0.2, 0.2, 0.24), GOLD if i == game.banner_emblem else Color(0.1, 0.1, 0.14), 4, 2 if i == game.banner_emblem else 1)
		_icon(Stats.BANNER_EMBLEMS[i], b.get_center(), 5, Color.WHITE, locked)
		hero_buttons.append([b, "banner_emblem", i])
	y += 48
	_text(Vector2(origin.x, y), "FRAME", 9, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.BANNER_FRAMES.size():
		var b := Rect2(origin.x + 76 + i * (sw + 3), y - 11, sw, 18)
		var locked: bool = Stats.BANNER_FRAMES[i][0] == "Royal" and not game.unlocked()
		_plate(b, Stats.BANNER_FRAMES[i][1] if not locked else Color(0.2, 0.2, 0.24), GOLD if i == game.banner_frame else Color(0.1, 0.1, 0.14), 4, 2 if i == game.banner_frame else 1)
		hero_buttons.append([b, "banner_frame", i])
	y += 26
	_text(Vector2(origin.x, y), "TITLE", 9, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var tx := origin.x + 76
	var ty := y - 11
	for i in Stats.BANNER_TITLES.size():
		var t: Array = Stats.BANNER_TITLES[i]
		var tw: float = _text_width(t[1].to_upper(), 8) + 12
		if tx + tw > origin.x + w:
			tx = origin.x + 76
			ty += 22
		var b := Rect2(tx, ty, tw, 18)
		var have: bool = t[0] <= game.account_level() or "--debug-unlock" in OS.get_cmdline_user_args()
		_plate(b, INK_LIGHT if have else Color(0.2, 0.2, 0.24), GOLD if i == game.banner_title else Color(0.1, 0.1, 0.14), 4, 2 if i == game.banner_title else 1)
		_text(b.position + Vector2(0, 13), t[1].to_upper(), 8, Color.WHITE if have else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 1)
		hero_buttons.append([b, "banner_title", i])
		tx += tw + 4


func _draw_nameplate(rect: Rect2) -> void:
	## The account card: portrait, hero name, rank title, level badge, XP bar.
	_chunky(rect, Color(0.18, 0.16, 0.3))
	var pc := rect.position + Vector2(40, rect.size.y / 2.0)
	_class_card(pc, 24, 0, Role.BASE)
	var level: int = game.account_level()
	var name: String = game.hero_name if game.hero_name.strip_edges() != "" else "Unnamed hero"
	_text(rect.position + Vector2(76, 26), name, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	_text(rect.position + Vector2(76, 44), Stats.rank_title(level).to_upper(), 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var span: Array = Stats.account_span(game.account_xp)
	var bar := Rect2(rect.position + Vector2(76, 52), Vector2(rect.size.x - 150, 12))
	_bar(bar, (float(span[0]) / span[1]) if span[1] > 0 else 1.0, Color(0.95, 0.6, 0.2))
	_text(bar.position + Vector2(0, 10), ("%d / %d XP" % [span[0], span[1]]) if span[1] > 0 else "MAX LEVEL", 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 2)
	var badge := rect.position + Vector2(rect.size.x - 36, rect.size.y / 2.0)
	draw_circle(badge, 24, Color(0.08, 0.06, 0.12))
	draw_circle(badge, 20, Color(0.95, 0.6, 0.2))
	_text(badge + Vector2(-20, 7), str(level), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40, 3)
	_text(badge + Vector2(-20, 18), "LV", 7, Color(0.1, 0.05, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 40, 0)


func _draw_title() -> void:
	## The main menu: a bright, chunky Fall Guys style front end over the
	## live world. A nameplate top-left, big tab buttons down the left, and
	## the chosen tab's panel on the right.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.1, 0.62))
	var cx := size.x / 2.0
	_draw_logo(Rect2(cx - 200, 2, 400, 160))
	_draw_nameplate(Rect2(16, 16, 330, 78))
	_text(Vector2(cx - 300, 178), "Elves against Humans. Break the door, steal the monarch, carry them home.", 13, CREAM,
		HORIZONTAL_ALIGNMENT_CENTER, 600, 3)
	# Tabs down the left.
	var tabs := [["PLAY", Color(0.86, 0.25, 0.5)], ["HERO", Color(0.95, 0.55, 0.15)], ["PROGRESS", Color(0.5, 0.3, 0.8)], ["OPTIONS", Color(0.15, 0.6, 0.65)]]
	var tx := 24.0
	var ty := 206.0
	for i in tabs.size():
		var b := Rect2(tx, ty + i * 78, 190, 64)
		var hover: bool = b.has_point(_mouse())
		var selected: bool = game.title_tab == i
		_chunky(b, tabs[i][1], selected, hover)
		_text(b.position + Vector2(0, 41), tabs[i][0], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 5)
		title_buttons.append([b, i])
	var panel := Rect2(236, 196, size.x - 236 - 24, size.y - 196 - 46)
	match game.title_tab:
		0: _draw_title_play(panel)
		1: _draw_title_hero(panel)
		2: _draw_title_progress(panel)
		_: _draw_title_play(panel)
	options_button = Rect2(tx, ty + 3 * 78, 190, 64)
	var foot := "Press 1 or 2 (or click a side) to play  ·  Esc never quits by accident"
	if game.cursor_shown:
		foot = "D-pad or stick moves the pointer  ·  %s picks  ·  %s backs out  ·  bumpers switch tabs" % [_k("ui_confirm"), _k("ui_back")]
	elif game.couch_players > 1:
		foot = "%d on this screen: player 1 on keyboard and mouse, players 2-%d on gamepads  ·  press 1 or 2 to play" % [game.couch_players, game.couch_players]
	_text(Vector2(cx - 300, size.y - 16), foot, 11, GREY, HORIZONTAL_ALIGNMENT_CENTER, 600, 2)


func _draw_title_play(panel: Rect2) -> void:
	_chunky(panel, Color(0.12, 0.16, 0.26))
	_text(panel.position + Vector2(0, 30), "CHOOSE YOUR SIDE", 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 4)
	var cw := 300.0
	var gap := 24.0
	var left := panel.position.x + (panel.size.x - cw * 2 - gap) / 2.0
	var fy := panel.position.y + 44
	var rects := [Rect2(left, fy, cw, 226), Rect2(left + cw + gap, fy, cw, 226)]
	_faction_card(rects[0], 0, "1", "D-pad left", "Wind and wood: glaives, moonbows, brambles, living totems. Quick on their feet.")
	_faction_card(rects[1], 1, "2", "D-pad right", "Steel and faith: shields, crossbows, fire, holy light. Recover energy faster.")
	faction_buttons.append([rects[0], 0])
	faction_buttons.append([rects[1], 1])
	# Map tiles and bot difficulty under the sides.
	var row_y := fy + 240
	_text(Vector2(left, row_y + 14), "MAP", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.MAPS.size():
		var b := Rect2(left + 50 + i * 190, row_y, 180, 34)
		var on: bool = game.map_variant == i
		var locked: bool = i > 0 and not game.unlocked()
		_chunky(b, (Color(0.2, 0.55, 0.3) if i == 0 else Color(0.25, 0.25, 0.55)) if not locked else Color(0.3, 0.3, 0.34), on, b.has_point(_mouse()))
		_text(b.position + Vector2(0, 23), Stats.MAPS[i][0].to_upper(), 12, Color.WHITE if not locked else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 3)
		if locked:
			_text(b.position + Vector2(0, 32), "LEVEL %d" % Stats.UNLOCK_LEVEL, 7, Color(1.0, 0.75, 0.5), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 1)
		hero_buttons.append([b, "map", i])
	# Couch play, to the right of the map tiles: how many on this screen and
	# whether they join you or fight you.
	var cxr := left + 450
	_text(Vector2(cxr, row_y + 14), "COUCH", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var less := Rect2(cxr + 56, row_y, 30, 34)
	var more := Rect2(cxr + 124, row_y, 30, 34)
	_chunky(less, Color(0.25, 0.22, 0.3), false, less.has_point(_mouse()))
	_chunky(more, Color(0.25, 0.22, 0.3), false, more.has_point(_mouse()))
	_text(less.position + Vector2(0, 23), "-", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, less.size.x, 3)
	_text(more.position + Vector2(0, 23), "+", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, more.size.x, 3)
	_text(Vector2(cxr + 86, row_y + 23), "%d" % game.couch_players, 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 38, 3)
	var mode := Rect2(cxr + 162, row_y, 92, 34)
	var coop: bool = game.couch_mode == "coop"
	_chunky(mode, Color(0.2, 0.5, 0.35) if coop else Color(0.55, 0.25, 0.3), game.couch_players > 1, mode.has_point(_mouse()))
	_text(mode.position + Vector2(0, 23), "CO-OP" if coop else "VERSUS", 11, Color.WHITE if game.couch_players > 1 else GREY, HORIZONTAL_ALIGNMENT_CENTER, mode.size.x, 2)
	couch_buttons.append([less, "less"])
	couch_buttons.append([more, "more"])
	couch_buttons.append([mode, "mode"])
	var dy := row_y + 46
	_text(Vector2(left, dy + 14), "BOTS", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.BOT_DIFFICULTIES.size():
		var name: String = Stats.BOT_DIFFICULTIES[i]
		var b := Rect2(left + 50 + i * 100, dy, 92, 30)
		var on: bool = game.bot_difficulty == name
		_chunky(b, Color(0.55, 0.4, 0.12) if on else Color(0.25, 0.22, 0.3), on, b.has_point(_mouse()))
		_text(b.position + Vector2(0, 21), name.to_upper(), 11, Color.WHITE if on else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 2)
		difficulty_buttons.append([b, name])
	_text(Vector2(left + 360, dy + 20), Stats.BOT_TUNING[game.bot_difficulty].desc, 10, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	# The match card: how a round goes, as chunky tags.
	var ty := dy + 50
	_text(Vector2(left, ty + 14), "MATCH", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var tags := [["%d s FORTIFY" % int(Stats.PREP_TIME), Color(0.55, 0.42, 0.15)], ["%d MIN CLOCK" % int(Stats.MATCH_TIME / 60.0), Color(0.2, 0.3, 0.5)],
		["FIRST TO %d CAPTURES" % Stats.CAPTURES_TO_WIN, Color(0.5, 0.2, 0.25)], ["OVERTIME ON A TIE", Color(0.3, 0.25, 0.45)], ["5 v 5 WITH BOTS", Color(0.2, 0.4, 0.3)]]
	var tx := left + 50
	for t in tags:
		var w: float = _text_width(t[0], 10) + 26
		var b := Rect2(tx, ty, w, 30)
		_chunky(b, t[1])
		_text(b.position + Vector2(0, 20), t[0], 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w, 2)
		tx += w + 8
	_text(Vector2(left + 50, ty + 46), "Fortify first: build turrets, set traps and raise barricades behind the wall of light; then the horn sounds and the gates are fair game.", 9, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var how := "%s · %s attacks · %s / %s abilities · %s dodges · %s grabs and raises barricades · %s perks · %s pauses" % [
		"Left stick moves · right stick aims" if game.on_pad(null) else "Move WASD · aim with the mouse",
		_k("attack"), _k("ability_1"), _k("ability_2"), _k("dodge"), _k("interact"), _k("rank_menu"), _k("menu")]
	_paragraph(Vector2(panel.position.x + 20, panel.end.y - 16), how, 10, Color(0.85, 0.85, 0.85), panel.size.x - 40, 12.0)


func _draw_title_hero(panel: Rect2) -> void:
	## YOUR HERO: name, hair, trim and look. The choices follow you into
	## every class you take, on top of the team colours.
	_chunky(panel, Color(0.3, 0.2, 0.12))
	_text(panel.position + Vector2(0, 30), "YOUR HERO", 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 4)
	var pc := panel.position + Vector2(110, 150)
	draw_circle(pc, 74, Color(0.08, 0.06, 0.12))
	draw_circle(pc, 68, Color(0.2, 0.3, 0.25))
	_class_card(pc, 56, 0, Role.BASE)
	draw_circle(pc + Vector2(-52, 52), 13, Stats.HERO_HAIR[game.hero_hair][1])
	draw_arc(pc + Vector2(-52, 52), 13, 0, TAU, 24, GOLD, 2.0)
	var trim: Color = Stats.HERO_TRIM[game.hero_trim][1]
	draw_circle(pc + Vector2(52, 52), 13, trim if game.hero_trim > 0 else Color(0.3, 0.5, 0.4))
	draw_arc(pc + Vector2(52, 52), 13, 0, TAU, 24, GOLD, 2.0)
	_text(Vector2(pc.x - 100, pc.y + 100), Stats.rank_title(game.account_level()).to_upper(), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 200, 2)
	var nx := panel.position.x + 240
	_text(Vector2(nx, panel.position.y + 64), "NAME", 11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var field := Rect2(nx, panel.position.y + 70, 400, 30)
	_plate(field, Color(0.05, 0.06, 0.1, 0.9), GOLD if game.name_editing else GOLD_DARK, 8, 2)
	var shown: String = game.hero_name
	if game.name_editing and int(Time.get_ticks_msec() / 400) % 2 == 0:
		shown += "|"
	elif shown == "" and not game.name_editing:
		shown = "click to name your hero"
	_text(field.position + Vector2(10, 21), shown, 14, Color.WHITE if game.hero_name != "" or game.name_editing else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	hero_buttons.append([field, "name", 0])
	var rows := [["HAIR", Stats.HERO_HAIR, game.hero_hair, "hair"], ["TRIM", Stats.HERO_TRIM, game.hero_trim, "trim"], ["LOOK", Stats.HERO_LOOKS, game.hero_look, "look"]]
	for r in rows.size():
		var label: String = rows[r][0]
		var options: Array = rows[r][1]
		var chosen: int = rows[r][2]
		var y: float = panel.position.y + 124 + r * 62
		_text(Vector2(nx, y), "%s  ·  %s" % [label, options[chosen][0]], 11, GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		for i in options.size():
			var wide: bool = rows[r][3] == "look"
			var b := Rect2(nx + i * (150 if wide else 44), y + 8, 140 if wide else 36, 30)
			var col: Color = options[i][1]
			if col.a == 0.0:
				col = Color(0.3, 0.5, 0.4) if not wide else Color(0.35, 0.45, 0.4)
			var locked: bool = wide and i > 0 and not game.unlocked()
			_chunky(b, col if not locked else Color(0.3, 0.3, 0.34), i == chosen, b.has_point(_mouse()))
			if wide:
				_text(b.position + Vector2(0, 20), options[i][0].to_upper() if not locked else "LOCKED · LV %d" % Stats.UNLOCK_LEVEL, 11, Color.WHITE if not locked else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 2)
			hero_buttons.append([b, rows[r][3], i])
	_paragraph(Vector2(nx, panel.position.y + 320), "Your look carries into every class you pick. The Shadowborn look (dusk-tinted armour, violet rim light, a cape on every class) unlocks at account level %d." % Stats.UNLOCK_LEVEL,
		10, CREAM, 400, 12.0)
	_draw_banner_editor(Vector2(nx + 430, panel.position.y + 64), panel.end.x - (nx + 430) - 24)


func _draw_title_progress(panel: Rect2) -> void:
	## PROGRESS: account level, rank ladder and the level-10 unlocks.
	_chunky(panel, Color(0.22, 0.14, 0.34))
	_text(panel.position + Vector2(0, 30), "PROGRESS", 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 4)
	var level: int = game.account_level()
	var span: Array = Stats.account_span(game.account_xp)
	var lx := panel.position.x + 30
	var badge := Vector2(lx + 50, panel.position.y + 110)
	draw_circle(badge, 50, Color(0.08, 0.06, 0.12))
	draw_circle(badge, 44, Color(0.95, 0.6, 0.2))
	_text(badge + Vector2(-50, 14), str(level), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 100, 5)
	_text(badge + Vector2(-50, 34), "LEVEL", 9, Color(0.15, 0.08, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 100, 0)
	_text(Vector2(lx + 120, panel.position.y + 92), Stats.rank_title(level).to_upper(), 24, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(Vector2(lx + 120, panel.position.y + 112), "%d XP on your account" % game.account_xp, 11, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var bar := Rect2(lx + 120, panel.position.y + 122, 330, 16)
	_bar(bar, (float(span[0]) / span[1]) if span[1] > 0 else 1.0, Color(0.95, 0.6, 0.2))
	_text(bar.position + Vector2(0, 13), ("%d / %d to level %d" % [span[0], span[1], level + 1]) if span[1] > 0 else "MAX LEVEL", 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 2)
	if game.last_match_gain > 0:
		_text(Vector2(lx + 120, panel.position.y + 156), "Last match: +%d XP" % game.last_match_gain, 11, Color(0.6, 1.0, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	# The rank ladder.
	_text(Vector2(lx, panel.position.y + 196), "RANKS", 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.RANK_TITLES.size():
		var entry: Array = Stats.RANK_TITLES[i]
		var reached: bool = level >= entry[0]
		var b := Rect2(lx + i * 82, panel.position.y + 204, 76, 40)
		_chunky(b, Color(0.95, 0.6, 0.2) if reached else Color(0.25, 0.22, 0.3), level >= entry[0] and (i == Stats.RANK_TITLES.size() - 1 or level < Stats.RANK_TITLES[i + 1][0]))
		_text(b.position + Vector2(0, 17), "LV %d" % entry[0], 9, Color.WHITE if reached else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 2)
		_text(b.position + Vector2(0, 32), entry[1].to_upper(), 8, Color.WHITE if reached else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 2)
	# Unlocks.
	_text(Vector2(lx, panel.position.y + 276), "LEVEL %d UNLOCKS" % Stats.UNLOCK_LEVEL, 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for i in Stats.UNLOCKS.size():
		var u: Array = Stats.UNLOCKS[i]
		var row := Rect2(lx, panel.position.y + 284 + i * 50, panel.size.x - 60, 44)
		var open: bool = game.unlocked()
		_chunky(row, Color(0.2, 0.45, 0.3) if open else Color(0.25, 0.22, 0.3))
		_icon("class_rogue" if u[0] == "class" else ("cape" if u[0] == "look" else "moon"), row.position + Vector2(26, 22), 11, Color.WHITE if open else GREY)
		_text(row.position + Vector2(50, 19), u[1].to_upper(), 13, Color.WHITE if open else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		_text(row.position + Vector2(50, 34), u[2], 9, CREAM if open else GREY, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		_text(row.position + Vector2(0, 27), "UNLOCKED" if open else "LOCKED", 10, Color(0.6, 1.0, 0.6) if open else Color(1.0, 0.7, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 14, 2)


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
		outcome = "VICTORY!" if winner == _my_team() else "DEFEAT"
		color = Color(0.2, 0.5, 0.95) if winner == _my_team() else Color(0.6, 0.15, 0.15)
	_icon("crown", Vector2(cx, 50), 16, GOLD)
	_card("logo_elves", Rect2(cx - 330, 40, 110, 110))
	_card("logo_humans", Rect2(cx + 220, 40, 110, 110))
	_ribbon(Vector2(cx, 108), 420, 64, color)
	_text(Vector2(cx - 210, 122), outcome, 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 420, 6)
	_text(Vector2(cx - 210, 168), "%s %d   -   %d %s" % [Stats.FACTIONS[0].name, game.score[0], game.score[1], Stats.FACTIONS[1].name],
		22, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 420, 4)
	# Match MVP: the highest score on either team.
	var mvp = null
	for u in game.units:
		if mvp == null or game.unit_score(u) > game.unit_score(mvp):
			mvp = u
	if mvp:
		var mvp_line := "MVP  %s  ·  %s %s  ·  %d kills, %d captures, %d score" % [mvp.display_name, Stats.FACTIONS[mvp.team].name,
			mvp.role_name(), mvp.kills, mvp.captures, game.unit_score(mvp)]
		_icon("crown", Vector2(cx - _text_width(mvp_line, 13) / 2.0 - 14, 192), 7, GOLD)
		_text(Vector2(cx - 300, 197), mvp_line, 13, GOLD.lerp(Color.WHITE, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 600, 3)
	# Account progress: what this match added, and the level you are now.
	if not game.demo:
		var strip := Rect2(cx - 330, 208, 660, 30)
		_plate(strip, Color(0.2, 0.14, 0.3, 0.95), Color(0.95, 0.6, 0.2), 8, 2)
		var level: int = game.account_level()
		var span: Array = Stats.account_span(game.account_xp)
		_text(strip.position + Vector2(12, 20), "ACCOUNT LV %d  %s" % [level, Stats.rank_title(level).to_upper()], 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		var bar := Rect2(strip.position + Vector2(230, 9), Vector2(250, 12))
		_bar(bar, (float(span[0]) / span[1]) if span[1] > 0 else 1.0, Color(0.95, 0.6, 0.2))
		_text(bar.position + Vector2(0, 10), ("%d / %d XP" % [span[0], span[1]]) if span[1] > 0 else "MAX", 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 2)
		var gain := "+%d XP" % game.last_match_gain
		if level > game.level_before:
			gain += "   LEVEL UP!"
			if level >= Stats.UNLOCK_LEVEL and game.level_before < Stats.UNLOCK_LEVEL:
				gain += "  Rogue, Shadowborn, Moonlit unlocked"
		_text(strip.position + Vector2(0, 20), gain, 12, Color(0.6, 1.0, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, strip.size.x - 12, 2)
	var table := Rect2(cx - 330, 244, 660, size.y - 244 - 60)
	_plate(table, INK, GOLD, 12, 2)
	_draw_scoreboard_table(Rect2(table.position + Vector2(16, 14), Vector2(table.size.x - 32, table.size.y - 28)))
	_text(Vector2(cx - 210, size.y - 26), "Press R or Enter to play again", 14, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 420, 3)
