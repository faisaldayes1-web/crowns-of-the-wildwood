extends SceneTree
## Renders the STORE's item icons from the real models: every hat, hair
## style and hair colour on the hero's head, every cape and cape dye from
## behind, every armour tint on a Knight, every weapon skin on the Knight's
## sword and shield. Transparent 256x256 PNGs in assets/ui/store/, named
## <kind>_<index>.png (store.gd draws them on the cards). Needs a GPU (run
## under xvfb with Vulkan), from the project root:
##   xvfb-run -a -s "-screen 0 1280x1280x24" godot --path . --rendering-driver vulkan \
##       --resolution 768x768 --script tools/render_store_icons.gd
## then `godot --headless --path . --import`.

const Stats = preload("res://scripts/stats.gd")
const Store = preload("res://scripts/store.gd")
const StoreGear = preload("res://scripts/store_gear.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const Role = Stats.Role

const OUT := "res://assets/ui/store"
const SIZE := 256
const BASE := {"body": "rogue", "skin": Color(0.96, 0.75, 0.61), "hair": Color(0.4, 0.25, 0.12), "face": 0}

var cam: Camera3D
var stage: Node3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.transparent_bg = true
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.94, 0.82)
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-35, 30, 0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-15, 200, 0)
	stage.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 26.0
	stage.add_child(cam)
	await process_frame
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var n := 0
	for kind in ["hat", "hair_style", "hair", "cape", "trim", "outfit", "weapon"]:
		if only != "" and kind != only:
			continue
		for i in Store.table(kind).size():
			if i == 0 and kind in ["hat", "cape", "outfit", "weapon"]:
				continue
			await _shoot(kind, i)
			n += 1
	print("store icons: %d rendered" % n)
	quit()


func _custom(kind: String, i: int) -> Dictionary:
	var c := BASE.duplicate()
	match kind:
		"hat", "hair_style":
			c = Store.wear(c, kind, i)
			c.hair = Color(0.85, 0.42, 0.16) if kind == "hair_style" else c.hair
		"hair": c.hair = Stats.HERO_HAIR[i][1]
		"cape": c = Store.wear(c, "cape", i)
		"trim":
			c.cape = "cape"
			if i > 0:
				c.trim = Stats.HERO_TRIM[i][1]
		"outfit", "weapon": c = Store.wear(c, kind, i)
	return c


func _shoot(kind: String, i: int) -> void:
	var m := CharacterModel.new()
	stage.add_child(m)
	var role: int = Role.KNIGHT if kind in ["outfit", "weapon"] else Role.BASE
	m.setup(1, role, "", _custom(kind, i), 1)
	m.rotation.y = PI + 0.45
	if kind in ["cape", "trim"]:
		m.rotation.y = 0.55   # the back, a little turned
	if m.anim:
		m.anim.seek(0.3, true)
	await process_frame
	await process_frame
	var head := Vector3(0, 1.55, 0)
	if m.skeleton:
		var b: int = m.skeleton.find_bone("head")
		if b >= 0:
			head = m.skeleton.global_transform * m.skeleton.get_bone_global_pose(b).origin
	var look: Vector3
	var dist: float
	match kind:
		"hat", "hair_style", "hair":
			look = head + Vector3(0, 0.55 if kind == "hat" else 0.3, 0)
			dist = 4.9 if kind == "hat" else 4.2
		"cape", "trim":
			look = Vector3(0, 0.95, 0)
			dist = 5.6
		"outfit":
			look = Vector3(0, 1.05, 0)
			dist = 7.0
		"weapon":
			# The Knight's sword and shield, close.
			look = Vector3(0, 0.98, 0)
			dist = 6.4
	cam.global_position = look + Vector3(0, dist * 0.18, dist)
	cam.look_at(look)
	for k in 4:
		await process_frame
	var img := root.get_texture().get_image()
	var s := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path("%s/%s_%d.png" % [OUT, kind, i]))
	m.free()
