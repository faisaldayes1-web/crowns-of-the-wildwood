extends SceneTree
## Renders every character the player can be (the three bare builds, each
## class at rank 1 and 3, and each promotion) for both factions, front and
## back, in a cape dye, so a dye that misses a model shows at a glance.
## One 256x256 PNG per shot in user://trim_check/ (names: dye_role_team_side).
##   xvfb-run -a -s "-screen 0 1280x1280x24" godot --path . --rendering-driver vulkan \
##       --resolution 768x768 --script tools/trim_check.gd -- --dye=1
## --dye=N is a Stats.HERO_TRIM index (0 = the faction colour). Also checks
## headlessly that the dye reaches every model's skin: see tools/store_test.gd.

const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const Role = Stats.Role

const OUT := "user://trim_check"
const SIZE := 256

var cam: Camera3D
var stage: Node3D


static func cast() -> Array:
	## [label, role, variant, rank, extra custom] for every playable look.
	var out: Array = []
	for b in Stats.HERO_BODIES:
		out.append(["base-" + str(b[1]), Role.BASE, "", 1, {"body": b[1]}])
	for role in [Role.KNIGHT, Role.RANGER, Role.MAGE, Role.HEALER, Role.ENGINEER, Role.ROGUE]:
		var name: String = Role.keys()[role].to_lower()
		out.append([name + "-r1", role, "", 1, {}])
		out.append([name + "-r3", role, "", 3, {}])
		if Stats.VARIANTS.has(role):
			for v in Stats.VARIANTS[role]:
				out.append([name + "-" + str(v.name).to_lower(), role, v.name, 3, {}])
	return out


func _init() -> void:
	var dye := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dye="):
			dye = int(arg.trim_prefix("--dye="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.2, 0.19)
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
	var back := DirectionalLight3D.new()
	back.light_energy = 0.9
	back.rotation_degrees = Vector3(-35, 210, 0)
	stage.add_child(back)
	cam = Camera3D.new()
	cam.fov = 26.0
	stage.add_child(cam)
	await process_frame
	var n := 0
	for who in cast():
		for team in 2:
			for side in ["front", "back"]:
				var c: Dictionary = who[4].duplicate()
				c.hair = Color(0.4, 0.25, 0.12)
				if dye > 0:
					c.trim = Stats.HERO_TRIM[dye][1]
				var m := CharacterModel.new()
				stage.add_child(m)
				m.setup(team, who[1], who[2], c, who[3])
				m.rotation.y = PI + 0.45 if side == "front" else 0.45
				if m.anim:
					m.anim.seek(0.3, true)
				var look := Vector3(0, 1.0, 0)
				cam.global_position = look + Vector3(0, 1.3, 7.2)
				cam.look_at(look)
				for k in 4:
					await process_frame
				var img := root.get_texture().get_image()
				var s := mini(img.get_width(), img.get_height())
				img = img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
				img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
				img.save_png(ProjectSettings.globalize_path("%s/%d_%s_%s_%s.png" % [OUT, dye, who[0], ["elf", "human"][team], side]))
				m.free()
				n += 1
	print("trim check: %d shots in %s" % [n, ProjectSettings.globalize_path(OUT)])
	quit()
