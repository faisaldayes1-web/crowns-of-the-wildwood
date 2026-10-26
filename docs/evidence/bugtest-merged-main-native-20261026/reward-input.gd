# Agent: Codex-faisal3/bugtest. Native UI loot/profile check, no seeded rewards.
extends SceneTree
var app
var failures := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		if FileAccess.file_exists("C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE"):
			print("BUGTEST_PAUSED local stop file retained");quit(3);return
		await process_frame
func check(ok: bool,label: String) -> void:
	print("BUGTEST_CHECK ",JSON.stringify({"label":label,"pass":ok}))
	if not ok: failures += 1
func wallet() -> Dictionary:
	return {"xp":app.account_xp,"gold":app.account_gold,"shards":app.account_shards,"chests":app.account_chests,"owned":app.owned_items}
func click(id: String) -> bool:
	var point := Vector2(-1,-1)
	for item in app.hud.menu_buttons:
		if item[1] == id: point = item[0].get_center(); break
	if point.x < 0:
		print("BUGTEST_UNSUPPORTED missing native hit region ",id)
		return false
	var motion := InputEventMouseMotion.new()
	motion.position = point;motion.global_position = point
	Input.parse_input_event(motion);await frames(3)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT;event.position = point;event.global_position = point;event.pressed = pressed
		Input.parse_input_event(event);await frames(3)
	await frames(30)
	print("BUGTEST_INPUT native mouse ",id)
	return true
func _run() -> void:
	root.size = Vector2i(1280,720)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(150)
	app = current_scene
	check(app != null and app.main_menu.screen == "title","normal package title loads saved profile")
	var cfg := ConfigFile.new()
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected-profile="): expected = arg.trim_prefix("--expected-profile=")
	if expected == "" or cfg.load(expected) != OK: quit(1);return
	check(app.account_xp == cfg.get_value("profile","account_xp",-1) and app.account_gold == cfg.get_value("profile","account_gold",-1) and app.account_shards == cfg.get_value("profile","account_shards",-1),"native restart retains earned XP gold and shards")
	check(app.account_chests == cfg.get_value("profile","account_chests",-1) and app.owned_items == cfg.get_value("profile","owned_items",null),"native restart retains exact chest count and collection")
	print("BUGTEST_WALLET ",JSON.stringify({"phase":"loaded","wallet":wallet()}))
	if "--bugtest-reward-restart" in OS.get_cmdline_user_args():
		if not await click("store"): quit(92);return
		check(app.main_menu.screen == "store" and app.account_chests == 0 and not app.owned_items.is_empty(),"restarted native store retains consumed chest and earned item")
		print("BUGTEST_RESULT ",JSON.stringify({"failures":failures,"scope":"Separate-process native earned reward and opened chest persistence"}))
		quit(0 if failures == 0 else 1);return
	check(app.account_chests == 1 and app.account_xp > 0,"normal completed match actually earned one chest and XP")
	if not await click("store"): quit(92);return
	check(app.main_menu.screen == "store","native title Store opens actual store")
	var old_count: int = app.account_chests
	var old_owned: Array = app.owned_items.duplicate(true)
	if not await click("store_chest"): quit(92);return
	check(app.account_chests == old_count - 1 and app.owned_items.size() == old_owned.size() + 1,"native OPEN consumes earned chest and grants one unowned item")
	print("BUGTEST_WALLET ",JSON.stringify({"phase":"opened","wallet":wallet(),"reveal":app.main_menu.store.reveal}))
	# Reveal dismissal uses real Time ticks in production, so observe real time.
	var until: int = Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < until: await frames(1)
	if not await click("store_reveal_close"): quit(92);return
	check(app.main_menu.store.reveal.is_empty(),"native click dismisses actual timed chest reveal")
	if not await click("back"): quit(92);return
	check(app.main_menu.screen == "title","native Back returns from store to title")
	print("BUGTEST_RESULT ",JSON.stringify({"failures":failures,"scope":"Native store opens real match-earned chest; timed reveal/back; no reward/state injection or direct store APIs; headless only"}))
	quit(0 if failures == 0 else 1)
