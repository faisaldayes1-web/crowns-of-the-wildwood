extends Control
## In-match HUD, laid out after the UI reference: score and timer at the top,
## team rosters down each side, and the player's hearts and stamina or mana
## at the bottom. Everything is drawn in code so it can be reskinned later.

const Stats = preload("res://scripts/stats.gd")

const PANEL := Color(0.08, 0.1, 0.16, 0.85)
const PANEL_EDGE := Color(0.85, 0.7, 0.35)
const GOLD := Color(1.0, 0.82, 0.25)
const HEART := Color(0.95, 0.15, 0.2)
const HEART_EMPTY := Color(0.25, 0.25, 0.28)
const STAMINA := Color(0.35, 0.85, 0.35)
const MANA := Color(0.3, 0.55, 1.0)

var game
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or not game.playing and not game.game_over:
		return
	_draw_scoreboard()
	_draw_roster(0, Vector2(12, 90), false)
	_draw_roster(1, Vector2(size.x - 232, 90), true)
	if game.player:
		_draw_player_panel(game.player)


# --- Pieces ----------------------------------------------------------------

func _panel(rect: Rect2, fill: Color = PANEL) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, PANEL_EDGE, false, 2.0)


func _text(pos: Vector2, text: String, font_size: int, color: Color = Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, text, align, width, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, align, width, font_size, color)


func _heart(center: Vector2, scale: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		points.append(center + Vector2(x, -y) * scale)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(0, 0, 0, 0.7), 1.5)


func _hearts(origin: Vector2, count: int, scale: float, spacing: float) -> void:
	for i in Stats.MAX_HEARTS:
		_heart(origin + Vector2(i * spacing, 0), scale, HEART if i < count else HEART_EMPTY)


func _crown(center: Vector2, scale: float) -> void:
	var p := PackedVector2Array([
		Vector2(-10, 6), Vector2(-12, -6), Vector2(-5, 0), Vector2(0, -9),
		Vector2(5, 0), Vector2(12, -6), Vector2(10, 6)])
	for i in p.size():
		p[i] = center + p[i] * scale
	draw_colored_polygon(p, GOLD)


func _bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), color)
	draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.0)


func _draw_scoreboard() -> void:
	var cx := size.x / 2.0
	var elf_color: Color = Stats.FACTIONS[0].color.darkened(0.35)
	var human_color: Color = Stats.FACTIONS[1].color.darkened(0.35)
	_panel(Rect2(cx - 230, 10, 130, 54), elf_color)
	_panel(Rect2(cx + 100, 10, 130, 54), human_color)
	_panel(Rect2(cx - 90, 10, 180, 54))
	_crown(Vector2(cx - 195, 37), 1.6)
	_crown(Vector2(cx + 195, 37), 1.6)
	_text(Vector2(cx - 160, 50), str(game.score[0]), 34, Color.WHITE)
	_text(Vector2(cx + 120, 50), str(game.score[1]), 34, Color.WHITE)
	var left := maxf(game.time_left, 0.0)
	_text(Vector2(cx - 90, 50), "%02d:%02d" % [int(left) / 60, int(left) % 60], 34, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, 180)
	_text(Vector2(cx - 120, 84), "CAPTURE THE CROWN", 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 240)


func _draw_roster(team: int, origin: Vector2, right_side: bool) -> void:
	var row := 0
	for u in game.units:
		if u.team != team:
			continue
		var rect := Rect2(origin + Vector2(0, row * 50), Vector2(220, 44))
		_panel(rect, Stats.FACTIONS[team].color.darkened(0.55) if not u.is_player else Color(0.35, 0.3, 0.1, 0.9))
		var title: String = ("YOU  " if u.is_player else "") + u.role_name()
		if u.carrying:
			title += "  (carrying!)"
		_text(rect.position + Vector2(10, 18), title, 14, Color(1, 0.92, 0.6) if u.is_player else Color.WHITE)
		if u.dead:
			_text(rect.position + Vector2(10, 37), "respawning in %d" % ceili(u.respawn_timer), 13, Color(1, 0.6, 0.5))
		else:
			_hearts(rect.position + Vector2(18, 31), u.hearts, 0.42, 18)
			var frac: float = u.energy / u.energy_max()
			_bar(Rect2(rect.position + Vector2(100, 26), Vector2(108, 8)), frac, MANA if u.energy_kind() == "mana" else STAMINA)
		row += 1


func _draw_player_panel(p) -> void:
	var w := 420.0
	var rect := Rect2(size.x / 2.0 - w / 2.0, size.y - 128, w, 92)
	_panel(rect)
	_text(rect.position + Vector2(16, 26), p.role_name().to_upper(), 20, GOLD)
	if p.dead:
		_text(rect.position + Vector2(16, 62), "Down! Respawning in %d" % ceili(p.respawn_timer), 20, Color(1, 0.6, 0.5))
		return
	_hearts(rect.position + Vector2(30, 60), p.hearts, 0.95, 40)
	var is_mana: bool = p.energy_kind() == "mana"
	var bar := Rect2(rect.position + Vector2(190, 48), Vector2(214, 22))
	_bar(bar, p.energy / p.energy_max(), MANA if is_mana else STAMINA)
	_text(bar.position + Vector2(0, -6), "MANA" if is_mana else "STAMINA", 13, Color.WHITE)
	_text(bar.position + Vector2(0, 17), "%d / %d" % [int(p.energy), int(p.energy_max())], 15, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)
