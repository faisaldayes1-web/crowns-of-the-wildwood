extends SceneTree
## Where does the main thread go? In one running bot match, switches each
## subsystem off for a few seconds between two baseline stretches and prints
## the median frame time before, during and after (base, off, base again),
## so background load on the machine shows up as base-to-base drift.
##     godot --path . --resolution 1920x1080 --script tools/cost_ab.gd -- --demo --seed=7 --gfx=2

const SETTLE := 14.0
const SECS := 4.0

var game
var saved := []


func _median() -> float:
	var times := []
	var last := Time.get_ticks_usec()
	var t0 := last
	while Time.get_ticks_usec() - t0 < SECS * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	return times[times.size() / 2]


func _off(what: String) -> void:
	saved = []
	match what:
		"cpu_particles":
			for p in root.find_children("*", "CPUParticles3D", true, false):
				saved.append([p, p.emitting, p.visible, p.process_mode])
				p.emitting = false
				p.visible = false
				p.process_mode = Node.PROCESS_MODE_DISABLED
		"gpu_particles":
			for p in root.find_children("*", "GPUParticles3D", true, false):
				saved.append([p, p.emitting, p.visible, p.process_mode])
				p.emitting = false
				p.visible = false
		"animation":
			for a in root.find_children("*", "AnimationPlayer", true, false):
				saved.append([a, a.speed_scale])
				a.speed_scale = 0.0
				a.process_mode = Node.PROCESS_MODE_DISABLED
			for a in root.find_children("*", "AnimationTree", true, false):
				saved.append([a, a.active])
				a.active = false
		"skeletons":
			for s in root.find_children("*", "Skeleton3D", true, false):
				saved.append([s, s.process_mode])
				s.process_mode = Node.PROCESS_MODE_DISABLED
		"hud":
			for h in root.find_children("*", "CanvasLayer", true, false):
				saved.append([h, h.visible])
				h.visible = false
		"critters", "units", "projectiles", "fx", "labels3d":
			var file: String = {"critters": "critter.gd", "units": "unit.gd", "projectiles": "projectile.gd", "fx": "fx.gd", "labels3d": ""}[what]
			for n in root.find_children("*", "", true, false):
				if what == "labels3d":
					if n is Label3D:
						saved.append([n, n.visible])
						n.visible = false
				elif n.get_script() and n.get_script().resource_path.get_file() == file:
					saved.append([n, n.process_mode])
					n.process_mode = Node.PROCESS_MODE_DISABLED
		"physics":
			PhysicsServer3D.set_active(false)
		"lights":
			for l in root.find_children("*", "Light3D", true, false):
				if not l is DirectionalLight3D:
					saved.append([l, l.visible])
					l.visible = false


func _on(what: String) -> void:
	if what == "physics":
		PhysicsServer3D.set_active(true)
		return
	for s in saved:
		var n = s[0]
		if not is_instance_valid(n):
			continue
		match what:
			"cpu_particles", "gpu_particles":
				n.emitting = s[1]
				n.visible = s[2]
				n.process_mode = s[3]
			"animation":
				if n is AnimationPlayer:
					n.speed_scale = s[1]
					n.process_mode = Node.PROCESS_MODE_INHERIT
				else:
					n.active = s[1]
			"hud", "labels3d", "lights":
				n.visible = s[1]
			_:
				n.process_mode = s[1]


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < SETTLE * 1000.0:
		await process_frame
	var census := {}
	for k in ["CPUParticles3D", "GPUParticles3D", "AnimationPlayer", "AnimationTree", "Skeleton3D", "Label3D", "OmniLight3D", "SpotLight3D"]:
		census[k] = root.find_children("*", k, true, false).size()
	print("COST census %s" % str(census))
	for what in ["cpu_particles", "gpu_particles", "animation", "skeletons", "hud", "critters", "units", "labels3d", "lights", "physics"]:
		var a: float = await _median()
		_off(what)
		var b: float = await _median()
		_on(what)
		var c: float = await _median()
		print("COST %-14s base %.2f  off %.2f  base %.2f   saves ~%.2f ms" % [what, a, b, c, (a + c) / 2.0 - b])
	quit()
