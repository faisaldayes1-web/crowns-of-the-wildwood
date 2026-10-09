class_name Guide
extends Node3D
## The Wildwood Guide: a friendly tutorial NPC in each team's starting
## courtyard. A white speech bubble with "..." floats over its head when
## someone is near (Faisal 09:04 2026-10-09: its lines used to float as
## text and clipped through the castle wall); pressing interact beside it
## opens the conversation panel on the HUD (see game.guide_* and
## hud._draw_guide), and only then does it speak.

const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")

const TALK_RANGE := 2.6
const BUBBLE_RANGE := 16.0   # the whole courtyard sees the "..."

const INTRO := [
	"Welcome to the Wildwood!",
	"Your goal is simple: steal the enemy Crown and bring it back here.",
	"Choose a class at the Class Station. The Upgrade Station opens your perks.",
	"Upgrade your abilities as you gain experience.",
	"Knights fight up close. Rangers attack from range. Mages control the battlefield. Healers keep the team alive.",
	"Break their castle gate, reach the Crown Vault, and bring the Crown home!",
]

# Topic menu: [question, answer]. %s slots are filled with key labels.
const TOPICS := [
	["What is the objective?", "Break the enemy castle door, smash the lock on their Crown Vault, grab their crown and carry it back to your own throne. The first side to two captures wins."],
	["How do I fight?", "%s attacks. %s and %s are your class abilities, %s dodges (three seconds to recover), and Knights hold %s to block. Watch your stamina or mana bar."],
	["How do classes work?", "KNIGHT: frontline fighter, strong against enemies and structures. RANGER: attacks from a distance, use cover and keep your space. MAGE: powerful abilities and area attacks. HEALER: keeps teammates alive and can turn losing fights around. ENGINEER: builds and tunes turrets on the walls, and the hammer wrecks doors."],
	["How do I upgrade?", "Gain experience by fighting, supporting teammates, destroying defenses and completing objectives. Press %s (or stand on the Upgrade Station) to spend perk points. At higher levels you can specialise your class. Falling costs you two levels and the newest perks they bought; your promotion stays."],
	["How does the Crown work?", "The Crown sits in the enemy's Crown Vault behind a lock. Break the lock, press %s to grab it, and run. If you fall it drops where you died; a defender can carry it home, or your team can pick it back up."],
	["Where should I go?", "Up the stairs, through the courtyard and out the front gate. Fight for the shrine in the middle, cross a bridge, then push to the enemy gate. Blessings of Light appear in the field; Potions heal you. Call your team with %s (attack), %s (defend) or %s (to me), and plant a war banner with %s in the field so fallen friends rejoin beside it."],
]

var game
var team := 0
var model: CharacterModel
var bubble: Sprite3D
var prompt: Label3D
var bob := 0.0
static var bubble_tex: ImageTexture


func setup(p_game, p_team: int, pos: Vector3, face: float) -> void:
	game = p_game
	team = p_team
	position = pos
	rotation.y = face
	model = CharacterModel.new()
	add_child(model)
	model.setup(team, Stats.Role.MAGE, "")
	model.play_loop("Idle")
	bubble = Sprite3D.new()
	bubble.texture = _bubble_texture()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true   # never cut by a wall or a canopy
	bubble.shaded = false
	bubble.pixel_size = 0.0075
	bubble.position = Vector3(0, 2.75, 0)
	bubble.visible = false
	add_child(bubble)
	prompt = _label(22, Color(1.0, 0.85, 0.3), Vector3(0, 2.3, 0))
	prompt.text = "[%s]  TALK" % game.key_label("interact")
	prompt.visible = false


static func _bubble_texture() -> ImageTexture:
	## A white speech bubble with a dark outline, a tail at the bottom left and
	## three dots, drawn once into a texture.
	if bubble_tex:
		return bubble_tex
	var w := 160
	var h := 124
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ink := Color(0.16, 0.11, 0.07)
	for y in h:
		for x in w:
			# Signed distance to the rounded body (8..152 x 6..90, radius 30).
			var qx := absf(x + 0.5 - 80.0) - (72.0 - 30.0)
			var qy := absf(y + 0.5 - 48.0) - (42.0 - 30.0)
			var body := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - 30.0
			# The tail: a triangle from the body's lower edge down to (44, 118).
			var t := 1e9
			if y >= 80 and y <= 118:
				var k := (y - 80.0) / 38.0
				var lx := lerpf(52.0, 44.0, k)
				var rx := lerpf(84.0, 46.0, k)
				t = maxf(lx - (x + 0.5), (x + 0.5) - rx)
			var d := minf(body, t)
			if d < -4.0:
				img.set_pixel(x, y, Color(1, 1, 1))
			elif d < 0.0:
				img.set_pixel(x, y, ink)
			elif d < 1.0:
				img.set_pixel(x, y, Color(ink, 1.0 - d))
	for cx in [52.0, 80.0, 108.0]:
		for y in range(36, 60):
			for x in range(int(cx) - 12, int(cx) + 12):
				var dd := Vector2(x + 0.5 - cx, y + 0.5 - 48.0).length()
				if dd < 9.0:
					img.set_pixel(x, y, ink.lerp(Color(1, 1, 1), clampf(dd - 8.0, 0.0, 1.0)))
	bubble_tex = ImageTexture.create_from_image(img)
	return bubble_tex


func _label(size: int, color: Color, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 8
	l.modulate = color
	l.position = at
	l.visible = false
	add_child(l)
	return l


func _process(delta: float) -> void:
	var p = game.player
	if p == null or p.team != team or p.dead:
		bubble.visible = false
		prompt.visible = false
		return
	var d: float = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	bob += delta
	bubble.position.y = 2.75 + sin(bob * 3.0) * 0.06
	bubble.visible = d < BUBBLE_RANGE and not game.guide_open
	prompt.visible = d < TALK_RANGE and not game.guide_open
	# Face whoever is near.
	if d < BUBBLE_RANGE:
		var to: Vector3 = p.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), delta * 4.0)
	if game.guide_open and d > TALK_RANGE + 1.5:
		game.guide_close()


func in_reach(u) -> bool:
	return Vector2(u.global_position.x - global_position.x, u.global_position.z - global_position.z).length() < TALK_RANGE
