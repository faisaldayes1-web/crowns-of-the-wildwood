class_name Guide
extends Node3D
## The Wildwood Guide: a friendly tutorial NPC in each team's starting
## courtyard. It chats in a speech bubble when someone is near, and
## pressing interact beside it opens the conversation panel on the HUD
## (see game.guide_* and hud._draw_guide).

const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")

const TALK_RANGE := 2.6
const BUBBLE_RANGE := 13.0
const AMBIENT := [
	"Welcome to the Wildwood!",
	"Steal the enemy Crown and bring it back here.",
	"Step on a station to pick your class.",
	"Press %s next to me and I'll explain everything.",
]

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
	["What is the objective?", "Break the enemy castle door, smash the lock on their Crown Vault, grab their monarch and carry them back to your own throne. The first side to two captures wins."],
	["How do I fight?", "%s attacks. %s and %s are your class abilities, %s dodges (three seconds to recover), and Knights hold %s to block. Watch your stamina or mana bar."],
	["How do classes work?", "KNIGHT: frontline fighter, strong against enemies and structures. RANGER: attacks from a distance, use cover and keep your space. MAGE: powerful abilities and area attacks. HEALER: keeps teammates alive and can turn losing fights around."],
	["How do I upgrade?", "Gain experience by fighting, supporting teammates, destroying defenses and completing objectives. Press %s (or stand on the Upgrade Station) to spend perk points. At higher levels you can specialise your class. Dying costs you your perks."],
	["How does the Crown work?", "The Crown sits in the enemy's Crown Vault behind a lock. Break the lock, press %s to grab it, and run. If you fall it drops where you died; a defender can carry it home, or your team can pick it back up."],
	["Where should I go?", "Up the stairs, through the courtyard and out the front gate. Fight for the shrine in the middle, cross a bridge, then push to the enemy gate. Blessings of Light appear in the field; Potions heal you."],
]

var game
var team := 0
var model: CharacterModel
var bubble: Label3D
var prompt: Label3D
var line := 0
var line_timer := 0.0
var bob := 0.0


func setup(p_game, p_team: int, pos: Vector3, face: float) -> void:
	game = p_game
	team = p_team
	position = pos
	rotation.y = face
	model = CharacterModel.new()
	add_child(model)
	model.setup(team, Stats.Role.MAGE, "")
	model.play_loop("Idle")
	var mark := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.0
	mm.bottom_radius = 0.16
	mm.height = 0.3
	mark.mesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 1.5
	mark.material_override = mat
	mark.position = Vector3(0, 2.5, 0)
	mark.rotation.x = PI
	mark.name = "Mark"
	add_child(mark)
	bubble = _label(28, Color(0.12, 0.1, 0.08), Vector3(0, 2.9, 0))
	bubble.modulate = Color(0.12, 0.1, 0.08)
	bubble.outline_modulate = Color(1.0, 0.97, 0.88)
	bubble.outline_size = 14
	prompt = _label(22, Color(1.0, 0.85, 0.3), Vector3(0, 2.3, 0))
	prompt.text = "[%s]  TALK" % game.key_label("interact")
	prompt.visible = false


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
	get_node("Mark").position.y = 2.5 + sin(bob * 3.0) * 0.08
	get_node("Mark").rotation.y += delta * 1.5
	line_timer -= delta
	if line_timer <= 0.0:
		line_timer = 5.0
		line = (line + 1) % AMBIENT.size()
	var text: String = AMBIENT[line]
	if "%s" in text:
		text = text % game.key_label("interact")
	bubble.text = text
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
