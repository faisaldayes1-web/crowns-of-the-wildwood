# Agent: Codex-faisal3/bugtest. Separate actual profile restart; observations only.
extends SceneTree
var failures:=0
func check(ok: bool,label: String) -> void:
	print("BUGTEST_CHECK ",JSON.stringify({"agent":"Codex-faisal3/bugtest","label":label,"pass":ok}))
	if not ok:failures+=1
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var expected_path: String="";var prefix: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected-wallet="):expected_path=arg.trim_prefix("--expected-wallet=")
		if arg.begins_with("--bugtest-user-prefix="):prefix=arg.trim_prefix("--bugtest-user-prefix=").replace("\\","/")
	var actual: String=OS.get_user_data_dir().replace("\\","/")
	if prefix.is_empty() or not actual.begins_with(prefix+"/"):quit(92);return
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	root.size=Vector2i(1280,720);change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	var end: int=Time.get_ticks_msec()+180000
	while Time.get_ticks_msec()<end:
		if FileAccess.file_exists("C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE"):quit(3);return
		await process_frame
		if is_instance_valid(current_scene) and current_scene.main_menu!=null and not current_scene.menus_warming and not is_instance_valid(current_scene.loading_layer):break
	var app=current_scene
	check(app!=null and app.main_menu.screen=="title" and not app.playing,"separate process starts actual normal title")
	check(app.account_xp==expected.xp and app.account_gold==expected.gold,"separate process preserves exact naturally earned XP and gold")
	check(app.account_shards==expected.shards and app.account_chests==expected.chests,"separate process preserves exact earned shards and chest")
	check(not app.game_over and app.summary==null,"separate title has no stale match/result state")
	check(app.bot_difficulty=="Normal" and is_equal_approx(Engine.time_scale,1.0),"Normal difficulty and unmodified engine scale persist")
	print("BUGTEST_FOUR_WALLET ",JSON.stringify({"agent":"Codex-faisal3/bugtest","actual_user_path":actual,"phase":"restart","wallet":{"xp":app.account_xp,"gold":app.account_gold,"shards":app.account_shards,"chests":app.account_chests}}))
	print("BUGTEST_RESULT ",JSON.stringify({"agent":"Codex-faisal3/bugtest","failures":failures,"scope":"Separate-process actual naturally earned profile restart, no save or game writes/rendered claim"}))
	quit(0 if failures==0 else 1)
