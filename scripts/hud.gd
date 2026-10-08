extends Control
## In-match HUD plus the title, pause and rank menus, drawn in code after the
## UI references: the logo top-right, score and timer up top, team rosters with
## portraits down each side (hidden unless asked for), a minimap top-left, the player's portrait,
## hearts, energy, experience and ability slots at the bottom, and the
## chat on the left. Reskin by editing here.

const Stats = preload("res://scripts/stats.gd")
const Guide = preload("res://scripts/guide.gd")
const Monarch = preload("res://scripts/monarch.gd")
const Scoreboard = preload("res://scripts/scoreboard.gd")
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
# The storybook frame (the 2026-10-07 HUD reference): planked wood, a blue-grey
# iron rim with brass corners, leaf sprigs, parchment and rope.
const WOOD := Color(0.42, 0.25, 0.13)
const WOOD_DARK := Color(0.27, 0.15, 0.07)
const IRON := Color(0.42, 0.46, 0.52)
const IRON_DARK := Color(0.2, 0.22, 0.27)
const BRASS := Color(0.86, 0.66, 0.28)
const PARCHMENT := Color(0.93, 0.85, 0.66)
const ROPE := Color(0.66, 0.48, 0.28)
const SPRIG := Color(0.4, 0.68, 0.26)
const LEAF_GREEN := Color(0.36, 0.66, 0.2)

const TABS := ["MAP", "CLASSES", "UPGRADES", "SCOREBOARD", "CONTROLS", "SETTINGS"]

var game
var local_unit = null   # couch play: the local player this HUD belongs to (null = the main player)
var pane := false       # couch play: drawn inside one player's pane
var couch_buttons: Array = []   # title: [rect, "more"|"less"|"mode"]
var font: Font
var bar_font: Font     # round bold face for the top bar (Lilita One, OFL)
var topbar_tex: Texture2D   # the top bar art (tools/make_topbar.py)
var title_font: Font   # chunky cartoon display face for the big banners (Luckiest Guy, Apache 2.0)
var logo: Texture2D
var icons: Dictionary = {}  # kind -> Texture2D, painted icons from tools/make_icons.py
var skill_art: Dictionary = {}   # hexagon skill tiles and shield faces (assets/ui/skills)
var next_slot_art := ""          # set just before _slot(): the skill art to draw for it
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
var touch_rects: Array = []      # [rect, action] for the ability tiles and corner buttons (touch.gd)
var hud_scale := 1.0             # the player panel's shrink factor in narrow panes
var slot_flash: Dictionary = {}  # ability slot -> seconds of ready flash left
var options_button := Rect2()
var close_button := Rect2()
var quit_button := Rect2()     # pause menu: back to the main menu
var difficulty_buttons: Array = []  # [rect, name] on the title screen
var guide_buttons: Array = []       # [rect, "next" | "close" | topic index]
var chat_buttons: Array = []        # [rect, tab index]
var hero_buttons: Array = []        # [rect, "hair" | "trim" | "name", index]
var faction_buttons: Array = []     # [rect, team]
var title_buttons: Array = []       # [rect, tab] on the title screen
var menu_buttons: Array = []        # [rect, id, arg] drawn by the main menu (menu.gd)
var lava_cells: Array = []          # Ember Pass maps: crust plates [centre, polygon, shade] in world x/z


func _ready() -> void:
	font = ThemeDB.fallback_font
	title_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	bar_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	if ResourceLoader.exists("res://assets/ui/topbar/topbar.png"):
		topbar_tex = load("res://assets/ui/topbar/topbar.png")
	if title_font == null:
		title_font = font
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
	# Skill tiles and scoreboard shields cut from Faisal's UI reference
	# (2026-10-08): the hexagon art replaces the drawn tile for the moves it
	# covers.
	for key in ["punch", "dodge", "lock_a", "lock_b", "perks", "drop", "shield_elf", "shield_human"]:
		var path := "res://assets/ui/skills/%s.png" % key
		if ResourceLoader.exists(path):
			skill_art[key] = load(path)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if game:
		var me = _me() if game.playing else null
		if me and me.carrying and not me.dead:
			holding_since = 0.0 if holding_since < 0.0 else holding_since + _delta
		else:
			holding_since = -1.0
		game.menu_tick()
		# The centre hint line (a Label game.gd owns) sits just under the
		# objective banner, clear of the timer plate.
		if not pane and game.message_label:
			if game.message_label.offset_top < 120:
				game.message_label.offset_top = 120
				game.message_label.offset_bottom = 160
			# The fortify call-out repeats the objective banner word for
			# word, so it stays in the chat log only.
			if game.prep_left > 0.0 and game.message_label.text.begins_with("FORTIFY!"):
				game.message_label.text = ""
		_hide_world_prompts()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if game and not pane:  # the panes would feed every key to the chat twice
		game.menu_input(event)
		if game.game_over and game.summary and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_click_end(get_local_mouse_position())


func _click_end(at: Vector2) -> void:
	## The summary's two buttons: scoreboard, and skip / continue.
	var s = game.summary
	if s.board_rect.has_point(at):
		s.show_board = not s.show_board
	elif s.continue_rect.has_point(at):
		if s.done():
			get_tree().reload_current_scene()
		else:
			s.skip()


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
	quit_button = Rect2()
	if not pane:
		touch_rects = []
	difficulty_buttons = []
	guide_buttons = []
	chat_buttons = []
	hero_buttons = []
	faction_buttons = []
	title_buttons = []
	couch_buttons = []
	menu_buttons = []
	if not game.playing and not game.game_over:
		_draw_title()
		if game.menu_open:
			menu_buttons = []   # the pause/settings panel covers the menu: only its buttons count
			hero_buttons = []
			_draw_game_menu()
		_draw_toasts()
		if game.cursor_shown:
			_draw_cursor()
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
	if game.game_over:
		# The summary screen replaces the live HUD (couch panes just clear).
		if not pane:
			_draw_end()
			if game.cursor_shown:
				_draw_cursor()
		return
	_draw_screen_fx()
	if not pane:
		_screen_frame()
	# (No logo during play: Faisal 2026-10-07 21:14.)
	_draw_scoreboard()
	if game.show_fps:
		_text(Vector2(size.x - 134, size.y - 152), "%d FPS" % Engine.get_frames_per_second(), 11, GREY, HORIZONTAL_ALIGNMENT_RIGHT, 120, 2)
	if game.rosters_visible and _me() and not pane:
		_draw_roster(_my_team(), Vector2(14, 130), true)
		_draw_roster(1 - _my_team(), Vector2(size.x - 300, 100), true)
	if not game.guide_open:
		# The minimap sits top-left; the objective card and HOW TO WIN list are
		# gone from the live HUD (the guide and the pause menu still carry them).
		if _narrow():
			_draw_minimap(Vector2(88, 90), 68.0)
		else:
			_draw_minimap(Vector2(124, 124), 100.0)
	_draw_toasts()
	if _me() and not game.guide_open:
		_draw_world_prompt()
		_draw_player_panel(_me())
	if game.killer_timer > 0.0 and _me() and _me().dead and not game.killer_card.is_empty():
		_draw_killer_card()
	if _me() and not _me().kill_banner.is_empty():
		_draw_kill_banner(_me())
	if not game.guide_open and not pane:
		_draw_kill_feed()
	if _me() and _me().carrying and not _me().dead:
		_draw_holding_banner(_me())
	if game.stolen_timer > 0.0 and not (_me() and _me().carrying):   # the carrier sees their own banner
		_draw_stolen_card()
	elif game.capture_timer > 0.0:
		_draw_capture_card()
	elif game.levelup_timer > 0.0:
		_draw_levelup_card()
	if pane:
		if local_unit:
			_text(Vector2(14, 184 if _narrow() else 252), "PLAYER %d" % (local_unit.local_index + 1), 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
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
	for list in [menu_buttons, title_buttons, faction_buttons, hero_buttons, couch_buttons, tab_buttons, bind_buttons,
			difficulty_buttons, toggle_buttons, guide_buttons, chat_buttons, variant_buttons, volume_sliders]:
		for b in list:
			if b[0].size.x > 0.0:
				out.append(b[0])
	for r in rank_buttons:
		if r.size.x > 0.0:
			out.append(r)
	for r in [options_button, close_button, reset_button, quit_button]:
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

func _keycap(center: Vector2, key: String, w: float = 30.0, dark: bool = false) -> void:
	## A cream keycap for keys and mouse buttons (a dark one for locked
	## slots); PlayStation face buttons are drawn as the shapes on the pad,
	## Xbox face buttons as coloured letters on a dark button.
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
	var rect := Rect2(center - Vector2(w / 2.0, 9), Vector2(w, 18))
	if dark:
		_plate(rect, Color(0.14, 0.14, 0.16), Color(0.32, 0.32, 0.36), 4, 1)
		_text(rect.position + Vector2(0, 14), key, 11, Color(0.5, 0.5, 0.54), HORIZONTAL_ALIGNMENT_CENTER, w, 0)
		return
	_plate(rect, CREAM, Color(0.45, 0.33, 0.16), 4, 1)
	_text(rect.position + Vector2(0, 14), key, 11, Color(0.18, 0.12, 0.08), HORIZONTAL_ALIGNMENT_CENTER, w, 0)


func _k(action: String) -> String:
	## The keycap label for this HUD's player: keyboard, or pad names when
	## they hold one.
	return game.key_label(action, local_unit)


func _slot(origin: Vector2, size_px: float, icon: String, color: Color, key: String, label: String,
		remaining: float, total: float, usable: bool, rank: int = 0, active: bool = false, cost: float = 0.0, cost_color: Color = STAMINA,
		glow: bool = false) -> void:
	## One ability slot: a glossy tile in the move's colour (red punch,
	## green dodge, crimson perks, gold crown) in a dark iron frame, its
	## icon on top, the key on a cream plate across the bottom edge and the
	## name underneath. A slot that is not ready darkens; one with no icon is
	## locked: dark grey with a padlock. glow rings it in gold.
	var rect := Rect2(origin, Vector2(size_px, size_px))
	var locked := icon == ""
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
	# Hexagon tiles, like Faisal's UI reference (2026-10-08): a dark outer
	# edge, a thick bronze rim, then the glossy coloured face lit from the top.
	var hc := rect.get_center()
	var hr := size_px * 0.62
	if glow and not locked:
		var gpulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 220.0)
		for i in 5:
			draw_colored_polygon(_hex_pts(hc, hr + 8.0 + i * 3.0), Color(1.0, 0.78, 0.25, 0.07 * gpulse))
	var frame := BRASS
	if glow and not locked:
		frame = GOLD.lightened(0.15)
	elif active:
		frame = Color(0.75, 0.88, 1.0)
	elif locked:
		frame = Color(0.45, 0.36, 0.24)
	var shadow := _hex_pts(hc + Vector2(0, 3), hr + 7.0)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	var art: String = next_slot_art
	next_slot_art = ""
	if art != "" and skill_art.has(art):
		# The painted hexagon (rim and all) from the reference art: its hex
		# fills 90% of the picture's height.
		var th := 2.0 * (hr + 6.0) / 0.9
		var tex: Texture2D = skill_art[art]
		var tw := th * tex.get_width() / tex.get_height()
		draw_texture_rect(tex, Rect2(hc - Vector2(tw, th) / 2.0, Vector2(tw, th)), false,
			Color.WHITE if (ready or locked) else Color(0.55, 0.55, 0.58))
	else:
		_hex_tile(hc, hr, frame, color, locked, ready)
	if art != "" and skill_art.has(art):
		pass   # the painted tile carries its own icon
	elif locked:
		_padlock(rect.get_center() + Vector2(0, -3), size_px * 0.3, Color(0.58, 0.58, 0.62))
	elif not _tile_glyph(icon, rect.get_center() + Vector2(0, -4), size_px * 0.3, not ready):
		_icon(icon, rect.get_center() + Vector2(0, -4), size_px * 0.29, Color.WHITE, not ready)
	if remaining > 0.0:
		var frac := clampf(remaining / maxf(total, 0.01), 0.0, 1.0)
		var top := hc.y - hr
		var cut := PackedVector2Array([Vector2(hc.x - hr * 2.0, top - 2.0), Vector2(hc.x + hr * 2.0, top - 2.0),
			Vector2(hc.x + hr * 2.0, top + 2.0 * hr * frac), Vector2(hc.x - hr * 2.0, top + 2.0 * hr * frac)])
		for poly in Geometry2D.intersect_polygons(_hex_pts(hc, hr - 2.5), cut):
			draw_colored_polygon(poly, Color(0, 0, 0, 0.6))
		_text(rect.position + Vector2(0, size_px * 0.58), ("%.1f" % remaining) if remaining < 10.0 else str(ceili(remaining)),
			16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size_px)
	# The energy cost in the top-left corner, so you can see which moves
	# are cheap bread-and-butter and which ones to spend sparingly.
	if cost > 0.0:
		var tag := Rect2(rect.position + Vector2(2, 2), Vector2(20, 12))
		draw_rect(tag, Color(0, 0, 0, 0.55))
		_text(tag.position + Vector2(0, 10), str(int(cost)), 9, cost_color if usable else cost_color.darkened(0.4), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 0)
	# Rank pips in the top-right corner.
	for i in rank:
		draw_circle(rect.end - Vector2(7 + i * 8, size_px - 7), 2.6, GOLD)
		draw_arc(rect.end - Vector2(7 + i * 8, size_px - 7), 2.6, 0, TAU, 10, Color(0.3, 0.2, 0.05), 1.0)
	_keycap(Vector2(rect.get_center().x, rect.end.y + 4), key, maxf(24.0, _text_width(key, 11) + 10.0), locked)
	if label != "":
		_text(Vector2(rect.position.x - 22, rect.end.y + 31), label, 12, CREAM if ready else Color(0.62, 0.58, 0.52),
			HORIZONTAL_ALIGNMENT_CENTER, size_px + 44, 3)


func _hex_tile(hc: Vector2, hr: float, frame: Color, color: Color, locked: bool, ready: bool) -> void:
	## The drawn hexagon tile for moves with no painted art.
	draw_colored_polygon(_hex_pts(hc, hr + 6.0), Color(0.16, 0.09, 0.03))
	var rim := _hex_pts(hc, hr + 4.0)
	var rim_cols := PackedColorArray()
	for q in rim:
		rim_cols.append(frame.lightened(0.3) if q.y < hc.y else frame.darkened(0.3))
	draw_polygon(rim, rim_cols)
	draw_colored_polygon(_hex_pts(hc, hr), Color(0.1, 0.06, 0.03))
	var tile := color
	if locked:
		tile = color if color != Color.WHITE else Color(0.3, 0.3, 0.34)
		tile = tile.darkened(0.25)
	elif not ready:
		tile = color.darkened(0.32).lerp(Color(0.2, 0.2, 0.22), 0.15)
	var face := _hex_pts(hc, hr - 2.5)
	var face_cols := PackedColorArray()
	for q in face:
		var f := clampf((q.y - (hc.y - hr)) / (2.0 * hr), 0.0, 1.0)
		face_cols.append(tile.lightened(0.28).lerp(tile.darkened(0.35), f))
	draw_polygon(face, face_cols)
	# A soft radial glow in the middle and a glossy cap over the top half.
	if not locked:
		draw_circle(hc + Vector2(0, -2), hr * 0.55, Color(1, 1, 1, 0.12 if ready else 0.04))
	var cap := PackedVector2Array([face[5], face[0], face[1], hc + Vector2(hr * 0.75, -hr * 0.05), hc + Vector2(-hr * 0.75, -hr * 0.05)])
	draw_colored_polygon(cap, Color(1, 1, 1, 0.16 if not locked else 0.06))
	var face_line := face.duplicate()
	face_line.append(face[0])
	draw_polyline(face_line, Color(0, 0, 0, 0.55), 1.2)
	var rim_hi := _hex_pts(hc, hr + 3.0)
	draw_polyline(PackedVector2Array([rim_hi[4], rim_hi[5], rim_hi[0], rim_hi[1]]), Color(1, 0.95, 0.75, 0.6), 1.2)


func _hex_pts(c: Vector2, r: float) -> PackedVector2Array:
	## A pointy-topped hexagon, first corner at the top, clockwise.
	var pts := PackedVector2Array()
	for i in 6:
		var ang := -PI / 2.0 + i * TAU / 6.0
		pts.append(c + Vector2(cos(ang) * r * 0.92, sin(ang) * r))
	return pts


func _tile_glyph(kind: String, c: Vector2, s: float, dim: bool) -> bool:
	## Code-drawn icons for the main slots (fist, dodge, perks heart, crown),
	## bold and outlined to read on their coloured tiles. False for any other
	## kind, so the caller falls back to the painted icon.
	var f := 0.75 if dim else 1.0
	var ink := Color(0.18, 0.03, 0.03)
	match kind:
		"fist":
			var red := Color(0.98, 0.22, 0.2) * Color(f, f, f)
			var palm := Rect2(c + Vector2(-0.62, -0.25) * s, Vector2(1.24, 1.05) * s)
			var sb := StyleBoxFlat.new()
			sb.bg_color = red
			sb.set_corner_radius_all(int(0.3 * s))
			sb.set_border_width_all(2)
			sb.border_color = ink
			draw_style_box(sb, palm.grow(1.5))
			draw_style_box(sb, Rect2(c + Vector2(-0.45, 0.65) * s, Vector2(0.9, 0.35) * s))
			for i in 4:
				var k := c + Vector2(-0.48 + i * 0.32, -0.38) * s
				draw_circle(k, 0.2 * s + 1.5, ink)
				draw_circle(k, 0.2 * s, red.lightened(0.08))
				draw_circle(k + Vector2(-0.05, -0.06) * s, 0.06 * s, Color(1, 1, 1, 0.55 * f))
			draw_line(c + Vector2(-0.55, 0.15) * s, c + Vector2(0.25, 0.15) * s, ink, 2.0)
			draw_line(c + Vector2(0.25, 0.15) * s, c + Vector2(0.35, 0.45) * s, ink, 2.0)
			draw_rect(Rect2(c + Vector2(-0.5, -0.1) * s, Vector2(0.25, 0.5) * s), Color(1, 1, 1, 0.2 * f))
			return true
		"dodge":
			var g := Color(0.75, 1.0, 0.55) * Color(f, f, f)
			for i in 3:
				var x := (-0.75 + i * 0.5) * s
				var pts := PackedVector2Array([c + Vector2(x, -0.62 * s), c + Vector2(x + 0.5 * s, 0), c + Vector2(x, 0.62 * s)])
				draw_polyline(pts, Color(0.05, 0.25, 0.05), 0.34 * s)
				draw_polyline(pts, g, 0.2 * s)
			return true
		"vigor":
			var hc := Color(0.98, 0.18, 0.25) * Color(f, f, f)
			var pts := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32.0
				pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * s / 15.0)
			var rim := PackedVector2Array()
			for q in pts:
				rim.append(c + (q - c) * 1.12)
			draw_colored_polygon(rim, Color(1, 0.92, 0.9) * Color(f, f, f))
			draw_colored_polygon(pts, hc)
			rim.append(rim[0])
			draw_polyline(rim, ink, 1.5)
			draw_circle(c + Vector2(-0.45, -0.4) * s, 0.16 * s, Color(1, 1, 1, 0.5 * f))
			draw_polyline(PackedVector2Array([c + Vector2(-0.95, 0.05) * s, c + Vector2(-0.35, 0.05) * s, c + Vector2(-0.18, -0.35) * s,
				c + Vector2(0.08, 0.45) * s, c + Vector2(0.28, 0.05) * s, c + Vector2(0.95, 0.05) * s]), Color(1, 1, 1, 0.95 * f), maxf(1.6, 0.13 * s))
			return true
		"crown":
			_crown_glyph(c + Vector2(0, 0.15 * s), s * 0.95, 0.0, 0.65 if dim else 1.0)
			return true
	return false


func _banner_ribbon(rect: Rect2, color: Color, notch_left: bool) -> void:
	## A cloth banner: the main band with gold trim and, at the outer end,
	## a swallow-tailed fold dropping behind it.
	var r := rect
	var dir := -1.0 if notch_left else 1.0
	var outer_x := r.position.x if notch_left else r.end.x
	# The tail behind: a darker strip leaving the outer end, lower down.
	var tail := 44.0
	var ty := r.position.y + 9.0
	var th := r.size.y - 4.0
	var tx0 := outer_x - dir * 16.0
	var tx1 := outer_x + dir * tail
	var tail_pts := PackedVector2Array([Vector2(tx0, ty), Vector2(tx1, ty + 4.0), Vector2(tx1 - dir * 14.0, ty + th * 0.55),
		Vector2(tx1, ty + th + 2.0), Vector2(tx0, ty + th)])
	draw_colored_polygon(tail_pts, color.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(tx0, ty), Vector2(tx1, ty + 4.0), Vector2(tx1 - dir * 7.0, ty + th * 0.28), Vector2(tx0, ty + th * 0.3)]), Color(1, 1, 1, 0.07))
	tail_pts.append(tail_pts[0])
	draw_polyline(tail_pts, color.darkened(0.7), 2.0)
	# The fold where the band turns under.
	draw_colored_polygon(PackedVector2Array([Vector2(outer_x, r.end.y), Vector2(outer_x + dir * 14.0, ty + th),
		Vector2(outer_x + dir * 14.0, r.end.y - 6.0)]), color.darkened(0.6))
	# The band.
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(pts, color)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, r.size.y * 0.4)), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - r.size.y * 0.25), Vector2(r.size.x, r.size.y * 0.25 - 2)), Color(0, 0, 0, 0.14))
	for y in [r.position.y + 4.0, r.end.y - 4.0]:
		draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), BRASS, 2.5)
		draw_line(Vector2(r.position.x + 2, y - 1.0), Vector2(r.end.x - 2, y - 1.0), GOLD.lightened(0.3), 0.8)
	pts.append(pts[0])
	draw_polyline(pts, color.darkened(0.7), 2.5)


func _laurel(c: Vector2, side: float, scale: float, rx: float = 50.0, ry: float = 30.0) -> void:
	## A green laurel branch on a gold stem curling up one side of the clock
	## from below.
	var stem := PackedVector2Array()
	for i in 13:
		var a := deg_to_rad(lerpf(110.0, 218.0, i / 12.0))
		stem.append(c + Vector2(-side * cos(a) * rx, sin(a) * ry))
	draw_polyline(stem, Color(0.45, 0.3, 0.06), 3.0 * scale)
	draw_polyline(stem, BRASS, 1.6 * scale)
	for k in 8:
		var t := 0.06 + k * 0.125
		var a := deg_to_rad(lerpf(110.0, 218.0, t))
		var p := c + Vector2(-side * cos(a) * rx, sin(a) * ry)
		var tang := Vector2(side * sin(a) * rx, cos(a) * ry).normalized()
		var out := Vector2(-side * cos(a), sin(a) * 0.6).normalized()
		for s: float in [1.0, -1.0]:
			var dir := (tang + out * s * 0.85).normalized()
			var ln := (10.0 + k * 0.9) * scale * (1.0 if s > 0.0 else 0.8)
			var tip := p + dir * ln
			var sd := Vector2(-dir.y, dir.x) * ln * 0.3
			var pts := PackedVector2Array([p, (p + tip) / 2.0 + sd, tip, (p + tip) / 2.0 - sd])
			draw_colored_polygon(pts, LEAF_GREEN if s > 0.0 else LEAF_GREEN.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([p, (p + tip) / 2.0 + sd, tip]), LEAF_GREEN.lightened(0.3))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.1, 0.25, 0.06), 1.1)


func _draw_minimap(c: Vector2, r: float) -> void:
	## The minimap as a round painted chart of the valley in an engraved
	## gold and bronze ring: an "N" on a small gold cartouche at the top, gem
	## studs at the sides and foot, and the home-defence tag hung across the
	## bottom.
	# The chart: a painted top-down valley filling the whole round window.
	var rw := maxf(r * 0.12, 9.0)
	var ri := r - 3.0
	var ro := r + rw
	var rm := (ri + ro) / 2.0
	var band := ro - ri
	draw_circle(c + Vector2(0, 4), ro + 3, Color(0, 0, 0, 0.4))
	_minimap_field(c, r)
	# Ring: dark bronze band between bright gold rims, lit from the top left,
	# with a beaded line of rivets round the middle.
	draw_arc(c, rm, 0, TAU, 128, Color(0.25, 0.15, 0.05), band + 4.0)
	draw_arc(c, rm, 0, TAU, 128, Color(0.55, 0.37, 0.14), band)
	draw_arc(c, rm, PI * 0.95, PI * 1.75, 64, Color(1, 0.88, 0.55, 0.28), band * 0.85)
	draw_arc(c, rm, PI * 0.05, PI * 0.8, 64, Color(0, 0, 0, 0.18), band * 0.85)
	draw_arc(c, ro - 1.5, 0, TAU, 128, BRASS, 3.0)
	draw_arc(c, ro - 2.2, PI * 1.0, PI * 1.8, 48, GOLD.lightened(0.35), 1.2)
	draw_arc(c, ri + 1.5, 0, TAU, 128, BRASS.darkened(0.1), 2.6)
	draw_arc(c, ri + 1.0, PI * 0.1, PI * 0.9, 48, GOLD.lightened(0.2), 1.0)
	draw_arc(c, ro + 0.6, 0, TAU, 128, Color(0.2, 0.11, 0.03), 1.6)
	draw_arc(c, ri - 0.6, 0, TAU, 128, Color(0.2, 0.11, 0.03), 1.6)
	var beads := int(TAU * rm / 9.0)
	for i in beads:
		var a := TAU * i / beads
		var q := c + Vector2(cos(a), sin(a)) * rm
		draw_circle(q, 1.6, Color(0.3, 0.18, 0.06))
		draw_circle(q - Vector2(0.4, 0.4), 1.0, Color(1, 0.85, 0.5, 0.8))
	# Gem studs on the left, right and bottom of the ring.
	var team_gems := [Color(0.35, 0.9, 0.42), Color(0.38, 0.62, 1.0), Color(0.95, 0.28, 0.25)]
	var dirs := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
	for i in 3:
		var d: Vector2 = dirs[i]
		var g := c + d * rm
		var t := Vector2(-d.y, d.x)
		var s := band * 0.95
		var mount := PackedVector2Array([g + d * s * 1.25, g + t * s * 0.8, g - d * s * 0.9, g - t * s * 0.8])
		var sh := PackedVector2Array()
		for q in mount:
			sh.append(q + Vector2(0, 2))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.4))
		draw_colored_polygon(mount, BRASS)
		mount.append(mount[0])
		draw_polyline(mount, Color(0.3, 0.17, 0.04), 1.4)
		# A faceted diamond-cut gem: dark rim, lit upper facets, a glint.
		var gc: Color = team_gems[i]
		var gem := PackedVector2Array([g + d * s * 0.85, g + t * s * 0.55, g - d * s * 0.6, g - t * s * 0.55])
		draw_colored_polygon(gem, gc.darkened(0.25))
		var up := Vector2(0, -1)
		for j in 4:
			var q0: Vector2 = gem[j]
			var q1: Vector2 = gem[(j + 1) % 4]
			var mid := (q0 + q1) / 2.0 - g
			var lit := mid.normalized().dot(up)
			draw_colored_polygon(PackedVector2Array([q0, q1, g + (q0 + q1 - 2.0 * g) * 0.18]),
				gc.lightened(0.35) if lit > 0.1 else (gc if lit > -0.1 else gc.darkened(0.4)))
		draw_colored_polygon(PackedVector2Array([g + d * s * 0.3, g + t * s * 0.2, g - d * s * 0.2, g - t * s * 0.2]), gc.lightened(0.15))
		gem.append(gem[0])
		draw_polyline(gem, gc.darkened(0.7), 1.2)
		draw_circle(g + Vector2(-0.12, -0.2) * s, s * 0.09, Color(1, 1, 1, 0.85))
	# The "N" cartouche at the top.
	var nc := c + Vector2(0, -rm)
	var cw := maxf(band * 1.5, 15.0)
	var ch := maxf(band * 1.45, 15.0)
	var cart := PackedVector2Array([nc + Vector2(0, -ch * 0.78), nc + Vector2(cw * 0.5, -ch * 0.5), nc + Vector2(cw * 0.62, 0),
		nc + Vector2(cw * 0.5, ch * 0.5), nc + Vector2(0, ch * 0.72), nc + Vector2(-cw * 0.5, ch * 0.5), nc + Vector2(-cw * 0.62, 0),
		nc + Vector2(-cw * 0.5, -ch * 0.5)])
	var csh := PackedVector2Array()
	var crim := PackedVector2Array()
	for q in cart:
		csh.append(q + Vector2(0, 2))
		crim.append(nc + (q - nc) * 1.18)
	draw_colored_polygon(csh, Color(0, 0, 0, 0.45))
	draw_colored_polygon(crim, BRASS)
	draw_colored_polygon(cart, Color(0.16, 0.12, 0.08))
	crim.append(crim[0])
	draw_polyline(crim, Color(0.3, 0.17, 0.04), 1.4)
	cart.append(cart[0])
	draw_polyline(cart, GOLD.lightened(0.2), 1.0)
	var nfs := int(clampf(band * 1.15, 10.0, 15.0))
	_text(Vector2(nc.x - 12, nc.y + nfs * 0.38), "N", nfs, Color(1.0, 0.88, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 24, 2)
	var me = _me()
	if me and me.home_defense and not me.dead:
		var tw := minf(r * 1.6, 170.0)
		_home_pill(Rect2(Vector2(c.x - tw / 2.0, c.y + r - 12), Vector2(tw, 26)), me.team)


func _mm_poly(poly: PackedVector2Array, clip: PackedVector2Array, col: Color, edge: Color = Color(0, 0, 0, 0), ew: float = 1.0) -> void:
	## Fills (and optionally outlines) a polygon trimmed to the minimap circle.
	for piece in Geometry2D.intersect_polygons(poly, clip):
		if piece.size() < 3:
			continue
		draw_colored_polygon(piece, col)
		if edge.a > 0.0:
			var loop: PackedVector2Array = piece.duplicate()
			loop.append(piece[0])
			draw_polyline(loop, edge, ew)


func _mm_rect(rect: Rect2, clip: PackedVector2Array, col: Color, edge: Color = Color(0, 0, 0, 0), ew: float = 1.0) -> void:
	_mm_poly(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), clip, col, edge, ew)


func _mm_line(a: Vector2, b: Vector2, c: Vector2, rad: float, col: Color, w: float) -> void:
	## A line segment trimmed to the circle (c, rad).
	var d := b - a
	var f := a - c
	var qa := d.dot(d)
	if qa < 0.0001:
		return
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - rad * rad
	var disc := qb * qb - 4.0 * qa * qc
	if disc <= 0.0:
		return
	var sq := sqrt(disc)
	var t0 := maxf(0.0, (-qb - sq) / (2.0 * qa))
	var t1 := minf(1.0, (-qb + sq) / (2.0 * qa))
	if t0 >= t1:
		return
	draw_line(a + d * t0, a + d * t1, col, w)


func _minimap_field(c: Vector2, r: float) -> void:
	## The valley painted from above and clipped to the minimap circle: deep
	## forest round the edge, lighter meadow over the battlefield, tan roads,
	## the bright river and its bridges, the shrine ring, both castles as team
	## blocks with their crowns, potions, turrets and everyone the team can see.
	## The map is stretched a little north-south so the field fills the window.
	var hx: float = game.map_half.x
	var hz: float = game.map_half.y
	var sx := r / (hx - 6.0)
	var sz := sx * 1.6
	var m := func(p: Vector3) -> Vector2:
		return c + Vector2(p.x * sx, p.z * sz)
	var clip := PackedVector2Array()
	for i in 56:
		var a := TAU * i / 56.0
		clip.append(c + Vector2(cos(a), sin(a)) * r)
	var pt := Time.get_ticks_msec() / 1000.0
	var fx: float = game.CASTLE_X - game.CASTLE_DEPTH
	if game.vmap:
		_volcano_field(c, r, m, clip, sx, sz, pt)
	else:
		# Ground: deep forest green, the open field a lighter meadow.
		draw_circle(c, r, Color(0.2, 0.38, 0.15))
		var field := Rect2(c - Vector2(hx * sx, hz * sz), Vector2(hx * sx, hz * sz) * 2.0)
		_mm_rect(field, clip, Color(0.36, 0.6, 0.24))
		# Woodland blobs filling the ground outside the field.
		for i in 150:
			var a := fmod(i * 2.39996, TAU)
			var d := r * sqrt((i + 0.5) / 150.0)
			var q := c + Vector2(cos(a), sin(a)) * d
			if field.grow(-2.0).has_point(q) or d > r - 2.0:
				continue
			var tr := r * (0.045 + 0.025 * fmod(i * 0.618034, 1.0))
			draw_circle(q + Vector2(1, 1.5), tr, Color(0.08, 0.17, 0.06, 0.6))
			draw_circle(q, tr, Color(0.17, 0.4, 0.14) if i % 3 else Color(0.25, 0.48, 0.17))
			draw_circle(q - Vector2(tr, tr) * 0.3, tr * 0.45, Color(0.4, 0.62, 0.25, 0.6))
		# Sunlit patches on the meadow.
		for i in 14:
			var a := fmod(i * 2.39996 + 0.7, TAU)
			var d := r * 0.75 * sqrt((i + 0.5) / 14.0)
			var q := c + Vector2(cos(a), sin(a) * 0.6) * d
			if field.has_point(q):
				draw_circle(q, r * (0.07 + 0.03 * fmod(i * 0.618, 1.0)), Color(0.55, 0.78, 0.33, 0.28))
		# Trees on the field.
		for t in game.map_trees:
			var q: Vector2 = m.call(t)
			var tr: float = (2.6 if t.y > 0.5 else 1.9) * sx * 1.25
			if (q - c).length() > r - tr * 0.5:
				continue
			draw_circle(q + Vector2(0.8, 1.2), tr, Color(0.06, 0.14, 0.05, 0.55))
			draw_circle(q, tr, Color(0.16, 0.42, 0.14) if t.y > 0.5 else Color(0.22, 0.5, 0.17))
			draw_circle(q - Vector2(tr, tr) * 0.3, tr * 0.42, Color(0.42, 0.68, 0.28, 0.7))
		# Roads and tracks: a dark edge under tan dirt.
		var road := Color(0.8, 0.66, 0.43)
		for p in game.map_paths:
			var w: float = maxf(p[2] * sx * 1.1, 2.4)
			_mm_line(m.call(p[0]), m.call(p[1]), c, r, Color(0.42, 0.3, 0.16, 0.85), w + 2.0)
		for p in game.map_paths:
			var w: float = maxf(p[2] * sx * 1.1, 2.4)
			var a: Vector2 = m.call(p[0])
			var b: Vector2 = m.call(p[1])
			_mm_line(a, b, c, r, road, w)
			if (a - c).length() < r:
				draw_circle(a, w / 2.0, road)
			if (b - c).length() < r:
				draw_circle(b, w / 2.0, road)
		# Ruins, barrows and mills.
		for mark in game.map_marks:
			var q: Vector2 = m.call(mark[0])
			if (q - c).length() > r - 4.0:
				continue
			if mark[1] == "ruin":
				var rr := Rect2(q - Vector2(3.5 * sx, 2.5 * sz), Vector2(7 * sx, 5 * sz))
				draw_rect(rr.grow(1.0), Color(0.3, 0.3, 0.3, 0.6))
				draw_rect(rr, Color(0.7, 0.68, 0.64))
				draw_rect(rr.grow(-rr.size.x * 0.25), Color(0.55, 0.53, 0.5))
			elif mark[1] == "barrow":
				draw_circle(q, 3.2 * sx, Color(0.42, 0.45, 0.4))
				draw_circle(q, 1.6 * sx, Color(0.25, 0.26, 0.25))
			elif mark[1] == "mill":
				draw_rect(Rect2(q - Vector2(2.0, 2.0) * sx, Vector2(4, 4) * sx), Color(0.62, 0.46, 0.3))
				draw_arc(q + Vector2(-signf(mark[0].x) * 2.6 * sx, 0), 1.8 * sx, 0, TAU, 8, Color(0.35, 0.25, 0.15), 1.0)
		# The river (drawn a little wider than life so it reads), then bridges.
		var rh: float = maxf(game.RIVER_HALF * sx * 1.7, r * 0.055)
		_mm_rect(Rect2(c.x - rh - 2.0, c.y - r, 2.0 * rh + 4.0, 2.0 * r), clip, Color(0.62, 0.55, 0.36))
		_mm_rect(Rect2(c.x - rh, c.y - r, 2.0 * rh, 2.0 * r), clip, Color(0.13, 0.45, 0.95))
		_mm_rect(Rect2(c.x - rh * 0.35, c.y - r, rh * 0.7, 2.0 * r), clip, Color(0.4, 0.72, 1.0, 0.55))
		for i in game.BRIDGES.size():
			if i == 1:
				continue
			var bz: float = game.BRIDGES[i]
			var half: float = game.BRIDGE_HALF[i]
			var bq: Vector2 = m.call(Vector3(0, 0, bz))
			var br := Rect2(bq.x - rh - 3.0, bq.y - half * sz, 2.0 * rh + 6.0, 2.0 * half * sz)
			_mm_rect(br, clip, Color(0.6, 0.4, 0.22), Color(0.28, 0.16, 0.07), 1.2)
			for k in 3:
				var ly := br.position.y + br.size.y * (k + 1) / 4.0
				draw_line(Vector2(br.position.x + 1, ly), Vector2(br.end.x - 1, ly), Color(0.35, 0.2, 0.09, 0.6), 1.0)
		# The Crown Shrine: a gold ring round a glowing green heart.
		var sr: float = maxf(game.ISLAND_R * sx * 1.15, 7.0)
		draw_circle(c + Vector2(0, 1.5), sr + 2.5, Color(0, 0, 0, 0.35))
		draw_circle(c, sr + 2.0, Color(0.38, 0.27, 0.06))
		draw_circle(c, sr, GOLD)
		draw_circle(c, sr * 0.72, Color(0.65, 0.45, 0.1))
		draw_circle(c, sr * 0.6, Color(0.2, 0.62, 0.22))
		draw_circle(c, sr * 0.38, Color(0.45, 0.95, 0.4, 0.75 + 0.2 * sin(pt * 3.0)))
		for k in 8:
			var a := TAU * k / 8.0
			draw_circle(c + Vector2(cos(a), sin(a)) * sr * 0.86, maxf(sr * 0.1, 0.9), Color(1, 0.95, 0.65))
	# The castles: team-colour blocks, crown on the throne, door gold or red.
	for t in 2:
		var side := -1.0 if t == 0 else 1.0
		var tc := _team_color(t)
		var ox: float = side * fx
		var bx: float = side * (game.CASTLE_X + game.CASTLE_DEPTH)
		var cx: float = bx + side * game.CELLAR_DEPTH
		var cel_a: Vector2 = m.call(Vector3(minf(bx, cx), 0, -game.CELLAR_HALF_Z))
		var cel_b: Vector2 = m.call(Vector3(maxf(bx, cx), 0, game.CELLAR_HALF_Z))
		_mm_rect(Rect2(cel_a, cel_b - cel_a), clip, tc.darkened(0.65), tc.darkened(0.2), 1.0)
		var oa: Vector2 = m.call(Vector3(minf(ox, bx), 0, -game.CASTLE_HALF_Z))
		var ob: Vector2 = m.call(Vector3(maxf(ox, bx), 0, game.CASTLE_HALF_Z))
		var outer := Rect2(oa, ob - oa)
		_mm_rect(outer.grow(2.0), clip, Color(0.12, 0.12, 0.14, 0.9))
		_mm_rect(outer, clip, tc.darkened(0.1), tc.lightened(0.45), 1.5)
		_mm_rect(outer.grow(-outer.size.x * 0.16), clip, tc.lightened(0.12), tc.darkened(0.35), 1.0)
		var gate = game.gates[t]
		var door_color: Color = RED if gate.broken else GOLD
		_mm_line(m.call(Vector3(ox, 0, -Stats.DOOR_HALF)), m.call(Vector3(ox, 0, Stats.DOOR_HALF)), c, r, door_color, 3.0)
		var th: Vector2 = m.call(game.thrones[t])
		if (th - c).length() < r - 4.0:
			var cs := clampf(r / 180.0, 0.38, 0.62)
			_crown(th + Vector2(0.6, 1.0), cs, Color(0.25, 0.15, 0.02, 0.6))
			_crown(th, cs, GOLD)
	# Potions that are up: small pink-red markers.
	for orb in game.heal_orbs:
		if orb.active:
			var q: Vector2 = m.call(orb.global_position)
			if (q - c).length() < r - 3.0:
				_map_pin("potion", q, 4.2, Color(0.95, 0.4, 0.45))
	for b in game.blessings:
		if is_instance_valid(b):
			var bc: Vector2 = m.call(b.global_position)
			if (bc - c).length() < r - 3.0:
				draw_circle(bc, 6.0, Color(1.0, 0.9, 0.5, 0.35 + 0.25 * sin(pt * 6.0)))
				_icon("xp", bc, 4.0, GOLD)
	var my_team: int = _my_team()
	for tu in game.turrets:
		var tq: Vector2 = m.call(tu.global_position)
		if (tq - c).length() > r - 3.0:
			continue
		_map_pin("turret", tq, 4.2, _team_color(tu.team))
	# Everyone we can see. Enemies show within 22 m of a living teammate;
	# Elite Veterans and crown carriers always show. The player's own arrow
	# sticks to the rim when they are off the edge of the chart.
	var allies: Array = game.units.filter(func(u): return u.team == my_team and not u.dead)
	for u in game.units:
		if u.dead:
			continue
		var q: Vector2 = m.call(u.global_position)
		var enemy: bool = u.team != my_team
		if enemy and u.veteran < 2 and u.carrying == null:
			var seen := false
			for a in allies:
				if game._flat_dist(a.global_position, u.global_position) < 22.0:
					seen = true
					break
			if not seen:
				continue
		var ur := 3.0
		if (q - c).length() > r - ur - 2.0:
			if not u.is_player:
				continue
			q = c + (q - c).normalized() * (r - ur - 4.0)
		if u.is_player:
			# Each local player's arrow in their own colour; a couch partner
			# also gets a pulsing ring and their number (Faisal 2026-10-07 21:14).
			var pc: Color = game.player_color(u.local_index)
			var d := Vector2(u.facing.x, u.facing.z * 1.6).normalized()
			var n := Vector2(-d.y, d.x)
			var tip := q + d * (ur + 7.0)
			draw_colored_polygon(PackedVector2Array([tip, q + n * (ur + 2.5), q - n * (ur + 2.5)]), pc)
			draw_circle(q, ur + 2.5, pc)
			draw_arc(q, ur + 2.5, 0, TAU, 14, Color(0.3, 0.2, 0.0, 0.8), 1.0)
			if u != _me():
				draw_arc(q, ur + 6.0 + 1.5 * sin(pt * 4.0), 0, TAU, 20, pc, 2.0)
				_text(q + Vector2(-20, -ur - 22), "P%d" % (u.local_index + 1), 12, pc, HORIZONTAL_ALIGNMENT_CENTER, 40, 3)
		if u.veteran >= 2:
			draw_arc(q, ur + 3.0 + 1.5 * sin(pt * 5.0), 0, TAU, 16, Color(1, 0.3, 0.2) if enemy else GOLD, 2.0)
		elif u.veteran == 1:
			draw_arc(q, ur + 2.0, 0, TAU, 12, Color(0.95, 0.75, 0.3), 1.5)
		draw_circle(q, ur, Color(1.0, 0.25, 0.2) if enemy else Color(0.3, 1.0, 0.45))
		draw_arc(q, ur, 0, TAU, 12, Color(0, 0, 0, 0.65), 1.0)
		if u.carrying:
			_crown(q + Vector2(0, -ur - 4), 0.35)
	# A soft shadow round the inside of the ring.
	draw_arc(c, r - 3.0, 0, TAU, 72, Color(0, 0, 0, 0.22), 6.0)


func _volcano_field(c: Vector2, r: float, m: Callable, clip: PackedVector2Array, sx: float, sz: float, pt: float) -> void:
	## Ember Pass painted from above (after Faisal's concept): molten lava
	## breathing between black crust plates, charred plateaus under the
	## castles, causeways and plank bridges with their shadows on the lava,
	## the plazas' markers and the Fire Objective's flame.
	draw_circle(c, r, _lava_glow(pt))
	var o: Vector2 = m.call(Vector3.ZERO)
	var ax: Vector2 = m.call(Vector3(1, 0, 0)) - o
	var az: Vector2 = m.call(Vector3(0, 0, 1)) - o
	_draw_lava_plates(o, ax, az, func(q: Vector2) -> bool: return (q - c).length() < r - 1.0, PackedVector2Array(), pt)
	_volcano_network(c, r, m, clip, sx, pt, false)


func _lava_glow(pt: float) -> Color:
	## The molten colour under the crust, breathing slowly.
	return Color(0.42, 0.03, 0.02).lerp(Color(0.66, 0.08, 0.03), 0.35 + 0.25 * sin(pt * 1.3))


func _lava_plates() -> Array:
	## The lava's crust as irregular plates tiling the whole sea, in world x/z,
	## made once: a jittered grid whose cells (some split in two) share their
	## corners, each shrunk a little so a thin molten crack shows round it.
	if not lava_cells.is_empty() or game.vmap == null:
		return lava_cells
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var step := 6.5
	var nx := 40
	var nz := 22
	var x0 := -nx * step / 2.0
	var z0 := -nz * step / 2.0
	var grid := []
	for i in nx + 1:
		var col := []
		for j in nz + 1:
			col.append(Vector2(x0 + i * step + r.randf_range(-2.2, 2.2), z0 + j * step + r.randf_range(-2.2, 2.2)))
		grid.append(col)
	for i in nx:
		for j in nz:
			var q := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			var cells: Array = [q]
			var roll := r.randf()
			if roll < 0.3:
				cells = [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
			elif roll < 0.6:
				cells = [[q[0], q[1], q[3]], [q[1], q[2], q[3]]]
			for cl in cells:
				var cc := Vector2.ZERO
				for v in cl:
					cc += v
				cc /= cl.size()
				if game.vmap.walkable(Vector3(cc.x, 0, cc.y), -1.0):
					continue
				# One plate in sixteen has melted away: an open pool.
				if r.randf() < 0.06:
					continue
				var pts := PackedVector2Array()
				for v in cl:
					pts.append(cc + (v - cc) * 0.9)
				lava_cells.append([cc, pts, r.randf()])
	return lava_cells


func _draw_lava_plates(o: Vector2, ax: Vector2, az: Vector2, keep: Callable, box: PackedVector2Array, pt: float) -> void:
	## The crust plates mapped through o + ax*x + az*z, each with an ember rim;
	## with a box, plates crossing its edge are trimmed to it.
	for cell in _lava_plates():
		var cc: Vector2 = cell[0]
		if not keep.call(o + ax * cc.x + az * cc.y):
			continue
		var poly := PackedVector2Array()
		for v in cell[1]:
			poly.append(o + ax * v.x + az * v.y)
		var shade: float = cell[2]
		var col := Color(0.09, 0.025, 0.03).lerp(Color(0.24, 0.06, 0.045), shade * 0.7)
		var pieces: Array = [poly]
		if not box.is_empty():
			for pv in poly:
				if not Geometry2D.is_point_in_polygon(pv, box):
					pieces = Geometry2D.intersect_polygons(poly, box)
					break
		for piece in pieces:
			if piece.size() < 3:
				continue
			draw_colored_polygon(piece, col)
			var loop: PackedVector2Array = piece.duplicate()
			loop.append(piece[0])
			draw_polyline(loop, Color(0.85, 0.12, 0.03, 0.3 + 0.12 * sin(pt * 1.3 + shade * 6.0)), 1.0)
		# A glint of heat on some plates.
		if shade > 0.86:
			draw_circle(o + ax * cc.x + az * cc.y, maxf(ax.length() * 0.6, 1.0), Color(0.8, 0.14, 0.04, 0.45))


func _volcano_network(c: Vector2, r: float, m: Callable, clip: PackedVector2Array, sx: float, pt: float, detailed: bool = false) -> void:
	var v = game.vmap
	var rock := Color(0.27, 0.2, 0.2)
	var stone := Color(0.58, 0.5, 0.47)
	var plank := Color(0.56, 0.35, 0.2)
	var shadow := Color(0.06, 0.01, 0.01, 0.7)
	var glow := Color(0.75, 0.08, 0.03, 0.55)
	var drop := Vector2(1.2, 2.2) * (1.8 if detailed else 1.0)
	var inside := func(q: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(q, clip)
	# The castle plateaus: shadow on the lava, a hot rim, charred rock, speckles.
	for t in 2:
		var sd := -1.0 if t == 0 else 1.0
		var pa: Vector2 = m.call(Vector3(sd * v.LAND_X, 0, -v.LAND_Z))
		var pb: Vector2 = m.call(Vector3(sd * v.LAND_X1, 0, v.LAND_Z))
		var pr := Rect2(Vector2(minf(pa.x, pb.x), pa.y), Vector2(absf(pb.x - pa.x), pb.y - pa.y))
		_mm_rect(Rect2(pr.position + drop, pr.size), clip, shadow)
		_mm_rect(pr.grow(2.0), clip, glow)
		_mm_rect(pr, clip, rock, Color(0.08, 0.03, 0.03), 1.2)
		for k in (60 if detailed else 24):
			var q := pr.position + Vector2(fmod(k * 0.618034, 1.0), fmod(k * 0.381966 + 0.21, 1.0)) * pr.size
			if inside.call(q):
				draw_circle(q, (2.2 if detailed else 1.2) * (0.6 + fmod(k * 0.7548, 1.0)), rock.darkened(0.3) if k % 2 else rock.lightened(0.1))
		# Lit top edge, clipped to the map's frame (the plateau runs past it).
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y)]), clip):
			draw_polyline(seg, rock.lightened(0.35), 1.0)
		if t == 0:
			# The Elves' pines on their side.
			for k in 7:
				var tq: Vector2 = m.call(Vector3(-v.LAND_X - 1.5 - k * 7.3, 0, (v.LAND_Z - 1.2) * (1.0 if k % 2 else -1.0)))
				if inside.call(tq):
					var ts := 2.6 if not detailed else 4.5
					draw_circle(tq + Vector2(0.8, 1.2), ts, Color(0, 0, 0, 0.3))
					draw_circle(tq, ts, Color(0.16, 0.38, 0.15))
					draw_circle(tq - Vector2(ts, ts) * 0.25, ts * 0.45, Color(0.3, 0.55, 0.25))
	# Corridors: their shadow on the lava, a dark edge, then planks or stone.
	for sg in v.segs:
		var a: Vector2 = m.call(v.pos[sg[0]])
		var b: Vector2 = m.call(v.pos[sg[1]])
		var w: float = maxf(sg[2] * 2.0 * sx * 1.25, 3.0)
		_mm_line(a + drop, b + drop, c, r, shadow, w + 2.0)
		_mm_line(a, b, c, r, glow, w + 4.0)
		_mm_line(a, b, c, r, Color(0.1, 0.04, 0.03), w + 2.0)
	for sg in v.segs:
		var a: Vector2 = m.call(v.pos[sg[0]])
		var b: Vector2 = m.call(v.pos[sg[1]])
		var w: float = maxf(sg[2] * 2.0 * sx * 1.25, 3.0)
		var d := b - a
		var perp := Vector2(-d.y, d.x).normalized()
		_mm_line(a, b, c, r, plank if sg[3] == "bridge" else stone, w)
		if sg[3] == "bridge":
			# Planks across, a rope rail down each side.
			var n := int(d.length() / (2.2 if detailed else 3.5))
			for k in range(1, n):
				var q := a + d * (float(k) / n)
				_mm_line(q - perp * w * 0.5, q + perp * w * 0.5, c, r, Color(0.3, 0.18, 0.08, 0.75), 1.0)
			for sd2 in [-1.0, 1.0]:
				_mm_line(a + perp * w * 0.5 * sd2, b + perp * w * 0.5 * sd2, c, r, Color(0.25, 0.14, 0.06), 1.2)
		else:
			# Flagstone joints (causeways), steps (the stair).
			var n2 := int(d.length() / (3.0 if sg[3] == "stairs" else 5.0))
			for k in range(1, n2):
				var q := a + d * (float(k) / n2)
				_mm_line(q - perp * w * 0.5, q + perp * w * 0.5, c, r, stone.darkened(0.3 if sg[3] == "stairs" else 0.15), 1.0)
			_mm_line(a + perp * w * 0.5, b + perp * w * 0.5, c, r, stone.lightened(0.2), 1.0)
	# Plazas: shadow, hot rim, paving with a ring.
	for i in v.pos.size():
		if v.castle_of(v.pos[i]) >= 0:
			continue
		var q: Vector2 = m.call(v.pos[i])
		var pr2: float = v.rad[i] * sx * 1.2
		draw_circle(q + drop, pr2 + 1.0, shadow)
		draw_circle(q, pr2 + 2.5, glow)
		draw_circle(q, pr2 + 1.2, Color(0.1, 0.04, 0.03))
		draw_circle(q, pr2, stone)
		draw_arc(q, pr2 * 0.72, 0, TAU, 28, stone.darkened(0.22), 1.0)
		draw_arc(q, pr2 - 1.0, PI * 1.05, PI * 1.85, 16, stone.lightened(0.25), 1.0)
	if detailed:
		# The demonic dressing: spike clusters, rune obelisks, the beasts' bones.
		for sp in v.deco_spikes:
			var q: Vector2 = m.call(sp[0])
			if not inside.call(q):
				continue
			var aw: Vector3 = sp[1]
			var dv := Vector2(aw.x, aw.z).normalized() * 4.0
			var pv := Vector2(-dv.y, dv.x) * 0.35
			draw_colored_polygon(PackedVector2Array([q + dv, q + pv, q - pv]), Color(0.04, 0.02, 0.03))
		for ob in v.deco_obelisks:
			var q: Vector2 = m.call(ob)
			if inside.call(q):
				var dia := PackedVector2Array([q + Vector2(0, -4.5), q + Vector2(2.4, 0), q + Vector2(0, 3), q + Vector2(-2.4, 0)])
				draw_colored_polygon(dia, Color(0.05, 0.03, 0.04))
				dia.append(dia[0])
				draw_polyline(dia, Color(0.55, 0.06, 0.03), 1.0)
		for bn in v.deco_bones:
			var bc: Vector3 = bn[0]
			var fw := Vector3(cos(bn[1]), 0, -sin(bn[1]))
			var half: float = bn[2] / 2.0
			var a: Vector2 = m.call(bc - fw * half)
			var b: Vector2 = m.call(bc + fw * half)
			if not (inside.call(a) and inside.call(b)):
				continue
			var bone_col := Color(0.82, 0.76, 0.64)
			draw_line(a, b, bone_col, 2.0)
			var dd := b - a
			var pp := Vector2(-dd.y, dd.x).normalized()
			for k in 6:
				var q := a + dd * ((k + 1.0) / 7.0 * 0.8)
				var len := 3.6 * sx * sin((k + 1.0) / 7.0 * PI * 0.9 + 0.25)
				draw_line(q - pp * len, q + pp * len, bone_col, 1.4)
			var sk: Vector2 = m.call(bc + fw * (half + 2.0))
			draw_circle(sk, 2.4 * sx, bone_col)
			draw_circle(sk + pp * sx * 0.7, 0.6 * sx, Color(1.0, 0.15, 0.05))
			draw_circle(sk - pp * sx * 0.7, 0.6 * sx, Color(1.0, 0.15, 0.05))
	# Markers: the watch posts (each side's turret position), the Crossing,
	# the Fire Objective.
	var ps := clampf(r / 22.0, 4.5, 6.5) if not detailed else 9.0
	for t in 2:
		var mi: int = v.ids.find("m%d" % t)
		var q: Vector2 = m.call(v.pos[mi])
		_map_pin("post", q, ps, _team_color(t))
		if detailed:
			_map_label(q + Vector2(0, v.rad[mi] * sx * 1.2 + 11), "WATCH POST", CREAM)
	var ci: int = v.ids.find("c")
	var cq: Vector2 = m.call(v.CROSSING)
	_map_pin("crossing", cq, ps, GOLD)
	var fi: int = v.ids.find("f")
	var fq: Vector2 = m.call(v.FIRE_POS)
	_fire_icon(fq, clampf(r / 16.0, 5.5, 9.0) if not detailed else 11.0, v.fire_owner, v.fire_progress, pt)
	if detailed:
		_map_label(cq - Vector2(0, v.rad[ci] * sx * 1.2 + 6), "THE CROSSING", CREAM)
		var owner_txt: String = "FIRE OBJECTIVE" if v.fire_owner < 0 else "FIRE OBJECTIVE · %s" % Stats.FACTIONS[v.fire_owner].name.to_upper()
		_map_label(fq + Vector2(0, v.rad[fi] * sx * 1.2 + 11), owner_txt, Color(1.0, 0.75, 0.35))


func _map_label(at: Vector2, txt: String, col: Color) -> void:
	## A place name on the map: small capitals on a dark rounded tag, centred on at.
	var w := _text_width(txt, 9) + 12.0
	var tag := Rect2(at - Vector2(w / 2.0, 7), Vector2(w, 13))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.04, 0.82)
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.38, 0.18, 0.9)
	draw_style_box(sb, tag)
	_text(Vector2(tag.position.x, at.y + 3.5), txt, 9, col, HORIZONTAL_ALIGNMENT_CENTER, w, 1)


func _map_pin(kind: String, q: Vector2, s: float, rim: Color = Color(1.0, 0.8, 0.3)) -> void:
	## A round map marker: a dark badge in a coloured rim, lit from the top
	## left, with a small symbol (potion, turret, watch post, crossing, door,
	## spawn).
	draw_circle(q + Vector2(0, s * 0.2), s * 1.08, Color(0, 0, 0, 0.45))
	draw_circle(q, s, rim.darkened(0.3))
	draw_circle(q, s * 0.8, Color(0.13, 0.09, 0.08))
	draw_arc(q, s * 0.9, PI * 1.05, PI * 1.75, 10, rim.lightened(0.4), maxf(s * 0.12, 1.0))
	var k := s * 0.62
	var ink := Color(1.0, 0.92, 0.75)
	var hole := Color(0.13, 0.09, 0.08)
	match kind:
		"potion":
			draw_circle(q + Vector2(0, k * 0.3), k * 0.62, Color(0.95, 0.2, 0.3))
			draw_circle(q + Vector2(-k * 0.22, k * 0.12), k * 0.17, Color(1, 0.75, 0.8))
			draw_rect(Rect2(q + Vector2(-k * 0.2, -k * 0.7), Vector2(k * 0.4, k * 0.5)), Color(0.85, 0.85, 0.92))
			draw_rect(Rect2(q + Vector2(-k * 0.28, -k * 0.95), Vector2(k * 0.56, k * 0.26)), Color(0.62, 0.42, 0.22))
		"turret", "post":
			var col := rim.lightened(0.35) if kind == "turret" else ink
			draw_rect(Rect2(q + Vector2(-k * 0.45, -k * 0.4), Vector2(k * 0.9, k * 1.15)), col)
			for i in 3:
				draw_rect(Rect2(q + Vector2(-k * 0.6 + i * k * 0.45, -k * 0.75), Vector2(k * 0.3, k * 0.4)), col)
			draw_rect(Rect2(q + Vector2(-k * 0.15, k * 0.25), Vector2(k * 0.3, k * 0.5)), hole)
			if kind == "post":
				draw_rect(Rect2(q + Vector2(-k * 0.06, -k * 1.3), Vector2(k * 0.12, k * 0.6)), ink)
				draw_colored_polygon(PackedVector2Array([q + Vector2(k * 0.06, -k * 1.3), q + Vector2(k * 0.6, -k * 1.12), q + Vector2(k * 0.06, -k * 0.95)]), rim.lightened(0.2))
		"crossing":
			var w := maxf(s * 0.16, 1.2)
			draw_line(q + Vector2(-k, k) * 0.8, q + Vector2(k, -k) * 0.8, ink, w)
			draw_line(q + Vector2(k, k) * 0.8, q + Vector2(-k, -k) * 0.8, ink, w)
			draw_line(q + Vector2(-k * 0.75, k * 0.25), q + Vector2(-k * 0.25, k * 0.75), GOLD, w)
			draw_line(q + Vector2(k * 0.75, k * 0.25), q + Vector2(k * 0.25, k * 0.75), GOLD, w)
		"door":
			var col := rim.lightened(0.2)
			draw_rect(Rect2(q + Vector2(-k * 0.6, -k * 0.2), Vector2(k * 1.2, k * 0.95)), col)
			draw_circle(q + Vector2(0, -k * 0.2), k * 0.6, col)
			for i in 3:
				var x := -k * 0.35 + i * k * 0.35
				draw_line(q + Vector2(x, -k * 0.55), q + Vector2(x, k * 0.75), hole, 1.0)
			draw_line(q + Vector2(-k * 0.6, k * 0.25), q + Vector2(k * 0.6, k * 0.25), hole, 1.0)
		"spawn":
			draw_arc(q, k * 0.75, 0, TAU, 18, rim.lightened(0.45), maxf(s * 0.14, 1.0))
			draw_circle(q, k * 0.42, rim.lightened(0.15))
			draw_circle(q, k * 0.18, ink)


func _fire_icon(q: Vector2, s: float, owner: int, progress: float, pt: float) -> void:
	## The Fire Objective's marker: a flame in a red hexagon, ringed in the
	## holder's colour, with the capture filling round it.
	var ring_col := Color(1.0, 0.8, 0.3) if owner < 0 else _team_color(owner).lightened(0.25)
	draw_circle(q, s * 1.55, Color(0, 0, 0, 0.35))
	if absf(progress) > 0.01:
		var lead := 0 if progress < 0.0 else 1
		draw_arc(q, s * 1.4, -PI / 2.0, -PI / 2.0 + TAU * absf(progress), 32, _team_color(lead).lightened(0.3), 3.0)
	draw_arc(q, s * 1.18, 0, TAU, 24, ring_col, 1.6)
	var hexp := PackedVector2Array()
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		hexp.append(q + Vector2(cos(a), sin(a)) * s)
	draw_colored_polygon(hexp, Color(0.75, 0.08, 0.05))
	hexp.append(hexp[0])
	draw_polyline(hexp, Color(1.0, 0.75, 0.3), 1.2)
	var f := s * (0.8 + 0.06 * sin(pt * 8.0))
	var outer := PackedVector2Array([q + Vector2(0, -f), q + Vector2(f * 0.45, -f * 0.1), q + Vector2(f * 0.5, f * 0.35),
		q + Vector2(0, f * 0.65), q + Vector2(-f * 0.5, f * 0.35), q + Vector2(-f * 0.45, -f * 0.1)])
	draw_colored_polygon(outer, Color(1.0, 0.6, 0.12))
	var inner := PackedVector2Array([q + Vector2(0, -f * 0.35), q + Vector2(f * 0.25, f * 0.15), q + Vector2(0, f * 0.5), q + Vector2(-f * 0.25, f * 0.15)])
	draw_colored_polygon(inner, Color(1.0, 0.92, 0.45))


func _draw_logo(rect: Rect2) -> void:
	## The supplied logo art; if it is missing, a lettered stand-in in the
	## same colours (gold CROWNS, green WILDWOOD, a little crown on top).
	if logo:
		draw_texture_rect(logo, rect, false)
		return
	var cx := rect.get_center().x
	_crown(Vector2(cx, rect.position.y + 10), 1.1, GOLD)
	var y := rect.position.y + 40
	draw_string_outline(font, Vector2(rect.position.x, y), "CROWNS", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, 9, Color(0.18, 0.1, 0.04))
	draw_string(font, Vector2(rect.position.x, y), "CROWNS", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, Color(1.0, 0.78, 0.25))
	_text(Vector2(rect.position.x, y + 13), "OF THE", 10, CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 3)
	draw_string_outline(font, Vector2(rect.position.x, y + 40), "WILDWOOD", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, 9, Color(0.08, 0.16, 0.05))
	draw_string(font, Vector2(rect.position.x, y + 40), "WILDWOOD", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, Color(0.55, 0.82, 0.3))


func _close(rect: Rect2) -> void:
	## An X button in a panel's top-right corner. Recorded for mouse clicks.
	close_button = Rect2(rect.end.x - 34, rect.position.y + 8, 26, 26)
	_plate(close_button, Color(0.45, 0.12, 0.12), GOLD_DARK, 6, 1)
	_text(close_button.position + Vector2(0, 19), "✕", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 26, 0)


func _padlock(c: Vector2, s: float, col: Color) -> void:
	## A small padlock for a slot that has not been unlocked yet.
	draw_arc(c + Vector2(0, -0.15 * s), 0.42 * s, PI, TAU, 16, col, 0.17 * s)
	draw_line(c + Vector2(-0.42 * s, -0.15 * s), c + Vector2(-0.42 * s, 0.1 * s), col, 0.17 * s)
	draw_line(c + Vector2(0.42 * s, -0.15 * s), c + Vector2(0.42 * s, 0.1 * s), col, 0.17 * s)
	var body := Rect2(c + Vector2(-0.65 * s, 0.05 * s), Vector2(1.3 * s, 0.95 * s))
	_plate(body, col, col.darkened(0.5), 3, 1)
	draw_circle(c + Vector2(0, 0.42 * s), 0.13 * s, Color(0.08, 0.08, 0.1))
	draw_line(c + Vector2(0, 0.45 * s), c + Vector2(0, 0.75 * s), Color(0.08, 0.08, 0.1), 0.1 * s)


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.35, 0.2, 0.04), 1.2)
	draw_circle(c + Vector2(-0.15, -0.25) * r, r * 0.16, Color(1, 1, 0.85, 0.7))


func _team_shield(c: Vector2, s: float, team: int) -> void:
	## A tiny heater shield split in the team colour and gold: the home tag.
	var pts := PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, 0.1 * s),
		c + Vector2(0.55 * s, 0.75 * s), c + Vector2(0, 1.1 * s), c + Vector2(-0.55 * s, 0.75 * s), c + Vector2(-s, 0.1 * s)])
	var outer := PackedVector2Array()
	for q in pts:
		outer.append(c + (q - c) * 1.25)
	draw_colored_polygon(outer, Color(0.85, 0.87, 0.92))
	draw_colored_polygon(pts, _team_color(team).darkened(0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, -s), c + Vector2(s, 0.1 * s),
		c + Vector2(0.55 * s, 0.75 * s), c + Vector2(0, 1.1 * s)]), Color(0.95, 0.6, 0.15))
	outer.append(outer[0])
	draw_polyline(outer, Color(0.1, 0.1, 0.14), 1.2)


func _home_pill(rect: Rect2, team: int) -> void:
	## The navy "DEFENDING HOME" tag with a team shield on its left end.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.24, 0.97)
	sb.set_corner_radius_all(int(rect.size.y / 2.0))
	sb.set_border_width_all(2)
	sb.border_color = Color(0.72, 0.76, 0.86)
	sb.shadow_size = 4
	sb.shadow_color = Color(0, 0, 0, 0.4)
	draw_style_box(sb, rect)
	_team_shield(rect.position + Vector2(rect.size.y * 0.55, rect.size.y * 0.42), rect.size.y * 0.33, team)
	_text(rect.position + Vector2(rect.size.y, rect.size.y * 0.5 + 4.5), "DEFENDING HOME", 12, Color(0.92, 0.94, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - rect.size.y - 6, 2)


func _shield_shape(c: Vector2, w: float, h: float) -> PackedVector2Array:
	## A heater shield outline: flat top with clipped corners, straight sides,
	## then curving in to a point.
	var top := -h / 2.0
	var knee := top + h * 0.4
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-w / 2.0, top + 7.0))
	pts.append(c + Vector2(-w / 2.0 + 7.0, top))
	pts.append(c + Vector2(0, top + 5.0))
	pts.append(c + Vector2(w / 2.0 - 7.0, top))
	pts.append(c + Vector2(w / 2.0, top + 7.0))
	for i in 11:
		var t := i / 10.0
		pts.append(c + Vector2(w / 2.0 * (1.0 - pow(t, 1.7)), knee + (h / 2.0 - knee) * t))
	for i in range(9, -1, -1):
		var t := i / 10.0
		pts.append(c + Vector2(-w / 2.0 * (1.0 - pow(t, 1.7)), knee + (h / 2.0 - knee) * t))
	return pts

const SCORE_BANDS := [Color(0.66, 0.12, 0.11), Color(0.16, 0.3, 0.72)]


func _crest_shield(c: Vector2, w: float, h: float, team: int) -> void:
	## A faction crest on a big heater shield: the crest art's own shield
	## (stag or lion) cropped in, inside a thick gold rim with a dark edge.
	var pts := _shield_shape(c, w, h)
	var grown := func(f: float, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts:
			out.append(c + (q - c) * f + off)
		return out
	draw_colored_polygon(grown.call(1.2, Vector2(0, 4)), Color(0, 0, 0, 0.4))
	draw_colored_polygon(grown.call(1.18), Color(0.28, 0.16, 0.03))
	draw_colored_polygon(grown.call(1.14), BRASS)
	var hi: PackedVector2Array = grown.call(1.12)
	hi.resize(5)
	draw_polyline(hi, GOLD.lightened(0.4), 1.5)
	draw_colored_polygon(grown.call(1.04), Color(0.3, 0.18, 0.04))
	var tc: Color = SCORE_BANDS[team]
	var cols := PackedColorArray()
	for q in pts:
		cols.append(tc.lightened(0.1) if q.y < c.y else tc.darkened(0.35))
	draw_polygon(pts, cols)
	var face_key := "shield_elf" if team == 0 else "shield_human"
	var key := "crest_elf" if team == 0 else "crest_human"
	if skill_art.has(face_key):
		# The stag on red / lion on blue face from the reference art, its
		# own rim trimmed off by mapping the shield a little inside it.
		var ftex: Texture2D = skill_art[face_key]
		var fuv := PackedVector2Array()
		var fw := PackedColorArray()
		for q in pts:
			var f := (q - c) / Vector2(w, h) + Vector2(0.5, 0.5)
			fuv.append(Vector2(0.07, 0.06) + f * Vector2(0.86, 0.88))
			fw.append(Color.WHITE)
		draw_polygon(pts, fw, fuv, ftex)
	elif cards.has(key):
		# The crest art's shield face sits in its middle; map our shield's
		# box onto that part of the picture.
		var tex: Texture2D = cards[key]
		var ts := tex.get_size()
		var src := Rect2(ts * Vector2(0.22, 0.1), ts * Vector2(0.56, 0.62)) if team == 0 else Rect2(ts * Vector2(0.25, 0.14), ts * Vector2(0.5, 0.6))
		var uvs := PackedVector2Array()
		var white := PackedColorArray()
		for q in pts:
			var f := (q - c) / Vector2(w, h) + Vector2(0.5, 0.5)
			uvs.append((src.position + src.size * f) / ts)
			white.append(Color.WHITE)
		draw_polygon(pts, white, uvs, tex)
	else:
		_icon("crest_forest" if team == 0 else "crest_kingdom", c, w * 0.25, Color.WHITE)
	# Gloss on the upper left and the inner gold line.
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], c + Vector2(0, -h * 0.1), c + Vector2(-w * 0.45, h * 0.05)]), Color(1, 1, 1, 0.1))
	var line: PackedVector2Array = grown.call(1.0)
	line.append(line[0])
	draw_polyline(line, Color(0.25, 0.14, 0.03), 2.0)


func _shield_portrait(c: Vector2, w: float, h: float, team: int, role: int, dead: bool) -> void:
	## The player's class portrait (the supplied card art, or the class icon)
	## inside a gold-rimmed heater shield.
	var pts := _shield_shape(c, w, h)
	var scaled := func(k: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts:
			out.append(c + (q - c) * k)
		return out
	var shadow: PackedVector2Array = scaled.call(1.2)
	for i in shadow.size():
		shadow[i] += Vector2(0, 3)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	var rim: PackedVector2Array = scaled.call(1.17)
	draw_colored_polygon(rim, BRASS.darkened(0.25))
	draw_colored_polygon(scaled.call(1.12), BRASS)
	draw_colored_polygon(scaled.call(1.04), Color(0.3, 0.18, 0.05))
	var bg := _team_color(team).darkened(0.55)
	draw_colored_polygon(pts, bg)
	var key := _card_key(team, role)
	if cards.has(key):
		var tex: Texture2D = cards[key]
		var ts := tex.get_size()
		# The head and shoulders: the top of the card, a little wider than the shield.
		var src := Rect2(Vector2(ts.x * 0.12, ts.y * 0.03), Vector2(ts.x * 0.76, ts.x * 0.76 * h / w))
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var tint := Color(0.4, 0.4, 0.42) if dead else Color.WHITE
		for q in pts:
			var f := (q - (c - Vector2(w, h) / 2.0)) / Vector2(w, h)
			uvs.append((src.position + src.size * f) / ts)
			cols.append(tint)
		draw_polygon(pts, cols, uvs, tex)
	else:
		draw_circle(c + Vector2(0, -4), w * 0.36, bg.lightened(0.15))
		_icon(_class_icon(role), c + Vector2(0, -4), w * 0.24, Color.WHITE, dead)
	# Gloss and the gold edge lines.
	var gloss := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], c + Vector2(w / 2.0, -h * 0.2), c + Vector2(-w / 2.0, -h * 0.05)])
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.07))
	var line: PackedVector2Array = pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, Color(0.25, 0.14, 0.03), 2.0)
	rim.append(rim[0])
	draw_polyline(rim, Color(0.3, 0.18, 0.04), 2.0)
	var hi: PackedVector2Array = scaled.call(1.09)
	hi.append(hi[0])
	draw_polyline(hi, GOLD.lightened(0.3), 1.0)
	# Rivets on the rim.
	for q in [rim[1], rim[3], rim[8], rim[rim.size() - 9]]:
		draw_circle(q.lerp(c, 0.04), 2.2, Color(1, 0.92, 0.6))
	if dead:
		_text(c + Vector2(-w / 2.0, 6), "DOWN", 15, Color(1, 0.6, 0.55), HORIZONTAL_ALIGNMENT_CENTER, w, 4)


func _narrow() -> bool:
	## Couch panes too small for the full top row: the scoreboard shrinks,
	## the minimap gets smaller and the logo is left out.
	return size.x < 1140.0


func _clock_plate(rect: Rect2) -> void:
	## The timer plate: dark wood-black in a thick gold frame with clipped
	## corners and a shallow point at the bottom.
	var r := rect
	var ch := 10.0
	var outline := func(g: float) -> PackedVector2Array:
		var q := r.grow(g)
		return PackedVector2Array([q.position + Vector2(ch, 0), Vector2(q.end.x - ch, q.position.y), Vector2(q.end.x, q.position.y + ch),
			Vector2(q.end.x, q.end.y - ch - 4.0), Vector2(q.end.x - ch * 2.0, q.end.y - 4.0), Vector2(q.get_center().x, q.end.y + 3.0),
			Vector2(q.position.x + ch * 2.0, q.end.y - 4.0), Vector2(q.position.x, q.end.y - ch - 4.0), Vector2(q.position.x, q.position.y + ch)])
	var shadow: PackedVector2Array = outline.call(3.0)
	for i in shadow.size():
		shadow[i] += Vector2(0, 3)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	var o: PackedVector2Array = outline.call(2.0)
	draw_colored_polygon(o, BRASS)
	draw_colored_polygon(outline.call(-2.0), Color(0.35, 0.22, 0.05))
	var inner: PackedVector2Array = outline.call(-4.0)
	draw_colored_polygon(inner, Color(0.12, 0.09, 0.08))
	draw_rect(Rect2(r.position + Vector2(10, 5), Vector2(r.size.x - 20, r.size.y * 0.35)), Color(1, 0.9, 0.7, 0.05))
	inner.append(inner[0])
	draw_polyline(inner, Color(0.75, 0.55, 0.2, 0.6), 1.0)
	o.append(o[0])
	draw_polyline(o, Color(0.3, 0.18, 0.04), 2.0)
	var hi: PackedVector2Array = outline.call(0.5)
	hi.resize(4)
	draw_polyline(hi, GOLD.lightened(0.35), 1.2)
	for q in [Vector2(r.position.x + 3, r.get_center().y - 4), Vector2(r.end.x - 3, r.get_center().y - 4)]:
		draw_circle(q, 2.5, Color(1, 0.92, 0.6))
		draw_arc(q, 2.5, 0, TAU, 10, Color(0.35, 0.2, 0.04), 1.0)


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


func _screen_frame() -> void:
	## A thin bronze frame round the whole screen with ivy creeping in from
	## the corners and along the sides, like a storybook page (Faisal's UI
	## reference, 2026-10-08).
	var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	draw_rect(r.grow(2), Color(0.12, 0.07, 0.02, 0.7), false, 3.0)
	draw_rect(r, Color(0.62, 0.44, 0.18, 0.85), false, 2.0)
	draw_rect(r.grow(-2), Color(1.0, 0.85, 0.5, 0.25), false, 1.0)
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var dx := 1.0 if c.x < size.x / 2.0 else -1.0
		var dy := 1.0 if c.y < size.y / 2.0 else -1.0
		var q := PackedVector2Array([c, c + Vector2(dx * 18, 0), c + Vector2(dx * 14, dy * 4), c + Vector2(dx * 4, dy * 4), c + Vector2(dx * 4, dy * 14), c + Vector2(0, dy * 18)])
		draw_colored_polygon(q, BRASS)
		q.append(q[0])
		draw_polyline(q, Color(0.3, 0.17, 0.04), 1.2)
	# Ivy: a wavy stem with leaves, from each corner along both edges, and a
	# sprig half-way down the sides.
	var runs := [
		[r.position, Vector2(1, 0), 150.0], [r.position, Vector2(0, 1), 120.0],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 0), 150.0], [Vector2(r.end.x, r.position.y), Vector2(0, 1), 120.0],
		[Vector2(r.position.x, r.end.y), Vector2(0, -1), 140.0], [r.end, Vector2(0, -1), 140.0],
		[Vector2(r.position.x, r.end.y), Vector2(1, 0), 70.0], [r.end, Vector2(-1, 0), 60.0],
		[Vector2(r.position.x, size.y * 0.5), Vector2(0, -1), 60.0], [Vector2(r.end.x, size.y * 0.55), Vector2(0, 1), 60.0]]
	for i in runs.size():
		_ivy(runs[i][0], runs[i][1], runs[i][2], i)


func _ivy(start: Vector2, dir: Vector2, length: float, seed_i: int) -> void:
	var side := Vector2(-dir.y, dir.x)
	# Lean the sprig inwards, away from the screen edge.
	var inward := (size / 2.0 - start)
	if side.dot(inward) < 0.0:
		side = -side
	var stem := PackedVector2Array()
	var n := int(length / 8.0)
	for i in n + 1:
		var t := float(i) / n
		stem.append(start + dir * length * t + side * (3.0 + 3.0 * sin(t * 9.0 + seed_i)))
	draw_polyline(stem, Color(0.16, 0.28, 0.08, 0.95), 2.2)
	var leaves := int(length / 20.0)
	for k in leaves:
		var t := (k + 0.5) / leaves
		var p := start + dir * length * t + side * (3.0 + 3.0 * sin(t * 9.0 + seed_i))
		var flip := 1.0 if (k + seed_i) % 2 == 0 else -0.4
		var ldir := (side * flip + dir * 0.6).normalized()
		var ln := 9.0 + 4.0 * ((k * 7 + seed_i) % 3) * (1.0 - t * 0.5)
		var tip := p + ldir * ln
		var sd := Vector2(-ldir.y, ldir.x) * ln * 0.38
		var leaf := PackedVector2Array([p, (p + tip) / 2.0 + sd, tip, (p + tip) / 2.0 - sd])
		var col := LEAF_GREEN.darkened(0.1 * ((k + seed_i) % 3))
		draw_colored_polygon(leaf, col)
		draw_colored_polygon(PackedVector2Array([p, (p + tip) / 2.0 + sd, tip]), col.lightened(0.25))
		leaf.append(leaf[0])
		draw_polyline(leaf, Color(0.08, 0.18, 0.04), 1.0)


func _draw_scoreboard() -> void:
	## Two cloth banners, ELVES in green on the left and HUMANS in blue on the
	## right, each with its crest at the outer end, either side of a framed
	## clock in gold laurels; the phase line on a parchment scroll below.
	var cx := size.x / 2.0
	var k := 0.72 if _narrow() else 1.0
	if k < 1.0:
		draw_set_transform(Vector2(cx * (1.0 - k), 0), 0.0, Vector2(k, k))
	var now := Time.get_ticks_msec() / 1000.0
	# The bar itself is Faisal's UI reference art (2026-10-08) with its text
	# painted out (tools/make_topbar.py): banners, crest shields, the gold
	# clock frame with its crown and the parchment strip. The live text goes
	# on top in a round bold face.
	var tf: Font = bar_font if bar_font else font
	var ink := Color(0.2, 0.07, 0.04)
	if topbar_tex:
		var sc := 0.4969   # reference pixels -> HUD units
		var tsz := topbar_tex.get_size() * sc
		draw_texture_rect(topbar_tex, Rect2(Vector2(cx - tsz.x / 2.0, 0), tsz), false)
	else:
		for t in 2:
			_score_band(Rect2(Vector2(cx - 292.0 if t == 0 else cx + 62.0, 12), Vector2(230, 62)), SCORE_BANDS[t])
			_crest_shield(Vector2(cx + (-1.0 if t == 0 else 1.0) * 310.0, 54.0), 76.0, 94.0, t)
		_ornate_clock(Rect2(cx - 84, 8, 168, 78))
		_crown_glyph(Vector2(cx, 9), 20.0, 0.6)
	for t in 2:
		var mid := cx + (-157.0 if t == 0 else 159.0)
		_bar_text(Vector2(mid, 31), Stats.FACTIONS[t].name.to_upper(), tf, 17, Color(1.0, 0.95, 0.86), ink, 6)
		_bar_text(Vector2(mid, 61), str(game.score[t]), tf, 38, Color(1.0, 0.95, 0.84), ink, 10)
	# Twinkles round the shields, on top of the art's own.
	for j in 4:
		var sp := Vector2(cx + [-372.0, 362.0, -262.0, 262.0][j], [22.0, 26.0, 84.0, 82.0][j])
		var tw := maxf(0.0, sin(now * 2.5 + j * 1.7))
		var r := 2.5 + 6.0 * tw
		draw_line(sp - Vector2(r, 0), sp + Vector2(r, 0), Color(1, 0.97, 0.8, tw), 1.6)
		draw_line(sp - Vector2(0, r), sp + Vector2(0, r), Color(1, 0.97, 0.8, tw), 1.6)
	var fortify: bool = game.prep_left > 0.0
	var clock_x := cx + 3.0
	if fortify:
		# The fortify countdown takes the clock's place; the match clock waits.
		var pl: float = ceilf(game.prep_left)
		var pulse: bool = pl <= 5.0 and int(game.prep_left * 2.0) % 2 == 0
		_bar_text(Vector2(clock_x, 42), "FORTIFY", tf, 18, Color(1.0, 0.78, 0.32), ink, 4)
		_bar_text(Vector2(clock_x, 70), "%d:%02d" % [int(pl) / 60, int(pl) % 60], tf, 38, Color(1, 0.85, 0.5) if pulse else Color(1.0, 0.97, 0.92), ink, 5)
	else:
		var left := maxf(game.time_left, 0.0)
		var urgent := left < 60.0 and int(left * 2.0) % 2 == 0
		_bar_text(Vector2(clock_x, 42), "OVERTIME" if game.overtime else "BATTLE", tf, 18, Color(1, 0.55, 0.4) if game.overtime else Color(1.0, 0.78, 0.32), ink, 4)
		_bar_text(Vector2(clock_x, 70), "%d:%02d" % [int(left) / 60, int(left) % 60], tf, 38,
			Color(1, 0.4, 0.3) if urgent else Color(1.0, 0.97, 0.92), ink, 5)
	var line := "Steal their crown and carry it home to your throne room."
	var line_ink := Color(0.33, 0.2, 0.08)
	if fortify:
		line = "Build turrets, set traps and raise barricades (%s) before the barrier falls." % _k("interact")
		var kits: int = game.barricades_left[_my_team()]
		if kits >= 0:
			line += "  %d kit%s left." % [kits, "" if kits == 1 else "s"]
	elif game.overtime:
		line = "Overtime: no respawns. The last team standing or the next capture wins."
		line_ink = Color(0.55, 0.1, 0.05)
	var fire: Dictionary = game.vmap.status(_my_team()) if game.vmap and not fortify and not game.overtime else {}
	if not fire.is_empty() and fire.text != "":
		line = fire.text
		line_ink = fire.color
	if topbar_tex:
		# On the art's own parchment strip, right of its "i" medallion.
		var fs := 13 if _text_width(line, 13) < 490.0 else 12
		_bang_medallion(Vector2(cx - 254.0, 94.0))
		_text(Vector2(cx - 231.0, 98.5), line, fs, line_ink, HORIZONTAL_ALIGNMENT_CENTER, 499.0, 0)
	else:
		_info_banner(Vector2(cx, 98), line, line_ink)
	if not fire.is_empty() and line == fire.text:
		# Ember Pass: the Fire Objective's flame beside the strip, and the
		# capture filling along its foot.
		var x0 := cx - 250.0
		draw_circle(Vector2(x0, 98), 10, Color(0.33, 0.2, 0.07))
		_fire_icon(Vector2(x0, 98), 7.0, fire.owner, fire.progress, Time.get_ticks_msec() / 1000.0)
		var p: float = absf(fire.progress)
		if p > 0.01 and p < 0.999:
			var lead := 0 if fire.progress < 0.0 else 1
			draw_rect(Rect2(cx - 231.0, 108.0, 499.0 * p, 3.0), _team_color(lead))
	if k < 1.0:
		draw_set_transform(Vector2.ZERO)


func _bar_text(c: Vector2, text: String, f: Font, fs: int, face: Color, ink: Color, outline: int) -> void:
	## Centred on c.x with its baseline at c.y: a dark outline, a soft drop
	## shadow, then the face.
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - w / 2.0, c.y)
	draw_string_outline(f, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0, 0, 0, 0.35))
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, ink)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, face)


func _score_band(r: Rect2, color: Color) -> void:
	## A glossy cloth band in thick gold trim: lighter at the top, deep at
	## the bottom, a sheen line and a dark outline.
	draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r.grow(2), Color(0.25, 0.13, 0.03))
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([color.lightened(0.18), color.lightened(0.18), color.darkened(0.3), color.darkened(0.3)]))
	draw_rect(Rect2(r.position + Vector2(0, 9), Vector2(r.size.x, r.size.y * 0.22)), Color(1, 1, 1, 0.08))
	for y in [r.position.y + 3.0, r.end.y - 3.0]:
		draw_rect(Rect2(Vector2(r.position.x, y - 3.5), Vector2(r.size.x, 7)), Color(0.3, 0.17, 0.04))
		draw_rect(Rect2(Vector2(r.position.x, y - 2.5), Vector2(r.size.x, 5)), BRASS)
		draw_rect(Rect2(Vector2(r.position.x, y - 2.5), Vector2(r.size.x, 1.5)), GOLD.lightened(0.4))
	draw_rect(Rect2(Vector2(r.position.x, r.position.y + 7), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.25))


func _ornate_clock(r: Rect2) -> void:
	## The timer in a scalloped gold frame: a rounded, gently wavy outline in
	## gold with a dark edge, gold curls on both flanks and a dark inset.
	var c := r.get_center()
	var shape := func(a: float, b: float, wave: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in 96:
			var ang := TAU * i / 96.0
			var cs := cos(ang)
			var sn := sin(ang)
			var x := signf(cs) * pow(absf(cs), 0.4) * a
			var y := signf(sn) * pow(absf(sn), 0.4) * b
			var k := 1.0 + wave * cos(ang * 8.0)
			out.append(c + Vector2(x, y) * k)
		return out
	var a := r.size.x / 2.0
	var b := r.size.y / 2.0
	# Curls on both flanks.
	for side in [-1.0, 1.0]:
		var cc := c + Vector2(side * (a + 2.0), 0)
		draw_circle(cc + Vector2(0, 3), 13.0, Color(0, 0, 0, 0.3))
		draw_circle(cc, 12.0, Color(0.28, 0.15, 0.03))
		draw_circle(cc, 10.0, BRASS)
		draw_arc(cc, 6.0, -PI * 0.5, PI * 1.2, 14, Color(0.4, 0.24, 0.05), 2.5)
		draw_arc(cc, 9.0, PI * 1.05, PI * 1.7, 10, GOLD.lightened(0.4), 1.5)
	var sh: PackedVector2Array = shape.call(a + 4.0, b + 4.0, 0.015)
	for i in sh.size():
		sh[i] += Vector2(0, 4)
	draw_colored_polygon(sh, Color(0, 0, 0, 0.4))
	draw_colored_polygon(shape.call(a + 4.0, b + 4.0, 0.015), Color(0.28, 0.15, 0.03))
	var gold: PackedVector2Array = shape.call(a + 1.5, b + 1.5, 0.015)
	var gc := PackedColorArray()
	for q in gold:
		gc.append(GOLD.lightened(0.25) if q.y < c.y else BRASS.darkened(0.15))
	draw_polygon(gold, gc)
	var hi: PackedVector2Array = shape.call(a - 1.0, b - 1.0, 0.012)
	hi.append(hi[0])
	draw_polyline(hi, Color(1, 0.95, 0.7, 0.55), 1.2)
	draw_colored_polygon(shape.call(a - 7.0, b - 7.0, 0.0), Color(0.3, 0.17, 0.04))
	var inner: PackedVector2Array = shape.call(a - 9.0, b - 9.0, 0.0)
	var ic := PackedColorArray()
	for q in inner:
		ic.append(Color(0.2, 0.13, 0.09) if q.y < c.y else Color(0.1, 0.07, 0.06))
	draw_polygon(inner, ic)
	draw_rect(Rect2(c + Vector2(-a * 0.6, -b * 0.62), Vector2(a * 1.2, 2)), Color(1, 0.9, 0.7, 0.08))


func _info_banner(center: Vector2, line: String, ink: Color) -> void:
	## The objective line under the scoreboard: a parchment banner in a thin
	## gold frame with a round "i" medallion on the left and short gold end
	## caps, the text in sentence case.
	var fs := 12
	var w := maxf(_text_width(line, fs) + 74.0, 440.0)
	var rect := Rect2(center - Vector2(w / 2.0, 14), Vector2(w, 28))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.88, 0.7)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.38, 0.14)
	sb.shadow_size = 5
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_offset = Vector2(0, 2)
	draw_style_box(sb, rect)
	var inner := rect.grow(-3)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.4)), Color(1, 1, 0.95, 0.35))
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - 6), Vector2(inner.size.x, 6)), Color(0.6, 0.42, 0.16, 0.16))
	draw_rect(rect.grow(-4), Color(0.72, 0.53, 0.22, 0.55), false, 1.0)
	# Gold end caps, like the rolled ends of a scroll.
	for x in [rect.position.x, rect.end.x]:
		var cap := Rect2(Vector2(x - 5, rect.position.y - 3), Vector2(10, rect.size.y + 6))
		var cb := StyleBoxFlat.new()
		cb.bg_color = BRASS
		cb.set_corner_radius_all(4)
		cb.set_border_width_all(1)
		cb.border_color = Color(0.35, 0.2, 0.04)
		draw_style_box(cb, cap)
		draw_rect(Rect2(cap.position + Vector2(2, 3), Vector2(2, cap.size.y - 6)), Color(1, 0.95, 0.7, 0.6))
	_bang_medallion(Vector2(rect.position.x + 24, center.y))
	_text(Vector2(rect.position.x + 40, center.y + 4.5), line, fs, ink, HORIZONTAL_ALIGNMENT_CENTER, w - 54, 0)


func _bang_medallion(ic: Vector2) -> void:
	## The "!" medallion on the objective banner: a dark round plate in a
	## bronze rim with a cream exclamation mark.
	draw_circle(ic + Vector2(0, 1), 11.5, Color(0, 0, 0, 0.3))
	draw_circle(ic, 11, Color(0.5, 0.33, 0.12))
	draw_circle(ic, 9.5, Color(0.16, 0.12, 0.1))
	draw_arc(ic, 10.2, PI * 1.1, PI * 1.9, 10, Color(1, 0.85, 0.5, 0.5), 1.0)
	draw_rect(Rect2(ic + Vector2(-1.5, -6.5), Vector2(3.0, 7.5)), CREAM)
	draw_circle(ic + Vector2(0, 4.2), 1.8, CREAM)


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
			_text(rect.position + Vector2(52, 39), "back in %d" % ceili(u.respawn_timer), 12, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
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
			_text(rect.position + Vector2(46, 35), "back in %d" % ceili(u.respawn_timer), 10, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		else:
			_hearts(rect.position + Vector2(52, 30), u.hearts, 0.3, 13)
			_bar(Rect2(rect.position + Vector2(112, 26), Vector2(78, 8)), u.energy / u.energy_max(),
				MANA if u.energy_kind() == "mana" else STAMINA)
		row += 1


var holding_since := -1.0   # seconds since this HUD's player picked the crown up (-1 = not carrying)
const HOLD_BANNER_TIME := 3.6   # seconds the pickup banner stays up


func _draw_holding_banner(p) -> void:
	## YOU PICKED UP THE CROWN! A tilted royal-blue ribbon with gold trim
	## and swallowtail ends, the title in a chunky cartoon face (cream over
	## gold), a crown with rays on top, a parchment scroll with the hint
	## below, and blue and gold shards bursting out behind it. Pops in when
	## you pick the crown up, then bobs, twinkles and shines (Faisal
	## 2026-10-08, his banner image).
	var now := Time.get_ticks_msec() / 1000.0
	# Counted in _process (frame time, not the wall clock), so a slow frame
	# or a headless render still shows the whole pop.
	var t := maxf(holding_since, 0.0)
	# Only when you first pick it up (Faisal 2026-10-08 07:09): it pops in,
	# holds for a few seconds, then lifts away; the glowing CROWN button and
	# the Drop tile keep reminding you after that.
	if t > HOLD_BANNER_TIME:
		return
	var fade := clampf((HOLD_BANNER_TIME - t) / 0.5, 0.0, 1.0)
	var pop := 1.0 + (0.25 * sin(clampf(t / 0.4, 0.0, 1.0) * PI) if t < 0.4 else 0.0)
	var fit := clampf(size.x / 1280.0, 0.55, 1.0)
	var s := minf(t / 0.14, 1.0) * pop * fit * 0.84 * (1.0 + 0.015 * sin(now * 4.0))
	var a := clampf(t / 0.15, 0.0, 1.0) * fade
	s *= 0.9 + 0.1 * fade
	if s < 0.05:
		return
	var ours: bool = p.carrying.team == p.team
	draw_set_transform(Vector2(size.x / 2.0, 186.0 * fit + sin(now * 2.2) * 2.0 - (1.0 - fade) * 30.0), -0.06 + 0.012 * sin(now * 1.7), Vector2(s, s))
	var ink := Color(0.12, 0.07, 0.03, a)
	var gold := Color(1.0, 0.8, 0.22, a)
	# Burst: shards flying out from behind the ribbon, drifting outwards.
	for k in 16:
		var ang := -PI + (k + 0.5) * TAU / 16.0
		if absf(sin(ang)) > 0.6:
			continue   # out to the sides: clear of the scoreboard above and the player below
		var drift := fmod(now * 0.5 + k * 0.37, 1.0)
		var d := Vector2(cos(ang) * 1.45, sin(ang)) * (150.0 + 40.0 * drift + 18.0 * (k % 3))
		var dir := d.normalized()
		var side := Vector2(-dir.y, dir.x)
		var ln := 16.0 + 10.0 * (k % 2)
		var wd := 5.0 + 2.0 * ((k + 1) % 3)
		var col := Color(0.35, 0.8, 1.0, a * (1.0 - drift * 0.7)) if k % 2 == 0 else Color(1.0, 0.86, 0.25, a * (1.0 - drift * 0.7))
		draw_colored_polygon(PackedVector2Array([d - dir * ln, d + side * wd, d + dir * ln, d - side * wd]), col)
	# Ribbon geometry: an arch (ends lower than the middle).
	var half := 215.0
	var bend := 14.0
	var top := -66.0
	var bot := 40.0
	var edge := func(x: float, y: float) -> Vector2: return Vector2(x, y + bend * pow(x / half, 2.0))
	# Swallowtail ends behind the band, with a dark fold where they tuck in.
	for sx in [-1.0, 1.0]:
		var x0: float = sx * (half - 18.0)
		var x1: float = sx * (half + 62.0)
		var tail := PackedVector2Array([edge.call(x0, top + 26.0), edge.call(x1, top + 30.0), edge.call(x1 - sx * 22.0, (top + bot) / 2.0 + 16.0),
			edge.call(x1, bot + 6.0), edge.call(x0, bot + 2.0)])
		var tail_out := tail.duplicate()
		tail_out.append(tail[0])
		draw_colored_polygon(tail, Color(0.13, 0.3, 0.72, a))
		draw_colored_polygon(PackedVector2Array([tail[0], tail[1], tail[2], edge.call(x0, (top + bot) / 2.0 + 14.0)]), Color(0.22, 0.45, 0.92, a))
		draw_polyline(tail_out, ink, 5.0)
		draw_polyline(tail_out, gold, 2.0)
		draw_colored_polygon(PackedVector2Array([edge.call(sx * half, bot - 2.0), edge.call(x0, bot + 2.0), edge.call(sx * half, bot + 16.0)]), Color(0.04, 0.08, 0.25, a))
	# The band: lighter at the top, deep blue at the bottom.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 16
	for i in n + 1:
		var x := lerpf(-half, half, float(i) / n)
		pts.append(edge.call(x, top))
		cols.append(Color(0.2, 0.42, 0.9, a))
	for i in n + 1:
		var x := lerpf(half, -half, float(i) / n)
		pts.append(edge.call(x, bot))
		cols.append(Color(0.05, 0.13, 0.42, a))
	draw_polygon(pts, cols)
	# A soft sheen across the upper third, and the shine sweeping over it.
	var sheen := PackedVector2Array()
	for i in n + 1:
		sheen.append(edge.call(lerpf(-half, half, float(i) / n), top + 6.0))
	for i in n + 1:
		sheen.append(edge.call(lerpf(half, -half, float(i) / n), top + 30.0))
	draw_colored_polygon(sheen, Color(0.6, 0.8, 1.0, 0.12 * a))
	var sweep := (fmod(now * 0.55, 1.6) - 0.3) * 2.0 * half - half
	if absf(sweep) < half - 30.0:
		draw_colored_polygon(PackedVector2Array([edge.call(sweep, top + 4.0), edge.call(sweep + 36.0, top + 4.0), edge.call(sweep + 6.0, bot - 4.0), edge.call(sweep - 30.0, bot - 4.0)]),
			Color(1.0, 1.0, 1.0, 0.1 * a))
	# Gold trim along both edges over a dark ink line, studs at the ends.
	for y in [top, bot]:
		var line := PackedVector2Array()
		for i in n + 1:
			line.append(edge.call(lerpf(-half, half, float(i) / n), y))
		draw_polyline(line, ink, 9.0)
		draw_polyline(line, gold, 5.0)
		var hi := PackedVector2Array()
		for q in line:
			hi.append(q + Vector2(0, -1.5))
		draw_polyline(hi, Color(1.0, 0.96, 0.7, 0.8 * a), 1.5)
	for sx in [-1.0, 1.0]:
		var side_line := PackedVector2Array([edge.call(sx * half, top), edge.call(sx * half, bot)])
		draw_polyline(side_line, ink, 9.0)
		draw_polyline(side_line, gold, 5.0)
		for y in [top, bot]:
			draw_circle(edge.call(sx * half, y), 6.0, ink)
			draw_circle(edge.call(sx * half, y), 4.0, Color(1.0, 0.9, 0.45, a))
	# Stars either side of the title.
	for sx in [-1.0, 1.0]:
		_inked_star(edge.call(sx * (half - 34.0), -20.0), 11.0 + sin(now * 4.0 + sx) * 1.5, gold, ink)
	# The title: cream first line, big gold second line with an orange
	# drop and a dark outline, so it reads like a cartoon logo.
	var w := half * 2.0
	_title_text(Vector2(-half, -18.0), "YOU PICKED UP", 38, Color(1.0, 0.97, 0.88, a), Color(0.55, 0.62, 0.85, a), ink, w)
	_title_text(Vector2(-half, 30.0), "THE CROWN!", 56, Color(1.0, 0.84, 0.18, a), Color(0.9, 0.42, 0.04, a), ink, w)
	# The crown on top with its own rays, bobbing.
	var cc := Vector2(0, top - 22.0 + sin(now * 4.0) * 2.5)
	for k in 9:
		var ang := -PI / 2.0 + (k - 4) * 0.32
		var tw := 0.5 + 0.5 * sin(now * 5.0 + k * 1.3)
		var d := Vector2(cos(ang), sin(ang))
		draw_line(cc + d * 40.0, cc + d * (52.0 + 10.0 * tw), Color(1.0, 0.88, 0.35, (0.4 + 0.5 * tw) * a), 3.0)
	_crown_glyph(cc, 36.0, 1.0, a)
	# The parchment scroll with the hint, curled at both ends.
	var hint := "Carry it back to your throne!" if ours else "Run it home to your throne room!"
	var sw := 340.0
	var sy := bot + 22.0
	var scroll := Rect2(-sw / 2.0, sy - 16.0, sw, 34.0)
	for sx in [-1.0, 1.0]:
		var ex: float = sx * sw / 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(ex - sx * 6.0, sy - 14.0), Vector2(ex + sx * 16.0, sy - 10.0), Vector2(ex + sx * 8.0, sy + 2.0),
			Vector2(ex + sx * 16.0, sy + 16.0), Vector2(ex - sx * 6.0, sy + 18.0)]), Color(0.78, 0.62, 0.38, a))
	draw_rect(scroll.grow(2.5), ink)
	draw_rect(scroll, Color(0.98, 0.9, 0.7, a))
	draw_rect(Rect2(scroll.position, Vector2(scroll.size.x, 9.0)), Color(1.0, 0.98, 0.88, 0.7 * a))
	draw_rect(Rect2(scroll.position + Vector2(0, scroll.size.y - 6.0), Vector2(scroll.size.x, 6.0)), Color(0.85, 0.7, 0.45, 0.6 * a))
	for sx in [-1.0, 1.0]:
		draw_circle(Vector2(sx * sw / 2.0, sy + 1.0), 7.0, ink)
		draw_circle(Vector2(sx * sw / 2.0, sy + 1.0), 5.0, Color(0.88, 0.72, 0.45, a))
	var tw2 := _text_width(hint, 17)
	var hx := -tw2 / 2.0 + 14.0
	_runner(Vector2(hx - 22.0, sy + 1.0), 10.0, ink)
	draw_string(font, Vector2(hx, sy + 7.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.22, 0.13, 0.06, a))
	# Twinkles around the whole thing.
	for k in 5:
		var sp := Vector2([-260.0, 250.0, -150.0, 170.0, 40.0][k], [-70.0, -60.0, -110.0, -105.0, 80.0][k])
		var tw := maxf(0.0, sin(now * 3.0 + k * 1.9))
		var r := 3.0 + 6.0 * tw
		draw_line(sp - Vector2(r, 0), sp + Vector2(r, 0), Color(1, 0.98, 0.8, tw * a), 2.0)
		draw_line(sp - Vector2(0, r), sp + Vector2(0, r), Color(1, 0.98, 0.8, tw * a), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _title_text(pos: Vector2, text: String, size_px: int, face: Color, drop: Color, ink: Color, width: float) -> void:
	## Cartoon logo lettering: a thick dark outline, a coloured drop under
	## the face and a pale highlight on top.
	var f: Font = title_font if title_font else font
	draw_string_outline(f, pos + Vector2(0, 4), text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, 12, ink)
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, 10, ink)
	draw_string(f, pos + Vector2(0, 4), text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, drop)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, face)


func _inked_star(c: Vector2, r: float, col: Color, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.45))
	var out := pts.duplicate()
	out.append(pts[0])
	draw_colored_polygon(pts, col)
	draw_polyline(out, ink, 2.5)


func _runner(c: Vector2, r: float, col: Color) -> void:
	## A little running figure for the hint line.
	draw_circle(c + Vector2(0.35, -1.0) * r, 0.28 * r, col)
	var w := 0.22 * r
	draw_line(c + Vector2(0.2, -0.65) * r, c + Vector2(-0.15, 0.25) * r, col, w)          # body
	draw_line(c + Vector2(-0.15, 0.25) * r, c + Vector2(0.45, 0.6) * r, col, w)          # front thigh
	draw_line(c + Vector2(0.45, 0.6) * r, c + Vector2(0.35, 1.05) * r, col, w)           # front shin
	draw_line(c + Vector2(-0.15, 0.25) * r, c + Vector2(-0.55, 0.65) * r, col, w)        # back thigh
	draw_line(c + Vector2(-0.55, 0.65) * r, c + Vector2(-1.0, 0.55) * r, col, w)         # back shin
	draw_line(c + Vector2(0.12, -0.45) * r, c + Vector2(0.65, -0.1) * r, col, w)         # front arm
	draw_line(c + Vector2(0.12, -0.45) * r, c + Vector2(-0.45, -0.3) * r, col, w)        # back arm


func _draw_stolen_card() -> void:
	## CROWN STOLEN! A red card under the clock with the thief and a minimap
	## inset that shows where they are.
	var a := clampf(game.stolen_timer / 0.5, 0.0, 1.0)
	var pulse := 1.0 + 0.015 * sin(Time.get_ticks_msec() / 70.0)
	var rect := Rect2(size.x / 2.0 - 230 * pulse, 106, 460 * pulse, 78)
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
	var rect := Rect2(size.x / 2.0 - 230 * pulse, 106, 460 * pulse, 78)
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
	var rect := Rect2(size.x / 2.0 - 170, 106, 340, 78)
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
	var right: float = size.x - 104.0   # clear of the CROWN / KITS / MAP column
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
	var rect := Rect2(size.x / 2.0 - w / 2.0, 120 - (1.0 - pop) * 24.0, w, 66 * scale_k)
	# The burst behind the card.
	draw_arc(rect.get_center(), 40.0 + age * 160.0, 0, TAU, 40, Color(1.0, 0.85, 0.3, maxf(0.5 - age * 1.2, 0.0)), 6.0)
	_plate(rect, Color(0.42, 0.08, 0.08, 0.94 * a), Color(1.0, 0.85, 0.3, a), 12, 3)
	_class_card(rect.position + Vector2(36 * scale_k, rect.size.y / 2.0), 22 * scale_k, p.kill_banner.team, p.kill_banner.role_id, true)
	_text(rect.position + Vector2(68 * scale_k, 30 * scale_k), title, int(26 * scale_k), Color(1.0, 0.95, 0.7, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(rect.position + Vector2(68 * scale_k, 50 * scale_k), "%s the %s  ·  +%d XP" % [p.kill_banner.victim, p.kill_banner.role, Stats.XP_KILL], int(12 * scale_k), sub_color, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	_icon("sword", rect.end - Vector2(30 * scale_k, rect.size.y / 2.0), 12 * scale_k, Color(1.0, 0.85, 0.3, a))


func _draw_toasts() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var y := 120.0 if game.stolen_timer <= 0.0 and game.levelup_timer <= 0.0 else 192.0
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
	var lines := ["Break the enemy castle door", "Break the lock on their Crown Vault", "Carry their crown to your throne",
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


func _crown_glyph(c: Vector2, s: float, glow: float = 0.0, a: float = 1.0) -> void:
	## A chunky five-pointed gold crown with ball tips, a jewelled band and a
	## dark outline, drawn in code; s is half its width. glow adds a soft
	## gold halo behind it.
	if glow > 0.0:
		for i in 4:
			draw_circle(c + Vector2(0, -0.1 * s), s * (1.55 - i * 0.18), Color(1.0, 0.82, 0.3, 0.07 * glow * a))
	var ink := Color(0.3, 0.16, 0.03, a)
	var tips := [Vector2(-1.05, -0.62), Vector2(-0.52, -0.5), Vector2(0, -0.95), Vector2(0.52, -0.5), Vector2(1.05, -0.62)]
	var dips := [-0.02, -0.12, -0.12, -0.02]
	var body := PackedVector2Array([c + Vector2(-0.88, 0.32) * s])
	for i in 5:
		body.append(c + tips[i] * s)
		if i < 4:
			body.append(c + Vector2(lerpf(tips[i].x, tips[i + 1].x, 0.5), dips[i]) * s)
	body.append(c + Vector2(0.88, 0.32) * s)
	var lw := maxf(1.2, s * 0.09)
	var sh := PackedVector2Array()
	for q in body:
		sh.append(q + Vector2(0, lw))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.35 * a))
	draw_colored_polygon(body, Color(1.0, 0.76, 0.18, a))
	# The lit left half and a darker right flank give it some roundness.
	draw_colored_polygon(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], c + Vector2(0, 0.32) * s]), Color(1.0, 0.93, 0.55, 0.45 * a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.5, 0.02) * s, body[7], body[8], body[9], body[10]]), Color(0.75, 0.45, 0.05, 0.35 * a))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, ink, lw)
	for t in tips:
		draw_circle(c + t * s + Vector2(0, -0.08 * s), 0.15 * s, Color(1.0, 0.85, 0.35, a))
		draw_arc(c + t * s + Vector2(0, -0.08 * s), 0.15 * s, 0, TAU, 12, ink, lw * 0.7)
		draw_circle(c + t * s + Vector2(-0.04, -0.12) * s, 0.05 * s, Color(1, 1, 0.9, 0.8 * a))
	var band := Rect2(c + Vector2(-0.9, 0.26) * s, Vector2(1.8, 0.36) * s)
	draw_rect(band, Color(0.92, 0.62, 0.12, a))
	draw_rect(Rect2(band.position, Vector2(band.size.x, band.size.y * 0.4)), Color(1, 0.95, 0.65, 0.5 * a))
	draw_rect(band, ink, false, lw * 0.8)
	for x in [-0.52, 0.0, 0.52]:
		var gc := Color(0.85, 0.1, 0.12, a) if x == 0.0 else Color(0.2, 0.45, 0.95, a)
		var gp := c + Vector2(x, 0.44) * s
		draw_circle(gp, 0.1 * s + 0.5, ink)
		draw_circle(gp, 0.1 * s, gc)
		draw_circle(gp - Vector2(0.03, 0.03) * s, 0.035 * s, Color(1, 1, 1, 0.7 * a))
	var mid := c + Vector2(0, -0.2) * s
	draw_circle(mid, 0.12 * s + 0.5, ink)
	draw_circle(mid, 0.12 * s, Color(0.85, 0.1, 0.12, a))
	draw_circle(mid - Vector2(0.04, 0.04) * s, 0.04 * s, Color(1, 1, 1, 0.7 * a))


func _hooded_head(c: Vector2, r: float, team: int, dead: bool) -> void:
	## Fallback portrait: a chibi face peeking out of a team-coloured hood.
	var hood := _team_color(team).lightened(0.05)
	var skin := Color(0.98, 0.84, 0.7)
	if dead:
		hood = hood.darkened(0.5)
		skin = skin.darkened(0.5)
	draw_circle(c + Vector2(0, r * 0.85), r * 0.75, hood.darkened(0.25))   # shoulders
	draw_circle(c + Vector2(0, -r * 0.05), r * 0.78, hood)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.8), c + Vector2(r * 0.25, -r * 1.05), c + Vector2(r * 0.3, -r * 0.6)]), hood)
	draw_arc(c + Vector2(0, -r * 0.05), r * 0.78, PI * 1.05, PI * 1.6, 12, hood.lightened(0.3), r * 0.06)
	draw_circle(c + Vector2(0, r * 0.08), r * 0.55, skin)
	draw_arc(c + Vector2(0, r * 0.08), r * 0.57, PI * 1.08, PI * 1.92, 16, GOLD, r * 0.06)
	_arc_polygon(c + Vector2(0, r * 0.02), r * 0.52, PI * 1.05, PI * 1.95, Color(0.42, 0.26, 0.12))   # fringe
	for side in [-1.0, 1.0]:
		draw_circle(c + Vector2(side * 0.22 * r, r * 0.16), 0.085 * r, Color(0.12, 0.08, 0.06))
		draw_circle(c + Vector2(side * 0.22 * r - 0.03 * r, r * 0.13), 0.03 * r, Color.WHITE)
	draw_arc(c + Vector2(0, r * 0.36), 0.09 * r, 0.3, PI - 0.3, 8, Color(0.45, 0.2, 0.12), 1.2)


func _medallion(c: Vector2, r: float, team: int, role: int, dead: bool) -> void:
	## The player's portrait in a round gold ring: the owner's class card
	## cropped to the face, or a drawn hooded head.
	draw_circle(c + Vector2(0, 3), r + 8, Color(0, 0, 0, 0.4))
	draw_circle(c, r + 7, Color(0.3, 0.17, 0.04))
	draw_circle(c, r + 5.5, BRASS)
	draw_arc(c, r + 4.5, PI * 1.0, PI * 1.85, 24, GOLD.lightened(0.35), 1.6)
	draw_arc(c, r + 4.5, PI * 0.1, PI * 0.8, 24, Color(0.5, 0.3, 0.06), 1.6)
	draw_circle(c, r + 1.5, Color(0.25, 0.14, 0.03))
	var bg := _team_color(team).darkened(0.55)
	var grad := PackedVector2Array()
	var gcols := PackedColorArray()
	for i in 32:
		var ang := TAU * i / 32.0
		grad.append(c + Vector2(cos(ang), sin(ang)) * r)
		gcols.append(bg.lightened(0.25) if sin(ang) < 0.0 else bg)
	draw_polygon(grad, gcols)
	var key := _card_key(team, role)
	if cards.has(key):
		var tex: Texture2D = cards[key]
		var ts := tex.get_size()
		var side := ts.x * 0.66
		var src := Rect2(Vector2(ts.x * 0.56 - side / 2.0, ts.y * 0.2 - side / 2.0), Vector2(side, side))
		src.position.y = maxf(src.position.y, 0.0)
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var tint := Color(0.4, 0.4, 0.42) if dead else Color.WHITE
		for q in grad:
			uvs.append((src.position + src.size * (Vector2(0.5, 0.5) + (q - c) / (2.0 * r))) / ts)
			cols.append(tint)
		draw_polygon(grad, cols, uvs, tex)
	else:
		_hooded_head(c, r * 0.95, team, dead)
	draw_arc(c, r, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.18), r * 0.12)
	draw_arc(c, r + 0.5, 0, TAU, 48, Color(0.25, 0.14, 0.03), 2.0)
	for ang in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var q := c + Vector2(cos(ang), sin(ang)) * (r + 4.0)
		draw_circle(q, 2.2, Color(1, 0.92, 0.6))
		draw_arc(q, 2.2, 0, TAU, 8, Color(0.35, 0.2, 0.04), 0.8)


func _small_plate(rect: Rect2, text: String, fs: int) -> void:
	## A small dark plate in a gold rim with cream text: the "LV 1" tag.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.07)
	sb.set_corner_radius_all(int(rect.size.y / 2.0) - 1)
	sb.set_border_width_all(2)
	sb.border_color = BRASS
	sb.shadow_size = 3
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(0, 2)
	draw_style_box(sb, rect)
	draw_rect(Rect2(rect.position + Vector2(rect.size.y / 2.0, 2), Vector2(rect.size.x - rect.size.y, 1)), Color(1, 0.9, 0.6, 0.4))
	_text(Vector2(rect.position.x, rect.get_center().y + fs * 0.36), text, fs, CREAM, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 3)


func _ring_button(c: Vector2, r: float, hot: float = 0.0) -> void:
	## A round dark button in a gold ring with small gold spikes round it.
	if hot > 0.0:
		for i in 5:
			draw_circle(c, r + 8.0 + i * 3.0, Color(1.0, 0.8, 0.25, 0.06 * hot))
	draw_circle(c + Vector2(0, 3), r + 6, Color(0, 0, 0, 0.4))
	for deg in [-90.0, -35.0, -145.0, 10.0, 170.0, 55.0, 125.0]:
		var ang := deg_to_rad(deg)
		var d := Vector2(cos(ang), sin(ang))
		var t := Vector2(-d.y, d.x)
		var tip := PackedVector2Array([c + d * (r + 10.0), c + d * (r + 2.0) + t * 4.5, c + d * (r + 2.0) - t * 4.5])
		draw_colored_polygon(tip, BRASS)
		tip.append(tip[0])
		draw_polyline(tip, Color(0.3, 0.17, 0.04), 1.0)
	draw_circle(c, r + 5, Color(0.3, 0.17, 0.04))
	draw_circle(c, r + 3.5, BRASS)
	draw_arc(c, r + 2.8, PI * 1.0, PI * 1.85, 24, GOLD.lightened(0.35), 1.4)
	draw_circle(c, r, Color(0.2, 0.12, 0.07))
	draw_circle(c, r - 2, Color(0.13, 0.08, 0.05))
	_arc_polygon(c, r - 2, PI, TAU, Color(1, 0.9, 0.7, 0.06))
	draw_arc(c, r - 1, 0, TAU, 32, Color(0.62, 0.44, 0.16, 0.6), 1.0)


func _count_badge(c: Vector2, n: int) -> void:
	## A small cream square with a number: the kits left.
	var r := Rect2(c - Vector2(9, 9), Vector2(18, 18))
	_plate(r, CREAM, Color(0.35, 0.22, 0.08), 4, 2)
	_text(r.position + Vector2(0, 14), str(n), 13, Color(0.15, 0.1, 0.06), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0)


func _chest_glyph(c: Vector2, s: float) -> void:
	## A leather kit case with a brass clasp (s ≈ half its width).
	var body := Rect2(c + Vector2(-s, -0.45 * s), Vector2(2.0 * s, 1.3 * s))
	draw_arc(c + Vector2(0, -0.45 * s), 0.38 * s, PI, TAU, 12, Color(0.32, 0.18, 0.06), 0.16 * s)
	_plate(body, Color(0.72, 0.45, 0.2), Color(0.3, 0.16, 0.05), int(0.25 * s), 2)
	draw_rect(Rect2(body.position + Vector2(2, 2), Vector2(body.size.x - 4, body.size.y * 0.42)), Color(0.85, 0.58, 0.3))
	draw_line(body.position + Vector2(2, body.size.y * 0.45), Vector2(body.end.x - 2, body.position.y + body.size.y * 0.45), Color(0.3, 0.16, 0.05), 1.5)
	var clasp := Rect2(c + Vector2(-0.22 * s, -0.05 * s), Vector2(0.44 * s, 0.4 * s))
	draw_rect(clasp, GOLD)
	draw_rect(clasp, Color(0.35, 0.2, 0.04), false, 1.2)
	draw_circle(clasp.get_center(), 0.06 * s + 0.5, Color(0.35, 0.2, 0.04))


func _right_buttons(p, W: float) -> void:
	## The right-edge column: CROWN (glowing while you carry one), KITS with
	## the fortify kits left on a badge, and the map on M.
	var x := W - 50.0
	var r := 26.0
	var carrying: bool = p.carrying != null and not p.dead
	var now := Time.get_ticks_msec() / 1000.0
	var ys := [62.0, 166.0, 270.0]
	# CROWN
	var hot := (0.7 + 0.3 * sin(now * 4.0)) if carrying else 0.0
	_ring_button(Vector2(x, ys[0]), r, hot)
	_crown_glyph(Vector2(x, ys[0] + 3), r * 0.66, 1.0 if carrying else 0.0)
	_text(Vector2(x - 40, ys[0] + r + 20), "CROWN", 14, Color(1.0, 0.95, 0.82), HORIZONTAL_ALIGNMENT_CENTER, 80, 5)
	# KITS
	_ring_button(Vector2(x, ys[1]), r)
	_chest_glyph(Vector2(x, ys[1] + 1), r * 0.6)
	var kits: int = game.barricades_left[p.team]
	if kits > 0:
		_count_badge(Vector2(x + r * 0.85, ys[1] + r * 0.75), kits)
	_text(Vector2(x - 40, ys[1] + r + 20), "KITS", 14, Color(1.0, 0.95, 0.82), HORIZONTAL_ALIGNMENT_CENTER, 80, 5)
	# MAP
	_ring_button(Vector2(x, ys[2]), r)
	_map_glyph(Vector2(x, ys[2]), 1.25)
	# No key of its own: the map is the pause menu's first tab.
	_text(Vector2(x - 40, ys[2] + r + 20), "MAP", 14, Color(1.0, 0.95, 0.82), HORIZONTAL_ALIGNMENT_CENTER, 80, 5)


func _draw_player_panel(p) -> void:
	## The bottom row, laid out like the HUD target (2026-10-07): bottom-left
	## a gold-trimmed level shield on a compact dark panel (hearts and the
	## energy bar on one row, experience underneath); bottom centre-right the
	## ability strip on its own gold-framed board; the map, bag and menu
	## buttons in the corner. All of it shrinks together in narrow panes.
	var k := minf(1.0, size.x / 1280.0)
	hud_scale = k
	var W := size.x / k
	var H := size.y / k
	if k < 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var panel := Rect2(Vector2(116, H - 100), Vector2(430, 66))
	_status_panel(p, panel)
	_right_buttons(p, W)
	var buttons_w := 3.0 * 42.0 + 2.0 * 8.0
	var bx := W - 22.0 - buttons_w
	_corner_buttons(Vector2(bx, H - 89))
	_ability_strip(p, Rect2(Vector2(bx - 30.0 - 470.0, H - 122), Vector2(470, 110)))
	_status_tags(p, panel)
	if k < 1.0:
		draw_set_transform(Vector2.ZERO)


func _status_tags(p, panel: Rect2) -> void:
	## Tags above the player panel: a blessing or spawn protection, a rank
	## point waiting and the veteran streak.
	var tag_x := panel.position.x - 40.0
	var tag_y := panel.position.y - 34.0
	if p.buff != "" and p.buff_timer > 0.0:
		var bc: Color = Stats.BLESSING_KINDS[p.buff].color
		var badge := Rect2(Vector2(tag_x, tag_y), Vector2(222, 24))
		_plate(badge, bc.darkened(0.7), bc, 8, 2)
		_icon(Stats.BLESSING_KINDS[p.buff].icon, badge.position + Vector2(16, 12), 9, Color.WHITE)
		_text(badge.position + Vector2(32, 17), "BLESSING OF %s" % p.buff.to_upper(), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_text(badge.position + Vector2(0, 17), "%ds" % ceili(p.buff_timer), 11, bc.lightened(0.3), HORIZONTAL_ALIGNMENT_RIGHT, badge.size.x - 10, 2)
		draw_rect(Rect2(badge.position + Vector2(4, badge.size.y - 4), Vector2((badge.size.x - 8) * p.buff_timer / Stats.BLESSING_DURATION, 2)), bc)
		tag_x += 230.0
	elif p.spawn_protect > 0.0 and not p.dead:
		var sp := Rect2(Vector2(tag_x, tag_y), Vector2(170, 24))
		_plate(sp, Color(0.1, 0.25, 0.4, 0.95), Color(0.6, 0.85, 1.0), 8, 1)
		_icon("guard", sp.position + Vector2(14, 12), 7, Color.WHITE)
		_text(sp.position + Vector2(26, 17), "SPAWN PROTECTED  %d" % ceili(p.spawn_protect), 10, Color(0.85, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		tag_x += 178.0
	if p.points > 0 and not p.dead:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		var badge := Rect2(Vector2(tag_x, tag_y), Vector2(132, 24))
		_plate(badge, Color(0.55, 0.4, 0.05, pulse), GOLD, 8, 1)
		_icon("xp", badge.position + Vector2(14, 12), 7, Color.WHITE)
		_text(badge.position + Vector2(26, 17), "%s  RANK UP  +%d" % [_k("rank_menu"), p.points], 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		tag_x += 140.0
	if p.veteran > 0 and not p.dead:
		var vb := Rect2(Vector2(maxf(tag_x, panel.end.x - 224.0), tag_y), Vector2(224, 24))
		var vc := Color(1.0, 0.55, 0.2) if p.veteran == 2 else Color(1.0, 0.85, 0.3)
		_plate(vb, vc.darkened(0.7), vc, 8, 2)
		_icon("crown" if p.veteran == 2 else "xp", vb.position + Vector2(16, 12), 8, Color.WHITE)
		_text(vb.position + Vector2(30, 17), ("ELITE VETERAN · BOUNTY ON YOU" if p.veteran == 2 else "VETERAN") + "  ·  %d streak" % p.streak, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	elif p.streak >= 2 and not p.dead:
		_text(Vector2(panel.end.x, tag_y + 17), "%d kill streak" % p.streak, 11, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, -1, 3)


func _gold_corners(rect: Rect2, arm: float, thick: float) -> void:
	## Gold L-brackets with a rivet on the four corners of a frame.
	for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var dx := 1.0 if c.x < rect.get_center().x else -1.0
		var dy := 1.0 if c.y < rect.get_center().y else -1.0
		var o: Vector2 = c + Vector2(-dx * 2, -dy * 2)
		var cap := PackedVector2Array([o, o + Vector2(dx * arm, 0), o + Vector2(dx * (arm - 3), dy * thick), o + Vector2(dx * thick, dy * thick),
			o + Vector2(dx * thick, dy * (arm - 3)), o + Vector2(0, dy * arm)])
		draw_colored_polygon(cap, BRASS)
		draw_colored_polygon(PackedVector2Array([o, o + Vector2(dx * arm, 0), o + Vector2(dx * (arm - 1), dy * 2.5), o + Vector2(dx * 2.5, dy * 2.5),
			o + Vector2(dx * 2.5, dy * (arm - 1)), o + Vector2(0, dy * arm)]), GOLD.lightened(0.2))
		cap.append(cap[0])
		draw_polyline(cap, Color(0.35, 0.2, 0.04), 1.2)
		draw_circle(o + Vector2(dx, dy) * (thick * 0.55 + 1.0), 1.8, Color(1, 0.93, 0.65))


func _dark_frame(rect: Rect2, radius: int = 8) -> void:
	## A dark leather-black plate in a thin gold rim with a darker outer bevel.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.06, 0.94)
	sb.set_corner_radius_all(radius + 2)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.03, 0.02, 0.01)
	sb.shadow_size = 7
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(0, 2)
	draw_style_box(sb, rect.grow(3))
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.12, 0.1, 0.09, 0.96)
	fb.set_corner_radius_all(radius)
	fb.set_border_width_all(2)
	fb.border_color = BRASS
	draw_style_box(fb, rect)
	draw_rect(Rect2(rect.position + Vector2(radius, 2), Vector2(rect.size.x - radius * 2, 1)), Color(1, 0.9, 0.6, 0.35))
	draw_rect(rect.grow(-4), Color(0.5, 0.35, 0.12, 0.35), false, 1.0)


func _level_badge(c: Vector2, w: float, h: float, level: int) -> void:
	## The player's level on a gold-trimmed dark heater shield.
	var pts := _shield_shape(c, w, h)
	var scaled := func(f: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts:
			out.append(c + (q - c) * f)
		return out
	var shadow: PackedVector2Array = scaled.call(1.16)
	for i in shadow.size():
		shadow[i] += Vector2(0, 3)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	var rim: PackedVector2Array = scaled.call(1.14)
	draw_colored_polygon(rim, Color(0.35, 0.2, 0.04))
	draw_colored_polygon(scaled.call(1.1), BRASS)
	draw_colored_polygon(scaled.call(1.02), Color(0.3, 0.18, 0.05))
	draw_colored_polygon(pts, Color(0.13, 0.11, 0.12))
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], c + Vector2(w / 2.0, -h * 0.12), c + Vector2(-w / 2.0, 0)]), Color(1, 1, 1, 0.06))
	var hi: PackedVector2Array = scaled.call(1.07)
	hi.append(hi[0])
	draw_polyline(hi, GOLD.lightened(0.3), 1.0)
	var inner: PackedVector2Array = scaled.call(0.86)
	inner.append(inner[0])
	draw_polyline(inner, Color(0.62, 0.45, 0.16, 0.6), 1.0)
	_text(Vector2(c.x - w / 2.0, c.y + 2), "LV %d" % level, 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, w, 4)


func _status_panel(p, panel: Rect2) -> void:
	## Bottom-left, like Faisal's UI reference (2026-10-08): the portrait in
	## a gold ring wrapped in a laurel wreath, big glossy hearts beside it,
	## a slim stamina (or mana) bar and the gold experience bar under them.
	## No backing panel: it all sits straight on the world.
	var x0 := panel.position.x + 14.0
	var row_y := panel.position.y + 8.0
	for i in Stats.MAX_HEARTS:
		_big_heart(Vector2(x0 + 24.0 + i * 46.0, row_y), 1.0, i < (0 if p.dead else p.hearts))
	# The two bars share a bronze-framed dark block (the 2026-10-08
	# reference): the energy bar with its numbers, the experience bar under.
	var bar := Rect2(Vector2(x0 + 4.0, panel.position.y + 30.0), Vector2(Stats.MAX_HEARTS * 42.0 + 90.0, 18.0))
	_dark_frame(Rect2(bar.position - Vector2(4, 4), Vector2(bar.size.x + 8, 48)), 6)
	if p.dead:
		var msg := "Down for the rest of overtime" if game.overtime else "Down! Back in %d" % ceili(p.respawn_timer)
		_text(Vector2(bar.position.x, bar.position.y + 14.0), msg, 12, Color(1, 0.7, 0.6), HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 3)
	else:
		var is_mana: bool = p.energy_kind() == "mana"
		_meter(bar, p.energy / p.energy_max(), (MANA if is_mana else STAMINA).darkened(0.05))
		_text(Vector2(bar.position.x, bar.position.y + 14.0), "%d/%d" % [roundi(p.energy), roundi(p.energy_max())], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 3)
	_draw_xp_bar(p, Rect2(Vector2(x0 + 4.0, panel.position.y + 52.0), Vector2(bar.size.x, 18.0)))
	var name_tag := ""
	if p.local_index > 0:
		name_tag = "PLAYER %d" % (p.local_index + 1)
	elif game.hero_name != "":
		name_tag = game.hero_name.to_upper()
	if name_tag != "":
		_text(Vector2(x0 + 4.0, panel.position.y - 12.0), name_tag, 11, Color(1.0, 0.9, 0.62), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	# The portrait in its laurel wreath, the level on a small plate below.
	var mc := Vector2(panel.position.x - 46.0, panel.get_center().y)
	_laurel(mc + Vector2(0, 14), -1.0, 1.0, 52.0, 44.0)
	_laurel(mc + Vector2(0, 14), 1.0, 1.0, 52.0, 44.0)
	_medallion(mc, 44.0, p.team, p.role, p.dead)
	_small_plate(Rect2(mc + Vector2(-24, 38), Vector2(48, 20)), "LV %d" % p.level, 12)


func _big_heart(c: Vector2, scale: float, full: bool) -> void:
	## A chunky glossy heart with a thick dark outline; an empty one is a
	## dark hollow.
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * scale)
	var sh := PackedVector2Array()
	for q in pts:
		sh.append(q + Vector2(0, 3))
	for i in sh.size():
		sh[i] = c + (sh[i] - c) * 1.26
	draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	# A thick dark maroon border (Faisal 2026-10-08: "more of a border")
	# with a thin warm rim inside it.
	var outline := PackedVector2Array()
	var rim := PackedVector2Array()
	for q in pts:
		outline.append(c + (q - c) * 1.26 + Vector2(0, 1.0 * scale))
		rim.append(c + (q - c) * 1.11)
	draw_colored_polygon(outline, Color(0.17, 0.03, 0.04))
	draw_colored_polygon(rim, Color(0.52, 0.12, 0.1) if full else Color(0.33, 0.12, 0.1))
	if full:
		var cols := PackedColorArray()
		for q in pts:
			cols.append(Color(1.0, 0.3, 0.32) if q.y < c.y - 2.0 * scale else Color(0.78, 0.06, 0.12))
		draw_polygon(pts, cols)
		draw_circle(c + Vector2(-6.5, -6.0) * scale, 3.6 * scale, Color(1, 1, 1, 0.75))
		draw_circle(c + Vector2(-2.0, -8.0) * scale, 1.6 * scale, Color(1, 1, 1, 0.5))
	else:
		draw_colored_polygon(pts, Color(0.2, 0.08, 0.1))
		draw_circle(c + Vector2(-6.5, -6.0) * scale, 3.0 * scale, Color(1, 1, 1, 0.08))


func _meter(rect: Rect2, fraction: float, color: Color) -> void:
	## A bright glossy fill in a sunk dark trough with a thin bronze edge.
	_plate(rect, Color(0.05, 0.04, 0.04), Color(0.4, 0.3, 0.14), 4, 1)
	var inner := rect.grow(-2)
	var w := inner.size.x * clampf(fraction, 0.0, 1.0)
	if w > 0.0:
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), color.darkened(0.1))
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y * 0.45)), color.lightened(0.18))
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 3), Vector2(w, 3)), color.darkened(0.4))


func _draw_xp_bar(p, bar: Rect2) -> void:
	## Experience this life: a slim blue bar with the count in the middle
	## and the next level on a small plate with a star at the right end; it
	## glows gold while a rank point is waiting to be spent.
	var span: Array = Stats.xp_span(p.level)
	var frac := 1.0 if span[1] < 0 else clampf(float(p.xp - span[0]) / float(span[1] - span[0]), 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var hot: bool = p.points > 0 and not p.dead
	var edge := GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 6.0)) if hot else BRASS
	var lv_w := 0.0
	var track := Rect2(bar.position, Vector2(bar.size.x - lv_w, bar.size.y))
	_plate(track, Color(0.05, 0.05, 0.08), edge, 4, 1)
	var inner := track.grow(-2)
	var fill_w := inner.size.x * frac
	if fill_w > 0.5:
		var col := Color(0.98, 0.72, 0.12)
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), col)
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y * 0.45)), Color(1.0, 0.8, 0.4))
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 3), Vector2(fill_w, 3)), col.darkened(0.35))
		draw_rect(Rect2(inner.position.x + fill_w - 2, inner.position.y, 2, inner.size.y), Color(1, 0.95, 0.75, 0.8))
	var ty := bar.position.y + bar.size.y - 3.0
	var xp_text := "MAX LEVEL" if span[1] < 0 else "%d / %d XP" % [p.xp, span[1]]
	if hot:
		xp_text += "  ·  %d RANK POINT%s READY" % [p.points, "" if p.points == 1 else "S"]
	_text(Vector2(track.position.x, ty), xp_text, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, track.size.x, 3)
	if lv_w > 0.0 and span[1] >= 0:
		var lv := Rect2(Vector2(track.end.x + 3, bar.position.y), Vector2(lv_w - 3, bar.size.y))
		_plate(lv, Color(0.05, 0.05, 0.08), Color(0.3, 0.24, 0.14), 4, 1)
		_text(Vector2(lv.position.x + 3, ty), "LV %d" % (p.level + 1), 11, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		_star(Vector2(lv.end.x - 6, lv.position.y + 4), 4.5, GOLD)


func _ability_strip(p, strip: Rect2) -> void:
	## The ability bar on its own gold-framed wooden board: attack, dodge,
	## the two class abilities, perks (or block for shield classes) and grab,
	## each slot with its keycap under the icon and its name below.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.03)
	sb.set_corner_radius_all(10)
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(0, 3)
	draw_style_box(sb, strip.grow(3))
	var wb := StyleBoxFlat.new()
	wb.bg_color = WOOD_DARK
	wb.set_corner_radius_all(8)
	wb.set_border_width_all(3)
	wb.border_color = BRASS
	draw_style_box(wb, strip)
	var board := strip.grow(-4)
	for i in 4:
		var y := board.position.y + board.size.y * i / 4.0
		draw_rect(Rect2(Vector2(board.position.x + 3, y + 1), Vector2(board.size.x - 6, board.size.y / 4.0 - 1)),
			Color(1, 0.8, 0.55, 0.05) if i % 2 == 0 else Color(0, 0, 0, 0.1))
		if i > 0:
			draw_line(Vector2(board.position.x + 3, y), Vector2(board.end.x - 3, y), Color(0.12, 0.06, 0.02, 0.7), 1.5)
	draw_rect(Rect2(strip.position + Vector2(10, 2), Vector2(strip.size.x - 20, 1)), GOLD.lightened(0.35))
	draw_rect(strip.grow(-6), Color(0.62, 0.44, 0.16, 0.4), false, 1.0)
	_gold_corners(strip.grow(2), 22.0, 6.0)
	_ivy(strip.position + Vector2(4, 2), Vector2(1, 0), 70.0, 3)
	_ivy(Vector2(strip.end.x - 4, strip.position.y + 2), Vector2(-1, 0), 70.0, 6)
	# Gold scroll curls hung off the two ends.
	for side in [-1.0, 1.0]:
		var ex: float = strip.position.x if side < 0.0 else strip.end.x
		var cc := Vector2(ex + side * 3.0, strip.get_center().y + 6.0)
		draw_arc(cc, 6.0, 0, TAU, 16, Color(0.35, 0.2, 0.04), 4.0)
		draw_arc(cc, 6.0, 0, TAU, 16, BRASS, 2.2)
		draw_circle(cc, 2.2, GOLD.lightened(0.2))
	# Slots: attack, dodge, Q, E, perks (or block), grab.
	var abil: Array = p.abilities()
	var slot := 52.0
	var gap := 72.0
	var sx := strip.get_center().x - (5.0 * gap + slot) / 2.0
	var sy := strip.position.y + 20.0
	if not pane:
		var acts := ["attack", "dodge", "ability_1", "ability_2", "block" if p.can_block() else "rank_menu", "interact"]
		for i in 6:
			touch_rects.append([Rect2(Vector2(sx + i * gap, sy) * hud_scale, Vector2(slot, slot + 22.0) * hud_scale), acts[i]])
	var alive: bool = not p.dead and p.carrying == null
	var atk: Dictionary = p.attack_stats()
	var cost_c: Color = STAMINA if p.energy_kind() == "stamina" else MANA
	if _attack_icon(p.role, atk) == "fist":
		next_slot_art = "punch"
	_slot(Vector2(sx, sy), slot, _attack_icon(p.role, atk), Color(0.86, 0.16, 0.14), _k("attack"), atk.attack_name,
		p.attack_timer, atk.cooldown, alive and p.energy >= atk.cost, p.rank(0), false, atk.cost, cost_c)
	next_slot_art = "dodge"
	_slot(Vector2(sx + gap, sy), slot, "dodge", Color(0.22, 0.68, 0.18), _k("dodge"), "Dodge", p.dodge_cooldown, Stats.DODGE_COOLDOWN,
		alive and p.energy >= Stats.DODGE_COST)
	for i in 2:
		var at := Vector2(sx + (i + 2) * gap, sy)
		if i < abil.size():
			var a: Dictionary = p.ability(i)
			_slot(at, slot, a.get("icon", a.kind), Stats.ROLES[p.role].color.darkened(0.15), _k("ability_%d" % (i + 1)), a.name,
				p.ability_timers[i], a.cooldown, p.energy >= a.cost and alive, p.rank(i + 1), false, a.cost, cost_c)
		else:
			next_slot_art = ["lock_a", "lock_b"][i]
			_slot(at, slot, "", [Color(0.5, 0.3, 0.72), Color(0.62, 0.38, 0.22)][i], _k("ability_%d" % (i + 1)), "Locked", 0.0, 1.0, false)
	if p.can_block():
		_slot(Vector2(sx + 4 * gap, sy), slot, "block", Color(0.45, 0.5, 0.6), _k("block"), "Block", 0.0, 1.0, alive and p.energy > 0.0, 0, p.blocking)
	else:
		next_slot_art = "perks"
		_slot(Vector2(sx + 4 * gap, sy), slot, "vigor", Color(0.78, 0.1, 0.16), _k("rank_menu"), "Perks", 0.0, 1.0, true, p.rank(3), false, 0.0, STAMINA, p.points > 0)
	next_slot_art = "drop"
	_slot(Vector2(sx + 5 * gap, sy), slot, "crown", Color(0.92, 0.66, 0.16), _k("interact"), "Drop" if p.carrying else "Grab", 0.0, 1.0, not p.dead,
		0, false, 0.0, STAMINA, p.carrying != null and not p.dead)


func _corner_buttons(origin: Vector2) -> void:
	## Map, bag and menu: three small gold-rimmed squares in the corner with
	## an icon drawn in code and the key under each. The map opens the pause
	## menu (its first tab is the map) and the list holds up the scoreboard;
	## the bag is decoration until there is an inventory.
	var pad: bool = game.on_pad(local_unit)
	var keys := [_k("menu"), "" if pad else "I", _k("scoreboard")]
	for i in 3:
		var r := Rect2(origin + Vector2(i * 50.0, 0), Vector2(42, 42))
		if not pane:
			touch_rects.append([Rect2(r.position * hud_scale, r.size * hud_scale), ["menu", "", "scoreboard"][i]])
		_plate(r.grow(3), Color(0.06, 0.04, 0.03), Color(0.03, 0.02, 0.01), 8, 1)
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0.2, 0.13, 0.08)
		fb.set_corner_radius_all(7)
		fb.set_border_width_all(2)
		fb.border_color = BRASS
		draw_style_box(fb, r)
		draw_rect(Rect2(r.position + Vector2(4, 3), Vector2(r.size.x - 8, r.size.y * 0.4)), Color(1, 0.9, 0.7, 0.07))
		draw_rect(Rect2(r.position + Vector2(6, 2), Vector2(r.size.x - 12, 1)), GOLD.lightened(0.35))
		var c := r.get_center() + Vector2(0, -3)
		match i:
			0: _map_glyph(c)
			1: _bag_glyph(c)
			2:
				for j in 3:
					var y := c.y - 7.0 + j * 7.0
					draw_line(Vector2(c.x - 10, y + 1), Vector2(c.x + 10, y + 1), Color(0, 0, 0, 0.5), 3.5)
					draw_line(Vector2(c.x - 10, y), Vector2(c.x + 10, y), Color(0.95, 0.85, 0.6), 3.2)
		if keys[i] != "" and keys[i] != "-":
			_keycap(Vector2(r.get_center().x, r.end.y + 4), keys[i], maxf(20.0, _text_width(keys[i], 11) + 10.0))


func _map_glyph(c: Vector2, k: float = 1.0) -> void:
	## A folded parchment map with a red route and a pin (k scales it).
	var pts := [Vector2(-11, -8), Vector2(-4, -11), Vector2(4, -8), Vector2(11, -11), Vector2(11, 8), Vector2(4, 11), Vector2(-4, 8), Vector2(-11, 11)]
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(c + q * k)
	draw_colored_polygon(outline, PARCHMENT)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -11) * k, c + Vector2(4, -8) * k, c + Vector2(4, 11) * k, c + Vector2(-4, 8) * k]), PARCHMENT.darkened(0.15))
	outline.append(outline[0])
	draw_polyline(outline, Color(0.35, 0.22, 0.08), 1.5 * k)
	draw_polyline(PackedVector2Array([c + Vector2(-8, 5) * k, c + Vector2(-3, 0) * k, c + Vector2(2, 3) * k, c + Vector2(7, -4) * k]), Color(0.75, 0.2, 0.15), 1.4 * k)
	draw_circle(c + Vector2(7, -5) * k, 2.4 * k, RED)


func _bag_glyph(c: Vector2) -> void:
	## A leather satchel with a flap and a brass buckle.
	draw_arc(c + Vector2(0, -6), 6.0, PI, TAU, 10, Color(0.35, 0.2, 0.08), 2.5)
	var body := Rect2(c + Vector2(-11, -6), Vector2(22, 18))
	_plate(body, Color(0.62, 0.4, 0.2), Color(0.3, 0.17, 0.06), 5, 1)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -5), c + Vector2(11, -5), c + Vector2(9, 3), c + Vector2(-9, 3)]), Color(0.72, 0.48, 0.25))
	draw_line(c + Vector2(-9, 3), c + Vector2(9, 3), Color(0.3, 0.17, 0.06), 1.2)
	draw_rect(Rect2(c + Vector2(-2.5, 1), Vector2(5, 5)), BRASS)
	draw_rect(Rect2(c + Vector2(-2.5, 1), Vector2(5, 5)), Color(0.35, 0.2, 0.04), false, 1.0)


func _hide_world_prompts() -> void:
	## The floating Label3D prompts over the class hats and the guide stay in
	## the scene (their scripts drive them) but are made invisible: the HUD
	## draws its own F prompt pill for them, per player.
	for team in 2:
		var gd = game.guides[team] if team < game.guides.size() else null
		if gd and gd.prompt and gd.prompt.transparency < 1.0:
			gd.prompt.transparency = 1.0
		for role in game.seals[team]:
			var s = game.seals[team][role]
			if s and s.prompt and s.prompt.transparency < 1.0:
				s.prompt.transparency = 1.0


func _draw_world_prompt() -> void:
	## When this HUD's player stands where F (interact) does something, a
	## small dark pill with the key and the action hangs over the thing.
	var me = _me()
	if me == null or me.dead or game.guide_open or game.menu_open:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var text := ""
	var at := Vector3.INF
	var key := true
	var gd = game.guides[me.team]
	if me.carrying == null and gd and gd.in_reach(me):
		text = "TALK"
		at = gd.global_position + Vector3(0, 2.4, 0)
	if text == "" and me.carrying == null:
		for role in game.seals[me.team]:
			var s = game.seals[me.team][role]
			if s.in_reach(me):
				at = s.global_position + Vector3(0, 2.5, 0)
				if s.locked:
					text = "LOCKED · ACCOUNT LEVEL %d" % Stats.UNLOCK_LEVEL
					key = false
				elif me.role == role:
					text = "YOUR HAT"
					key = false
				else:
					text = "TAKE THE %s'S HAT" % s.class_title().to_upper()
				break
	if text == "" and me.carrying == null and game.prep_left <= 0.0:
		var m = game.monarchs[1 - me.team]
		var flat := Vector2(me.global_position.x - m.global_position.x, me.global_position.z - m.global_position.z).length()
		# 1.8 m is Unit.PICKUP_RANGE, the reach of a grab.
		if m.state != Monarch.State.CARRIED and flat < 1.8 and not (m.state == Monarch.State.HOME and game.vaults[1 - me.team].is_locked()):
			text = "GRAB CROWN"
			at = m.global_position + Vector3(0, 2.3, 0)
	if text == "" or cam.is_position_behind(at):
		return
	var sp: Vector2 = get_global_transform().affine_inverse() * cam.unproject_position(at)
	var k := "" if not key else _k("interact")
	var kw := 0.0 if k == "" else maxf(20.0, _text_width(k, 11) + 10.0)
	var w := _text_width(text, 13) + kw + (32.0 if kw > 0.0 else 24.0)
	var r := Rect2(sp - Vector2(w / 2.0, 14), Vector2(w, 28))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.1, 0.88)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.5, 0.42, 0.8)
	sb.shadow_size = 4
	sb.shadow_color = Color(0, 0, 0, 0.35)
	draw_style_box(sb, r)
	draw_rect(Rect2(r.position + Vector2(6, 1), Vector2(r.size.x - 12, 1)), Color(1, 1, 1, 0.12))
	var tx := r.position.x + 11.0
	if kw > 0.0:
		_keycap(Vector2(tx + kw / 2.0, sp.y), k, kw)
		tx += kw + 8.0
	_text(Vector2(tx, sp.y + 5.0), text, 13, Color(0.97, 0.95, 0.88), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


# --- Map ---------------------------------------------------------------------

func _draw_map(rect: Rect2, detailed: bool) -> void:
	## The valley from above: forest, the river with its bridges and the Crown
	## Shrine island, roads and paths, ruins, castles with their cellars,
	## doors, potions, blessings, and everyone the team can see. Enemies show
	## only near a teammate, except Elite Veterans, who are always revealed.
	var hx: float = game.map_half.x
	if detailed:
		# Room for the spawn cellars, which reach past the playfield's edge.
		hx = maxf(hx, game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH + 1.0)
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
	if game.vmap:
		# Ember Pass: lava, the plateaus and the bridge network instead of the valley.
		draw_rect(inner, _lava_glow(pt))
		var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)])
		var o: Vector2 = m.call(Vector3.ZERO)
		var ax: Vector2 = m.call(Vector3(1, 0, 0)) - o
		var az: Vector2 = m.call(Vector3(0, 0, 1)) - o
		_draw_lava_plates(o, ax, az, func(q: Vector2) -> bool: return inner.grow(30.0).has_point(q), box, pt)
		_volcano_network(inner.get_center(), inner.size.length(), m, box, sx, pt, detailed)
	# Forest.
	for t in game.map_trees:
		var r: float = (2.6 if t.y > 0.5 else 1.8) * sx
		if not inner.grow(-r).has_point(m.call(t)):
			continue
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
	if game.vmap == null:
		_draw_map_river(m, sx, sz, hz, detailed)
	_draw_map_castles(rect, m, sx, sz, fx, detailed)


func _draw_map_river(m: Callable, sx: float, sz: float, hz: float, detailed: bool) -> void:
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


func _draw_map_castles(rect: Rect2, m: Callable, sx: float, sz: float, fx: float, detailed: bool) -> void:
	var pt := Time.get_ticks_msec() / 1000.0
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
		if detailed:
			_map_pin("door", m.call(Vector3(ox - side * 3.0, 0, 0)), 7.5, door_color)
			_map_pin("spawn", m.call(Vector3(cx - side * game.CELLAR_DEPTH * 0.5, 0, 0)), 7.5, tc)
		_crown(m.call(game.thrones[t]), 0.45 if not detailed else 0.9)
		if detailed:
			_text(outer.position + Vector2(-40, -6), "%s CASTLE" % Stats.FACTIONS[t].name.to_upper(), 11, tc.lightened(0.5), HORIZONTAL_ALIGNMENT_CENTER, outer.size.x + 80, 2)
			_card("crest_elf" if t == 0 else "crest_human", Rect2(keep.position + Vector2(keep.size.x / 2.0 - 11, 2), Vector2(22, 22)))
			_text(cellar.position + Vector2(0, cellar.size.y + 12), "SPAWN", 9, tc.lightened(0.5), HORIZONTAL_ALIGNMENT_CENTER, cellar.size.x, 2)
	# Potions that are up, and any Blessing of Light on the field.
	for orb in game.heal_orbs:
		if orb.active:
			_map_pin("potion", m.call(orb.global_position), 4.0 if not detailed else 7.0, Color(0.95, 0.4, 0.45))
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
		_map_pin("turret", tc, 4.0 if not detailed else 7.0, _team_color(t.team))
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
	_text(rect.position + Vector2(0, rect.size.y - 12), ("D-pad spends a point  ·  %s / %s pick a promotion  ·  %s closes  ·  a fall costs 2 levels" % [_k("rank_5"), _k("rank_6"), _k("rank_menu")]) if game.on_pad(local_unit) else ("1-4 or click spends a point  ·  5 / 6 picks a promotion  ·  %s closes  ·  a fall costs 2 levels" % _k("rank_menu")), 11, GREY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)


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
	var footer := "Esc / Start resumes  ·  ← → switch tabs" if in_match else "Esc closes  ·  ← → switch tabs"
	_text(rect.position + Vector2(0, rect.size.y - 12), footer, 11, GREY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2)
	if in_match and not game.demo:
		# Back to the main menu: click (or Cross/A on it) twice to confirm.
		quit_button = Rect2(rect.position + Vector2(16, rect.size.y - 34), Vector2(170, 26))
		var arm: bool = game.quit_armed > 0.0
		_plate(quit_button, Color(0.6, 0.18, 0.12, 0.98) if arm else Color(0.4, 0.2, 0.15, 0.95), GOLD if arm else GOLD_DARK, 6, 1)
		_text(quit_button.position + Vector2(0, 18), "SURE? CLICK AGAIN" if arm else "MAIN MENU", 12, CREAM, HORIZONTAL_ALIGNMENT_CENTER, quit_button.size.x, 2)


func _menu_overview(body: Rect2) -> void:
	_text(body.position + Vector2(0, 16), "EMBER PASS" if game.vmap else "THE WILDWOOD VALLEY", 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 3)
	var keys := [["you", "You"], ["enemy", "Enemy in sight"], ["veteran", "Elite bounty"], ["potion", "Healing potion"],
		["blessing", "Blessing"], ["turret", "Turret"], ["door", "Door (red: broken)"], ["spawn", "Spawn cellar"]]
	var cols := 4
	if game.vmap:
		keys = [["fire", "Fire Objective"], ["post", "Watch post"], ["crossing", "The Crossing"], ["spawn", "Spawn cellar"],
			["door", "Door (red: broken)"], ["potion", "Healing potion"], ["you", "You"], ["enemy", "Enemy in sight"],
			["veteran", "Elite bounty"], ["turret", "Turret"], ["blessing", "Blessing"], ["bridge", "Bridge"],
			["path", "Causeway"], ["obelisk", "Rune obelisk"], ["spikes", "Obsidian spikes"], ["lava", "Lava (deadly)"]]
		cols = 6
	var rows: int = int(ceil(keys.size() / float(cols)))
	# Keep the key and the blurb below clear of the footer and MAIN MENU.
	var mh: float = minf(body.size.x * 26.0 / 58.0, body.size.y - 26.0 - 46.0 - rows * 17.0)
	var mw: float = mh * 58.0 / 26.0
	var map_rect := Rect2(body.position + Vector2((body.size.x - mw) / 2.0, 26), Vector2(mw, mh))
	_draw_map(map_rect, true)
	var y := map_rect.end.y + 18
	var cw := body.size.x / cols
	var pt := Time.get_ticks_msec() / 1000.0
	for i in keys.size():
		var x: float = body.position.x + 14 + (i % cols) * cw
		var ly: float = y + (i / cols) * 17
		_legend_icon(keys[i][0], Vector2(x, ly - 4), pt)
		_text(Vector2(x + 13, ly), keys[i][1], 11, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var blurb := "Break the enemy door, smash the Crown Vault lock, steal their crown, carry it home. Grab a class hat in your cellar."
	if game.vmap:
		blurb = "Hold the Fire Objective and every class on your team becomes its Fire form. Break the door, steal their crown, carry it home."
	_text(Vector2(body.position.x, y + rows * 17 + 6), blurb, 11, GREY, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 2)


func _legend_icon(kind: String, q: Vector2, pt: float) -> void:
	match kind:
		"you":
			draw_circle(q, 5.5, Color(1, 1, 0.3))
			draw_arc(q, 5.5, 0, TAU, 14, Color(0.3, 0.2, 0.0, 0.8), 1.0)
		"enemy":
			draw_circle(q, 4.5, Color(1.0, 0.25, 0.2))
			draw_arc(q, 4.5, 0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
		"veteran":
			draw_circle(q, 3.5, Color(1.0, 0.25, 0.2))
			draw_arc(q, 6.0 + sin(pt * 5.0), 0, TAU, 16, Color(1, 0.3, 0.2), 1.6)
		"blessing":
			_icon("xp", q, 4.5, GOLD)
		"fire":
			_fire_icon(q, 5.5, -1, 0.0, pt)
		"bridge":
			draw_rect(Rect2(q - Vector2(8, 3), Vector2(16, 6)), Color(0.56, 0.35, 0.2))
			for k in 3:
				draw_line(q + Vector2(-4 + k * 4, -3), q + Vector2(-4 + k * 4, 3), Color(0.3, 0.18, 0.08), 1.0)
		"path":
			draw_rect(Rect2(q - Vector2(8, 3), Vector2(16, 6)), Color(0.58, 0.5, 0.47))
			draw_line(q + Vector2(0, -3), q + Vector2(0, 3), Color(0.45, 0.38, 0.36), 1.0)
		"obelisk":
			var dia := PackedVector2Array([q + Vector2(0, -6.5), q + Vector2(3.4, 0), q + Vector2(0, 4.5), q + Vector2(-3.4, 0)])
			draw_colored_polygon(dia, Color(0.08, 0.05, 0.06))
			dia.append(dia[0])
			draw_polyline(dia, Color(0.6, 0.08, 0.04), 1.0)
		"spikes":
			for k in 3:
				var bx := q + Vector2(-4 + k * 4, 4)
				draw_colored_polygon(PackedVector2Array([bx + Vector2(-1.8, 0), bx + Vector2(1.8, 0), bx + Vector2(0.5, -9 + (k % 2) * 3)]), Color(0.06, 0.03, 0.04))
		"lava":
			draw_rect(Rect2(q - Vector2(8, 5), Vector2(16, 10)), _lava_glow(pt))
			draw_colored_polygon(PackedVector2Array([q + Vector2(-7, -4), q + Vector2(-1, -5), q + Vector2(0, 1), q + Vector2(-6, 3)]), Color(0.12, 0.03, 0.03))
			draw_colored_polygon(PackedVector2Array([q + Vector2(2, -4), q + Vector2(7, -3), q + Vector2(6, 4), q + Vector2(1, 3)]), Color(0.16, 0.04, 0.04))
		"door":
			_map_pin("door", q, 6.5, GOLD)
		"spawn":
			_map_pin("spawn", q, 6.5, _team_color(_my_team()))
		"post":
			_map_pin("post", q, 6.5, _team_color(_my_team()))
		"turret":
			_map_pin("turret", q, 6.5, _team_color(_my_team()))
		"potion":
			_map_pin("potion", q, 6.5, Color(0.95, 0.4, 0.45))
		"crossing":
			_map_pin("crossing", q, 6.5, GOLD)


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
	var toggles := [["Shake", game.screen_shake, "shake"], ["Numbers", game.damage_numbers, "numbers"],
		["FPS", game.show_fps, "fps"], ["Chat log", game.chat_visible, "chat"], ["Rosters", game.rosters_visible, "rosters"],
		["Fullscreen", game.fullscreen, "fullscreen"]]
	var tw: float = minf(136.0, (body.end.x - x - 10.0 - 7.0 * toggles.size()) / (toggles.size() + 1))
	for i in toggles.size():
		_toggle(Rect2(Vector2(x + 10 + i * (tw + 7), y + 76), Vector2(tw, 34)), toggles[i][0], toggles[i][1], toggles[i][2])
	# The graphics preset: click to cycle Low, Medium, High, Ultra.
	var gfx := Rect2(Vector2(x + 10 + toggles.size() * (tw + 7), y + 76), Vector2(tw, 34))
	_plate(gfx, INK_LIGHT, GOLD if game.gfx_quality >= 2 else Color(0.3, 0.3, 0.38), 8, 1)
	_text(gfx.position + Vector2(0, 13), "GRAPHICS", 8, GREY, HORIZONTAL_ALIGNMENT_CENTER, gfx.size.x, 1)
	_text(gfx.position + Vector2(0, 28), game.GFX_NAMES[game.gfx_quality], 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, gfx.size.x, 2)
	toggle_buttons.append([gfx, "gfx"])
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
	Scoreboard.draw_overlay(self)


func _draw_scoreboard_table(rect: Rect2, live: bool = false) -> void:
	## Drawn by scoreboard.gd (Tab overlay, pause menu tab, end-of-match board).
	Scoreboard.draw_table(self, rect, live)


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
	## The main menu (title, Select Map, Create Your Character, Ready Up) is
	## laid out and handled in menu.gd and drawn through this HUD. What
	## follows is the earlier tabbed front end, kept only as a fallback.
	if game.main_menu:
		game.main_menu.draw(self)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.1, 0.62))
	var cx := size.x / 2.0
	_draw_logo(Rect2(cx - 200, 2, 400, 160))
	_draw_nameplate(Rect2(16, 16, 330, 78))
	_text(Vector2(cx - 300, 178), "Elves against Humans. Break the door, steal the crown, carry it home.", 13, CREAM,
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
		var b := Rect2(left + 50 + i * 128, row_y, 122, 34)
		var on: bool = game.map_variant == i
		var locked: bool = i == 1 and not game.unlocked()
		var tile: Color = [Color(0.2, 0.55, 0.3), Color(0.25, 0.25, 0.55), Color(0.62, 0.22, 0.08)][mini(i, 2)]
		_chunky(b, tile if not locked else Color(0.3, 0.3, 0.34), on, b.has_point(_mouse()))
		_text(b.position + Vector2(0, 22), Stats.MAPS[i][0].to_upper(), 12 if Stats.MAPS[i][0].length() <= 11 else 9, Color.WHITE if not locked else GREY, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 3)
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
	## The end-of-match screen lives in match_summary.gd.
	if game.summary:
		game.summary.draw(self)
