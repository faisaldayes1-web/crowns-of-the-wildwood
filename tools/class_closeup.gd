extends SceneTree
## Windowed close-ups of every class on both teams, for gear/outline/clipping
## checks (claude-faisal3 11-05). Run:
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/class_closeup.gd -- --play
## Writes <dir>/<team>-<role>.png (a lit 3/4 view of the hero) and, with
## --swing, <dir>/<team>-<role>-swing.png a few frames into its basic attack.
const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")

var game
var cam: Camera3D


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("CLOSEUP saved ", path)


func run() -> void:
	if not Isolated.ok("class_closeup") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var out := OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var waited := 0
	while (not game.playing or game.player == null or not game.player.is_on_floor() or (game.loading_layer != null and game.loading_layer.visible)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(60)
	var swing := "--swing" in OS.get_cmdline_user_args()
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			only = int(a.trim_prefix("--role="))
	game.hud.visible = false
	var p = game.player
	for u in game.units:
		if u != p:
			u.process_mode = Node.PROCESS_MODE_DISABLED
			u.visible = false
	cam = Camera3D.new()
	cam.fov = 38
	game.add_child(cam)
	for team in [0, 1]:
		p.team = team
		for r in Stats.ROLES:
			if only >= 0 and r != only:
				continue
			p.set_role(r)
			p._stats_cache = {}
			p.redress()
			p.global_position = Vector3(-14, 0.0, 0)
			p.aim = Vector3(0.4, 0, 1).normalized()
			p.facing = p.aim
			p.rotation.y = atan2(-p.facing.x, -p.facing.z)
			p.velocity = Vector3.ZERO
			await _frames(20)
			var c: Vector3 = p.global_position + Vector3(0, 1.0, 0)
			cam.global_position = c + Vector3(2.0, 1.0, 4.6)
			cam.look_at(c, Vector3.UP)
			cam.make_current()
			var name := "%s-%s" % ["elves" if team == 0 else "humans", Stats.Role.keys()[r].to_lower()]
			await _frames(10)
			if OS.get_environment("DEBUG_AXES") != "" and r == Stats.Role.ENGINEER:
				var h = p.model._gear_node("1H_Axe")
				if h:
					print("AXES x=", h.global_basis.x, " y=", h.global_basis.y, " z=", h.global_basis.z, " facing=", p.facing, " cam_right=", cam.global_basis.x)
					for ch in h.get_children():
						print("AXES child ", ch.name, " ", ch.get_class(), " rot=", ch.rotation, " n=", ch.get_child_count(), " vis=", ch.visible)
			await _shot("%s/%s.png" % [out, name])
			if swing:
				p.attack_timer = 0.0
				p.energy = p.energy_max()
				p._attack(p.aim)
				await _frames(7)
				await _shot("%s/%s-swing.png" % [out, name])
				await _frames(40)
	quit(0)
