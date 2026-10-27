extends SceneTree
## Agent: Codex-faisal/characters. Exact-pack animation/lifecycle acceptance.
const Isolated = preload("C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal/isolated.gd")
const Stats = preload("res://scripts/stats.gd")
var checks := 0
var fails := 0
var phases := []
var output := "C:/ORY-Cache/qa/crowns-68-followup-Codex-faisal/animation"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print(("PASS " if ok else "FAIL ") + label)

func frames(count: int) -> void:
	for i in count: await process_frame

func phase(model, label: String, expected: String) -> void:
	await frames(2)
	check(model.anim.current_animation == expected, label + " selects " + expected)
	var before: float = model.anim.current_animation_position
	var bone_before: Transform3D = model.skeleton.get_bone_global_pose(0)
	var positions := []
	for frame in 4:
		await create_timer(0.06).timeout
		var finite := true
		var attached := 0
		for node in model.find_children("*", "BoneAttachment3D", true, false):
			attached += 1
			finite = finite and node.global_transform.is_finite()
		for b in model.skeleton.get_bone_count():
			finite = finite and model.skeleton.get_bone_global_pose(b).is_finite()
		check(finite and attached > 0, "%s sample %d bones/attachments finite" % [label, frame])
		positions.append(model.anim.current_animation_position)
		if OS.get_environment("C68_RENDER_SEQUENCE") == "1" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%s-%02d.png" % [label, frame]))
	check(absf(float(positions[-1]) - before) > 0.01, label + " animation time advances")
	phases.append({"phase": label, "expected": expected, "time_before": before, "sample_times": positions,
		"root_bone_pose_changed": not bone_before.is_equal_approx(model.skeleton.get_bone_global_pose(0))})

func _init() -> void:
	if not Isolated.ok("Codex-faisal/characters animation acceptance"):
		quit(2)
		return
	call_deferred("run")

func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await frames(20)
	var deadline := Time.get_ticks_msec() + 120000
	while (not g.main_menu or g.get("menus_warming")) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(g.main_menu != null, "main menu exists")
	g.main_menu._press("play", null)
	g.main_menu._press("to_lobby", null)
	g.main_menu.start()
	await frames(30)
	while is_instance_valid(g.loading_layer) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(g.playing and is_instance_valid(g.player), "real match/player ready")
	check(not is_instance_valid(g.loading_layer), "loading completes")
	var u = g.player
	# Freeze player decisions only; AnimationPlayer and the real match remain live.
	u.set_physics_process(false)
	u.set_process(false)
	u.set_role(Stats.Role.KNIGHT)
	await frames(3)
	u.model.revive()
	u.model.update_locomotion(false)
	await phase(u.model, "01-idle", "Idle")
	u.model.update_locomotion(true)
	await phase(u.model, "02-run", "Running_A")
	u.model.attack()
	await phase(u.model, "03-attack", "1H_Melee_Attack_Slice_Horizontal")
	await create_timer(0.6).timeout
	u.model.update_locomotion(true)
	await phase(u.model, "04-recover-run", "Running_A")
	u._die()
	check(u.dead and u.hearts == 0, "real unit death state")
	await phase(u.model, "05-death", "Death_A")
	u._respawn()
	await frames(4)
	check(not u.dead and u.role == Stats.Role.BASE and u.hearts > 0, "real respawn restores base class/alive")
	u.set_role(Stats.Role.KNIGHT)
	u.model.revive()
	await phase(u.model, "06-respawn-knight", "Idle")
	var result := {"agent": "Codex-faisal/characters", "checks": checks, "failures": fails, "phases": phases,
		"renderer": DisplayServer.get_name(), "rendered_sequence": OS.get_environment("C68_RENDER_SEQUENCE") == "1",
		"limitations": ["Player decisions disabled for deterministic animation exercise; no controller/network acceptance", "Finite transforms and advancing animation clocks do not establish natural deformation or visual quality", "Exact unchanged main pack; not the visual implementation candidate"]}
	FileAccess.open(output.path_join("animation-result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	g.queue_free()
	current_scene = null
	await frames(6)
	print("ANIMATION ACCEPTANCE: %d checks %d failures" % [checks, fails])
	quit(1 if fails else 0)
