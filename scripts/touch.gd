extends Control
## Touch controls for the web build (Faisal 2026-10-08: play it on an iPad
## in the browser). They appear the first time a finger touches the screen:
## the left half of the screen is a floating move stick (touch down, drag),
## the right half an attack pad (touch to swing, drag to aim; a twin-stick
## layout), and the HUD's own ability tiles and corner buttons become
## buttons. Everything goes through the input actions, so the player code
## does not know whether a key, a pad or a thumb pressed them. Menus take
## taps through Godot's mouse emulation and need nothing here.

const STICK_RANGE := 95.0   # pixels of drag for a full-strength move (was 70: too twitchy on an iPad)
const AIM_RANGE := 55.0
const DEAD := 0.18

var game
var active := false          # a touch has happened: draw the hints
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var aim_id := -1
var aim_origin := Vector2.ZERO
var aim_vec := Vector2.ZERO
var held: Dictionary = {}    # touch index -> action it is holding down


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.is_touchscreen_available():
		active = true
		if game:
			game.touch_active = true


var _was_playing := false


func _process(_delta: float) -> void:
	# Redrawn when a finger moves (below) and when play starts or stops, not
	# every frame: each ring is a polygon the browser re-uploads per redraw.
	if active:
		var now := _playing()
		if now != _was_playing:
			_was_playing = now
			queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)


func _prefix() -> String:
	return game.player.act_prefix if game and game.player else ""


func _playing() -> bool:
	return game and game.playing and not game.game_over and game.player and not game.menu_blocks_input(game.player) and not game.chat_open


func _down(i: int, pos: Vector2) -> void:
	queue_redraw()
	active = true
	if game:
		game.touch_active = true
	if not _playing():
		if game.rank_open and not game.menu_open and (game.hud.touch_close.grow(10).has_point(pos) or not game.hud._menu_rect().has_point(pos)):
			# The UPGRADES board: CLOSE, or a tap anywhere outside it, shuts it.
			game.rank_open = false
			return
		game.touch_tap = _snap(pos)   # a menu tap: game.menu_tick reads it as a click
		return
	var hud = game.hud
	# The HUD's ability tiles and corner buttons.
	for entry in hud.touch_rects:
		var r: Rect2 = entry[0]
		if r.grow(6).has_point(pos):
			var action: String = entry[1]
			if action == "":
				return
			if action == "quick_tap":
				game.touch_tap = pos   # a LEVEL UP tile with its own buy: handled like a click
				return
			if action == "attack" and aim_id < 0:
				# The big attack tile is also the aim pad: hold to swing,
				# drag to aim.
				aim_id = i
				aim_origin = pos
				aim_vec = Vector2.ZERO
				Input.action_press(_prefix() + "attack")
				return
			held[i] = _prefix() + action if action in ["attack", "dodge", "ability_1", "ability_2", "block", "interact", "rank_menu"] else action
			Input.action_press(held[i])
			return
	if pos.y < 110.0:
		return   # the score bar and minimap
	if pos.x < size.x * 0.45:
		if stick_id < 0:
			stick_id = i
			stick_origin = pos
			stick_vec = Vector2.ZERO
	elif aim_id < 0:
		aim_id = i
		aim_origin = pos
		aim_vec = Vector2.ZERO
		Input.action_press(_prefix() + "attack")


func _drag(i: int, pos: Vector2) -> void:
	queue_redraw()
	if i == stick_id:
		stick_vec = (pos - stick_origin) / STICK_RANGE
		if stick_vec.length() > 1.0:
			stick_vec = stick_vec.normalized()
			stick_origin = pos - stick_vec * STICK_RANGE   # the stick base follows a long drag
		_set_axis("move", stick_vec)
	elif i == aim_id:
		aim_vec = (pos - aim_origin) / AIM_RANGE
		if aim_vec.length() > 1.0:
			aim_vec = aim_vec.normalized()
		_set_axis("aim", aim_vec)


func _up(i: int) -> void:
	queue_redraw()
	if held.has(i):
		Input.action_release(held[i])
		held.erase(i)
	if i == stick_id:
		stick_id = -1
		stick_vec = Vector2.ZERO
		_set_axis("move", Vector2.ZERO)
	if i == aim_id:
		aim_id = -1
		aim_vec = Vector2.ZERO
		_set_axis("aim", Vector2.ZERO)
		Input.action_release(_prefix() + "attack")


func _set_axis(kind: String, v: Vector2) -> void:
	## Feed a stick vector into the four directional actions.
	var p := _prefix()
	var pairs := [["left", maxf(0.0, -v.x)], ["right", maxf(0.0, v.x)], ["up", maxf(0.0, -v.y)], ["down", maxf(0.0, v.y)]]
	for pair in pairs:
		var action := "%s%s_%s" % [p, kind, pair[0]]
		if pair[1] > DEAD:
			Input.action_press(action, pair[1])
		else:
			Input.action_release(action)


func release_all() -> void:
	for i in held.keys():
		Input.action_release(held[i])
	held.clear()
	if stick_id >= 0:
		_up(stick_id)
	if aim_id >= 0:
		_up(aim_id)


func _draw() -> void:
	if not active or not _playing():
		return
	# The move stick: a faint resting ring until a thumb lands, then the
	# base under the thumb and the knob where it drags.
	if stick_id >= 0:
		_ring(stick_origin, STICK_RANGE, Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.35))
		draw_circle(stick_origin + stick_vec * STICK_RANGE, 38.0, Color(1.0, 0.95, 0.7, 0.55))
		draw_arc(stick_origin + stick_vec * STICK_RANGE, 38.0, 0, TAU, 32, Color(0.3, 0.2, 0.05, 0.8), 3.0)
	else:
		var rest := Vector2(size.x * 0.17, size.y * 0.62)
		_ring(rest, 80.0, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.22))
		draw_circle(rest, 30.0, Color(1, 1, 1, 0.14))
	# The attack pad: a red ring where the thumb landed, an arrow for the aim.
	if aim_id >= 0:
		_ring(aim_origin, AIM_RANGE, Color(1.0, 0.3, 0.2, 0.12), Color(1.0, 0.45, 0.3, 0.45))
		if aim_vec.length() > DEAD:
			var tip := aim_origin + aim_vec.normalized() * (AIM_RANGE + 10.0)
			draw_line(aim_origin, tip, Color(1.0, 0.6, 0.4, 0.8), 4.0)
			draw_circle(tip, 7.0, Color(1.0, 0.7, 0.5, 0.9))



func _ring(c: Vector2, r: float, fill: Color, edge: Color) -> void:
	draw_circle(c, r, fill)
	draw_arc(c, r, 0, TAU, 48, edge, 2.5)


func _snap(pos: Vector2) -> Vector2:
	## Fingers are wider than a mouse pointer: a tap up to 24 px outside a
	## menu button counts as a tap on the nearest one.
	if game == null or game.hud == null:
		return pos
	var best := 24.0
	var hit := pos
	for r in game.hud.button_rects():
		if r.has_point(pos):
			return pos
		var q := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
		var d := q.distance_to(pos)
		if d < best:
			best = d
			hit = r.get_center()
	return hit
