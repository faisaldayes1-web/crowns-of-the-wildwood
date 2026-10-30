# Agent: Codex-faisal3/bugtest. Original production HUD/menu/legend via queued device0 input.
# No game/progression/clock/focus/handler setters; no rendered or packaged-export claim.
extends SceneTree
var app
var receipt:=""
var prefix:=""
var phase:=""
var prior:=""
var failures:=0
var stopping:=false
var q:={"agent":"Codex-faisal3/bugtest","checks":[],"events":[],"states":[],"regions":[],"legend_samples":[],"completed":false,"rendered":false,"physical_input":false,"packaged_export":false}
func _initialize()->void:_run.call_deferred()
func write_record()->void:
	q.failures=failures
	if not receipt.is_empty():
		var f:=FileAccess.open(receipt,FileAccess.WRITE)
		if f:f.store_string(JSON.stringify(q,"  "))
func check(ok:bool,label:String)->bool:
	q.checks.append({"pass":ok,"label":label});print("BUGTEST_CHECK ",JSON.stringify(q.checks[-1]))
	if not ok:failures+=1
	write_record();return ok
func finish(code:int,reason:String)->void:q.reason=reason;write_record();print("BUGTEST_FAILURE ",reason);quit(code)
func frames(n:int)->void:
	for i in n:
		if stopping:return
		if FileAccess.file_exists("C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE"):
			stopping=true;finish(3,"PAUSE retained");return
		await process_frame
func cfg(path:String)->Dictionary:
	var c:=ConfigFile.new();var err:=c.load(path)
	if err!=OK:return {"load_error":err}
	var d:={}
	for section in c.get_sections():
		d[section]={}
		for key in c.get_section_keys(section):d[section][key]=c.get_value(section,key)
	return d
func equal(a,b)->bool:return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func account()->Dictionary:
	return {"id":app.profile_id,"name":app.hero_name,"xp":app.account_xp,"gold":app.account_gold,"shards":app.account_shards,"chests":app.account_chests,"owned":app.owned_items.duplicate(true),"legend_seen":app.legend_seen,"legend_sides":app.legend_sides.duplicate(),"legend_classes":app.legend_classes.duplicate()}
func snapshot(label:String)->Dictionary:
	var d:={"label":label,"frame":Engine.get_process_frames(),"wall_ms":Time.get_ticks_msec(),"screen":app.main_menu.screen,"overlay":app.main_menu.overlay,"playing":app.playing,"menu_open":app.menu_open,"account":account(),"level":app.account_level(),"legend_unlocked":app.legend_unlocked(),"legend_due":app.legend_due(),"bot_difficulty":app.bot_difficulty,"exit_armed":app.main_menu.exit_armed,"cfg":cfg("user://controls.cfg"),"profile_cfg":cfg("user://profiles/"+str(app.profile_id)+".cfg"),"legend_present":app.legend!=null,"time_scale":Engine.time_scale,"swallow_frame":app.swallow_frame,"lobby_pad_frame":app.lobby_pad_frame,"confirm_block":app.confirm_block,"cursor_shown":app.cursor_shown,"ui_back_pressed":Input.is_action_pressed("ui_back"),"ui_back_just_pressed":Input.is_action_just_pressed("ui_back")}
	if app.legend!=null:
		var at:Array=app.legend.segment();d.legend={"mode":app.legend.mode,"t":app.legend.t,"ff":app.legend.ff,"hold":app.legend.hold,"done":app.legend.done,"pad":app.legend.pad,"segment":app.legend.segs[at[0]][0],"total":app.legend.total(),"segments":app.legend.segs.duplicate(true)}
	q.states.append(d);write_record();return d
func record_event(row:Dictionary)->bool:
	if stopping:return false
	if FileAccess.file_exists("C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE"):
		stopping=true;finish(3,"PAUSE retained before input");return false
	row.sequence=q.events.size()+1;row.frame=Engine.get_process_frames();row.device=0;q.events.append(row);write_record();return true
func tap(code:Key)->void:
	for pressed in [true,false]:
		var e:=InputEventKey.new();e.device=0;e.keycode=code;e.physical_keycode=code;e.pressed=pressed
		if not record_event({"kind":"key","code":int(code),"pressed":pressed}):return
		Input.parse_input_event(e);await frames(4)
	await frames(6)
func pad_tap(button:JoyButton)->void:
	for pressed in [true,false]:
		var e:=InputEventJoypadButton.new();e.device=0;e.button_index=button;e.pressed=pressed
		if not record_event({"kind":"pad","button":int(button),"pressed":pressed}):return
		Input.parse_input_event(e);snapshot("pad "+str(button)+" "+str(pressed)+" immediately after queue")
		for i in 4:
			await frames(1);snapshot("pad "+str(button)+" "+str(pressed)+" laterframe "+str(i))
	await frames(6)
func region(key:String)->Rect2:
	for row in app.hud.menu_buttons:
		if row[1]==key:return row[0]
	return Rect2()
func click(rect:Rect2,label:String)->bool:
	if not check(rect.has_area() and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(rect.get_center()),"actual current HUD input region: "+label):return false
	q.regions.append({"label":label,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]});write_record()
	var point:=rect.get_center();var m:=InputEventMouseMotion.new();m.device=0;m.position=point;m.global_position=point
	if not record_event({"kind":"motion","point":[point.x,point.y]}):return false
	Input.parse_input_event(m);await frames(3)
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.device=0;e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
		if not record_event({"kind":"mouse","pressed":pressed,"point":[point.x,point.y]}):return false
		Input.parse_input_event(e);await frames(4)
	await frames(8);return true
func normal_roll(label:String)->bool:
	if not await click(region("roll_credits"),label):return false
	var s:=snapshot(label)
	return check(s.legend_present and s.legend.mode=="roll" and s.legend.segment=="roll" and s.legend.segments.size()==2 and not s.legend.ff and not s.legend.hold and not s.legend.done and equal(account(),q.initial.account),"normal ROLL CREDITS starts fresh unforced roll without progression mutation: "+label)
func normal_exit()->void:
	await tap(KEY_ESCAPE)
	if not check(app.main_menu.overlay=="" and app.main_menu.screen=="title" and not app.playing,"normal Escape closes final overlay to Title"):finish(1,"final overlay close");return
	if not await click(region("exit"),"first normal EXIT arm"):finish(1,"exit region");return
	if not check(app.main_menu.exit_armed>0.0,"first actual EXIT click only arms confirmation"):finish(1,"exit arm");return
	q.final=snapshot("before production confirmed EXIT");q.completed=failures==0;q.production_quit_requested=true
	write_record();print("BUGTEST_RESULT ",JSON.stringify({"agent":"Codex-faisal3/bugtest","checks":q.checks.size(),"failures":failures,"events":q.events.size(),"states":q.states.size(),"completed":q.completed,"phase":phase,"rendered":false,"production_quit_requested":true}))
	await click(region("exit"),"second normal EXIT confirm")
	await frames(30);q.completed=false;finish(1,"production confirmed EXIT failed to quit")
func _run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bugtest-user-prefix="):prefix=arg.trim_prefix("--bugtest-user-prefix=").replace("\\","/").trim_suffix("/")
		if arg.begins_with("--bugtest-receipt="):receipt=arg.trim_prefix("--bugtest-receipt=")
		if arg.begins_with("--bugtest-phase="):phase=arg.trim_prefix("--bugtest-phase=")
		if arg.begins_with("--bugtest-prior="):prior=arg.trim_prefix("--bugtest-prior=")
	q.phase=phase;var actual:=OS.get_user_data_dir().replace("\\","/");q.storage={"actual":actual,"controls":ProjectSettings.globalize_path("user://controls.cfg")};q.pre_main=cfg("user://controls.cfg");write_record()
	if not check(phase in ["cycle","reload"] and not prefix.is_empty() and actual.begins_with(prefix+"/") and q.storage.controls.replace("\\","/")==actual+"/controls.cfg","actual private source-runtime userData before main/input"):finish(92,"storage");return
	if not check(DisplayServer.get_name()=="headless" and Engine.time_scale==1.0,"headless normal time: rendered/physical/audio explicitly unsupported"):finish(92,"platform");return
	root.size=Vector2i(1280,720);change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await frames(5);app=current_scene
	var deadline:=Time.get_ticks_msec()+120000
	while app!=null and (app.main_menu==null or app.menus_warming or is_instance_valid(app.loading_layer)):
		if Time.get_ticks_msec()>deadline:finish(92,"normal startup deadline");return
		await frames(1)
	await frames(5)
	if not check(app!=null and app.main_menu.screen=="title" and not app.playing and not app.menu_open and not app.name_editing and app.legend==null,"normal Title ready under unchanged source headless first-name rule"):finish(1,"startup");return
	q.initial=snapshot("initial "+phase)
	if not check(q.pre_main.has("load_error") and app.account_level()==1 and app.account_xp==0 and not app.legend_seen,"diagnostic fresh unseeded level1 before any input"):finish(1,"fresh");return
	if not await click(region("credits"),"normal CREDITS only diagnostic"):finish(1,"credits");return
	if not check(app.main_menu.overlay=="credits","diagnostic opens credits through production pointer"):finish(1,"credits state");return
	if not await normal_roll("diagnostic fresh roll"):finish(1,"roll");return
	await pad_tap(JOY_BUTTON_A)
	if not check(app.legend!=null and app.legend.segs[app.legend.segment()[0]][0]=="thanks","diagnostic normal pad A advances to thanks"):finish(1,"padA");return
	snapshot("before closing thanks with B")
	await pad_tap(JOY_BUTTON_B)
	var after:=snapshot("after closing thanks with B")
	q.expected_contract_pass=app.legend==null and app.main_menu.overlay=="credits" and equal(account(),q.initial.account) and not app.playing
	q.source_defect_reproduced=app.legend==null and app.main_menu.overlay=="" and equal(account(),q.initial.account) and not app.playing
	q.observation=after;write_record()
	if not check(q.expected_contract_pass or q.source_defect_reproduced,"diagnostic conclusively classifies pad-close state without bypass"):finish(1,"unclassified");return
	await normal_exit()
