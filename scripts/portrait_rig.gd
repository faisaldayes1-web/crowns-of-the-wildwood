extends Node
## HD class busts for the dialogue screen and the class cards (Faisal 11-05:
## "too low quality"; the old portrait was a 267 px painted card stretched to
## 360+). One SubViewport per (team, class) with its own world: the same
## 3D model the match uses, dressed by character_model.gd, lit softly from
## the front-left with a cool rim, rendered at 2-3x the size it is shown at
## with 4x MSAA on a transparent background, so the HUD can lay it over any
## backdrop and the dark outline stays clean at 1080p and 1440p.
## Rendered once (the card) or kept live at ~12 fps (the talking guide).

const CharacterModel = preload("res://scripts/character_model.gd")
const Self = preload("res://scripts/portrait_rig.gd")

static var _rigs := {}

var vp: SubViewport
var model
var team := 0
var role := 0
var px := 768
var live := false          # keep re-rendering (the guide idles); otherwise it renders a few frames, then stops
var _age := 0
var _cam: Camera3D


static func supported() -> bool:
	## Phones and browsers keep the painted cards (a MSAA viewport per class is too much there).
	return not (OS.has_feature("web") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"))


static func bust(host: Node, team_: int, role_: int, px_: int = 768) -> Self:
	## The cached rig for this hero (built on first use under `host`).
	var key := "%d_%d_%d" % [team_, role_, px_]
	var r = _rigs.get(key)
	if r != null and is_instance_valid(r) and r.is_inside_tree():
		return r
	r = Self.new()
	r.team = team_
	r.role = role_
	r.px = px_
	host.add_child(r)
	_rigs[key] = r
	return r


static func prewarm(host: Node, team_: int) -> void:
	## Build every class bust for a team now (cards render once, then stop).
	if not supported():
		return
	for r in [1, 2, 3, 4, 5, 6]:   # Role.KNIGHT .. ROGUE; the soldier has no card
		bust(host, team_, r, 512)


func texture() -> Texture2D:
	return vp.get_texture() if vp != null else null


func ready_to_draw() -> bool:
	return vp != null and _age >= 3


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the age counter must run while a menu has the tree paused
	vp = SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.88)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28.0, 38.0, 0.0)   # from the front-left, a little above
	key.light_energy = 1.25
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10.0, 200.0, 0.0)   # a cool edge from behind-right
	rim.light_color = Color(0.7, 0.85, 1.0)
	rim.light_energy = 0.7
	vp.add_child(rim)
	model = CharacterModel.new()
	vp.add_child(model)
	model.setup(team, role, "", {}, 1)
	model.rotation.y = PI - 0.45   # faces the camera, turned a little to its right: a 3/4 view
	_cam = Camera3D.new()
	_cam.fov = 22.0
	vp.add_child(_cam)
	_frame_bust()
	_cam.current = true


func _frame_bust() -> void:
	## Head and shoulders, fitted to this model's own head (the classes differ: a
	## mage's hat, a knight's helm, a hood): the box of everything around the head
	## sets the height of the picture and where the camera looks.
	var head: MeshInstance3D = null
	var meshes: Array = []
	_collect(model, meshes)
	for m in meshes:
		if "_Head" in str(m.name):
			head = m
	if head == null:
		_cam.position = Vector3(0.0, 1.3, 4.0)
		_cam.look_at(Vector3(0.0, 1.3, 0.0), Vector3.UP)
		return
	var hb: AABB = head.global_transform * head.get_aabb()
	var c := hb.get_center()
	var top := hb.end.y
	for m in meshes:
		if not m.visible or m == head or m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		# Hats, hoods and hair: whatever sits over the head (near it in x and z).
		if absf(b.get_center().x - c.x) < 0.45 and absf(b.get_center().z - c.z) < 0.45 and b.end.y > c.y:
			top = maxf(top, b.end.y)
	var bottom := hb.position.y - hb.size.y * 0.55   # to the shoulders
	var tall := top - bottom
	var mid := (top + bottom) / 2.0
	var dist := tall * 0.5 / tan(deg_to_rad(_cam.fov) * 0.5) * 1.18
	var look := Vector3(c.x, mid, c.z)
	_cam.position = look + Vector3(0.0, 0.08, dist)
	_cam.look_at(look, Vector3.UP)


func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for ch in n.get_children():
		_collect(ch, out)


func _process(_delta: float) -> void:
	_age += 1
	if live or _age < 6:
		return
	if vp != null and vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED   # one good frame is enough for a card


func keep_live(on: bool) -> void:
	## The talking guide idles: render every frame while it is on screen.
	if on == live:
		return
	live = on
	_age = 0   # off: _process stops the rendering a few frames later
	if vp != null and on:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
