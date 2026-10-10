extends RefCounted
## The main menu, laid out from the project owner's mockup: the title with
## its column of wooden buttons, SELECT MAP (map cards, game settings and
## game mode), CREATE YOUR CHARACTER (tabs, the hero in 3D, the appearance
## panel) and READY UP (up to four fighters on glowing pedestals).
##
## The HUD calls draw() from its _draw (the drawing goes through it), and
## game.menu_tick() calls tick() with each fresh click. The 3D side (the
## valley shot, the castle hall, the models) is menu_stage.gd.

const Stats = preload("res://scripts/stats.gd")
const Guide = preload("res://scripts/guide.gd")
const Face = preload("res://scripts/face.gd")
const Store = preload("res://scripts/store.gd")
const Role = Stats.Role

# Map cards: [title, thumbnail, Stats.MAPS index or -1 for coming soon].
const MAP_CARDS := [["THE WILDWOOD", "map_wildwood", 0], ["MOONLIT WILDWOOD", "map_moonlit", 1],
	["STONEKEEP FORTRESS", "map_stonekeep", -1], ["EMBER PASS", "map_ember", 2], ["TWILIGHT GROVE", "map_twilight", -1]]
const DIFFICULTIES := [["CASUAL", "Relaxed, good for new players", "Easy", "crown"], ["NORMAL", "Classic experience", "Normal", "crown"],
	["HARDCORE", "For the bravest", "Hard", "skull"]]
const CHAR_TABS := [["APPEARANCE", "appearance"], ["HAIR", "hair"], ["FACE", "face"], ["ARMOR", "tunic"], ["COLORS", "palette"], ["EMBLEM", "emblem"]]
const PREVIEW_ROLES := [Role.BASE, Role.KNIGHT, Role.RANGER, Role.MAGE, Role.HEALER]
const SLOT_COLORS := [Color(0.16, 0.38, 0.95), Color(0.85, 0.16, 0.16), Color(0.2, 0.62, 0.22), Color(0.92, 0.72, 0.1)]
const CREDITS := [
	["A GAME BY", "Faisal"],
	["BUILT WITH", "Godot Engine 4 (MIT licence)"],
	["CHARACTERS, PROPS AND GEAR", "KayKit Adventurers, Dungeon, Medieval Hexagon, Halloween, Furniture and Restaurant packs by Kay Lousberg (CC0)"],
	["TITLE LETTERING", "Lilita One by Juan Montoreano (SIL Open Font License)"],
	["LOGO AND CARD ART", "Supplied by the project owner"],
	["TEXTURES, ICONS, SOUND AND MUSIC", "Made by the game's own generator scripts"],
]

var game
var h                        # the HUD this frame (all drawing goes through it)
var stage                    # menu_stage.gd
var screen := "title"        # title, map, character, lobby, store
var overlay := ""            # "", "credits", "tutorial", "progress"
var map_first := 0           # leftmost map card shown
var map_pick := 0            # selected card (MAP_CARDS index)
var char_tab := 0
var preview_role := Role.BASE
var preview_team := 1
var preview_rank := 1
var tutorial_topic := 0
var exit_armed := 0.0
var readied := [true, false, false, false]   # lobby: local players 2-4 ready up
var join_pads: Array = []    # lobby: the pad device of local players 2-4, in join order
var p1_pad := -1             # the pad player 1 last used in the menus
var font_title: Font
var tex := {}
var store                    # store.gd: the STORE screen


func _init(g) -> void:
	game = g
	store = Store.new(g, self)
	font_title = load("res://assets/ui/fonts/LilitaOne-Regular.ttf")
	var dir := DirAccess.open("res://assets/ui/menu")
	if dir:
		for file in dir.get_files():
			var f := file.trim_suffix(".import")
			if f.ends_with(".png") and not tex.has(f.trim_suffix(".png")):
				tex[f.trim_suffix(".png")] = load("res://assets/ui/menu/%s" % f)
	map_pick = 0
	for i in MAP_CARDS.size():
		if MAP_CARDS[i][2] == game.map_variant:
			map_pick = i


func go(to: String) -> void:
	screen = to
	overlay = ""
	exit_armed = 0.0
	game.sfx.ui("ui_open", -6.0)
	if to == "lobby":
		_enter_lobby()


func back() -> void:
	## Esc / Circle / B: close an overlay, else one screen back.
	if overlay != "":
		overlay = ""
	elif screen == "lobby":
		screen = "map"
	elif screen != "title":
		screen = "title"
	else:
		return
	game.sfx.ui("ui_close", -6.0)


# --- Drawing helpers --------------------------------------------------------------

func nine(name: String, r: Rect2, l: float, t: float, rr: float, b: float, mod: Color = Color.WHITE) -> void:
	## Nine-slice one of the painted pieces (margins in texture pixels).
	var tx: Texture2D = tex.get(name)
	if tx == null:
		h._plate(r)
		return
	var ts := tx.get_size()
	var xs := [0.0, l, ts.x - rr, ts.x]
	var ys := [0.0, t, ts.y - b, ts.y]
	# Squeeze the margins if the rect is smaller than them.
	var kx := minf(1.0, r.size.x / (l + rr))
	var ky := minf(1.0, r.size.y / (t + b))
	var dx := [r.position.x, r.position.x + l * kx, r.end.x - rr * kx, r.end.x]
	var dy := [r.position.y, r.position.y + t * ky, r.end.y - b * ky, r.end.y]
	for i in 3:
		for j in 3:
			var src := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			var dst := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			if dst.size.x > 0.5 and dst.size.y > 0.5:
				h.draw_texture_rect_region(tx, dst, src, mod)


func icon(name: String, c: Vector2, size: float, mod: Color = Color.WHITE) -> void:
	var tx: Texture2D = tex.get("icon_" + name)
	if tx:
		h.draw_texture_rect(tx, Rect2(c - Vector2(size, size) / 2.0, Vector2(size, size)), false, mod)


func ttext(pos: Vector2, text: String, size: int, color: Color = Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT,
		width := -1.0, outline := 6) -> void:
	## Lettering in the chunky title face with a dark outline and drop shadow.
	var f: Font = font_title if font_title else h.font
	if outline > 0:
		h.draw_string_outline(f, pos + Vector2(0, 2.5), text, align, width, size, outline, Color(0, 0, 0, 0.5))
		h.draw_string_outline(f, pos, text, align, width, size, outline, Color(0.12, 0.07, 0.03))
	h.draw_string(f, pos, text, align, width, size, color)


func button(r: Rect2, id: String, arg = null) -> bool:
	## Record a clickable rect; returns whether the pointer is over it.
	h.menu_buttons.append([r, id, arg])
	return r.has_point(h._mouse())


func plaque(center_x: float, y: float, text: String, w: float = 420.0) -> void:
	var r := Rect2(center_x - w / 2.0, y, w, 64)
	nine("plaque", r, 110, 24, 110, 24)
	ttext(Vector2(r.position.x, r.position.y + 42), text, 30, Color(1.0, 0.86, 0.45), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 7)


func green_button(r: Rect2, label: String, id: String, enabled: bool = true, with_icon: bool = true) -> void:
	var hover := button(r, id) and enabled
	var rr := r.grow(3) if hover else r
	nine("btn_green" if enabled else "btn_green_off", rr, 48, 20, 48, 20, Color(1.12, 1.12, 1.12) if hover else Color.WHITE)
	var tw: float = font_title.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x if font_title else 100.0
	var x0 := rr.get_center().x - tw / 2.0 + (20.0 if with_icon else 0.0)
	if with_icon:
		icon("swords", Vector2(x0 - 30, rr.get_center().y - 1), 40)
	ttext(Vector2(x0, rr.get_center().y + 10), label, 26, Color.WHITE if enabled else Color(0.85, 0.85, 0.85))


func wood_button(r: Rect2, label: String, id: String, arg = null, ic: String = "", size: int = 22, selected: bool = false, enabled: bool = true) -> void:
	var hover := button(r, id, arg) and enabled
	var rr := r.grow(2) if hover else r
	var mod := Color.WHITE if enabled else Color(0.55, 0.55, 0.55)
	nine("btn_wood_hi" if (hover or selected) else "btn_wood", rr, 20, 20, 20, 20, mod)
	if selected or hover:
		# A warm glow round the selected plank.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(10)
		sb.shadow_color = Color(1.0, 0.75, 0.25, 0.35)
		sb.shadow_size = 10
		h.draw_style_box(sb, rr.grow(-4))
	var tx := rr.position.x + 18
	if ic != "":
		icon(ic, Vector2(rr.position.x + 34, rr.get_center().y), rr.size.y * 0.7, mod)
		tx = rr.position.x + 64
	ttext(Vector2(tx, rr.get_center().y + size * 0.36), label, size, Color(1, 0.97, 0.9) if enabled else Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1, 5)


func slate(r: Rect2, name: String = "panel_slate") -> void:
	nine(name, r, 14, 14, 14, 14)


func option_box(r: Rect2, selected: bool, hover: bool, accent: Color = Color(0.45, 0.9, 0.3)) -> void:
	## A dark option tile; selected ones glow in the accent colour.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.19) if not selected else Color(0.12, 0.2, 0.12).lerp(accent.darkened(0.7), 0.4)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(3 if selected else 2)
	sb.border_color = accent if selected else (Color(0.85, 0.68, 0.35) if hover else Color(0.36, 0.33, 0.3))
	if selected:
		sb.shadow_color = Color(accent, 0.45)
		sb.shadow_size = 8
	h.draw_style_box(sb, r)
	h.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y * 0.4)), Color(1, 1, 1, 0.04))


func label(pos: Vector2, text: String, size: int = 13, color: Color = Color(0.92, 0.9, 0.85)) -> void:
	h._text(pos, text, size, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)


# --- Frame ------------------------------------------------------------------------

func draw(hud) -> void:
	h = hud
	exit_armed = maxf(exit_armed - hud.get_process_delta_time(), 0.0)
	if stage:
		stage.show_screen(screen)
	match screen:
		"map": _draw_map()
		"character": _draw_character()
		"lobby": _draw_lobby()
		"store": store.draw(h, stage, preview_team)
		_: _draw_title()
	if overlay != "":
		h.draw_rect(Rect2(Vector2.ZERO, h.size), Color(0, 0, 0, 0.55))
		match overlay:
			"credits": _draw_credits()
			"tutorial": _draw_tutorial()
			"progress": _draw_progress()
	if game.cursor_shown:
		var hint := "%s select  ·  %s back" % [h._k("ui_confirm"), h._k("ui_back")]
		if screen == "lobby" and game.couch_players < 4 and game.couch_players > 1 or screen == "lobby" and _split_on():
			hint += "  ·  other pads press %s to join" % h._k("ui_confirm")
		h._text(Vector2(0, h.size.y - 8), hint, 11, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, h.size.x, 3)


# --- Title ------------------------------------------------------------------------

# The title's buttons and account chip are painted into its background
# (assets/ui/menu/title_bg.png); these are their places in its pixels.
const BG_W := 1672.0
const BG_PLAY := Rect2(18, 322, 380, 80)
const BG_ITEMS := [Rect2(38, 415, 340, 63), Rect2(38, 493, 340, 63), Rect2(38, 572, 340, 63), Rect2(38, 651, 340, 63), Rect2(38, 730, 340, 65)]
const BG_CHIP := Rect2(1385, 20, 265, 70)
const BG_STORE := Rect2(38, 809, 340, 63)    # under the painted column: drawn, not painted
const BG_PURSE := Rect2(1385, 98, 265, 50)   # under the account chip


func _bg_rect(r: Rect2) -> Rect2:
	## A rect in the title picture's pixels, on screen (the picture covers the screen).
	var k := maxf(h.size.x / BG_W, h.size.y / (BG_W * 941.0 / 1672.0))
	var off: Vector2 = (h.size - Vector2(BG_W, BG_W * 941.0 / 1672.0) * k) / 2.0
	return Rect2(off + r.position * k, r.size * k)


func _bg_hover(r: Rect2, round: float) -> void:
	## A warm glow round a painted button under the pointer.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.95, 0.8, 0.1)
	sb.set_corner_radius_all(int(round))
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.85, 0.4, 0.9)
	sb.shadow_color = Color(1.0, 0.75, 0.25, 0.55)
	sb.shadow_size = 12
	h.draw_style_box(sb, r)


func _draw_title() -> void:
	## The painted title: the logo and buttons are part of the picture, so
	## this only places their hit areas, lights the one under the pointer and
	## keeps the account chip live.
	var play := _bg_rect(BG_PLAY)
	if button(play, "play"):
		_bg_hover(play.grow(-4), 14)
	var ids := ["customize", "settings", "tutorial", "credits", "exit"]
	for i in ids.size():
		var r := _bg_rect(BG_ITEMS[i])
		if button(r, ids[i]):
			_bg_hover(r.grow(-2), 8)
	# STORE: a plank like the painted ones, under EXIT, and the gold purse
	# under the account chip (both open the store).
	# (Not clickable under an overlay: the purse sits under its close button.)
	var sr := _bg_rect(BG_STORE)
	var sov := button(sr, "store") if overlay == "" else false
	nine("btn_wood_hi" if sov else "btn_wood", sr, 20, 20, 20, 20)
	if sov:
		_bg_hover(sr.grow(-2), 8)
	# Laid out like the painted planks: the icon at the left, the word from ~29%.
	h._icon("coin", sr.position + Vector2(sr.size.x * 0.12, sr.size.y / 2.0), sr.size.y * 0.2, Color.WHITE)
	ttext(Vector2(sr.position.x + sr.size.x * 0.29, sr.position.y + sr.size.y * 0.68), "STORE", int(sr.size.y * 0.5), Color(1, 0.97, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
	if game.account_chests > 0:
		var badge := Vector2(sr.end.x - sr.size.y * 0.95, sr.get_center().y)
		h._icon("chest", badge, sr.size.y * 0.17, Color.WHITE)
		ttext(badge + Vector2(sr.size.y * 0.3, sr.size.y * 0.2), "x%d" % game.account_chests, int(sr.size.y * 0.36), Color(1.0, 0.9, 0.55), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	var purse := _bg_rect(BG_PURSE)
	var pov := button(purse, "store") if overlay == "" else false
	slate(purse.grow(2) if pov else purse)
	h._icon("coin", purse.position + Vector2(purse.size.y / 2.0 + 4, purse.size.y / 2.0), purse.size.y * 0.16, Color.WHITE)
	ttext(Vector2(purse.position.x + purse.size.y + 8, purse.position.y + purse.size.y * 0.62), "%d GOLD" % game.account_gold, int(purse.size.y * 0.42), Color(1.0, 0.86, 0.38), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	if exit_armed > 0.0:
		var r := _bg_rect(BG_ITEMS[4])
		var tip := Rect2(r.end.x + 10, r.position.y + 6, 190, r.size.y - 12)
		slate(tip)
		ttext(Vector2(tip.position.x, tip.get_center().y + 7), "CLICK AGAIN", 19, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER, tip.size.x, 4)
	# Account chip, top right, painted over the picture's own: level, rank and XP.
	var chip := _bg_rect(BG_CHIP)
	var ch := button(chip, "progress")
	slate(chip.grow(2) if ch else chip)
	var level: int = game.account_level()
	var badge := chip.position + Vector2(chip.size.y / 2.0 + 2, chip.size.y / 2.0)
	h.draw_circle(badge, chip.size.y * 0.36, Color(0.08, 0.06, 0.1))
	h.draw_circle(badge, chip.size.y * 0.31, Color(0.95, 0.62, 0.2))
	ttext(badge + Vector2(-20, 8), str(level), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40, 4)
	var tx := chip.position.x + chip.size.y + 8
	var nm: String = game.hero_name if game.hero_name.strip_edges() != "" else "Unnamed Hero"
	ttext(Vector2(tx, chip.position.y + 24), nm, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	h._text(Vector2(tx, chip.position.y + 39), Stats.rank_title(level).to_upper(), 10, Color(1.0, 0.82, 0.4), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var span: Array = Stats.account_span(game.account_xp)
	h._bar(Rect2(Vector2(tx, chip.position.y + 44), Vector2(chip.end.x - tx - 12, 7)), (float(span[0]) / span[1]) if span[1] > 0 else 1.0, Color(0.95, 0.6, 0.2))


# --- Select Map -------------------------------------------------------------------

func _draw_map() -> void:
	var frame := Rect2(82, 46, h.size.x - 164, 600)
	nine("frame_big", frame, 40, 40, 40, 40)
	plaque(h.size.x / 2.0, 14, "SELECT MAP", 400)
	# Map cards: four at a time, arrows page through the rest.
	var cw := 236.0
	var gap := 18.0
	var left: float = h.size.x / 2.0 - (cw * 4 + gap * 3) / 2.0
	var cy := 102.0
	for k in 4:
		var i := map_first + k
		if i >= MAP_CARDS.size():
			break
		_map_card(Rect2(left + k * (cw + gap), cy, cw, 186), i)
	for side in [-1, 1]:
		var can: bool = (map_first > 0) if side < 0 else (map_first + 4 < MAP_CARDS.size())
		var ac := Vector2(h.size.x / 2.0 + side * (cw * 2 + gap * 1.5 + 34), cy + 93)
		var ar := Rect2(ac - Vector2(20, 30), Vector2(40, 60))
		if can:
			var ov := button(ar, "map_page", side)
			icon("arrow_left" if side < 0 else "arrow_right", ac, 52 if ov else 46)
		else:
			icon("arrow_left" if side < 0 else "arrow_right", ac, 46, Color(0.4, 0.4, 0.4, 0.6))
	# GAME SETTINGS: difficulty.
	var gs := Rect2(132, 316, 470, 300)
	slate(gs)
	ttext(Vector2(gs.position.x, gs.position.y + 32), "GAME SETTINGS", 22, Color(1.0, 0.82, 0.38), HORIZONTAL_ALIGNMENT_CENTER, gs.size.x, 5)
	label(gs.position + Vector2(22, 62), "DIFFICULTY", 13)
	for i in DIFFICULTIES.size():
		var d: Array = DIFFICULTIES[i]
		var r := Rect2(gs.position.x + 20, gs.position.y + 74 + i * 72, gs.size.x - 40, 62)
		var on: bool = game.bot_difficulty == d[2]
		var ov := button(r, "difficulty", d[2])
		option_box(r, on, ov, Color(0.45, 0.95, 0.3) if i < 2 else Color(1.0, 0.35, 0.3))
		icon(d[3], r.position + Vector2(34, r.size.y / 2.0), 40)
		ttext(r.position + Vector2(66, 28), d[0], 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		h._text(r.position + Vector2(66, 47), d[1], 12, Color(0.85, 0.85, 0.82), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	# GAME MODE: team size and split screen.
	var gm := Rect2(632, 316, 516, 300)
	slate(gm)
	ttext(Vector2(gm.position.x, gm.position.y + 32), "GAME MODE", 22, Color(1.0, 0.82, 0.38), HORIZONTAL_ALIGNMENT_CENTER, gm.size.x, 5)
	label(gm.position + Vector2(24, 62), "TEAM SIZE", 13)
	# Matches are strictly 4v4 for now (Faisal 2026-10-09): one fixed box,
	# nothing to pick; bots fill the seats players leave empty.
	var tr := Rect2(gm.position.x + 22, gm.position.y + 74, 120, 50)
	option_box(tr, true, false, Color(1.0, 0.8, 0.25))
	ttext(Vector2(tr.position.x, tr.position.y + 33), "%dv%d" % [game.TEAM_SIZE, game.TEAM_SIZE], 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 4)
	h._text(Vector2(tr.end.x + 16, tr.position.y + 31), "Bots fill any empty seats", 13, Color(0.85, 0.85, 0.82), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	label(gm.position + Vector2(24, 160), "SPLIT SCREEN", 13)
	icon("gamepad", gm.position + Vector2(56, 206), 50)
	h._text(gm.position + Vector2(90, 212), "-", 16, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	for k in 2:
		var on: bool = _split_on() == (k == 1)
		var r := Rect2(gm.position.x + 116 + k * 196, gm.position.y + 180, 180, 52)
		var ov := button(r, "split", k == 1)
		option_box(r, on, ov, Color(1.0, 0.8, 0.25))
		ttext(Vector2(r.position.x, r.position.y + 35), ["OFF", "ON"][k], 22, Color.WHITE if on else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
	if _split_on():
		# Two players: side by side (vertical) or stacked (horizontal).
		_layout_picker(Rect2(gm.position.x + 116, gm.position.y + 240, 376, 34))
	else:
		h._text(Vector2(gm.position.x + 116, gm.position.y + 260), "Play together on the same screen", 12, Color(0.88, 0.86, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 376, 2)
	h._text(Vector2(gm.position.x, gm.position.y + 284), "Bots fill every empty place on both sides.", 10, Color(0.7, 0.7, 0.68), HORIZONTAL_ALIGNMENT_CENTER, gm.size.x, 2)
	var playable: bool = _card_open(map_pick)
	green_button(Rect2(h.size.x / 2.0 - 190, 618, 380, 74), "START MATCH", "to_lobby", playable)
	wood_button(Rect2(40, 640, 150, 50), "BACK", "back", null, "", 20)


func _card_open(i: int) -> bool:
	var m: int = MAP_CARDS[i][2]
	return m == 0 or m == 2 or (m == 1 and game.unlocked())


func _map_card(r: Rect2, i: int) -> void:
	var c: Array = MAP_CARDS[i]
	var open := _card_open(i)
	var sel := map_pick == i
	var ov := button(r, "map_card", i)
	# Glow and frame.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(4 if sel else 3)
	sb.border_color = Color(1.0, 0.78, 0.25) if sel else (Color(0.85, 0.7, 0.4) if ov else Color(0.42, 0.36, 0.3))
	if sel:
		sb.shadow_color = Color(1.0, 0.7, 0.2, 0.6)
		sb.shadow_size = 14
	h.draw_style_box(sb, r)
	var img := Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 44))
	var tx: Texture2D = tex.get(c[1])
	if tx:
		var dim := Color.WHITE if open else Color(0.5, 0.5, 0.52)
		var ts := tx.get_size()
		var want := img.size.x / img.size.y
		var src := Rect2(Vector2.ZERO, ts)
		if ts.x / ts.y > want:
			src = Rect2((ts.x - ts.y * want) / 2.0, 0, ts.y * want, ts.y)
		else:
			src = Rect2(0, (ts.y - ts.x / want) / 2.0, ts.x, ts.x / want)
		h.draw_texture_rect_region(tx, img, src, dim)
	h.draw_rect(img, Color(0.1, 0.06, 0.03), false, 2.0)
	# Name strip.
	var strip := Rect2(r.position.x + 5, r.end.y - 39, r.size.x - 10, 34)
	h.draw_rect(strip, Color(0.1, 0.08, 0.07, 0.95))
	h.draw_rect(Rect2(strip.position, Vector2(strip.size.x, 2)), Color(0.55, 0.42, 0.22))
	ttext(Vector2(strip.position.x, strip.position.y + 24), c[0], 15, Color.WHITE if open else Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_CENTER, strip.size.x, 4)
	if not open:
		icon("lock", img.get_center() + Vector2(0, -10), 44)
		var why := "COMING SOON" if c[2] < 0 else "UNLOCKS AT LEVEL %d" % Stats.UNLOCK_LEVEL
		ttext(Vector2(img.position.x, img.get_center().y + 34), why, 15, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER, img.size.x, 5)


# --- Create Your Character ------------------------------------------------------------

func _draw_character() -> void:
	if stage:
		stage.show_hero(preview_team, preview_role, game.hero_custom(), preview_rank)
	plaque(632, 22, "CREATE YOUR CHARACTER", 600)
	icon("crown", Vector2(632, 20), 46)
	# Tabs down the left, an ivy vine climbing their left edge (Faisal's
	# create-character reference, 2026-10-09).
	h._ivy(Vector2(52, 128 + CHAR_TABS.size() * 62 - 6), Vector2(0, -1), CHAR_TABS.size() * 62.0 - 14.0, 31)
	for i in CHAR_TABS.size():
		var r := Rect2(60, 128 + i * 62, 272, 52)
		var sel := char_tab == i
		var ov := button(r, "char_tab", i)
		var rr := r.grow(2) if ov else r
		nine("panel_row", rr, 14, 14, 14, 14)
		if sel:
			# The open tab gets a chevron at its right end.
			icon("arrow_right", rr.position + Vector2(rr.size.x - 22, rr.size.y / 2.0), 22, Color(1.0, 0.86, 0.45))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.32, 0.22, 0.08, 0.55)
			sb.set_corner_radius_all(8)
			sb.set_border_width_all(3)
			sb.border_color = Color(1.0, 0.78, 0.3)
			sb.shadow_color = Color(1.0, 0.7, 0.2, 0.45)
			sb.shadow_size = 10
			h.draw_style_box(sb, rr)
		var locked := false
		icon(CHAR_TABS[i][1], rr.position + Vector2(32, rr.size.y / 2.0), 38, Color(0.6, 0.6, 0.6) if locked else Color.WHITE)
		ttext(rr.position + Vector2(62, rr.size.y / 2.0 + 7), CHAR_TABS[i][0], 19, Color(0.65, 0.65, 0.65) if locked else (Color(1.0, 0.92, 0.65) if sel else Color.WHITE), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		if locked:
			icon("lock", rr.position + Vector2(rr.size.x - 24, rr.size.y / 2.0), 24)
	# Side switch under the hero: a green stag plate and a blue crown plate.
	for k in 2:
		var r := Rect2(410 + k * 202, 630, 196, 56)
		var on := preview_team == k
		var ov := button(r, "preview_team", k)
		var rr := r.grow(2) if ov else r
		var base := Color(0.13, 0.42, 0.18) if k == 0 else Color(0.12, 0.27, 0.72)
		var sb := StyleBoxFlat.new()
		sb.bg_color = base if on else base.darkened(0.35)
		sb.set_corner_radius_all(9)
		sb.set_border_width_all(3)
		sb.border_color = Color(1.0, 0.8, 0.32) if on else Color(0.62, 0.5, 0.28)
		if on:
			sb.shadow_color = Color(0.45, 0.6, 1.0, 0.7) if k == 1 else Color(0.5, 1.0, 0.45, 0.6)
			sb.shadow_size = 10
		h.draw_style_box(sb, rr)
		h.draw_rect(Rect2(rr.position + Vector2(6, 5), Vector2(rr.size.x - 12, rr.size.y * 0.32)), Color(1, 1, 1, 0.1))
		icon("stag" if k == 0 else "crown", rr.position + Vector2(40, rr.size.y / 2.0), 44)
		ttext(Vector2(rr.position.x + 64, rr.position.y + 38), "ELF" if k == 0 else "HUMAN", 24, Color.WHITE if on else Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x - 76, 5)
	# The panel on the right.
	var panel := Rect2(832, 110, 430, 480)
	slate(panel)
	# The open tab's name on a wood plaque over the panel's top edge, ivy
	# sprigs at both ends, as in the reference.
	var pr := Rect2(panel.get_center().x - 165, panel.position.y - 22, 330, 48)
	nine("plaque", pr, 110, 24, 110, 24)
	ttext(Vector2(pr.position.x, pr.position.y + 33), CHAR_TABS[char_tab][0], 22, Color(1.0, 0.86, 0.45), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 5)
	h._ivy(pr.position + Vector2(8, 10), Vector2(1, 0), 44.0, 32)
	h._ivy(Vector2(pr.end.x - 8, pr.position.y + 10), Vector2(-1, 0), 44.0, 33)
	h.draw_rect(Rect2(panel.position.x + 30, panel.position.y + 46, panel.size.x - 60, 1), Color(0.6, 0.48, 0.28, 0.6))
	match char_tab:
		0: _tab_appearance(panel)
		1: _tab_hair(panel)
		2: _tab_face(panel)
		3: _tab_armor(panel)
		4: _tab_colors(panel)
		5: _tab_emblem(panel)
	green_button(Rect2(876, 604, 340, 70), "CONFIRM", "confirm", true, false)


func _row_label(panel: Rect2, y: float, text: String) -> void:
	label(Vector2(panel.position.x + 22, y + 6), text, 15 if text.length() < 12 else 13)


func swatch(r: Rect2, fill: Color, sel: bool, id: String, arg, locked: bool = false) -> void:
	var ov := button(r, id, arg) and not locked
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill if not locked else fill.darkened(0.5)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(3 if sel else 2)
	sb.border_color = Color(1.0, 0.8, 0.3) if sel else (Color(0.9, 0.8, 0.6) if ov else Color(0.12, 0.1, 0.08))
	if sel:
		sb.shadow_color = Color(1.0, 0.75, 0.25, 0.55)
		sb.shadow_size = 7
	h.draw_style_box(sb, r)
	h.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y * 0.3)), Color(1, 1, 1, 0.12))


func _row_x(panel: Rect2, i: int, n: int, w: float) -> float:
	## Left edge of item i of n spread across a row's choice area.
	var x0 := panel.position.x + 132
	var span := panel.size.x - 132 - 22
	return x0 + (i * (span - w) / maxf(n - 1, 1)) if n > 1 else x0


func _tab_appearance(panel: Rect2) -> void:
	var y := panel.position.y + 74
	var step := 51.0
	# Body type: arrows round the build silhouettes.
	_row_label(panel, y, "Body Type")
	var ax0 := panel.position.x + 132
	var ax1 := panel.end.x - 22
	button(Rect2(ax0 - 4, y - 18, 26, 36), "body_step", -1)
	icon("arrow_left", Vector2(ax0 + 8, y), 26)
	button(Rect2(ax1 - 22, y - 18, 26, 36), "body_step", 1)
	icon("arrow_right", Vector2(ax1 - 8, y), 26)
	var nb := Stats.HERO_BODIES.size()
	for i in nb:
		var c := Vector2(ax0 + 30 + (ax1 - ax0 - 60) * (i + 0.5) / nb, y)
		var on: bool = game.hero_body == i
		var r := Rect2(c - Vector2(24, 22), Vector2(48, 44))
		var ov := button(r, "body", i)
		if on:
			swatch(r, Color(0.32, 0.28, 0.2), true, "body", i)
		icon(["body_slim", "body_sturdy", "body_broad"][i], c, 40, Color.WHITE if on else (Color(0.85, 0.85, 0.85) if ov else Color(0.5, 0.5, 0.5)))
	y += step
	_row_label(panel, y, "Skin Tone")
	for i in Stats.HERO_SKINS.size():
		swatch(Rect2(_row_x(panel, i, Stats.HERO_SKINS.size(), 50), y - 19, 50, 38), Stats.HERO_SKINS[i][1], game.hero_skin == i, "skin", i)
	y += step
	_row_label(panel, y, "Hair Style")
	var ns := Stats.HERO_HAIR_STYLES.size()
	for i in ns:
		var r := Rect2(_row_x(panel, i, ns, 44), y - 21, 44, 42)
		swatch(r, Color(0.2, 0.21, 0.24), game.hero_hair_style == i, "hair_style", i)
		hair_thumb(r.get_center(), i, 1.0)
		if not Store.owns(game, "hair_style", i):
			icon("lock", r.end - Vector2(8, 8), 15)
	y += step
	_row_label(panel, y, "Hair Color")
	var hairs: Array = range(Stats.HERO_HAIR.size()).filter(func(i): return Store.owns(game, "hair", i))
	for k in hairs.size():
		var i: int = hairs[k]
		var c := Vector2(_row_x(panel, k, hairs.size(), 36) + 18, y)
		_dot(c, Stats.HERO_HAIR[i][1], game.hero_hair == i, "hair", i)
	y += step
	_row_label(panel, y, "Face Style")
	for i in Stats.HERO_FACES.size():
		var r := Rect2(_row_x(panel, i, Stats.HERO_FACES.size(), 42), y - 20, 42, 40)
		swatch(r, Stats.HERO_SKINS[game.hero_skin][1], game.hero_face == i, "face", i)
		face_thumb(r.grow(-3), i)
	y += step
	_row_label(panel, y, "Eye Color")
	var eye := _eye_index()
	for i in Stats.HERO_EYES.size():
		var c := Vector2(_row_x(panel, i, Stats.HERO_EYES.size(), 36) + 18, y)
		_dot(c, Stats.HERO_EYES[i][1], eye == i, "eye", i)
	y += step
	_row_label(panel, y, "Facial Markings")
	for i in Stats.HERO_MARKS.size():
		var r := Rect2(_row_x(panel, i, Stats.HERO_MARKS.size(), 46), y - 20, 46, 40)
		mark_thumb(r, i, game.hero_mark == i)
	y += step + 4
	label(Vector2(panel.position.x + 26, y - 4), "Preview", 15)
	label(Vector2(panel.position.x + 26, y + 15), "Emblem", 15)
	for i in PREVIEW_ROLES.size():
		var role: int = PREVIEW_ROLES[i]
		var r := Rect2(_row_x(panel, i, PREVIEW_ROLES.size(), 46), y - 22, 46, 44)
		var on := preview_role == role
		swatch(r, Color(0.2, 0.2, 0.24), on, "preview_role", role)
		h._icon(h._class_icon(role) if role != Role.BASE else ("class_elf" if preview_team == 0 else "class_human"), r.get_center(), 13, Color.WHITE)


func _dot(c: Vector2, fill: Color, on: bool, id: String, arg) -> void:
	## A round colour choice with a gold ring when picked.
	var r := Rect2(c - Vector2(18, 18), Vector2(36, 36))
	var ov := button(r, id, arg)
	if on:
		h.draw_circle(c, 23, Color(1.0, 0.75, 0.25, 0.3))
	h.draw_circle(c, 19 if on else 17, Color(1.0, 0.8, 0.3) if on else (Color(0.9, 0.8, 0.6) if ov else Color(0.08, 0.07, 0.06)))
	h.draw_circle(c, 15, fill)
	h.draw_circle(c + Vector2(-5, -5), 4, Color(1, 1, 1, 0.3))


func _eye_index() -> int:
	## The eye colour shown as picked: the player's own, else their side's.
	if game.hero_eye >= 0:
		return game.hero_eye
	return 2 if preview_team == 0 else 0


const MARK_CROPS := {"scar": Rect2(316, 16, 150, 240), "claws": Rect2(14, 250, 140, 74), "freckles": Rect2(326, 250, 136, 60), "paint": Rect2(40, 255, 432, 50)}


func mark_thumb(r: Rect2, i: int, on: bool) -> void:
	## A facial marking choice: the marking cropped from its texture over the skin.
	var mk: String = Stats.HERO_MARKS[i][1]
	swatch(r, Color(0.2, 0.21, 0.24) if mk == "" else Stats.HERO_SKINS[game.hero_skin][1].darkened(0.1), on, "mark", i)
	if mk == "":
		var c := r.get_center()
		h.draw_arc(c, 12, 0, TAU, 24, Color(0.92, 0.9, 0.85), 2.5)
		h.draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), Color(0.92, 0.9, 0.85), 2.5)
		h.draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), Color(0.92, 0.9, 0.85), 2.5)
		return
	var path := "res://assets/characters/faces/face_mark_%s.png" % mk
	if not tex.has(path):
		tex[path] = load(path)
	var src: Rect2 = MARK_CROPS[mk]
	var box := r.grow(-5)
	var k := minf(box.size.x / src.size.x, box.size.y / src.size.y) * 1.0
	var sz := src.size * k
	h.draw_texture_rect_region(tex[path], Rect2(box.get_center() - sz / 2.0, sz), src)


func _tab_hair(panel: Rect2) -> void:
	var y := panel.position.y + 86
	label(Vector2(panel.position.x + 26, y), "HAIR COLOUR  ·  %s" % Stats.HERO_HAIR[game.hero_hair][0], 15)
	for i in Stats.HERO_HAIR.size():
		var c := Vector2(panel.position.x + 62 + (i % 4) * 102, y + 46 + (i / 4) * 78)
		var r := Rect2(c - Vector2(30, 30), Vector2(60, 60))
		var on: bool = game.hero_hair == i
		var have := Store.owns(game, "hair", i)
		var ov := button(r, "hair", i)
		h.draw_circle(c, 31 if on else 28, Color(1.0, 0.8, 0.3) if on else (Color(0.9, 0.8, 0.6) if ov else Color(0.1, 0.08, 0.06)))
		h.draw_circle(c, 25, Stats.HERO_HAIR[i][1] if have else Stats.HERO_HAIR[i][1].darkened(0.45))
		h.draw_circle(c + Vector2(-8, -8), 6, Color(1, 1, 1, 0.3))
		if not have:
			_price_tag(c + Vector2(0, 2), "hair", i)
		h._text(Vector2(c.x - 50, c.y + 44), Stats.HERO_HAIR[i][0].to_upper(), 11, Color.WHITE if on else Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 100, 2)
	label(Vector2(panel.position.x + 26, y + 258), "HAIR STYLE  ·  %s" % Stats.HERO_HAIR_STYLES[game.hero_hair_style], 15)
	for i in Stats.HERO_HAIR_STYLES.size():
		var r := Rect2(panel.position.x + 26 + i * 74, y + 274, 64, 64)
		swatch(r, Color(0.2, 0.21, 0.24), game.hero_hair_style == i, "hair_style", i)
		hair_thumb(r.get_center(), i, 1.45)
		if not Store.owns(game, "hair_style", i):
			h.draw_rect(r.grow(-2), Color(0, 0, 0, 0.4))
			_price_tag(r.get_center() + Vector2(0, 4), "hair_style", i)


func hair_thumb(c: Vector2, style: int, k: float) -> void:
	## A little head in the chosen hair colour showing hair style `style`:
	## the cut on top, then the ponytail, long hair, braids or bun.
	var hc: Color = Stats.HERO_HAIR[game.hero_hair][1]
	var skin: Color = Stats.HERO_SKINS[game.hero_skin][1]
	var ink := Color(0.1, 0.07, 0.05)
	var r := 9.0 * k
	match style:
		1:
			h.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.7, -r * 0.6), c + Vector2(r * 1.7, r * 0.4), c + Vector2(r * 1.2, r * 1.6), c + Vector2(r * 0.6, r * 0.2)]), hc)
		2:
			h.draw_rect(Rect2(c + Vector2(-r * 1.15, -r * 0.3), Vector2(r * 2.3, r * 1.9)), hc)
		3:
			for sd in [-1.0, 1.0]:
				for j in 3:
					h.draw_circle(c + Vector2(sd * r * 1.05, r * (0.3 + j * 0.55)), r * (0.32 - j * 0.04), hc)
		4:
			h.draw_circle(c + Vector2(0, -r * 1.2), r * 0.55, hc)
			h.draw_circle(c + Vector2(0, -r * 1.2), r * 0.55, ink, false, 1.2)
	h.draw_circle(c + Vector2(0, r * 0.15), r, skin)
	h.draw_arc(c + Vector2(0, r * 0.15), r, 0, TAU, 20, ink, 1.2)
	var cap := PackedVector2Array()
	for j in 13:
		var a := PI + PI * j / 12.0
		cap.append(c + Vector2(cos(a) * r * 1.08, r * 0.15 + sin(a) * r * 1.08))
	cap.append(c + Vector2(r * 0.6, -r * 0.1))
	cap.append(c + Vector2(-r * 0.2, -r * 0.35))
	h.draw_colored_polygon(cap, hc)


func _price_tag(c: Vector2, kind: String, i: int) -> void:
	## A lock and the STORE price over a choice not owned yet.
	icon("lock", c + Vector2(0, -6), 20)
	var p := "%d" % Store.price(Store.item_for(kind, i))
	h._icon("coin", c + Vector2(-h._text_width(p, 10) / 2.0 - 6, 11), 2.6, Color.WHITE)
	h._text(Vector2(c.x - 30, c.y + 15), p, 10, Color(1.0, 0.88, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 66, 2)


func face_thumb(r: Rect2, i: int) -> void:
	## Both eyes of face style i, cropped from its texture.
	var path := "res://assets/characters/faces/face_eyes_%s_%s.png" % [Face.STYLES[i], Stats.HERO_EYES[_eye_index()][2]]
	if not tex.has(path):
		tex[path] = load(path)
	var src := Rect2(30, 60, 452, 230)
	var w := r.size.x
	var hh := w * src.size.y / src.size.x
	h.draw_texture_rect_region(tex[path], Rect2(r.position.x, r.get_center().y - hh / 2.0, w, hh), src)


func _tab_face(panel: Rect2) -> void:
	var y := panel.position.y + 70
	for i in Stats.HERO_FACES.size():
		var r := Rect2(panel.position.x + 20 + (i % 3) * 132, y + (i / 3) * 196, 124, 184)
		var on: bool = game.hero_face == i
		swatch(r, Stats.HERO_SKINS[game.hero_skin][1], on, "face", i)
		face_thumb(Rect2(r.position + Vector2(8, 12), Vector2(r.size.x - 16, 80)), i)
		ttext(Vector2(r.position.x, r.position.y + 124), Stats.HERO_FACES[i][0].to_upper(), 18, Color.WHITE if on else Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
		h._paragraph(Vector2(r.position.x + 8, r.position.y + 146), Stats.HERO_FACES[i][1], 11, Color(1, 1, 1, 0.9), r.size.x - 16, 13.0)


func _tab_armor(panel: Rect2) -> void:
	var y := panel.position.y + 74
	label(Vector2(panel.position.x + 26, y), "LOOK", 15)
	for i in Stats.HERO_LOOKS.size():
		var r := Rect2(panel.position.x + 26 + i * 204, y + 10, 192, 56)
		var locked: bool = i > 0 and not game.unlocked()
		var on: bool = game.hero_look == i
		var ov := button(r, "look", i)
		option_box(r, on, ov, Color(1.0, 0.8, 0.25) if i == 0 else Color(0.75, 0.5, 1.0))
		ttext(Vector2(r.position.x, r.position.y + 27), Stats.HERO_LOOKS[i][0].to_upper(), 19, Color.WHITE if not locked else Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
		h._text(Vector2(r.position.x, r.position.y + 45), "Team colours" if i == 0 else ("LEVEL %d" % Stats.UNLOCK_LEVEL if locked else "Dusk armour, violet glow, a cape"), 10, Color(0.85, 0.85, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
		if locked:
			icon("lock", r.position + Vector2(r.size.x - 18, 16), 22)
	# STORE gear: what you own is worn on a click, the rest opens the store.
	y += 84
	for row in [["ARMOUR TINT", "outfit"], ["HAT  ·  no class hat on", "hat"], ["CAPE & SCARF", "cape"], ["WEAPON SKIN", "weapon"]]:
		label(Vector2(panel.position.x + 26, y), row[0], 13)
		var kind: String = row[1]
		var n: int = Store.table(kind).size()
		for i in n:
			var r := Rect2(panel.position.x + 26 + i * minf(52.0, (panel.size.x - 52 - 44) / maxf(n - 1, 1)), y + 8, 44, 38)
			var have := Store.owns(game, kind, i)
			var on: bool = Store.equipped(game, kind) == i
			var ov := button(r, "gear", [kind, i])
			option_box(r, on, ov, Color(1.0, 0.8, 0.25))
			if i == 0:
				h.draw_line(r.get_center() + Vector2(-8, -8), r.get_center() + Vector2(8, 8), Color(0.8, 0.78, 0.74), 2.5)
			else:
				store.h = h
				store.thumb(r.grow(-5), kind, i)
			if not have:
				h.draw_rect(r.grow(-2), Color(0, 0, 0, 0.45))
				icon("lock", r.end - Vector2(9, 9), 16)
		y += 60
	label(Vector2(panel.position.x + 26, y), "GEAR RANK  ·  preview what promotions earn", 13)
	for k in 4:
		var r := Rect2(panel.position.x + 26 + k * 102, y + 8, 92, 40)
		var ov := button(r, "rank", k + 1)
		option_box(r, preview_rank == k + 1, ov, Color(1.0, 0.8, 0.25))
		ttext(Vector2(r.position.x, r.position.y + 28), "RANK %d" % (k + 1), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)


func _tab_colors(panel: Rect2) -> void:
	var y := panel.position.y + 86
	label(Vector2(panel.position.x + 26, y), "TRIM  ·  %s" % Stats.HERO_TRIM[game.hero_trim][0], 15)
	for i in Stats.HERO_TRIM.size():
		var c := Vector2(panel.position.x + 62 + (i % 4) * 102, y + 50 + (i / 4) * 86)
		var r := Rect2(c - Vector2(36, 30), Vector2(72, 60))
		var col: Color = Store.swatch_color("trim", i, preview_team)
		var have := Store.owns(game, "trim", i)
		swatch(r, col if have else col.darkened(0.45), game.hero_trim == i, "trim", i)
		if not have:
			_price_tag(c + Vector2(0, 2), "trim", i)
		h._text(Vector2(c.x - 50, c.y + 46), Stats.HERO_TRIM[i][0].to_upper(), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 100, 2)
	h._paragraph(Vector2(panel.position.x + 26, y + 272), "Trim colours your cape and sash on every class. TEAM keeps your side's colour. Locked dyes are in the STORE.", 12, Color(0.82, 0.82, 0.78), panel.size.x - 52, 16.0)


func _tab_emblem(panel: Rect2) -> void:
	# Name, then the banner (calling card) editor the enemy sees on a kill.
	var y := panel.position.y + 66
	label(Vector2(panel.position.x + 22, y + 12), "NAME", 13)
	var field := Rect2(panel.position.x + 80, y - 6, panel.size.x - 102, 28)
	h._plate(field, Color(0.05, 0.06, 0.1, 0.9), Color(1.0, 0.8, 0.3) if game.name_editing else Color(0.55, 0.42, 0.22), 6, 2)
	var shown: String = game.hero_name
	if game.name_editing and int(Time.get_ticks_msec() / 400) % 2 == 0:
		shown += "|"
	elif shown == "" and not game.name_editing:
		shown = "click to name your hero"
	h._text(field.position + Vector2(10, 19), shown, 14, Color.WHITE if game.hero_name != "" or game.name_editing else Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	h.hero_buttons.append([field, "name", 0])
	h._draw_banner_editor(Vector2(panel.position.x + 22, y + 46), panel.size.x - 44)


# --- Ready Up -----------------------------------------------------------------------------

func _split_on() -> bool:
	return game.couch_players > 1 or game.split_screen


func _enter_lobby() -> void:
	readied = [true, false, false, false]
	if not _split_on():
		game.couch_players = 1
	game.lobby_sides.resize(4)
	for k in 4:
		if game.lobby_sides[k] == null:
			game.lobby_sides[k] = 0 if (game.couch_mode == "coop" or k % 2 == 0) else 1


func lobby_slots() -> Array:
	## What the four pedestals show: the local players, then (solo) the
	## first bots of each side, or (split screen) empty places to join.
	var out: Array = []
	var n: int = game.couch_players
	for k in n:
		var team: int = game.lobby_sides[k]
		var custom: Dictionary = game.hero_custom() if k == 0 else {}
		var p1_role: int = preview_role if preview_role != Role.BASE else Role.KNIGHT
		out.append({"kind": "local", "k": k, "team": team, "role": [Role.KNIGHT, Role.RANGER, Role.MAGE, Role.HEALER][k] if k > 0 else p1_role,
			"custom": custom, "rank": 3, "color": SLOT_COLORS[k], "readied": k == 0 or readied[k]})
	if _split_on():
		while out.size() < 4:
			out.append({"kind": "join", "empty": true})
		return out
	# Solo: one ally and then the enemy, from the bot lineup (the rest are
	# counted under the cards).
	var me: int = game.lobby_sides[0]
	var lineup: Array = game.LINEUP
	var allies: int = mini(game.team_size - 1, 1)
	for side in [me, 1 - me]:
		for i in game.team_size:
			if side == me and (i == 0 or i > allies):
				continue
			if out.size() >= 4:
				break
			out.append({"kind": "bot", "team": side, "role": lineup[i % lineup.size()][0], "rank": 1, "ally": side == me,
				"name": Stats.BOT_NAMES[side][i % Stats.BOT_NAMES[side].size()], "color": Stats.FACTIONS[side].color, "readied": true})
	return out


func _draw_lobby() -> void:
	var slots := lobby_slots()
	if stage:
		stage.show_lobby(slots)
	plaque(h.size.x / 2.0, 14, "READY UP", 380)
	var all_ready := true
	for i in 4:
		var cx: float = h.size.x * (0.15 + i * 0.233)
		var s: Dictionary = slots[i] if i < slots.size() else {"kind": "none"}
		if s.kind == "none":
			continue
		# Tag.
		var tag := Rect2(cx - 84, 84, 168, 44)
		var tcol: Color = s.get("color", Color(0.4, 0.4, 0.45))
		var title := ""
		match s.kind:
			"local": title = "P%d" % (s.k + 1)
			"bot": title = "ALLY" if s.ally else "FOE"
			"join": title = "P%d" % (i + 1)
		if s.kind == "join":
			tcol = Color(0.4, 0.4, 0.45)
		nine("tag", tag, 14, 14, 14, 14, tcol.lightened(0.15))
		ttext(Vector2(tag.position.x, tag.position.y + 32), title, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 5)
		# Name plate.
		var plate := Rect2(cx - 112, 486, 224, 118)
		slate(plate)
		match s.kind:
			"local":
				var nm: String = (game.hero_name if game.hero_name.strip_edges() != "" else "Player1") if s.k == 0 else "Player%d" % (s.k + 1)
				ttext(Vector2(plate.position.x, plate.position.y + 30), nm, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 4)
				var lv := "Lv %d" % game.account_level() if s.k == 0 else "Guest"
				h._text(Vector2(plate.position.x, plate.position.y + 50), lv, 14, Color(0.55, 0.95, 0.45), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 3)
				_side_chip(Rect2(plate.position.x + 14, plate.position.y + 58, plate.size.x - 28, 22), s.k, s.team)
				_ready_bar(Rect2(plate.position.x + 14, plate.position.y + 84, plate.size.x - 28, 28), s.readied, s.k)
				if not s.readied:
					all_ready = false
				if s.k > 0:
					var x := Rect2(plate.end.x - 26, plate.position.y + 6, 20, 20)
					var ov := button(x, "kick", s.k)
					h._text(x.position + Vector2(0, 15), "✕", 13, Color(1, 0.5, 0.45) if ov else Color(0.7, 0.6, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 20, 2)
			"bot":
				ttext(Vector2(plate.position.x, plate.position.y + 30), s.name, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 4)
				h._text(Vector2(plate.position.x, plate.position.y + 50), "BOT  ·  %s" % game.bot_difficulty.to_upper(), 12, Color(0.75, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 3)
				var side_name: String = Stats.FACTIONS[s.team].name.to_upper()
				h._text(Vector2(plate.position.x, plate.position.y + 72), side_name, 12, Stats.FACTIONS[s.team].color.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 3)
				_ready_bar(Rect2(plate.position.x + 14, plate.position.y + 84, plate.size.x - 28, 28), true, -1)
			"join":
				var r := Rect2(plate.position.x + 14, plate.position.y + 14, plate.size.x - 28, plate.size.y - 28)
				var ov := button(r, "add_player", null)
				option_box(r, false, ov)
				ttext(Vector2(r.position.x, r.position.y + 36), "PRESS %s TO JOIN" % ("A" if game.pad_style != "ps" else "✕"), 17, Color(1.0, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
				h._text(Vector2(r.position.x, r.position.y + 62), "or click to add a gamepad player", 11, Color(0.8, 0.8, 0.76), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
	var sizes := "%dv%d" % [game.team_size, game.team_size]
	var extra: int = game.team_size * 2 - slots.filter(func(s): return s.kind != "join").size()
	var note := "%s on %s  ·  %s" % [sizes, MAP_CARDS[map_pick][0].capitalize(), DIFFICULTIES[maxi(["Easy", "Normal", "Hard"].find(game.bot_difficulty), 0)][0].capitalize()]
	if extra > 0:
		note += "  ·  +%d more bot%s" % [extra, "" if extra == 1 else "s"]
	h._text(Vector2(0, 638), note, 13, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, h.size.x, 3)
	wood_button(Rect2(56, 652, 220, 54), "BACK", "back", null, "", 22)
	green_button(Rect2(h.size.x - 452, 646, 400, 68), "START MATCH" if all_ready else "WAITING...", "start", all_ready)
	if game.couch_players == 2:
		_layout_picker(Rect2(h.size.x / 2.0 - 230, 662, 340, 34))


func _layout_picker(r: Rect2) -> void:
	## SPLIT SCREEN layout for two players: VERTICAL (side by side) or
	## HORIZONTAL (top and bottom). The same setting as the Options board's.
	var bw := (r.size.x - 8.0) / 2.0
	for k in 2:
		var layout: String = ["vertical", "horizontal"][k]
		var b := Rect2(r.position.x + k * (bw + 8.0), r.position.y, bw, r.size.y)
		var on: bool = game.split_layout == layout
		var ov := button(b, "split_layout", layout)
		option_box(b, on, ov, Color(1.0, 0.8, 0.25))
		h._split_glyph(b.position + Vector2(22, b.size.y / 2.0), layout, Color.WHITE if on else Color(0.75, 0.75, 0.75))
		ttext(Vector2(b.position.x + 34, b.position.y + b.size.y / 2.0 + 6), layout.to_upper(), 15, Color.WHITE if on else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, b.size.x - 40, 3)


func _side_chip(r: Rect2, k: int, team: int) -> void:
	## ELVES | HUMANS for a local player: click (or press left/right on their pad) to switch.
	for side in 2:
		var cr := Rect2(r.position.x + side * r.size.x / 2.0, r.position.y, r.size.x / 2.0 - 2, r.size.y)
		var on := team == side
		var ov := button(cr, "side", [k, side])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Stats.FACTIONS[side].color.darkened(0.25) if on else Color(0.15, 0.15, 0.18)
		sb.set_corner_radius_all(5)
		sb.set_border_width_all(2 if on or ov else 1)
		sb.border_color = Color(1.0, 0.85, 0.4) if on else (Color(0.8, 0.7, 0.5) if ov else Color(0.3, 0.3, 0.32))
		h.draw_style_box(sb, cr)
		h._text(Vector2(cr.position.x, cr.position.y + 16), "ELVES" if side == 0 else "HUMANS", 11, Color.WHITE if on else Color(0.65, 0.65, 0.65), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 2)


func _ready_bar(r: Rect2, is_ready: bool, k: int) -> void:
	var ov := false
	if k > 0:
		ov = button(r, "readied", k)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.42, 0.14) if is_ready else Color(0.25, 0.25, 0.28)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.9, 0.35) if is_ready else (Color(0.85, 0.75, 0.5) if ov else Color(0.45, 0.45, 0.5))
	h.draw_style_box(sb, r)
	icon("check" if is_ready else "wait", r.position + Vector2(16, r.size.y / 2.0), 30)
	h._text(Vector2(r.position.x + 20, r.position.y + 19), "Ready" if is_ready else "Not ready", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 20, 2)


# --- Overlays -------------------------------------------------------------------------

func _overlay_frame(title: String) -> Rect2:
	var frame := Rect2(150, 70, h.size.x - 300, 590)
	nine("frame_big", frame, 40, 40, 40, 40)
	plaque(h.size.x / 2.0, 38, title, 380)
	var x := Rect2(frame.end.x - 62, frame.position.y + 26, 34, 34)
	var ov := button(x, "close", null)
	h._plate(x, Color(0.5, 0.14, 0.12) if ov else Color(0.38, 0.1, 0.09), Color(0.85, 0.65, 0.3), 6, 2)
	h._text(x.position + Vector2(0, 24), "✕", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, x.size.x, 0)
	return frame.grow(-40)


func _draw_credits() -> void:
	var body := _overlay_frame("CREDITS")
	var y := body.position.y + 70
	for c in CREDITS:
		ttext(Vector2(body.position.x, y), c[0], 18, Color(1.0, 0.8, 0.38), HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 4)
		var used: float = _centered_paragraph(Vector2(body.position.x + 60, y + 24), c[1], 14, body.size.x - 120)
		y += 46 + used


func _centered_paragraph(pos: Vector2, text: String, size: int, width: float) -> float:
	var words := text.split(" ")
	var lines: Array = []
	var line := ""
	for w in words:
		var trial := w if line == "" else line + " " + w
		if h._text_width(trial, size) > width and line != "":
			lines.append(line)
			line = w
		else:
			line = trial
	if line != "":
		lines.append(line)
	for i in lines.size():
		h._text(pos + Vector2(0, i * (size + 4)), lines[i], size, Color(0.95, 0.93, 0.88), HORIZONTAL_ALIGNMENT_CENTER, width, 2)
	return (lines.size() - 1) * (size + 4)


func _draw_tutorial() -> void:
	var body := _overlay_frame("TUTORIAL")
	for i in Guide.TOPICS.size():
		var r := Rect2(body.position.x + 10, body.position.y + 40 + i * 62, 330, 52)
		var on := tutorial_topic == i
		var ov := button(r, "topic", i)
		option_box(r, on, ov, Color(1.0, 0.8, 0.25))
		h._text(Vector2(r.position.x + 16, r.position.y + 32), Guide.TOPICS[i][0], 15, Color.WHITE if on else Color(0.85, 0.85, 0.82), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var pane := Rect2(body.position.x + 360, body.position.y + 40, body.size.x - 370, 364)
	slate(pane)
	ttext(Vector2(pane.position.x, pane.position.y + 40), Guide.TOPICS[tutorial_topic][0].to_upper(), 20, Color(1.0, 0.82, 0.38), HORIZONTAL_ALIGNMENT_CENTER, pane.size.x, 5)
	h._paragraph(Vector2(pane.position.x + 28, pane.position.y + 82), game.guide_answer(tutorial_topic), 15, Color(0.95, 0.93, 0.88), pane.size.x - 56, 22.0)
	h._paragraph(Vector2(body.position.x + 10, body.end.y - 40), "In a match the Wildwood Guide stands in your courtyard: press %s beside them to ask again." % game.key_label("interact"), 12, Color(0.8, 0.8, 0.76), body.size.x - 20, 15.0)


func _draw_progress() -> void:
	var body := _overlay_frame("PROGRESS")
	var panel := body.grow(10)
	h._draw_title_progress(panel)
	# SAVED PROGRESS: it saves itself; the code moves it to another device.
	var lx := panel.position.x + 30
	var y := panel.position.y + 446
	h._text(Vector2(lx, y), "SAVED PROGRESS", 12, Color(1.0, 0.82, 0.38), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var ago := "" if game.saved_at < 0.0 else "  Last saved %s." % _ago(Time.get_ticks_msec() / 1000.0 - game.saved_at)
	h._text(Vector2(lx, y + 16), "Your level, XP, gold, chests and store items save by themselves after every match and purchase.%s" % ago, 10, Color(0.92, 0.9, 0.84), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	h._text(Vector2(lx, y + 30), "To play on another device (iPad and PC): EXPORT here, then IMPORT the code there.", 10, Color(0.92, 0.9, 0.84), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var bw := 200.0
	wood_button(Rect2(lx, y + 40, bw, 36), "EXPORT CODE", "progress_export", null, "", 16)
	wood_button(Rect2(lx + bw + 16, y + 40, bw, 36), "IMPORT CODE", "progress_import", null, "", 16)
	h._text(Vector2(lx + 2 * bw + 34, y + 63), "Import copies the code from the clipboard" if not OS.has_feature("web") else "Import asks you to paste the code", 10, Color(0.75, 0.73, 0.68), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)


func _ago(t: float) -> String:
	if t < 60.0:
		return "just now"
	if t < 3600.0:
		return "%d min ago" % int(t / 60.0)
	return "%d h ago" % int(t / 3600.0)


# --- Input ------------------------------------------------------------------------------

func tick(clicked: bool, mouse: Vector2) -> void:
	## Called by game.menu_tick on every fresh click (mouse or pad confirm).
	if not clicked or h == null:
		return
	if screen == "store" and not store.reveal.is_empty() and overlay == "":
		store.press("store_reveal_close", null)
		return
	for b in h.menu_buttons:
		if b[0].has_point(mouse):
			_press(b[1], b[2])
			return


func open_store(kind: String = "", i: int = -1) -> void:
	store.show(kind, i)
	go("store")


func _press(id: String, arg) -> void:
	game.sfx.ui("ui_click", -4.0)
	if id.begins_with("store_"):
		store.press(id, arg)
		return
	match id:
		"play": go("map")
		"store": open_store()
		"gear":
			# A store item choice in Create Your Character: wear it if owned,
			# else open the store on it.
			if Store.owns(game, arg[0], arg[1]):
				Store.equip(game, arg[0], arg[1])
				if arg[0] == "hat" or arg[0] == "cape":
					preview_role = Role.BASE
			else:
				open_store(arg[0], arg[1])
		"customize": go("character")
		"settings":
			game.menu_open = true
			game.menu_tab = 5
		"tutorial": overlay = "tutorial"
		"credits": overlay = "credits"
		"progress": overlay = "progress"
		"close": overlay = ""
		"progress_export": game.export_progress()
		"progress_import": game.import_progress()
		"topic": tutorial_topic = int(arg)
		"exit":
			if exit_armed > 0.0:
				game._save_settings()
				game.get_tree().quit()
			exit_armed = 3.0
		"back": back()
		"map_page": map_first = clampi(map_first + int(arg), 0, maxi(MAP_CARDS.size() - 4, 0))
		"map_card":
			var i := int(arg)
			if _card_open(i):
				map_pick = i
				# Ember Pass has other ground, so picking it (or leaving it)
				# rebuilds the world and comes back to this screen.
				game.select_map(MAP_CARDS[i][2])
				game._save_settings()
			elif MAP_CARDS[i][2] == 1:
				game.toast("The Moonlit Wildwood unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
			else:
				game.toast("%s is coming in a later update" % MAP_CARDS[i][0].capitalize(), Color(1.0, 0.8, 0.5))
		"difficulty":
			game.bot_difficulty = str(arg)
			game._save_settings()
		"team_size":
			pass   # fixed at 4v4 for now
		"split":
			game.split_screen = bool(arg)
			if not game.split_screen:
				game.couch_players = 1
				join_pads = []
			game._save_settings()
		"split_layout":
			game.set_split_layout(str(arg))
		"to_lobby":
			if _card_open(map_pick):
				go("lobby")
		"char_tab": char_tab = int(arg)
		"preview_team": preview_team = int(arg)
		"preview_role": preview_role = int(arg)
		"rank": preview_rank = int(arg)
		"body":
			game.hero_body = int(arg)
			preview_role = Role.BASE   # a class wears its own body: show the build itself
			game._save_settings()
		"body_step":
			game.hero_body = posmod(game.hero_body + int(arg), Stats.HERO_BODIES.size())
			preview_role = Role.BASE
			game._save_settings()
		"skin":
			game.hero_skin = int(arg)
			game._save_settings()
		"face":
			game.hero_face = int(arg)
			if preview_role == Role.KNIGHT:
				preview_role = Role.BASE   # the helmet hides the brows
			game._save_settings()
		"eye":
			game.hero_eye = int(arg)
			if preview_role == Role.KNIGHT:
				preview_role = Role.BASE
			game._save_settings()
		"mark":
			game.hero_mark = int(arg)
			if preview_role == Role.KNIGHT:
				preview_role = Role.BASE
			game._save_settings()
		"hair", "trim", "hair_style" when not Store.owns(game, id, int(arg)):
			open_store(id, int(arg))
		"hair":
			game.hero_hair = int(arg)
			if preview_role == Role.KNIGHT:
				preview_role = Role.BASE   # the helmet hides the hair
			game._save_settings()
		"trim":
			game.hero_trim = int(arg)
			game._save_settings()
		"look":
			if int(arg) == 0 or game.unlocked():
				game.hero_look = int(arg)
				game._save_settings()
			else:
				game.toast("The Shadowborn look unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
		"hair_style":
			game.hero_hair_style = int(arg)
			if preview_role == Role.KNIGHT:
				preview_role = Role.BASE   # the helmet hides most of the hair
			game._save_settings()
		"confirm":
			game._save_settings()
			go("title")
		"side":
			game.lobby_sides[arg[0]] = arg[1]
		"readied":
			readied[int(arg)] = not readied[int(arg)]
			if readied[int(arg)] and stage:
				stage.cheer(int(arg))
		"kick": remove_player(int(arg))
		"add_player": add_player(-1)
		"start": start()


func add_player(device: int) -> void:
	## A gamepad joins the lobby as the next local player.
	if game.couch_players >= game.COUCH_MAX:
		return
	game.split_screen = true
	if device >= 0:
		if device in join_pads:
			return
		join_pads.append(device)
	game.couch_players += 1
	readied[game.couch_players - 1] = false
	game.sfx.ui("rank_up", -6.0)


func remove_player(k: int) -> void:
	if k <= 0 or k >= game.couch_players:
		return
	if k - 1 < join_pads.size():
		join_pads.remove_at(k - 1)
	for j in range(k, 3):
		readied[j] = readied[j + 1]
		game.lobby_sides[j] = game.lobby_sides[j + 1]
	readied[3] = false
	game.couch_players -= 1


func pad_event(event: InputEvent) -> bool:
	## Lobby: pads other than player 1's join with A / Cross, ready up with
	## A again, switch sides on the D-pad, and leave with B / Circle.
	## Returns true when the press was theirs (so it does not click for player 1).
	if not (event is InputEventJoypadButton and event.pressed):
		return false
	var dev: int = event.device
	if screen != "lobby" or overlay != "":
		p1_pad = dev
		return false
	var k := join_pads.find(dev)
	if k < 0:
		if dev == p1_pad or not _split_on():
			p1_pad = dev
			return false
		if event.button_index == JOY_BUTTON_A:
			add_player(dev)
			return true
		return false
	var who := k + 1
	match event.button_index:
		JOY_BUTTON_A:
			readied[who] = not readied[who]
			if readied[who] and stage:
				stage.cheer(who)
		JOY_BUTTON_B:
			remove_player(who)
		JOY_BUTTON_DPAD_LEFT:
			game.lobby_sides[who] = 0
		JOY_BUTTON_DPAD_RIGHT:
			game.lobby_sides[who] = 1
	return true


func start() -> void:
	for k in range(1, game.couch_players):
		if not readied[k]:
			return
	game.join_pads = join_pads.duplicate()
	game.p1_pad_device = p1_pad
	game._start_match(game.lobby_sides[0])
