extends SceneTree
## Faisal 2026-11-04 ("Yes, match chibi"): the class-card portraits are
## renders of the real in-game unit models (chibi), not painted art. Each
## team x class unit is shot as a 3/4 bust on a transparent background;
## tools/compose_card_portraits.py lays the bust into the existing card frame
## (same size, border, name banner and leaves) over a soft team backdrop.
## Needs a GPU, from the project root:
##   godot --path . --resolution 768x960 --script tools/render_card_portraits.gd
## Writes build/card_busts/<elf|human>_<class>.png (not imported).
## Agent: claude-faisal/crowns-visual2

const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const Role = Stats.Role
const OUT := "res://build/card_busts"
const ROLES := {"base": Role.BASE, "knight": Role.KNIGHT, "ranger": Role.RANGER, "mage": Role.MAGE,
	"healer": Role.HEALER, "engineer": Role.ENGINEER, "rogue": Role.ROGUE}

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
	env.environment.ambient_light_color = Color(0.75, 0.74, 0.82)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-30, 35, 0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.75, 0.85, 1.0)
	rim.light_energy = 0.8
	rim.rotation_degrees = Vector3(-10, 200, 0)
	stage.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 24.0
	stage.add_child(cam)
	await process_frame
	var n := 0
	for team in [0, 1]:
		for rname in ROLES:
			await _shoot(team, rname)
			n += 1
	print("card busts: %d rendered" % n)
	quit()


func _shoot(team: int, rname: String) -> void:
	var m := CharacterModel.new()
	stage.add_child(m)
	m.setup(team, ROLES[rname], "", {}, 1)
	m.rotation.y = PI + 0.4
	if m.anim:
		m.anim.seek(0.3, true)
	for k in 3:
		await process_frame
	var head := Vector3(0, 1.5, 0)
	if m.skeleton:
		var b: int = m.skeleton.find_bone("head")
		if b >= 0:
			head = m.skeleton.global_transform * m.skeleton.get_bone_global_pose(b).origin
	var look := head + Vector3(0, -0.5, 0)
	var dist := 8.0
	cam.global_position = look + Vector3(0, dist * 0.12, dist)
	cam.look_at(look)
	for k in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [OUT, "elf" if team == 0 else "human", rname]))
	m.free()
