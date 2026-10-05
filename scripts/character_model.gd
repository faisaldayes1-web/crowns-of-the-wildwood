extends Node3D
## An animated character from the KayKit Adventurers pack (CC0), dressed for
## a faction and class: the right model, the right weapons shown, a team
## colour skin, elf ears for elves, and a small animation state machine
## (idle / run / one-shot actions / held loops) driven by unit.gd.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

const SCENES := {
	"knight": "res://assets/characters/Knight.glb",
	"rogue": "res://assets/characters/Rogue.glb",
	"rogue_hooded": "res://assets/characters/Rogue_Hooded.glb",
	"mage": "res://assets/characters/Mage.glb",
	"barbarian": "res://assets/characters/Barbarian.glb",
}
const LOOPS := ["Idle", "Unarmed_Idle", "2H_Melee_Idle", "Running_A", "Walking_A", "Blocking",
	"Spellcasting", "2H_Ranged_Shooting", "Sit_Floor_Idle", "Lie_Idle", "Death_A_Pose"]
const ALL_GEAR := ["1H_Sword", "1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Rectangle_Shield", "Round_Shield",
	"Spike_Shield", "Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable", "Spellbook",
	"Spellbook_open", "1H_Wand", "2H_Staff", "1H_Axe", "1H_Axe_Offhand", "2H_Axe", "Mug", "Barbarian_Round_Shield"]

var anim: AnimationPlayer
var skeleton: Skeleton3D
var flash_mats: Array = []     # the skin materials; unit.gd tints them red on a hit
var idle_anim := "Idle"
var move_anim := "Running_A"
var attack_anims: Array = ["1H_Melee_Attack_Slice_Horizontal"]
var height := 1.75             # for the overhead label
var busy_until := 0.0          # a one-shot action plays until this time
var held := ""                 # a loop held by the unit (blocking, casting)
var current := ""


static func config(team: int, role: int, variant: String = "") -> Dictionary:
	## Which model, gear and animations a faction + class (or monarch) uses.
	var c := {"scale": 0.75, "ears": team == 0, "crown": false, "hat": true}
	match variant:
		"queen":
			c.scene = "rogue"
			c.skin = "queen"
			c.show = []
			c.idle = "Idle"
			c.attacks = []
			c.crown = true
		"king":
			c.scene = "barbarian"
			c.skin = "king"
			c.show = []
			c.idle = "Idle"
			c.attacks = []
			c.crown = true
			c.hat = false
		_:
			match role:
				Role.KNIGHT:
					c.scene = "knight"
					c.skin = "knight"
					c.show = ["1H_Sword", "Badge_Shield"]
					c.idle = "Idle"
					c.attacks = ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal"]
					c.scale = 0.82
				Role.RANGER:
					c.scene = "rogue_hooded"
					c.skin = "rogue"
					c.show = ["2H_Crossbow"]
					c.idle = "Idle"
					c.attacks = ["2H_Ranged_Shoot"]
				Role.MAGE:
					c.scene = "mage"
					c.skin = "mage"
					c.show = ["2H_Staff"]
					c.idle = "Idle"
					c.attacks = ["Spellcast_Shoot"]
				Role.HEALER:
					c.scene = "mage"
					c.skin = "healer"
					c.show = ["1H_Wand", "Spellbook_open"]
					c.idle = "Idle"
					c.attacks = ["1H_Melee_Attack_Chop"]
					c.hat = false
				_:
					c.scene = "rogue"
					c.skin = "rogue"
					c.show = []
					c.idle = "Unarmed_Idle"
					c.attacks = ["Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Punch_B"]
					c.scale = 0.72
	return c


func setup(team: int, role: int, variant: String = "") -> void:
	for child in get_children():
		child.queue_free()
	var c := config(team, role, variant)
	var inst: Node3D = load(SCENES[c.scene]).instantiate()
	add_child(inst)
	inst.scale = Vector3.ONE * c.scale
	inst.rotation.y = PI  # the models face +Z; the game's forward is -Z
	anim = inst.find_child("AnimationPlayer", true, false)
	skeleton = inst.find_child("Skeleton3D", true, false)
	idle_anim = c.idle
	attack_anims = c.attacks
	height = 1.75 * (c.scale / 0.75) + (0.25 if c.scene == "mage" and c.hat else 0.0)

	# Only the gear this class uses.
	for name in ALL_GEAR:
		var node := inst.find_child(name, true, false)
		if node:
			node.visible = name in c.show
	if not c.hat:
		for name in ["Mage_Hat", "Barbarian_Hat", "Knight_Helmet"]:
			var hat := inst.find_child(name, true, false)
			if hat and (c.scene != "knight" or variant != ""):
				hat.visible = false

	# Team colour skin on every mesh.
	var skin: Texture2D = load("res://assets/characters/skins/%s_%s.png" % [c.skin, "elf" if team == 0 else "human"])
	flash_mats = []
	for mesh in _meshes(inst):
		for i in mesh.get_surface_override_material_count():
			var mat: Material = mesh.get_active_material(i)
			if mat is StandardMaterial3D:
				var dup: StandardMaterial3D = mat.duplicate()
				dup.albedo_texture = skin
				mesh.set_surface_override_material(i, dup)
				flash_mats.append(dup)

	if skeleton:
		if c.ears:
			_add_ears(team)
		if c.crown:
			_add_crown()

	if anim:
		for name in LOOPS:
			if anim.has_animation(name):
				anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		play_loop(idle_anim)


func _meshes(node: Node) -> Array:
	var out := []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out


func _attach_to_head() -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	skeleton.add_child(att)
	return att


func _add_ears(team: int) -> void:
	var att := _attach_to_head()
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.97, 0.84, 0.72)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.42
		ear.mesh = cone
		ear.material_override = skin_mat
		ear.position = Vector3(side * 0.5, 0.25, 0.0)
		ear.rotation.z = -side * (PI / 2.0 - 0.35)
		att.add_child(ear)


func _add_crown() -> void:
	var att := _attach_to_head()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.98, 0.8, 0.25)
	gold.metallic = 0.7
	gold.roughness = 0.3
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.42
	ring.bottom_radius = 0.4
	ring.height = 0.22
	band.mesh = ring
	band.material_override = gold
	band.position = Vector3(0, 0.78, 0)
	att.add_child(band)
	for i in 6:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07
		cone.height = 0.26
		spike.mesh = cone
		spike.material_override = gold
		var ang := TAU * i / 6.0
		spike.position = Vector3(cos(ang) * 0.4, 1.0, sin(ang) * 0.4)
		att.add_child(spike)
	var jewel := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.09
	gem.height = 0.18
	jewel.mesh = gem
	var jm := StandardMaterial3D.new()
	jm.albedo_color = Color(0.9, 0.2, 0.3)
	jm.emission_enabled = true
	jm.emission = Color(0.9, 0.2, 0.3)
	jewel.material_override = jm
	jewel.position = Vector3(0, 0.82, 0.42)
	att.add_child(jewel)


# --- Animation ---------------------------------------------------------------

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func play_loop(name: String) -> void:
	if anim == null or not anim.has_animation(name) or current == name:
		return
	current = name
	anim.play(name, 0.15)


func play_once(name: String, speed: float = 1.0) -> void:
	## A one-shot action (attack, dodge, hit). Locomotion resumes after it.
	if anim == null or not anim.has_animation(name):
		return
	current = name
	anim.play(name, 0.08, speed)
	busy_until = _now() + anim.get_animation(name).length / speed


func attack() -> void:
	if attack_anims.is_empty():
		return
	play_once(attack_anims[randi() % attack_anims.size()], 1.6)


func hold(name: String) -> void:
	## Keep a loop (Blocking, Spellcasting) until release().
	held = name
	play_loop(name)


func release() -> void:
	held = ""
	current = ""


func die() -> void:
	held = ""
	busy_until = _now() + 9999.0
	if anim and anim.has_animation("Death_A"):
		current = "Death_A"
		anim.play("Death_A", 0.05, 1.3)


func revive() -> void:
	busy_until = 0.0
	held = ""
	current = ""
	play_loop(idle_anim)


func update_locomotion(moving: bool) -> void:
	## Called every frame by the owner: picks idle or run unless busy.
	if anim == null or _now() < busy_until:
		return
	if held != "":
		play_loop(held)
		return
	play_loop(move_anim if moving else idle_anim)
