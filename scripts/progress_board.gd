extends Node
## Account presentation only. Agent: Codex-faisal3, cf-chief-faisal-1105g.
## All costs, ranks, unlocks and story gates come from the shipped rules.
const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const GOLD := Color("e5ba5c")
const CREAM := Color("f5ead0")
const MUTED := Color("aaa595")
var account_open := false
var preview: SubViewport
var age := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	# A separate, bounded preview: reuse the real Shadowborn model/materials.
	# It never changes the player's look, the shared portrait rigs or XP.
	preview = SubViewport.new()
	preview.size = Vector2i(384, 448)
	preview.own_world_3d = true
	preview.transparent_bg = true
	preview.msaa_3d = Viewport.MSAA_4X
	add_child(preview)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bac5e0")
	env.ambient_light_energy = 0.85
	var world := WorldEnvironment.new()
	world.environment = env
	preview.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, 38, 0)
	light.light_energy = 1.25
	preview.add_child(light)
	var model := CharacterModel.new()
	preview.add_child(model)
	model.setup(0, Stats.Role.BASE, "", {"look": Stats.HERO_LOOKS[1][1], "cape": "cape"}, 1)
	model.rotation.y = PI - 0.55
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	preview.add_child(camera)
	camera.position = Vector3(0, 1.25, 4)
	camera.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	camera.current = true
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _process(_delta: float) -> void:
	age += 1
	if preview != null and age == 12:
		preview.render_target_update_mode = SubViewport.UPDATE_DISABLED


func draw(menu) -> void:
	var h = menu.h
	var game = menu.game
	var width: float = minf(h.size.x - 64, 1160)
	var height: float = minf(h.size.y - 94, 620)
	var frame := Rect2(Vector2((h.size.x - width) / 2, 64), Vector2(width, height))
	menu.nine("frame_big", frame, 40, 40, 40, 40)
	menu.plaque(h.size.x / 2, frame.position.y - 28, "YOUR JOURNEY", 400)
	var body := frame.grow(-30)
	var level: int = game.account_level()
	var span: Array = Stats.account_span(game.account_xp)
	var crest := body.position + Vector2(44, 48)
	_medal(h, crest, 40, true, true, 0)
	menu.ttext(crest + Vector2(-40, 10), str(level), 30, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 80, 4)
	var hx := body.position.x + 106
	menu.ttext(Vector2(hx, body.position.y + 25), game.hero_name + "  /  " + Stats.rank_title(level), 26, CREAM, HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 390, 3)
	var bar := Rect2(hx, body.position.y + 42, body.size.x - 400, 26)
	h._bar(bar, float(span[0]) / span[1] if span[1] > 0 else 1.0, Color("7da94b"))
	var xp := "%d / %d XP to level %d" % [span[0], span[1], level + 1] if span[1] > 0 else "MAX LEVEL"
	h._text(Vector2(bar.position.x, bar.end.y + 19), xp, 14, CREAM, HORIZONTAL_ALIGNMENT_LEFT, bar.size.x, 1)
	var story := Rect2(body.end.x - 260, body.position.y + 6, 260, 46)
	var unlocked: bool = game.legend_unlocked()
	menu.wood_button(story, "WATCH STORY FINALE" if unlocked else "STORY FINALE / LV %d" % game.legend_level(), "watch_legend", null, "crown" if unlocked else "lock", 16, false, unlocked)
	h._text(Vector2(story.position.x, story.end.y + 20), "Legend rank is earned at level 30.", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER, story.size.x, 1)
	var road_y := body.position.y + 128
	menu.ttext(Vector2(body.position.x, road_y - 13), "THE RANK ROAD", 18, GOLD)
	var next := "Top rank reached"
	for entry in Stats.RANK_TITLES:
		if entry[0] > level:
			next = "NEXT: %s / LEVEL %d" % [entry[1], entry[0]]
			break
	h._text(Vector2(body.position.x, road_y - 13), next, 13, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, body.size.x, 1)
	var step := body.size.x / Stats.RANK_TITLES.size()
	var line_y := road_y + 32
	h.draw_line(Vector2(body.position.x + step / 2, line_y), Vector2(body.end.x - step / 2, line_y), Color("655133"), 7, true)
	for i in Stats.RANK_TITLES.size():
		var entry: Array = Stats.RANK_TITLES[i]
		var earned: bool = level >= entry[0]
		var current: bool = earned and (i == Stats.RANK_TITLES.size() - 1 or level < Stats.RANK_TITLES[i + 1][0])
		var next_rank: bool = not earned and (i == 0 or level >= Stats.RANK_TITLES[i - 1][0])
		var x := body.position.x + step * (i + 0.5)
		if i > 0 and earned:
			h.draw_line(Vector2(x - step, line_y), Vector2(x, line_y), GOLD, 5, true)
		_medal(h, Vector2(x, line_y), 23 if current else 19, earned, current, i)
		h._icon("crown" if earned else "lock", Vector2(x, line_y), 12, CREAM if earned else MUTED)
		if next_rank:
			h.draw_arc(Vector2(x, line_y), 25, -PI / 2, PI * 1.5, 32, GOLD, 2, true)
		var title: String = entry[1].to_upper()
		menu.ttext(Vector2(x - step / 2, road_y + 73), title, menu.fit_size(title, 13, step - 8), GOLD if current or next_rank else (CREAM if earned else MUTED), HORIZONTAL_ALIGNMENT_CENTER, step, 2)
		h._text(Vector2(x - step / 2, road_y + 91), "NOW / LV %d" % entry[0] if current else "LV %d" % entry[0], 11, CREAM if earned else MUTED, HORIZONTAL_ALIGNMENT_CENTER, step, 1)
	var card_y := road_y + 126
	menu.ttext(Vector2(body.position.x, card_y - 9), "LEVEL %d UNLOCKS" % Stats.UNLOCK_LEVEL, 18, GOLD)
	var card_height := maxf(142, body.end.y - card_y - 62)
	var card_width := (body.size.x - 24) / 3
	for i in 3:
		var card := Rect2(body.position.x + i * (card_width + 12), card_y, card_width, card_height)
		menu.slate(card)
		var art := Rect2(card.position + Vector2(8, 8), Vector2(card.size.x * 0.38, card.size.y - 16))
		if i == 1 and preview != null:
			h.draw_texture_rect(preview.get_texture(), art, false)
		elif i == 0:
			var rogue: Texture2D = load("res://assets/ui/cards/elf_rogue.png")
			h.draw_texture_rect(rogue, art, false)
		elif i == 2:
			var moon: Texture2D = menu.texture("map_moonlit")
			if moon:
				h.draw_texture_rect(moon, art, false)
		else:
			h._icon("cape", art.get_center(), 30, CREAM)
		var text_x := art.end.x + 8
		var text_w := card.end.x - text_x - 12
		var title: String = Stats.UNLOCKS[i][1].to_upper()
		menu.ttext(Vector2(text_x, card.position.y + 30), title, menu.fit_size(title, 19, text_w), CREAM, HORIZONTAL_ALIGNMENT_LEFT, text_w, 3)
		h._fit_paragraph(Rect2(text_x, card.position.y + 44, text_w, card.size.y - 86), Stats.UNLOCKS[i][2], 13, MUTED)
		h._text(Vector2(text_x, card.end.y - 18), "UNLOCKED" if game.unlocked() else "REQUIRES LV %d" % Stats.UNLOCK_LEVEL, 12, Color("a2d56b") if game.unlocked() else GOLD, HORIZONTAL_ALIGNMENT_LEFT, text_w, 1)
	var foot_y := body.end.y - 38
	menu.wood_button(Rect2(body.position.x, foot_y, 200, 38), "ACCOUNT & SAVE", "progress_account", null, "", 16, account_open)
	h._text(Vector2(body.position.x + 220, foot_y + 24), "Progress saves automatically after matches and purchases.", 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 390, 1)
	menu.wood_button(Rect2(body.end.x - 130, foot_y, 130, 38), "BACK", "close", null, "", 18)
	if account_open:
		_draw_account(menu, frame)


func _medal(h, center: Vector2, radius: float, earned: bool, current: bool, rank_index: int) -> void:
	h.draw_circle(center + Vector2(0, 3), radius + 3, Color(0, 0, 0, 0.5))
	h.draw_circle(center, radius + 2, GOLD if earned or current else Color("655d4b"))
	h.draw_circle(center, radius - 2, Color("6a4a24") if earned else Color("282b29"))
	if current:
		h.draw_arc(center, radius + 5, 0, TAU, 48, Color("a1c968"), 3, true)
	# Higher crests gain laurel leaves; earned/current/locked also differ in ink.
	for n in mini(rank_index, 4):
		for side in [-1, 1]:
			var p := center + Vector2(side * (radius - 2), (n - 1.5) * 6)
			h.draw_line(p, p + Vector2(side * 5, -4), GOLD if earned else Color("655d4b"), 3, true)


func _draw_account(menu, frame: Rect2) -> void:
	var h = menu.h
	h.draw_rect(frame.grow(-12), Color(0.03, 0.04, 0.03, 0.94))
	var card := Rect2(frame.get_center() - Vector2(330, 130), Vector2(660, 260))
	menu.nine("frame_big", card, 32, 32, 32, 32)
	menu.ttext(card.position + Vector2(28, 48), "ACCOUNT & SAVE", 26, GOLD)
	h._fit_paragraph(Rect2(card.position + Vector2(28, 66), Vector2(604, 70)), "Your level, XP, gold, chests and items save on this device. To move this player, export a code here and import it on the other device.", 17, CREAM)
	menu.wood_button(Rect2(card.position + Vector2(28, 154), Vector2(190, 44)), "EXPORT CODE", "progress_export", null, "", 18)
	menu.wood_button(Rect2(card.position + Vector2(234, 154), Vector2(190, 44)), "IMPORT CODE", "progress_import", null, "", 18)
	menu.wood_button(Rect2(card.position + Vector2(440, 154), Vector2(190, 44)), "DONE", "progress_account", null, "", 18)
	# Only the Account modal answers while it covers the journey.
	menu.overlay_from = h.menu_buttons.size() - 3
