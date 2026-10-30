extends RefCounted
## Small outfit touches from the character art sheet, added on top of the
## KayKit models: a knotted scarf for Knights and Rangers in their side's
## colour (or the player's trim colour), with its tails flying behind.

static func _bone_node(skeleton: Skeleton3D, bone: String) -> Node3D:
	## A node that follows `bone`, with model-space coordinates.
	var b := skeleton.find_bone(bone)
	if b < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skeleton.add_child(att)
	var n := Node3D.new()
	n.transform = skeleton.get_bone_global_rest(b).affine_inverse()
	att.add_child(n)
	return n


static func dress(skeleton: Skeleton3D, role: int, color: Color, outline: Material) -> void:
	if role != 1 and role != 2:   # Knight, Ranger
		return
	var n := _bone_node(skeleton, "chest")
	if n == null:
		return
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = color
	cloth.roughness = 0.9
	cloth.rim_enabled = true
	cloth.rim = 0.3
	cloth.next_pass = outline
	var dark := cloth.duplicate()
	dark.albedo_color = color.darkened(0.25)
	# The wrap round the neck.
	var wrap := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.24
	tor.outer_radius = 0.43
	tor.rings = 20
	tor.ring_segments = 10
	wrap.mesh = tor
	wrap.material_override = cloth
	wrap.position = Vector3(0, 1.19, 0.0)
	wrap.scale = Vector3(1.0, 0.55, 0.92)
	n.add_child(wrap)
	# The knot at the side and two tails trailing behind.
	var knot := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.2
	knot.mesh = s
	knot.material_override = cloth
	knot.position = Vector3(0.22, 1.14, 0.24)
	n.add_child(knot)
	for k in 2:
		var tail := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.15, 0.36 - k * 0.08, 0.04)
		tail.mesh = b
		tail.material_override = dark if k == 1 else cloth
		tail.position = Vector3(0.26 + k * 0.08, 0.98 + k * 0.03, 0.26 - k * 0.03)
		tail.rotation = Vector3(-0.25, 0.4, 0.35 + k * 0.3)
		n.add_child(tail)


# Team tabards (claude-faisal/tabard): a skinned cloth mesh modelled on the
# KayKit rig in Blender (assets/characters/tabard/build_tabard.py), so a Human
# and an Elf of the same class read apart from the match camera. One mesh per
# body serves both teams; the colour comes from a tiny per-team palette (cloth,
# hem) on the material. "Tabard_Front" drops the back panel for a worn cape.
# Keyed by class (on its body): Knights (Knight body) and Healers (Mage body),
# the classes whose two teams looked alike from above. Rangers, Mages and
# Rogues already wear team hoods and hats; the Engineer's shirt is team
# coloured under the bear hood.
const TABARDS := {"knight": "res://assets/characters/tabard/tabard_knight.glb",
	"healer": "res://assets/characters/tabard/tabard_healer.glb"}
static var tabard_scenes := {}
static var tabard_palettes := {}


static func tabard(skeleton: Skeleton3D, body: String, team_col: Color, gold_hem: bool, with_back: bool,
		outline: Material) -> StandardMaterial3D:
	## Adds the tabard under `skeleton`; returns its material (for the hit flash).
	if skeleton == null or not TABARDS.has(body):
		return null
	var ps: PackedScene = tabard_scenes.get(body)
	if ps == null:
		ps = load(TABARDS[body])
		tabard_scenes[body] = ps
	var src_root := ps.instantiate()
	var src := src_root.find_child("Tabard" if with_back else "Tabard_Front", true, false) as MeshInstance3D
	if src == null:
		src_root.free()
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Tabard"
	mi.mesh = src.mesh
	mi.skin = src.skin
	src_root.free()
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _palette(team_col, gold_hem)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	mat.rim_enabled = true
	mat.rim = 0.2
	mat.rim_tint = 0.45
	mat.next_pass = outline
	mi.material_override = mat
	return mat


static func _palette(team_col: Color, gold_hem: bool) -> Texture2D:
	var key := "%s|%s" % [team_col.to_html(), gold_hem]
	if tabard_palettes.has(key):
		return tabard_palettes[key]
	var img := Image.create(2, 1, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, team_col)
	img.set_pixel(1, 0, Color(0.98, 0.78, 0.26) if gold_hem else team_col.darkened(0.35))
	var tex := ImageTexture.create_from_image(img)
	tabard_palettes[key] = tex
	return tex


# Team head pieces (claude-faisal/headband): what the match camera sees of a unit is
# mostly the top of its head, so the classes whose headgear is not team coloured wear
# a team piece there. Modelled in Blender on the KayKit headgear
# (assets/characters/headband/build_headband.py) in the model's rest space, and hung
# on the head bone through its inverse rest so they ride every animation.
# Knight: a crest over the helmet (the rank plume grows out of it from rank 2) and a
# band round it. Engineer: a band round the bear hood and caps on the bear ears.
# Healer: a cloth headband. Promotions tint the whole skin and wash the team colour
# out of the Mage hat and the Ranger/Rogue hood, so promoted Mages, Rangers and Rogues
# get a band there too. Colour: the tabard's 2x1 palette (team colour; the trim is a
# darker team colour, or gold from rank 2).
const HEADBAND := "res://assets/characters/headband/headband.glb"
const HEAD_PIECES := {"knight": ["Knight_Crest", "Knight_Band"], "bear": ["Bear_Band", "Bear_Ears"],
	"healer": ["Healer_Band"], "mage": ["Mage_Band"], "hood": ["Hood_Band"]}
static var head_meshes := {}


static func headband(skeleton: Skeleton3D, key: String, team_col: Color, gold_trim: bool,
		outline: Material) -> StandardMaterial3D:
	## Adds the head pieces for `key` (HEAD_PIECES) on the head bone; returns their
	## material (for the hit flash), or null.
	if skeleton == null or not HEAD_PIECES.has(key):
		return null
	if head_meshes.is_empty():
		var root: Node = (load(HEADBAND) as PackedScene).instantiate()
		for list in HEAD_PIECES.values():
			for piece in list:
				var src := root.find_child(piece, true, false) as MeshInstance3D
				if src:
					head_meshes[piece] = src.mesh
		root.free()
	var n := _bone_node(skeleton, "head")
	if n == null:
		return null
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _palette(team_col, gold_trim)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.85
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.45
	mat.next_pass = outline
	n.name = "TeamHead"
	for piece in HEAD_PIECES[key]:
		if head_meshes.has(piece):
			var mi := MeshInstance3D.new()
			mi.name = piece
			mi.mesh = head_meshes[piece]
			mi.material_override = mat
			n.add_child(mi)
	return mat
