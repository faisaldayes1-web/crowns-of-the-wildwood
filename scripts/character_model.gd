extends Node3D
## An animated character from the KayKit Adventurers pack (CC0), dressed for
## a faction and class: the right model, the right weapons shown, a team
## colour skin, elf ears for elves, and a small animation state machine
## (idle / run / one-shot actions / held loops) driven by unit.gd.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role
const Face = preload("res://scripts/face.gd")
const OutfitFlair = preload("res://scripts/outfit_flair.gd")

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
var tint := Color.WHITE        # the variant's skin tint; unit.gd restores it after a hit flash
var outline: StandardMaterial3D  # the outline pass; unit.gd colours it by side and highlight
var held := ""                 # a loop held by the unit (blocking, casting)
var current := ""


static func config(team: int, role: int, variant: String = "", rank: int = 1) -> Dictionary:
	## Which model, gear and animations a faction + class (or monarch) uses.
	## `rank` (1-4, from the class's total upgrades) steps the gear up, like
	## the rank rows in the class reference sheet.
	var c := {"scale": 0.84, "ears": team == 0, "crown": false, "hat": true}
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
					c.show = ["1H_Sword", ["Badge_Shield", "Round_Shield", "Rectangle_Shield", "Spike_Shield"][clampi(rank, 1, 4) - 1]]
					c.idle = "Idle"
					c.attacks = ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal"]
					c.scale = 0.92
				Role.RANGER:
					c.scene = "rogue_hooded"
					c.skin = "rogue"
					c.show = []  # Rangers carry a built bow (see _add_weapon_art)
					c.idle = "Idle"
					c.attacks = ["2H_Ranged_Shoot"]
				Role.MAGE:
					c.scene = "mage"
					c.skin = "mage"
					c.show = ["2H_Staff"]
					c.idle = "Idle"
					c.attacks = ["Spellcast_Shoot"]
				Role.ENGINEER:
					c.scene = "barbarian"
					c.skin = "barbarian"
					c.show = ["1H_Axe"]  # the axe holder carries a built hammer (see _add_weapon_art)
					c.idle = "Idle"
					c.attacks = ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal"]
					c.scale = 0.9
				Role.ROGUE:
					c.scene = "rogue_hooded"
					c.skin = "rogue"
					c.show = ["Knife", "Knife_Offhand"]
					c.idle = "Idle"
					c.attacks = ["1H_Melee_Attack_Stab", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal"]
					c.scale = 0.84
				Role.HEALER:
					c.scene = "mage"
					c.skin = "healer"
					c.show = ["1H_Wand", "Spellbook_open"] if rank < 4 else ["2H_Staff"]
					c.idle = "Idle"
					c.attacks = ["Spellcast_Shoot"]
					c.hat = false
				_:
					# Villagers: elves in the hooded tunic (the reference's
					# green hood), humans bare-headed.
					c.scene = "rogue_hooded" if team == 0 else "rogue"
					c.skin = "rogue"
					c.show = []
					c.idle = "Unarmed_Idle"
					c.attacks = ["Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Punch_B"]
					c.scale = 0.8
			# A class variant (promotion) swaps gear, animations and tints the skin.
			if variant != "" and Stats.VARIANTS.has(role):
				for v in Stats.VARIANTS[role]:
					if v.name == variant:
						if v.has("show"):
							c.show = v.show
						if v.has("attacks"):
							c.attacks = v.attacks
						if v.has("idle"):
							c.idle = v.idle
						c.tint = v.get("tint", Color.WHITE)
	return c


# Cells (col, row) of the 8x4 palette grid that hold each skin's hair and
# trim (cape / sash), per base model. Mirrors tools/recolor_skins.py.
const CELLS := {
	"knight": {"trim": [Vector2i(2, 2)], "hair": [Vector2i(1, 0)], "skin": [Vector2i(0, 0)]},
	"rogue": {"trim": [Vector2i(2, 2)], "hair": [Vector2i(1, 0)], "skin": [Vector2i(0, 0)]},
	"mage": {"trim": [Vector2i(2, 1), Vector2i(1, 2)], "hair": [Vector2i(1, 0), Vector2i(2, 0)], "skin": [Vector2i(0, 0)]},
	"healer": {"trim": [Vector2i(2, 1), Vector2i(1, 2)], "hair": [Vector2i(1, 0), Vector2i(2, 0)], "skin": [Vector2i(0, 0)]},
	"barbarian": {"trim": [Vector2i(2, 2)], "hair": [Vector2i(1, 0)], "skin": [Vector2i(0, 0)]},
}
static var custom_cache := {}
static var flat_cache := {}   # mesh resource path -> faceted copy (see _flat_mesh)
var model_root: Node3D

# Chunky proportions (Faisal's character reference, 2026-10-09): a big head,
# oversized mitten hands and big boots. The animations only drive bone
# position and rotation, so a pose scale on these bones sticks. The hand
# slots are scaled back so weapons keep their size.
const CHUNKY := {"head": 1.22, "hand.l": 1.3, "hand.r": 1.3, "handslot.l": 0.8, "handslot.r": 0.8, "foot.l": 1.25, "foot.r": 1.25}


static func customised_skin(skin: Texture2D, skin_name: String, custom: Dictionary) -> Texture2D:
	## The team skin with the player's hair and trim colours painted into
	## the palette cells (keeping each cell's shading gradient). Cached.
	if custom.is_empty() or not CELLS.has(skin_name):
		return skin
	var key := "%s|%s|%s|%s" % [skin.resource_path, custom.get("hair", Color.TRANSPARENT).to_html(), custom.get("trim", Color.TRANSPARENT).to_html(),
		custom.get("skin", Color.TRANSPARENT).to_html()]
	if custom_cache.has(key):
		return custom_cache[key]
	var img: Image = skin.get_image()
	if img == null:
		return skin
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var cw: int = img.get_width() / 8
	var ch: int = img.get_height() / 4
	for part in ["hair", "trim", "skin"]:
		if not custom.has(part):
			continue
		var target: Color = custom[part]
		for cell in CELLS[skin_name][part]:
			var x0: int = cell.x * cw
			var y0: int = cell.y * ch
			var vmax := 0.01
			for y in range(y0, y0 + ch, 8):
				for x in range(x0, x0 + cw, 8):
					vmax = maxf(vmax, img.get_pixel(x, y).v)
			for y in range(y0, y0 + ch):
				for x in range(x0, x0 + cw):
					var p := img.get_pixel(x, y)
					var v := minf(target.v * (p.v / vmax) * 1.15, 1.0)
					img.set_pixel(x, y, Color.from_hsv(target.h, target.s, v, p.a))
	var out := ImageTexture.create_from_image(img)
	custom_cache[key] = out
	return out


func setup(team: int, role: int, variant: String = "", custom: Dictionary = {}, rank: int = 1) -> void:
	for child in get_children():
		child.queue_free()
	var c := config(team, role, variant, rank)
	if role == Role.BASE and variant == "" and custom.has("body") and SCENES.has(custom.body):
		# The player's chosen build for the unclassed body, bare-headed.
		c.scene = custom.body
		c.skin = custom.body
		c.hat = false
		c.bare = true
	var inst: Node3D = load(SCENES[c.scene]).instantiate()
	add_child(inst)
	model_root = inst
	inst.scale = Vector3.ONE * c.scale
	inst.rotation.y = PI  # the models face +Z; the game's forward is -Z
	anim = inst.find_child("AnimationPlayer", true, false)
	skeleton = inst.find_child("Skeleton3D", true, false)
	idle_anim = c.idle
	attack_anims = c.attacks
	tint = c.get("tint", Color.WHITE)
	height = 1.75 * (c.scale / 0.75) + (0.25 if c.scene == "mage" and c.hat else 0.0)

	# A dark outline (an inflated back-face pass) and a soft rim light make
	# the characters pop from the ground the way the reference art does.
	outline = StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Color(0.09, 0.07, 0.1)
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.022

	# Only the gear this class uses.
	for name in ALL_GEAR:
		var node := inst.find_child(name, true, false)
		if node:
			node.visible = name in c.show
	if not c.hat:
		for name in ["Mage_Hat", "Barbarian_Hat", "Knight_Helmet"]:
			var hat := inst.find_child(name, true, false)
			if hat and (c.scene != "knight" or variant != "" or c.get("bare", false)):
				hat.visible = false
	# Capes are earned: Knights and Rangers wear one from rank 3 (promotions always do).
	for name in ["Knight_Cape", "Rogue_Cape"]:
		var cape := inst.find_child(name, true, false)
		if cape and variant == "" and role != Role.BASE:
			cape.visible = rank >= 3 or custom.has("look")

	# Team colour skin on every mesh, on faceted (flat-shaded) copies of the
	# meshes so the low-poly angles read crisp, like the reference art.
	var skin: Texture2D = load("res://assets/characters/skins/%s_%s.png" % [c.skin, "elf" if team == 0 else "human"])
	skin = customised_skin(skin, c.skin, custom)
	flash_mats = []
	for mesh in _meshes(inst):
		mesh.mesh = _flat_mesh(mesh.mesh)
		for i in mesh.get_surface_override_material_count():
			var mat: Material = mesh.get_active_material(i)
			if mat is StandardMaterial3D:
				var dup: StandardMaterial3D = mat.duplicate()
				dup.albedo_texture = skin
				dup.albedo_color = tint * custom.get("look", Color.WHITE)
				dup.rim_enabled = true
				dup.rim = 0.35
				dup.rim_tint = 0.6
				if custom.has("look"):
					# The Shadowborn look: a violet glow along the edges.
					dup.emission_enabled = true
					dup.emission = Color(0.35, 0.15, 0.6)
					dup.emission_energy_multiplier = 0.25
				dup.roughness = 0.75
				dup.next_pass = outline
				mesh.set_surface_override_material(i, dup)
				flash_mats.append(dup)

	if skeleton:
		for bone in CHUNKY:
			var bi: int = skeleton.find_bone(bone)
			if bi >= 0:
				skeleton.set_bone_pose_scale(bi, Vector3.ONE * CHUNKY[bone])
		_add_face(inst, c.scene, team, role, custom, skin)
		if c.ears:
			_add_ears(team, custom.get("skin", Color(0.97, 0.84, 0.72)))
		if int(custom.get("hair_style", 0)) > 0 and variant == "":
			_add_hair_style(int(custom.hair_style), custom.get("hair", Face.hair_color(skin)))
		if c.crown:
			_add_crown()
	_add_class_flair(role, variant)
	if skeleton and variant == "":
		OutfitFlair.dress(skeleton, role, custom.get("trim", Stats.FACTIONS[team].color.darkened(0.1)), outline)
	if variant == "" or Stats.VARIANTS.has(role):
		_add_rank_flair(team, role, rank)
	if variant == "":
		_add_weapon_art(team, role, rank)

	if anim:
		for name in LOOPS:
			if anim.has_animation(name):
				anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		play_loop(idle_anim)


func _add_class_flair(role: int, variant: String) -> void:
	## What makes each class read at a glance beyond its gear: the Ranger's
	## quiver on the back, arcane sparks around the Mage, soft healing motes
	## around the Healer.
	match role:
		Role.RANGER:
			var quiver: Node3D = load("res://assets/props/gear/quiver.gltf").instantiate()
			quiver.position = Vector3(0.14, 1.05, 0.22)
			quiver.rotation = Vector3(0.35, 0, -0.25)
			quiver.scale = Vector3.ONE * 1.1
			add_child(quiver)
		Role.MAGE, Role.HEALER:
			var cp := CPUParticles3D.new()
			cp.amount = 14
			cp.lifetime = 1.4
			cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			cp.emission_sphere_radius = 0.5
			cp.direction = Vector3.UP
			cp.spread = 30.0
			cp.initial_velocity_min = 0.2
			cp.initial_velocity_max = 0.5
			cp.gravity = Vector3(0, 0.3, 0)
			cp.scale_amount_min = 0.05
			cp.scale_amount_max = 0.1
			cp.position = Vector3(0, 1.0, 0)
			var sph := SphereMesh.new()
			sph.radius = 0.5
			sph.height = 1.0
			sph.radial_segments = 5
			sph.rings = 3
			cp.mesh = sph
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var col := Color(0.8, 0.5, 1.0) if role == Role.MAGE else Color(0.6, 1.0, 0.7)
			if variant == "Pyromancer":
				col = Color(1.0, 0.6, 0.25)
			elif variant == "Frostweaver":
				col = Color(0.6, 0.9, 1.0)
			elif variant == "Dark Priest":
				col = Color(0.7, 0.4, 0.9)
			mat.albedo_color = col
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = 2.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.8
			cp.material_override = mat
			add_child(cp)


func _gear_node(name: String) -> Node3D:
	## The rig's gear holder for `name` (a BoneAttachment3D riding the gear
	## bone), so built weapons follow the hand through every animation.
	if model_root == null:
		return null
	return model_root.find_child(name, true, false) as Node3D


func _prism(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	m.mesh = pm
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	parent.add_child(m)


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	m.position = pos
	m.material_override = mat
	parent.add_child(m)


func _ring(parent: Node3D, inner: float, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = inner + 0.04
	tm.rings = 12
	tm.ring_segments = 6
	m.mesh = tm
	m.position = pos
	m.material_override = mat
	parent.add_child(m)


func _add_weapon_art(team: int, role: int, rank: int) -> void:
	## The weapon sheet's per-rank art: a built bow for Rangers (the packs
	## only have crossbows), runes and gold on Knight swords, crystals and
	## rings on Mage and Healer staves. Everything hangs off the gear bones.
	var team_col: Color = Stats.FACTIONS[team].color
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.98, 0.8, 0.25)
	gold.metallic = 0.7
	gold.roughness = 0.3
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.48, 0.3, 0.15)
	wood.roughness = 0.85
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = team_col.lightened(0.1)
	cloth.roughness = 1.0
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.4, 0.75, 0.3)
	leaf.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.4, 0.42, 0.47)
	iron.metallic = 0.6
	iron.roughness = 0.4
	match role:
		Role.ENGINEER:
			# A hammer (or sledge) on the axe holder: the packs have no hammer.
			var holder := _gear_node("1H_Axe")
			if holder == null:
				holder = _gear_node("2H_Axe")
			if holder == null:
				return
			for m in _meshes(holder):
				m.visible = false
			holder.visible = true
			var big: bool = holder.name == "2H_Axe"
			var shaft_len := 1.1 if big else 0.8
			_prism(holder, Vector3(0.05, shaft_len, 0.05), Vector3(0, shaft_len / 2.0 - 0.3, 0), Vector3.ZERO, wood)
			var head_mat: Material = gold if rank >= 4 else iron
			var head_size := Vector3(0.36, 0.2, 0.2) if big else Vector3(0.28, 0.16, 0.16)
			_prism(holder, head_size, Vector3(0, shaft_len - 0.35, 0), Vector3.ZERO, head_mat)
			if rank >= 2:
				_prism(holder, Vector3(0.07, 0.05, 0.07), Vector3(0, shaft_len - 0.55, 0), Vector3.ZERO, iron)
				_prism(holder, Vector3(0.07, 0.05, 0.07), Vector3(0, -0.2, 0), Vector3.ZERO, iron)
			if rank >= 3:
				_prism(holder, head_size * Vector3(1.05, 0.3, 1.05), Vector3(0, shaft_len - 0.35, 0), Vector3.ZERO, gold)
			if rank >= 4:
				var gm := StandardMaterial3D.new()
				gm.albedo_color = team_col.lightened(0.4)
				gm.emission_enabled = true
				gm.emission = team_col * 1.5
				_sphere(holder, 0.05, Vector3(0, shaft_len - 0.2, 0), gm)
		Role.RANGER:
			var bow := _gear_node("2H_Crossbow")
			if bow == null:
				return
			# The holder was hidden with the crossbow; show it and hide the mesh.
			for m in _meshes(bow):
				m.visible = false
			bow.visible = true
			# Limbs: an arc of tapered segments across x, bulging forward (+z).
			var half := 0.62
			var bulge := 0.32
			var segs := 8
			var limb := gold if rank >= 4 else wood
			var prev := Vector3(-half, 0.05, -0.05)
			for i in range(1, segs + 1):
				var t: float = -1.0 + 2.0 * i / segs
				var p := Vector3(t * half, 0.05, bulge * (1.0 - t * t) - 0.05)
				var seg := MeshInstance3D.new()
				var bm := BoxMesh.new()
				var thick: float = 0.09 - 0.04 * absf(t)
				bm.size = Vector3(thick, thick, (p - prev).length() + 0.02)
				seg.mesh = bm
				seg.position = (p + prev) / 2.0
				seg.basis = Basis.looking_at(p - prev, Vector3.UP)
				seg.material_override = limb
				bow.add_child(seg)
				prev = p
			_box(bow, Vector3(0.1, 0.12, 0.16), Vector3(0, 0.05, bulge - 0.05), Vector3.ZERO, cloth if rank >= 2 else wood)
			_box(bow, Vector3(half * 2.0, 0.015, 0.015), Vector3(0, 0.05, -0.05), Vector3.ZERO, wood)
			# A nocked arrow along the bolt line.
			_box(bow, Vector3(0.03, 0.03, 0.95), Vector3(0, 0.06, 0.35), Vector3.ZERO, wood)
			var steel := StandardMaterial3D.new()
			steel.albedo_color = Color(0.8, 0.82, 0.88)
			steel.metallic = 0.6
			_prism(bow, Vector3(0.06, 0.12, 0.03), Vector3(0, 0.06, 0.88), Vector3(PI / 2.0, 0, 0), steel)
			for sx in [-1.0, 1.0]:
				_box(bow, Vector3(0.06, 0.012, 0.1), Vector3(sx * 0.035, 0.06, -0.06), Vector3(0, 0, sx * 0.5), cloth)
			if rank >= 2:
				for t in [-0.5, 0.5]:
					_box(bow, Vector3(0.12, 0.1, 0.1), Vector3(t * half, 0.05, bulge * 0.75 - 0.05), Vector3.ZERO, cloth)
			if rank >= 3:
				for sx in [-1.0, 1.0]:
					_box(bow, Vector3(0.1, 0.09, 0.09), Vector3(sx * half, 0.05, -0.05), Vector3.ZERO, gold)
					_prism(bow, Vector3(0.08, 0.16, 0.03), Vector3(sx * half * 0.8, 0.14, 0.05), Vector3(0, 0, sx * 0.6), leaf)
			if rank >= 4:
				_sphere(bow, 0.06, Vector3(0, 0.13, bulge - 0.05), _glow(team_col.lightened(0.4), 2.0))
		Role.KNIGHT:
			var sword := _gear_node("1H_Sword")
			if sword == null:
				return
			if rank >= 2:
				var rune := _glow(Color(0.55, 0.8, 1.0), 1.2 if rank < 4 else 2.0)
				_box(sword, Vector3(0.025, 1.0, 0.16), Vector3(0, 0.7, 0), Vector3.ZERO, rune)
			if rank >= 3:
				_box(sword, Vector3(0.62, 0.09, 0.15), Vector3(0, 0.08, 0), Vector3.ZERO, gold)
				_sphere(sword, 0.07, Vector3(0, -0.4, 0), gold)
			if rank >= 4:
				_sphere(sword, 0.07, Vector3(0, 0.08, 0), _glow(Color(0.55, 0.8, 1.0), 2.5))
		Role.MAGE:
			var staff := _gear_node("2H_Staff")
			if staff == null:
				return
			var glow := _glow(Color(0.7, 0.55, 1.0), 2.0)
			if rank >= 2:
				for sx in [-1.0, 1.0]:
					_prism(staff, Vector3(0.08, 0.22, 0.08), Vector3(0.04 + sx * 0.17, 0.95, 0), Vector3(0, 0, -sx * 0.5), glow)
			if rank >= 3:
				_ring(staff, 0.13, Vector3(0.04, 0.78, 0), gold)
			if rank >= 4:
				_prism(staff, Vector3(0.15, 0.42, 0.15), Vector3(0.04, 1.45, 0), Vector3.ZERO, glow)
				for sx in [-1.0, 1.0]:
					_prism(staff, Vector3(0.06, 0.3, 0.1), Vector3(0.04 + sx * 0.24, 1.12, 0), Vector3(0, 0, -sx * 0.9), gold)
		Role.HEALER:
			var glow := _glow(Color(0.6, 0.95, 0.8), 2.0)
			if rank < 4:
				var wand := _gear_node("1H_Wand")
				if wand == null:
					return
				if rank >= 2:
					_prism(wand, Vector3(0.09, 0.22, 0.09), Vector3(0, 0.8, 0), Vector3.ZERO, glow)
				if rank >= 3:
					_ring(wand, 0.07, Vector3(0, 0.6, 0), gold)
					for sx in [-1.0, 1.0]:
						_prism(wand, Vector3(0.06, 0.14, 0.03), Vector3(sx * 0.1, 0.68, 0), Vector3(0, 0, sx * 0.7), leaf)
			else:
				var staff := _gear_node("2H_Staff")
				if staff == null:
					return
				_box(staff, Vector3(0.08, 0.4, 0.08), Vector3(0.04, 1.1, 0), Vector3.ZERO, gold)
				_box(staff, Vector3(0.32, 0.08, 0.08), Vector3(0.04, 1.14, 0), Vector3.ZERO, gold)
				_sphere(staff, 0.085, Vector3(0.04, 1.34, 0), glow)
				_ring(staff, 0.13, Vector3(0.04, 0.78, 0), gold)


func _glow(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _attach_to(bone: String) -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skeleton.add_child(att)
	return att


func _box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	parent.add_child(m)


func _add_rank_flair(team: int, role: int, rank: int) -> void:
	## The rank sheet's progression on top of the gear swaps: plumes,
	## pauldrons and gold trim for Knights, feathers and arrows for Rangers,
	## hat crystals for Mages, halos and wings for Healers. Rank 1 is plain.
	if skeleton == null or rank <= 1:
		return
	var team_col: Color = Stats.FACTIONS[team].color
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.98, 0.8, 0.25)
	gold.metallic = 0.7
	gold.roughness = 0.3
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.86)
	steel.metallic = 0.6
	steel.roughness = 0.45
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = team_col.lightened(0.1)
	cloth.roughness = 1.0
	match role:
		Role.KNIGHT:
			var head := _attach_to_head()
			var h := 0.4 + 0.14 * (rank - 2)
			for i in 3:
				_box(head, Vector3(0.09, h, 0.3), Vector3(0, 0.98 + h / 2.0, -0.05 - i * 0.1), Vector3(-0.35 - i * 0.2, 0, 0), cloth)
			if rank >= 3:
				for side in ["l", "r"]:
					var arm := _attach_to("upperarm." + side)
					var pad := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = 0.2 if rank == 3 else 0.24
					sm.height = sm.radius * 2.0
					pad.mesh = sm
					pad.scale = Vector3(1.0, 0.75, 1.0)
					pad.position = Vector3(0, 0.08, 0)
					pad.material_override = steel if rank == 3 else gold
					arm.add_child(pad)
			if rank >= 4:
				_box(head, Vector3(0.07, 0.3, 0.07), Vector3(0, 0.98 + h + 0.1, -0.05), Vector3.ZERO, gold)
		Role.RANGER:
			var head := _attach_to_head()
			_box(head, Vector3(0.06, 0.55, 0.14), Vector3(0.24, 0.9, -0.1), Vector3(0, 0, 0.6), cloth)
			if rank >= 3:
				var bundle: Node3D = load("res://assets/props/gear/arrow_bundle.gltf").instantiate()
				bundle.position = Vector3(0.08, 1.28, 0.28)
				bundle.rotation = Vector3(0.5, 0, -0.25)
				bundle.scale = Vector3.ONE * 1.1
				add_child(bundle)
			if rank >= 4:
				_box(head, Vector3(0.06, 0.55, 0.14), Vector3(-0.24, 0.9, -0.1), Vector3(0, 0, -0.6), gold)
		Role.MAGE:
			var head := _attach_to_head()
			var glow := _glow(Color(0.75, 0.55, 1.0), 2.0)
			var gem := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.08
			sph.height = 0.16
			gem.mesh = sph
			gem.material_override = glow
			gem.position = Vector3(0, 0.9, 0.4)
			head.add_child(gem)
			if rank >= 3:
				var n := 3 if rank == 3 else 5
				for i in n:
					var a := TAU * i / n + PI / 2.0
					var cr := MeshInstance3D.new()
					var pm := PrismMesh.new()
					pm.size = Vector3(0.1, 0.28 if rank == 3 else 0.38, 0.1)
					cr.mesh = pm
					cr.material_override = glow
					cr.position = Vector3(cos(a) * 0.3, 1.3, sin(a) * 0.3)
					cr.rotation = Vector3(0.45 * sin(a), -a, -0.45 * cos(a))
					head.add_child(cr)
		Role.HEALER:
			var head := _attach_to_head()
			var halo := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.28 if rank < 4 else 0.36
			tm.outer_radius = tm.inner_radius + 0.06
			halo.mesh = tm
			halo.material_override = _glow(Color(1.0, 0.9, 0.5), 2.2)
			halo.position = Vector3(0, 1.08, 0)
			head.add_child(halo)
			if rank >= 3:
				var chest := _attach_to("chest")
				var wing := _glow(Color(1.0, 0.98, 0.9), 0.8)
				for side in [-1.0, 1.0]:
					_box(chest, Vector3(0.55, 0.06, 0.16), Vector3(side * 0.4, 0.25, -0.22), Vector3(0, 0, side * 0.5), wing)
					_box(chest, Vector3(0.35, 0.05, 0.12), Vector3(side * 0.5, 0.05, -0.24), Vector3(0, 0, side * 0.9), wing)
			if rank >= 4:
				for i in 4:
					var a := TAU * i / 4.0
					var gem := MeshInstance3D.new()
					var sph := SphereMesh.new()
					sph.radius = 0.06
					sph.height = 0.12
					gem.mesh = sph
					gem.material_override = _glow(Color(0.6, 0.95, 1.0), 2.0)
					gem.position = Vector3(cos(a) * 0.39, 1.08, sin(a) * 0.39)
					head.add_child(gem)


static func _flat_mesh(mesh: Mesh) -> Mesh:
	## A copy of the mesh with every triangle's own normal (no smoothing), so
	## the facets catch the light one by one; bones and weights come along.
	## Cached per source mesh, since every unit shares the same few models.
	if mesh == null:
		return mesh
	var key := mesh.resource_path if mesh.resource_path != "" else str(mesh.get_instance_id())
	if flat_cache.has(key):
		return flat_cache[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(mesh, s)
		st.deindex()
		st.generate_normals()
		st.generate_tangents()
		# Re-index (vertices with different normals stay separate, so the
		# facets survive); Face.clean_head needs an index array.
		st.index()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		out.surface_set_material(s, mesh.surface_get_material(s))
	flat_cache[key] = out
	return out


func _meshes(node: Node) -> Array:
	var out := []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out


func _add_face(inst: Node3D, scene: String, team: int, role: int, custom: Dictionary, skin: Texture2D) -> void:
	## Anime eyes, brows and mouth over the head (scripts/face.gd); the
	## model's dot eyes are painted out of the head's skin.
	var head: MeshInstance3D = null
	for m in _meshes(inst):
		if "_Head" in str(m.name):
			head = m
	if head == null:
		return
	head.mesh = Face.clean_head(head.mesh)
	for i in head.get_surface_override_material_count():
		var mat = head.get_surface_override_material(i)
		if mat is StandardMaterial3D:
			mat.albedo_texture = Face.no_eyes(mat.albedo_texture)
	var face = Face.new()
	var brow: Color = custom.get("hair", Face.hair_color(skin))
	var iris: String = Stats.HERO_EYES[int(custom.eye)][2] if custom.has("eye") else ""
	var mark: String = Stats.HERO_MARKS[int(custom.get("mark", 0))][1]
	face.build(skeleton, scene, team, int(custom.get("face", Face.default_style(role))), brow.darkened(0.3), iris, mark)


func _attach_to_head() -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	skeleton.add_child(att)
	return att


func _add_ears(team: int, skin_color: Color = Color(0.97, 0.84, 0.72)) -> void:
	var att := _attach_to_head()
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = skin_color
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.42
		ear.mesh = cone
		ear.material_override = skin_mat
		ear.position = Vector3(side * 0.46, 0.22, 0.0)
		ear.rotation.z = -side * (PI / 2.0 - 0.35)
		att.add_child(ear)


func _hair_piece(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, scl: Vector3 = Vector3.ONE) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _flat_mesh(mesh)
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scl
	parent.add_child(m)


static func _cyl(top: float, bottom: float, h: float, seg: int = 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


static func _ball(r: float, seg: int = 7) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = 4
	return m


func _add_hair_style(style: int, color: Color) -> void:
	## Modelled hair styles beyond the model's own cut (Stats.HERO_HAIR_STYLES,
	## Faisal 09:14 2026-10-09 "add more hairstyles"): chunky faceted pieces
	## on the head bone, kept to the back and sides so they still show under
	## every class hat and helmet. Head-bone space (measured from the KayKit
	## heads): +z is the face, the head and its own hair span about
	## x -0.55..0.55, y -0.08..0.95, z -0.52..0.52, so every piece sits on or
	## outside that box.
	var head := _attach_to_head()
	var hair := StandardMaterial3D.new()
	hair.albedo_color = color
	hair.roughness = 0.8
	hair.rim_enabled = true
	hair.rim = 0.3
	hair.next_pass = outline
	var tie := StandardMaterial3D.new()
	tie.albedo_color = color.darkened(0.55)
	tie.next_pass = outline
	match style:
		1:  # Ponytail: a knot high on the back of the head and a tail in three tapering lengths.
			_hair_piece(head, _ball(0.16, 6), Vector3(0, 0.72, -0.54), Vector3.ZERO, hair)
			_hair_piece(head, _cyl(0.11, 0.11, 0.08, 6), Vector3(0, 0.66, -0.66), Vector3(-1.2, 0, 0), tie)
			_hair_piece(head, _cyl(0.15, 0.12, 0.36, 6), Vector3(0, 0.48, -0.76), Vector3(-0.45, 0, 0), hair)
			_hair_piece(head, _cyl(0.12, 0.08, 0.34, 6), Vector3(0, 0.16, -0.84), Vector3(-0.12, 0, 0), hair)
			_hair_piece(head, _cyl(0.08, 0.0, 0.26, 5), Vector3(0, -0.12, -0.82), Vector3(0.2, 0, 0), hair)
		2:  # Long: a fan of five locks over the back down past the shoulders and a lock either side of the face.
			for i in range(-2, 3):
				var lx := i * 0.2
				_hair_piece(head, _cyl(0.13, 0.08, 0.95, 5), Vector3(lx, 0.2, -0.56 + absf(lx) * 0.12), Vector3(-0.1, 0, i * 0.07), hair)
			for side in [-1.0, 1.0]:
				_hair_piece(head, _cyl(0.11, 0.06, 0.75, 5), Vector3(side * 0.58, 0.2, 0.14), Vector3(0, 0, side * 0.06), hair)
		3:  # Braids: two plaits of chunky beads down the sides, each with a tie and a tuft.
			for side in [-1.0, 1.0]:
				for k in 4:
					var r := 0.13 - k * 0.012
					_hair_piece(head, _ball(r, 6), Vector3(side * (0.6 - k * 0.01), 0.36 - k * 0.19, 0.12), Vector3(0, k * 0.6, 0), hair, Vector3(1.0, 0.85, 1.0))
				_hair_piece(head, _cyl(0.07, 0.07, 0.07, 6), Vector3(side * 0.57, -0.36, 0.12), Vector3.ZERO, tie)
				_hair_piece(head, _cyl(0.03, 0.1, 0.2, 5), Vector3(side * 0.57, -0.5, 0.12), Vector3(PI, 0, 0), hair)
		4:  # Bun: a big knot on top at the back of the head with a band round its base.
			_hair_piece(head, _ball(0.28, 7), Vector3(0, 1.02, -0.3), Vector3(0.4, 0, 0), hair, Vector3(1.0, 0.85, 1.0))
			_hair_piece(head, _cyl(0.2, 0.23, 0.08, 7), Vector3(0, 0.9, -0.24), Vector3(-0.5, 0, 0), tie)


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
