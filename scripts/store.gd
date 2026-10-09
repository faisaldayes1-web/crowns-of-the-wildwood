extends RefCounted
## The STORE (main menu): spend the gold from match rewards on cosmetic items
## for your own hero (hair colours, armour tints, capes and scarves, cape
## dyes, hats, weapon skins and banner pieces), and open the Match Chests
## each match banks. Looks only: nothing sold here changes a fight.
##
## The catalogue is Stats.STORE_ITEMS; ownership is game.owned_items
## ("kind:index" keys, saved with the account). The static functions below
## are the ownership rules everyone uses (menu.gd, hud.gd, game.gd); the
## instance is the screen, drawn by menu.gd through the HUD.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

# Kind -> [the game variable that wears it, the Stats table, free entries below this index].
const KINDS := {
	"hair": ["hero_hair", "HERO_HAIR", Stats.HERO_HAIR_FREE],
	"hair_style": ["hero_hair_style", "HERO_HAIR_STYLES", Stats.HERO_HAIR_STYLE_FREE],
	"trim": ["hero_trim", "HERO_TRIM", Stats.HERO_TRIM_FREE],
	"outfit": ["hero_outfit", "HERO_OUTFITS", 1],
	"hat": ["hero_hat", "HERO_HATS", 1],
	"cape": ["hero_cape", "HERO_CAPES", 1],
	"weapon": ["hero_weapon", "WEAPON_SKINS", 1],
	"banner_bg": ["banner_bg", "BANNER_BACKGROUNDS", Stats.BANNER_BG_FREE],
	"banner_emblem": ["banner_emblem", "BANNER_EMBLEMS", Stats.BANNER_EMBLEM_FREE],
	"banner_frame": ["banner_frame", "BANNER_FRAMES", Stats.BANNER_FRAME_FREE],
}
# The store's tabs: [title, menu icon, kinds shown, preview class].
const TABS := [["HAIR", "hair", ["hair_style", "hair"], Role.BASE], ["ARMOUR", "tunic", ["outfit"], Role.BASE],
	["CAPES & DYES", "palette", ["cape", "trim"], Role.BASE], ["HATS", "crown", ["hat"], Role.BASE],
	["WEAPONS", "swords", ["weapon"], Role.KNIGHT], ["BANNERS", "emblem", ["banner_bg", "banner_emblem", "banner_frame"], Role.BASE]]
# Swatch colours for the gear with no colour of its own (hats, capes).
const HAT_SWATCH := [Color(0.3, 0.3, 0.34), Color(0.75, 0.2, 0.18), Color(0.86, 0.72, 0.42), Color(0.35, 0.68, 0.3),
	Color(0.95, 0.55, 0.7), Color(0.32, 0.22, 0.62), Color(0.62, 0.65, 0.7), Color(1.0, 0.8, 0.28)]
const CAPE_SWATCH := [Color(0.3, 0.3, 0.34), Color(0.8, 0.3, 0.25), Color(0.5, 0.36, 0.22), Color(0.3, 0.62, 0.28),
	Color(0.62, 0.1, 0.16), Color(1.0, 0.5, 0.15)]
const KIND_LABEL := {"hair": "Hair Colour", "hair_style": "Hair Style", "trim": "Cape Dye", "outfit": "Armour Tint", "hat": "Hat", "cape": "Cape",
	"weapon": "Weapon Skin", "banner_bg": "Banner Background", "banner_emblem": "Banner Emblem", "banner_frame": "Banner Frame"}


# --- Ownership (static: shared by the menu, the HUD and the game) ------------------

static func key(kind: String, i: int) -> String:
	return "%s:%d" % [kind, i]


static func item_for(kind: String, i: int) -> Array:
	## The STORE_ITEMS entry selling this, or [] when it is not sold (free).
	for it in Stats.STORE_ITEMS:
		if it[0] == kind and it[1] == i:
			return it
	return []


static func price(it: Array) -> int:
	return int(Stats.RARITIES[it[2]][2])


static func owns(game, kind: String, i: int) -> bool:
	if not KINDS.has(kind) or i < int(KINDS[kind][2]) or item_for(kind, i).is_empty():
		return true
	return key(kind, i) in game.owned_items or "--debug-store-all" in OS.get_cmdline_user_args()


static func table(kind: String) -> Array:
	match kind:
		"hair": return Stats.HERO_HAIR
		"hair_style": return Stats.HERO_HAIR_STYLES
		"trim": return Stats.HERO_TRIM
		"outfit": return Stats.HERO_OUTFITS
		"hat": return Stats.HERO_HATS
		"cape": return Stats.HERO_CAPES
		"weapon": return Stats.WEAPON_SKINS
		"banner_bg": return Stats.BANNER_BACKGROUNDS
		"banner_emblem": return Stats.BANNER_EMBLEMS
		"banner_frame": return Stats.BANNER_FRAMES
	return []


static func item_name(kind: String, i: int) -> String:
	var row = table(kind)[i]
	if row is String:
		return String(row).replace("_", " ").capitalize()
	return String(row[0])


static func equipped(game, kind: String) -> int:
	return int(game.get(KINDS[kind][0]))


static func equip(game, kind: String, i: int) -> void:
	game.set(KINDS[kind][0], i)
	game._save_settings()


static func locked_toast(game, kind: String, i: int) -> void:
	## A locked choice was clicked: open the store on it (or say where it is).
	if game.main_menu and not game.playing:
		game.main_menu.open_store(kind, i)
		return
	var it := item_for(kind, i)
	game.toast("%s is in the STORE for %d gold" % [item_name(kind, i), price(it)], Color(1.0, 0.82, 0.4))


static func drop_unowned(game) -> void:
	## After loading: anything worn but not owned goes back to the default.
	for kind in KINDS:
		if not owns(game, kind, equipped(game, kind)):
			game.set(KINDS[kind][0], 0)


static func buy(game, kind: String, i: int) -> bool:
	var it := item_for(kind, i)
	if it.is_empty() or owns(game, kind, i) or game.account_gold < price(it):
		return false
	game.account_gold -= price(it)
	game.owned_items.append(key(kind, i))
	equip(game, kind, i)   # also saves
	return true


static func open_chest(game, rng: RandomNumberGenerator = null) -> Array:
	## Opens one Match Chest: an item not yet owned, picked by rarity weight,
	## or Stats.CHEST_GOLD gold when everything is owned. Returns the item
	## ([kind, index, rarity]) or [] for the gold.
	if game.account_chests <= 0:
		return []
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	game.account_chests -= 1
	var pool: Array = Stats.STORE_ITEMS.filter(func(it): return not owns(game, it[0], it[1]))
	if pool.is_empty():
		game.account_gold += Stats.CHEST_GOLD
		game._save_settings()
		return []
	var total := 0
	for it in pool:
		total += int(Stats.RARITIES[it[2]][3])
	var roll := rng.randi_range(0, total - 1)
	var got: Array = pool[0]
	for it in pool:
		roll -= int(Stats.RARITIES[it[2]][3])
		if roll < 0:
			got = it
			break
	game.owned_items.append(key(got[0], got[1]))
	game._save_settings()
	return got


static func swatch_color(kind: String, i: int, team: int = 0) -> Color:
	## The colour a choice is shown as on a tile.
	match kind:
		"hair": return Stats.HERO_HAIR[i][1]
		"trim":
			var c: Color = Stats.HERO_TRIM[i][1]
			return Stats.FACTIONS[team].color if c.a == 0.0 else c
		"outfit", "weapon":
			var c: Color = table(kind)[i][1]
			return Color(0.62, 0.65, 0.7) if c.a == 0.0 else c
		"hat": return HAT_SWATCH[i % HAT_SWATCH.size()]
		"cape": return CAPE_SWATCH[i % CAPE_SWATCH.size()]
		"banner_bg": return Stats.BANNER_BACKGROUNDS[i][2].lerp(Stats.BANNER_BACKGROUNDS[i][1], 0.4)
		"banner_frame": return Stats.BANNER_FRAMES[i][1]
	return Color(0.2, 0.2, 0.24)


static func wear(custom: Dictionary, kind: String, i: int) -> Dictionary:
	## `custom` (game.hero_custom()) with one item tried on.
	var c := custom.duplicate()
	match kind:
		"hair": c.hair = Stats.HERO_HAIR[i][1]
		"hair_style": c.hair_style = i
		"trim":
			if i == 0:
				c.erase("trim")
			else:
				c.trim = Stats.HERO_TRIM[i][1]
		"outfit": c.outfit = i
		"hat": c.hat = Stats.HERO_HATS[i][1]
		"cape": c.cape = Stats.HERO_CAPES[i][1]
		"weapon": c.weapon = i
	for k in ["outfit", "weapon", "hat", "cape"]:
		if c.has(k) and (c[k] is int and c[k] == 0 or c[k] is String and c[k] == ""):
			c.erase(k)
	return c


# --- The screen --------------------------------------------------------------------

var game
var menu                     # menu.gd (its drawing helpers)
var h
var tab := 0
var pick: Array = []         # the item on show: [kind, index, rarity]
var flash := 0.0             # gold flash after a purchase
var reveal: Array = []       # a chest just opened: [item or [], time opened]
var icons := {}              # item icon textures by path (null when there is none)
var instant_turn := "--shot-frame=" in " ".join(OS.get_cmdline_user_args())   # renders: no easing


func _init(g, m) -> void:
	game = g
	menu = m


func items_in(t: int) -> Array:
	var kinds: Array = TABS[t][2]
	return Stats.STORE_ITEMS.filter(func(it): return it[0] in kinds)


func show(kind: String = "", i: int = -1) -> void:
	## Open on an item (from a locked choice in Create Your Character).
	reveal = []
	pick = []
	if kind != "":
		for t in TABS.size():
			if kind in TABS[t][2]:
				tab = t
		pick = item_for(kind, i)
	if pick.is_empty():
		var first := items_in(tab)
		pick = first[0] if not first.is_empty() else []


func preview_role() -> int:
	return TABS[tab][3]


func preview_custom() -> Dictionary:
	var c: Dictionary = game.hero_custom()
	if not pick.is_empty() and not pick[0].begins_with("banner"):
		c = wear(c, pick[0], pick[1])
	return c


func draw(hud, stage, team: int) -> void:
	h = hud
	flash = maxf(flash - h.get_process_delta_time(), 0.0)
	if pick.is_empty():
		show()
	if stage:
		stage.show_hero(team, preview_role(), preview_custom(), 1)
		# Capes hang at the back: turn the hero round to show them.
		var want := 2.5 if not pick.is_empty() and pick[0] == "cape" else 0.0
		stage.hero_spin = want if instant_turn else lerpf(stage.hero_spin, want, minf(h.get_process_delta_time() * 5.0, 1.0))
	menu.plaque(632, 22, "STORE", 420)
	menu.icon("crown", Vector2(632, 20), 46)
	_wallet(Rect2(1012, 24, 240, 62))
	_chests(Rect2(28, 24, 300, 62))
	# Tabs down the left, like Create Your Character's.
	h._ivy(Vector2(52, 128 + TABS.size() * 62 - 6), Vector2(0, -1), TABS.size() * 62.0 - 14.0, 41)
	for i in TABS.size():
		var r := Rect2(60, 128 + i * 62, 272, 52)
		var sel := tab == i
		var ov: bool = menu.button(r, "store_tab", i)
		var rr := r.grow(2) if ov else r
		menu.nine("panel_row", rr, 14, 14, 14, 14)
		if sel:
			menu.icon("arrow_right", rr.position + Vector2(rr.size.x - 22, rr.size.y / 2.0), 22, Color(1.0, 0.86, 0.45))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.32, 0.22, 0.08, 0.55)
			sb.set_corner_radius_all(8)
			sb.set_border_width_all(3)
			sb.border_color = Color(1.0, 0.78, 0.3)
			sb.shadow_color = Color(1.0, 0.7, 0.2, 0.45)
			sb.shadow_size = 10
			h.draw_style_box(sb, rr)
		menu.icon(TABS[i][1], rr.position + Vector2(32, rr.size.y / 2.0), 38)
		menu.ttext(rr.position + Vector2(62, rr.size.y / 2.0 + 7), TABS[i][0], 19, Color(1.0, 0.92, 0.65) if sel else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		var have := items_in(i).filter(func(it): return owns(game, it[0], it[1])).size()
		h._text(Vector2(rr.end.x - 96, rr.position.y + rr.size.y / 2.0 + 5), "%d/%d" % [have, items_in(i).size()], 11, Color(0.85, 0.82, 0.72), HORIZONTAL_ALIGNMENT_RIGHT, 60, 2)
	_grid(Rect2(832, 110, 430, 480))
	_detail(Rect2(832, 600, 430, 110))
	menu.wood_button(Rect2(60, 652, 160, 52), "BACK", "back", null, "", 20)
	if flash > 0.0:
		_purchased()
	if not reveal.is_empty():
		_draw_reveal()


func _purchased() -> void:
	## Just bought: a gold ribbon pops over the hero, sparkles round it.
	var k := clampf(flash / 2.0, 0.0, 1.0)
	var a := clampf(flash / 0.5, 0.0, 1.0)
	var pop := 1.0 + 0.25 * sin(clampf((2.0 - flash) / 0.25, 0.0, 1.0) * PI)
	var c := Vector2(500, 150)
	h.draw_set_transform(c, 0.0, Vector2(pop, pop))
	var band := Rect2(-150, -26, 300, 52)
	h._plate(band, Color(0.55, 0.32, 0.05, 0.95 * a), Color(1.0, 0.85, 0.35, a), 12, 3)
	menu.ttext(Vector2(-150, 12), "PURCHASED!", 30, Color(1.0, 0.95, 0.75, a), HORIZONTAL_ALIGNMENT_CENTER, 300, 6)
	h.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for n in 10:
		var ang := TAU * n / 10.0 + (1.0 - k) * 2.0
		var p := c + Vector2(cos(ang) * 190.0, sin(ang) * 70.0) * (1.4 - k * 0.4)
		h.draw_circle(p, 4.0 + 3.0 * k, Color(1.0, 0.9, 0.4, a))


func _wallet(r: Rect2) -> void:
	menu.slate(r)
	var pulse := clampf(flash / 2.0, 0.0, 1.0)
	h._icon("coin", r.position + Vector2(34, r.size.y / 2.0), 11.0 + 2.0 * pulse, Color.WHITE)
	menu.ttext(Vector2(r.position.x + 62, r.position.y + 38), "%d" % game.account_gold, 30, Color(1.0, 0.85, 0.35).lerp(Color.WHITE, pulse), HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	h._text(Vector2(r.position.x + 62, r.position.y + 54), "GOLD  ·  +%d to +%d a match" % [Stats.MATCH_GOLD.loss, Stats.MATCH_GOLD.win], 10, Color(0.88, 0.85, 0.75), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _chests(r: Rect2) -> void:
	menu.slate(r)
	var n: int = game.account_chests
	var bob := sin(Time.get_ticks_msec() / 260.0) * 2.0 if n > 0 else 0.0
	h._icon("chest", r.position + Vector2(36, r.size.y / 2.0 + bob), 11.0, Color.WHITE, n == 0)
	menu.ttext(Vector2(r.position.x + 66, r.position.y + 30), "MATCH CHESTS", 16, Color(1.0, 0.92, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	h._text(Vector2(r.position.x + 66, r.position.y + 50), "x%d  ·  one per match" % n, 12, Color(0.9, 0.88, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var b := Rect2(r.end.x - 92, r.position.y + 12, 80, r.size.y - 24)
	var ov: bool = menu.button(b, "store_chest") and n > 0
	menu.nine("btn_green" if n > 0 else "btn_green_off", b.grow(2) if ov else b, 48, 20, 48, 20)
	menu.ttext(Vector2(b.position.x, b.position.y + 26), "OPEN", 17, Color.WHITE if n > 0 else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 4)


func _grid(panel: Rect2) -> void:
	menu.slate(panel)
	var pr := Rect2(panel.get_center().x - 165, panel.position.y - 22, 330, 48)
	menu.nine("plaque", pr, 110, 24, 110, 24)
	menu.ttext(Vector2(pr.position.x, pr.position.y + 33), TABS[tab][0], 22, Color(1.0, 0.86, 0.45), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 5)
	var items := items_in(tab)
	var cols := 3
	var rows := ceili(items.size() / float(cols))
	var cw := (panel.size.x - 40.0 - (cols - 1) * 10.0) / cols
	var ch := minf(116.0, (panel.size.y - 62.0 - (rows - 1) * 8.0) / maxf(rows, 1))
	for n in items.size():
		var it: Array = items[n]
		var r := Rect2(panel.position.x + 20 + (n % cols) * (cw + 10), panel.position.y + 44 + (n / cols) * (ch + 8), cw, ch)
		_card(r, it)


func _card(r: Rect2, it: Array) -> void:
	var kind: String = it[0]
	var i: int = it[1]
	var rar: Array = Stats.RARITIES[it[2]]
	var have := owns(game, kind, i)
	var worn := have and equipped(game, kind) == i
	var sel := pick == it
	var ov: bool = menu.button(r, "store_pick", it)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.15).lerp(rar[1].darkened(0.6), 0.35)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3 if sel else 2)
	sb.border_color = Color(1.0, 0.85, 0.4) if sel else (rar[1].lightened(0.2) if ov else rar[1].darkened(0.25))
	if sel:
		sb.shadow_color = Color(rar[1], 0.6)
		sb.shadow_size = 10
	h.draw_style_box(sb, r)
	# A rarity strip along the top edge.
	h.draw_rect(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, 4)), rar[1])
	# The item's picture fills the card above its name and price, over a
	# soft glow in the rarity colour.
	var side := minf(r.size.x - 16.0, r.size.y - 40.0)
	var pic := Rect2(r.position.x + (r.size.x - side) / 2.0, r.position.y + 9, side, side)
	if icon_tex(kind, i):
		var gc := pic.get_center()
		for k in 6:
			h.draw_circle(gc, side * (0.5 - k * 0.07), Color(rar[1], 0.05 + k * 0.025))
	thumb(pic, kind, i)
	h._text(Vector2(r.position.x + 4, r.end.y - 22), item_name(kind, i).to_upper(), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 2)
	var by := r.end.y - 7
	if worn:
		h._icon("check", Vector2(r.position.x + r.size.x / 2.0 - 36, by - 5), 4.0, Color(0.5, 1.0, 0.45))
		h._text(Vector2(r.position.x, by), "EQUIPPED", 11, Color(0.55, 1.0, 0.45), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
	elif have:
		h._text(Vector2(r.position.x, by), "OWNED", 11, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 2)
	else:
		var p := "%d" % price(it)
		var tw: float = h._text_width(p, 13)
		var cx := r.position.x + r.size.x / 2.0
		h._icon("coin", Vector2(cx - tw / 2.0 - 9, by - 5), 3.6, Color.WHITE)
		h._text(Vector2(cx - tw / 2.0 + 3, by), p, 13, Color(1.0, 0.85, 0.35) if game.account_gold >= price(it) else Color(0.85, 0.6, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func icon_tex(kind: String, i: int) -> Texture2D:
	## The item rendered on the real model (tools/render_store_icons.gd), or null.
	var path := "res://assets/ui/store/%s_%d.png" % [kind, i]
	if not icons.has(path):
		icons[path] = load(path) if ResourceLoader.exists(path) else null
	return icons[path]


func thumb(r: Rect2, kind: String, i: int) -> void:
	## A picture of a choice: the item rendered on the hero when it is big
	## enough to read, else a dyed disc, a banner piece or a drawn outline.
	var tx := icon_tex(kind, i) if minf(r.size.x, r.size.y) >= 48.0 else null
	if tx:
		var sq := minf(r.size.x, r.size.y)
		h.draw_texture_rect(tx, Rect2(r.get_center() - Vector2(sq, sq) / 2.0, Vector2(sq, sq)), false)
		return
	var c := r.get_center()
	var rad := minf(r.size.x, r.size.y) / 2.0
	var col := swatch_color(kind, i)
	match kind:
		"banner_bg", "banner_frame":
			var b := {"name": "", "bg": i if kind == "banner_bg" else game.banner_bg, "emblem": game.banner_emblem,
				"frame": i if kind == "banner_frame" else 1, "title": "", "level": 1, "team": 0}
			var br := Rect2(c - Vector2(rad * 1.6, rad * 0.7), Vector2(rad * 3.2, rad * 1.4))
			h._plate(br, Stats.BANNER_BACKGROUNDS[b.bg][1], Stats.BANNER_FRAMES[b.frame][1], 6, 3 if kind == "banner_frame" else 2)
			h.draw_rect(Rect2(br.position + Vector2(4, 4), Vector2(br.size.x - 8, br.size.y * 0.4)), Color(Stats.BANNER_BACKGROUNDS[b.bg][2], 0.4))
		"banner_emblem":
			h.draw_circle(c, rad, Color(0.05, 0.05, 0.08, 0.8))
			h.draw_arc(c, rad, 0, TAU, 32, Color(1.0, 0.8, 0.3), 2.0)
			h._icon(Stats.BANNER_EMBLEMS[i], c, rad * 0.32, Color.WHITE)
		"hair_style":
			menu.h = h
			menu.hair_thumb(c + Vector2(0, rad * 0.1), i, rad / 13.0)
		"hat":
			_hat_glyph(c, rad, i, col)
		"cape":
			_cape_glyph(c, rad, i, col)
		"weapon":
			var glow: float = Stats.WEAPON_SKINS[i][2]
			if glow > 0.0:
				h.draw_circle(c, rad, Color(col, 0.25))
			_sword_glyph(c, rad, col)
		"outfit":
			_plate_glyph(c, rad, col)
		_:
			h.draw_circle(c, rad, Color(0.05, 0.04, 0.03))
			h.draw_circle(c, rad - 3, col)
			h.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.22, Color(1, 1, 1, 0.3))


func _sword_glyph(c: Vector2, rad: float, col: Color) -> void:
	## A sword at a slant in the skin's metal.
	var ink := Color(0.08, 0.06, 0.05)
	var d := Vector2(0.7, -0.7)
	var n := Vector2(0.7, 0.7)
	var tip := c + d * rad * 1.0
	var base := c - d * rad * 0.35
	var blade := PackedVector2Array([base + n * rad * 0.13, tip + n * rad * 0.03, tip + d * rad * 0.12, tip - n * rad * 0.03, base - n * rad * 0.13])
	h.draw_colored_polygon(blade, col)
	h.draw_polyline(blade + PackedVector2Array([blade[0]]), ink, 1.5)
	h.draw_line(c - d * rad * 0.1 + n * rad * 0.42, c - d * rad * 0.1 - n * rad * 0.42, col.darkened(0.35), rad * 0.16)
	h.draw_line(c - d * rad * 0.45, c - d * rad * 0.85, Color(0.45, 0.28, 0.14), rad * 0.13)
	h.draw_circle(c - d * rad * 0.9, rad * 0.1, col.darkened(0.2))


func _plate_glyph(c: Vector2, rad: float, col: Color) -> void:
	## A breastplate in the tint.
	var ink := Color(0.08, 0.06, 0.05)
	var p := PackedVector2Array([c + Vector2(-rad * 0.75, -rad * 0.7), c + Vector2(-rad * 0.3, -rad * 0.8), c + Vector2(0, -rad * 0.55),
		c + Vector2(rad * 0.3, -rad * 0.8), c + Vector2(rad * 0.75, -rad * 0.7), c + Vector2(rad * 0.62, rad * 0.35),
		c + Vector2(0, rad * 0.85), c + Vector2(-rad * 0.62, rad * 0.35)])
	h.draw_colored_polygon(p, col)
	h.draw_polyline(p + PackedVector2Array([p[0]]), ink, 1.5)
	h.draw_line(c + Vector2(0, -rad * 0.5), c + Vector2(0, rad * 0.75), col.darkened(0.3), 2.0)
	h.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.5, -rad * 0.5), c + Vector2(-rad * 0.15, -rad * 0.45), c + Vector2(-rad * 0.3, rad * 0.2)]), Color(1, 1, 1, 0.25))


func _hat_glyph(c: Vector2, rad: float, i: int, col: Color) -> void:
	var ink := Color(0.08, 0.06, 0.05)
	var style: String = Stats.HERO_HATS[i][1]
	h.draw_circle(c + Vector2(0, rad * 0.35), rad * 0.55, Color(0.95, 0.8, 0.68))   # a head to wear it
	match style:
		"straw", "wizard":
			h.draw_rect(Rect2(c + Vector2(-rad, -rad * 0.05), Vector2(rad * 2.0, rad * 0.18)), col.darkened(0.15))
			if style == "wizard":
				h.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.5, 0), c + Vector2(rad * 0.5, 0), c + Vector2(rad * 0.15, -rad * 1.05)]), col)
				h.draw_circle(c + Vector2(0, -rad * 0.35), rad * 0.1, Color(1.0, 0.85, 0.3))
			else:
				h.draw_rect(Rect2(c + Vector2(-rad * 0.5, -rad * 0.5), Vector2(rad, rad * 0.5)), col)
				h.draw_rect(Rect2(c + Vector2(-rad * 0.5, -rad * 0.15), Vector2(rad, rad * 0.1)), Color(0.75, 0.2, 0.18))
		"cap":
			h.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.6, 0), c + Vector2(rad * 0.6, 0), c + Vector2(rad * 0.4, -rad * 0.45), c + Vector2(-rad * 0.45, -rad * 0.5)]), col)
			h.draw_line(c + Vector2(rad * 0.3, -rad * 0.35), c + Vector2(rad * 0.95, -rad * 1.0), Color(1.0, 0.95, 0.85), 4.0)
		"horns":
			h.draw_circle(c + Vector2(0, -rad * 0.05), rad * 0.55, col)
			for sx in [-1.0, 1.0]:
				h.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * rad * 0.4, -rad * 0.2), c + Vector2(sx * rad * 0.6, -rad * 0.05), c + Vector2(sx * rad * 1.0, -rad * 0.85)]), Color(0.95, 0.9, 0.78))
		"circlet", "flowers", "gold":
			h.draw_rect(Rect2(c + Vector2(-rad * 0.6, -rad * 0.2), Vector2(rad * 1.2, rad * 0.16)), col.darkened(0.1))
			for k in 5:
				var p := c + Vector2(-rad * 0.5 + k * rad * 0.25, -rad * 0.25)
				var pc: Color = col if style != "flowers" else [Color(1, 0.6, 0.75), Color.WHITE, Color(1, 0.88, 0.3)][k % 3]
				h.draw_circle(p, rad * (0.13 if style != "gold" else 0.08), pc)
			if style == "gold":
				h.draw_circle(c + Vector2(0, -rad * 0.18), rad * 0.12, Color(0.9, 0.2, 0.3))
		_:
			h.draw_line(c + Vector2(-rad * 0.6, -rad * 0.6), c + Vector2(rad * 0.6, rad * 0.6), Color(0.85, 0.82, 0.78), 3.0)
	h.draw_arc(c + Vector2(0, rad * 0.35), rad * 0.55, 0, TAU, 24, ink, 1.5)


func _cape_glyph(c: Vector2, rad: float, i: int, col: Color) -> void:
	var style: String = Stats.HERO_CAPES[i][1]
	if style == "scarf":
		h.draw_rect(Rect2(c + Vector2(-rad * 0.6, -rad * 0.6), Vector2(rad * 1.2, rad * 0.35)), col)
		h.draw_colored_polygon(PackedVector2Array([c + Vector2(rad * 0.2, -rad * 0.3), c + Vector2(rad * 0.5, -rad * 0.3), c + Vector2(rad * 0.75, rad * 0.9), c + Vector2(rad * 0.45, rad * 0.9)]), col.darkened(0.2))
		return
	var poly := PackedVector2Array([c + Vector2(-rad * 0.45, -rad * 0.8), c + Vector2(rad * 0.45, -rad * 0.8), c + Vector2(rad * 0.85, rad * 0.9), c + Vector2(-rad * 0.85, rad * 0.9)])
	h.draw_colored_polygon(poly, col)
	h.draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.08, 0.06, 0.05), 1.5)
	match style:
		"royal":
			h.draw_rect(Rect2(c + Vector2(-rad * 0.85, rad * 0.75), Vector2(rad * 1.7, rad * 0.15)), Color(1.0, 0.8, 0.3))
			h.draw_rect(Rect2(c + Vector2(-rad * 0.55, -rad * 0.9), Vector2(rad * 1.1, rad * 0.22)), Color(0.96, 0.94, 0.9))
		"ember":
			h.draw_rect(Rect2(c + Vector2(-rad * 0.85, rad * 0.72), Vector2(rad * 1.7, rad * 0.18)), Color(1.0, 0.75, 0.2))
		"leaf":
			for k in 4:
				h.draw_circle(c + Vector2(-rad * 0.6 + k * rad * 0.4, rad * 0.88), rad * 0.16, col.lightened(0.25))


func _detail(r: Rect2) -> void:
	## The picked item: name, rarity and what it is, and BUY / EQUIP.
	if pick.is_empty():
		return
	var kind: String = pick[0]
	var i: int = pick[1]
	var rar: Array = Stats.RARITIES[pick[2]]
	menu.slate(r)
	if kind.begins_with("banner"):
		# Banner pieces show on the banner itself, over the hero's head.
		var b := {"name": game.hero_name if game.hero_name.strip_edges() != "" else "You", "bg": game.banner_bg, "emblem": game.banner_emblem,
			"frame": game.banner_frame, "title": Stats.BANNER_TITLES[game.banner_title][1], "level": game.account_level(), "team": 0}
		b[kind.trim_prefix("banner_")] = i
		h._draw_banner(Rect2(390, 104, 400, 66), b)
	menu.ttext(Vector2(r.position.x + 20, r.position.y + 34), item_name(kind, i).to_upper(), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
	h._text(Vector2(r.position.x + 20, r.position.y + 56), "%s  ·  %s" % [rar[0].to_upper(), KIND_LABEL[kind]], 12, rar[1].lightened(0.15), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var note := "Looks only: no effect in a fight."
	match kind:
		"hat": note = "Worn while you have no class hat on."
		"weapon": note = "Recolours every class's weapons."
		"cape": note = "Hangs on every class, in your cape dye."
		"trim": note = "Dyes your cape, sash and scarf."
	h._text(Vector2(r.position.x + 20, r.position.y + 76), note, 11, Color(0.85, 0.83, 0.78), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var b := Rect2(r.end.x - 196, r.position.y + 20, 180, 62)
	var have := owns(game, kind, i)
	if not have:
		var cost := price(pick)
		var can: bool = game.account_gold >= cost
		var ov: bool = menu.button(b, "store_buy") and can
		menu.nine("btn_green" if can else "btn_green_off", b.grow(3) if ov else b, 48, 20, 48, 20, Color(1.12, 1.12, 1.12) if ov else Color.WHITE)
		menu.ttext(Vector2(b.position.x + 38, b.position.y + 40), "BUY", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
		h._icon("coin", Vector2(b.position.x + 106, b.position.y + 31), 4.5, Color.WHITE)
		menu.ttext(Vector2(b.position.x + 118, b.position.y + 39), "%d" % cost, 19, Color(1.0, 0.88, 0.4), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		if not can:
			h._text(Vector2(b.position.x, b.end.y + 14), "Need %d more gold" % (cost - game.account_gold), 11, Color(1.0, 0.7, 0.6), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 2)
	elif equipped(game, kind) != i:
		menu.wood_button(b, "EQUIP", "store_equip", null, "", 22)
	else:
		var off: bool = kind in ["outfit", "hat", "cape", "weapon", "trim"]
		if off:
			menu.wood_button(b, "TAKE OFF", "store_unequip", null, "", 20)
		else:
			menu.option_box(b, true, false)
			menu.ttext(Vector2(b.position.x, b.position.y + 40), "EQUIPPED", 20, Color(0.6, 1.0, 0.5), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 4)
	h._text(Vector2(r.position.x + 20, r.end.y - 12), "Also in Create Your Character once owned", 10, Color(0.7, 0.68, 0.62), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


func _draw_reveal() -> void:
	## A chest just opened: the chest bursts, then the card it held.
	var t: float = (Time.get_ticks_msec() / 1000.0) - float(reveal[1])
	h.draw_rect(Rect2(Vector2.ZERO, h.size), Color(0, 0, 0, 0.7))
	menu.button(Rect2(Vector2.ZERO, h.size), "store_reveal_close")
	var c := Vector2(h.size.x / 2.0, h.size.y / 2.0 - 10)
	var it: Array = reveal[0]
	var col: Color = Stats.RARITIES[it[2]][1] if not it.is_empty() else Color(1.0, 0.8, 0.3)
	# Rays.
	var k := clampf(t / 0.5, 0.0, 1.0)
	for n in 12:
		var a := TAU * n / 12.0 + t * 0.4
		var p := PackedVector2Array([c, c + Vector2(cos(a - 0.08), sin(a - 0.08)) * 300.0 * k, c + Vector2(cos(a + 0.08), sin(a + 0.08)) * 300.0 * k])
		h.draw_colored_polygon(p, Color(col, 0.18))
	if t < 0.55:
		var shake := sin(t * 60.0) * 5.0 * (t / 0.55)
		h._icon("chest", c + Vector2(shake, 0), 26.0 + t * 10.0, Color.WHITE)
		return
	var pop := minf((t - 0.55) / 0.2, 1.0)
	var card := Rect2(c - Vector2(150, 150) * pop, Vector2(300, 300) * pop)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14).lerp(col.darkened(0.6), 0.4)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4)
	sb.border_color = col
	sb.shadow_color = Color(col, 0.7)
	sb.shadow_size = 24
	h.draw_style_box(sb, card)
	if pop < 1.0:
		return
	menu.ttext(Vector2(card.position.x, card.position.y + 46), "NEW!" if not it.is_empty() else "GOLD!", 30, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 6)
	if it.is_empty():
		h._icon("coin", c + Vector2(0, 0), 24.0, Color.WHITE)
		menu.ttext(Vector2(card.position.x, card.end.y - 60), "+%d GOLD" % Stats.CHEST_GOLD, 26, Color(1.0, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 5)
		h._text(Vector2(card.position.x, card.end.y - 32), "You own everything in the store!", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 2)
	else:
		thumb(Rect2(c.x - 75, c.y - 98, 150, 150), it[0], it[1])
		menu.ttext(Vector2(card.position.x, card.end.y - 70), item_name(it[0], it[1]).to_upper(), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 5)
		h._text(Vector2(card.position.x, card.end.y - 46), "%s  ·  %s" % [Stats.RARITIES[it[2]][0].to_upper(), KIND_LABEL[it[0]]], 13, col.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 2)
		h._text(Vector2(card.position.x, card.end.y - 22), "Added to your collection: tap to try it on", 11, Color(0.9, 0.9, 0.86), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 2)


func press(id: String, arg) -> void:
	match id:
		"store_tab":
			tab = int(arg)
			var first := items_in(tab)
			pick = first[0] if not first.is_empty() else []
		"store_pick":
			pick = arg
		"store_buy":
			if not pick.is_empty() and buy(game, pick[0], pick[1]):
				flash = 2.0
				game.sfx.ui("rank_up", -4.0)
				game.toast("Bought %s! It's on." % item_name(pick[0], pick[1]), Color(1.0, 0.85, 0.4))
		"store_equip":
			if not pick.is_empty() and owns(game, pick[0], pick[1]):
				equip(game, pick[0], pick[1])
		"store_unequip":
			if not pick.is_empty():
				equip(game, pick[0], 0)
		"store_chest":
			if game.account_chests > 0:
				var got := open_chest(game)
				reveal = [got, Time.get_ticks_msec() / 1000.0]
				game.sfx.ui("rank_up", -2.0)
		"store_reveal_close":
			var t: float = (Time.get_ticks_msec() / 1000.0) - float(reveal[1]) if not reveal.is_empty() else 9.0
			if t < 0.8:
				return   # let the chest finish opening
			var it: Array = reveal[0] if not reveal.is_empty() else []
			reveal = []
			if not it.is_empty():
				show(it[0], it[1])
