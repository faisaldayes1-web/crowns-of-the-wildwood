extends SceneTree
## Renders every character model to a PNG for a quick look at the art.
## Usage (needs a display or xvfb):
##   godot --path . --rendering-driver opengl3 --script tools/showcase.gd -- --out=showcase.png

const Builder = preload("res://scripts/character_builder.gd")
const Stats = preload("res://scripts/stats.gd")

var frames := 0
var out_path := "showcase.png"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.33, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(40, 0.1, 20)
	floor.mesh = plane
	floor.position.y = -0.05
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.45, 0.5)
	floor.material_override = fm
	world.add_child(floor)
	var roles := [Stats.Role.BASE, Stats.Role.KNIGHT, Stats.Role.RANGER, Stats.Role.MAGE, Stats.Role.HEALER]
	for team in 2:
		for i in roles.size():
			var holder := Node3D.new()
			holder.position = Vector3(-5.0 + i * 2.5, 0, 1.6 if team == 0 else -1.6)
			holder.rotation.y = PI  # face the camera (models face -z)
			holder.scale = Stats.ROLES[roles[i]].build
			world.add_child(holder)
			var rig := Builder.build(holder, team, roles[i])
			rig.left_arm.rotation.z = 0.15
			rig.right_arm.rotation.z = -0.15
		var m := Node3D.new()
		m.position = Vector3(7.5, 0, 1.6 if team == 0 else -1.6)
		m.rotation.y = PI
		world.add_child(m)
		Builder.build_monarch(m, team)
	var cam := Camera3D.new()
	cam.position = Vector3(1.2, 4.2, 8.5)
	cam.rotation_degrees = Vector3(-24, 0, 0)
	cam.fov = 45
	world.add_child(cam)
	cam.make_current()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		root.get_texture().get_image().save_png(out_path)
		print("saved ", out_path)
		return true
	return false
