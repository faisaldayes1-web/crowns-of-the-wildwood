extends Node3D
## A chibi anime face on a KayKit head: big glossy eyes, eyebrows in the hair
## colour and a small mouth, painted by tools/make_faces.py and laid on thin
## curved patches just in front of the head (the model's own dot eyes are
## painted over in skin colour). The eyes blink now and then.
##
## Four styles (Stats.FACE_STYLES): Bold, Bright, Fierce, Gentle. Humans
## have brown eyes, Elves green.

const STYLES := ["bold", "bright", "fierce", "gentle"]
# The patches' frames in model space (see tools/make_faces.py).
const EYES_RECT := Rect2(-0.36, 1.48, 0.72, 0.36)
const MOUTH_RECT := Rect2(-0.12, 1.32, 0.24, 0.12)
const EYE_Y := 1.625
# How far the face front sits forward at each |x| (a little proud of the head).
const PROFILE := [[0.0, 0.457], [0.16, 0.455], [0.22, 0.432], [0.28, 0.388], [0.34, 0.334], [0.38, 0.29]]

static var tex_cache := {}
static var noeye_cache := {}

var eyes: MeshInstance3D
var next_blink := 0.0
var blink_left := 0.0


static func default_style(role: int) -> int:
	## Each class has its own look: Knights bold, Rangers fierce, Mages bright, Healers gentle.
	match role:
		1: return 0   # Knight
		2: return 2   # Ranger
		3: return 1   # Mage
		4: return 3   # Healer
	return 0


static func _tex(path: String) -> Texture2D:
	if not tex_cache.has(path):
		tex_cache[path] = load(path)
	return tex_cache[path]


static func _z(x: float) -> float:
	var ax := absf(x)
	for i in range(1, PROFILE.size()):
		if ax <= PROFILE[i][0]:
			var a: Array = PROFILE[i - 1]
			var b: Array = PROFILE[i]
			return lerpf(a[1], b[1], (ax - a[0]) / (b[0] - a[0]))
	return PROFILE[-1][1]


static func _patch(rect: Rect2, pivot_y: float, z_add: float, flat_z: float = -1.0) -> ArrayMesh:
	## A grid bent round the face, UV 0..1 over the rect (v down), around pivot_y.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 18
	var ny := 3
	for j in ny:
		for i in nx:
			var quad := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u: float = float(c[0]) / nx
				var v: float = float(c[1]) / ny
				var x := rect.position.x + u * rect.size.x
				var y := rect.position.y + rect.size.y * (1.0 - v)
				var z: float = (flat_z if flat_z > 0.0 else _z(x)) + z_add
				quad.append([Vector3(x, y - pivot_y, z), Vector2(u, v)])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3(quad[k][0].x * 0.6, 0, 1).normalized())
				st.set_uv(quad[k][1])
				st.add_vertex(quad[k][0])
	return st.commit()


static func no_eyes(skin: Texture2D) -> Texture2D:
	## The skin with the dot-eye cell (2, 0) painted over in mid skin tone.
	if noeye_cache.has(skin):
		return noeye_cache[skin]
	var img: Image = skin.get_image()
	if img == null:
		return skin
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var cw: int = img.get_width() / 8
	var ch: int = img.get_height() / 4
	var tone := img.get_pixel(cw / 2, ch / 2)
	img.fill_rect(Rect2i(2 * cw, 0, cw, ch), tone)
	var out := ImageTexture.create_from_image(img)
	noeye_cache[skin] = out
	return out


static func hair_color(skin: Texture2D) -> Color:
	var img: Image = skin.get_image()
	if img == null:
		return Color(0.35, 0.2, 0.1)
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var c := img.get_pixel(img.get_width() / 16 * 3, img.get_height() / 8)
	return c.darkened(0.15)


func _mat(tex: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.render_priority = 1
	return m


func build(skeleton: Skeleton3D, scene: String, team: int, style: int, brow: Color) -> void:
	## Attach to the head bone; build eyes, brows and (unless bearded) a mouth.
	var hb := skeleton.find_bone("head")
	if hb < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	skeleton.add_child(att)
	att.add_child(self)
	# Model space -> head bone space.
	transform = skeleton.get_bone_global_rest(hb).affine_inverse()
	var st: String = STYLES[clampi(style, 0, STYLES.size() - 1)]
	var iris := "green" if team == 0 else "brown"
	eyes = MeshInstance3D.new()
	eyes.mesh = _patch(EYES_RECT, EYE_Y, 0.0)
	eyes.position.y = EYE_Y
	eyes.material_override = _mat(_tex("res://assets/characters/faces/face_eyes_%s_%s.png" % [st, iris]))
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(eyes)
	var brows := MeshInstance3D.new()
	brows.mesh = _patch(EYES_RECT, EYE_Y, 0.004)
	brows.position.y = EYE_Y
	brows.material_override = _mat(_tex("res://assets/characters/faces/face_brows_%s.png" % st), brow)
	brows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(brows)
	if scene != "barbarian":
		var mouth := MeshInstance3D.new()
		mouth.mesh = _patch(MOUTH_RECT, 0.0, 0.0, 0.452)
		mouth.material_override = _mat(_tex("res://assets/characters/faces/face_mouth_%s.png" % st))
		mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mouth)
	next_blink = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	if eyes == null:
		return
	if blink_left > 0.0:
		blink_left -= delta
		eyes.scale.y = 0.12 if blink_left > 0.0 else 1.0
		return
	next_blink -= delta
	if next_blink <= 0.0:
		blink_left = 0.11
		next_blink = randf_range(2.5, 5.5)
