# Agent: Codex-faisal3/bugtest. Native inherited-before-fall interact edge, fair AI and read-only witnesses.
extends SceneTree
var app
var failures := 0
var native_events := 0
var input_cache := {}
var avoidance := [Vector3.ZERO]
var avoidance_ticks := [0]
var avoid_side := [1.0]
var qualified_case := false
var down_windows := 0
var held_before_fall := false
var preheld_witness := {}
func _initialize()->void:_run.call_deferred()
func frames(n:int)->void:
	for i in n:
		if FileAccess.file_exists("C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE"):quit(3);return
		await process_frame
func check(ok:bool,label:String)->void:
	print("BUGTEST_CHECK ",JSON.stringify({"agent":"Codex-faisal3/bugtest","label":label,"pass":ok}))
	if not ok:failures+=1
func axis(d:int,a:JoyAxis,v:float)->void:
	var id:="%d/a/%d"%[d,a]
	if input_cache.has(id) and absf(input_cache[id]-v)<.015:return
	input_cache[id]=v;var e:=InputEventJoypadMotion.new();e.device=d;e.axis=a;e.axis_value=v;Input.parse_input_event(e);native_events+=1
func button(d:int,b:JoyButton,v:bool)->void:
	var id:="%d/b/%d"%[d,b]
	if input_cache.get(id,false)==v:return
	input_cache[id]=v;var e:=InputEventJoypadButton.new();e.device=d;e.button_index=b;e.pressed=v;Input.parse_input_event(e);native_events+=1
func neutral()->void:
	for a in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:axis(7,a,0)
	for b in [JOY_BUTTON_A,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_RIGHT_SHOULDER]:button(7,b,false)
func key(code:Key,pressed:bool)->void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;Input.parse_input_event(e);native_events+=1
func tap(d:int,b:JoyButton)->void:
	button(d,b,true);await frames(3);button(d,b,false);await frames(8)
func click(id:String,wanted=null)->bool:
	var point:=Vector2(-1,-1)
	for item in app.hud.menu_buttons:
		if item[1]==id and (wanted==null or item[2]==wanted):point=item[0].get_center();break
	if point.x<0:print("BUGTEST_UNSUPPORTED missing live hit region ",id," ",wanted);return false
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);native_events+=1;await frames(3)
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;Input.parse_input_event(e);native_events+=1;await frames(3)
	await frames(30);return true
func probe(p,dir:Vector3,reach:float)->Dictionary:
	var from:Vector3=p.global_position+Vector3(0,.65,0)
	var q:=PhysicsRayQueryParameters3D.create(from,from+dir*reach,p.collision_mask,[p.get_rid()])
	return p.get_world_3d().direct_space_state.intersect_ray(q)
func steer(p,goal:Vector3)->Vector3:
	# Prior qualified native route policy; only read-only path/collision queries.
	if p.global_position.x*goal.x<0 and absf(p.global_position.x)>57:goal=Vector3(signf(p.global_position.x)*55,0,0)
	elif p.global_position.x*goal.x<0 and absf(p.global_position.x)>45:goal=Vector3(signf(p.global_position.x)*44,0,0)
	var leg:Vector3=app.route_point(p.global_position,goal)
	var delta:=Vector3(leg.x-p.global_position.x,0,leg.z-p.global_position.z)
	if delta.length()<.35:return Vector3.ZERO
	var dir:=delta.normalized()
	if avoidance_ticks[0]>0:avoidance_ticks[0]-=1;return avoidance[0]
	if delta.length()>1.5:
		var reach:=minf(2,delta.length()-.6);var hit:=probe(p,dir,reach)
		if not hit.is_empty():
			var normal:Vector3=hit.normal;normal.y=0;normal=normal.normalized()
			if -normal.dot(dir)>.65:
				var tangent:Vector3=Vector3(-normal.z,0,normal.x)*avoid_side[0]
				for candidate in [(dir*.4+tangent).normalized(),tangent,(dir*.4-tangent).normalized(),-tangent]:
					if probe(p,candidate,reach*.9).is_empty():avoidance[0]=candidate;avoidance_ticks[0]=3;return candidate
				avoid_side[0]=-avoid_side[0]
	return dir*minf(1,delta.length()/1.5)
func state(p,label:String)->Dictionary:
	var finishers:=[]
	for u in app.units:
		if u.team!=p.team and (u.finish_target==p or u.finish_victim==p):finishers.append({"name":u.display_name,"progress":u.finish_progress,"finishing":u.finishing})
	var s:={"agent":"Codex-faisal3/bugtest","label":label,"physics_frame":Engine.get_physics_frames(),"clock":app.match_clock(),"position":str(p.global_position),"spawn_point":str(p.spawn_point),"hearts":p.hearts,"dead":p.dead,"downed":p.downed,"down_elapsed":p.downed_total-p.downed_timer,"down_timer":p.downed_timer,"skip_hold":p.skip_hold,"respawn_timer":p.respawn_timer,"respawn_total":p.respawn_total,"deaths":p.deaths,"level":p.level,"fell_level":p.fell_level,"times_revived":p.times_revived,"revive_progress":p.revive_progress,"executed":p.executed_by!=null,"finishers":finishers,"carrying":p.carrying!=null,"menu":app.menu_open,"tree_paused":paused,"input_held":Input.is_action_pressed(p.act_prefix+"interact")}
	print("BUGTEST_DOWN_STATE ",JSON.stringify(s));return s
func finish(status:String)->void:
	neutral();key(KEY_ESCAPE,false)
	print("BUGTEST_RESULT ",JSON.stringify({"agent":"Codex-faisal3/bugtest","status":status,"qualified_case":qualified_case,"down_windows":down_windows,"failures":failures,"native_events":native_events,"scope":"Actual0963 package; genuine earned-copy profile; native Normal4v4 one-human pad7 menu/pursuit and inherited-before-fall interact hold exclusion; distinct from freshpress/pause case. Normal AI/health/rules/clock; read-only snapshots/path/collision. No forced down, direct gameplay APIs, rendered/hardware/performance/fullmatch acceptance."}))
	quit(0 if failures==0 else 1)
func window(p)->bool:
	down_windows+=1
	for a in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:axis(7,a,0)
	var down:Dictionary=state(p,"natural-down-with-inherited-interact")
	if not held_before_fall or not down.input_held:
		print("BUGTEST_UNSUPPORTED no qualified held-before-fall input");return false
	check(not preheld_witness.is_empty() and not preheld_witness.downed and preheld_witness.hearts>0 and preheld_witness.input_held,"native interact was held while standing before normal enemy down")
	var previous:Dictionary=down
	var max_skip:float=p.skip_hold
	for i in 110:
		if p.dead or not p.downed or p.downed_total-p.downed_timer>=.50:break
		previous=state(p,"inherited-hold-near-trigger") if p.skip_hold>.9 else {"skip_hold":p.skip_hold,"down_elapsed":p.downed_total-p.downed_timer,"executed":p.executed_by!=null}
		await frames(1);max_skip=maxf(max_skip,p.skip_hold)
	var after:Dictionary=state(p,"after-inherited-hold-window")
	var independent:bool=p.downed and not p.dead
	if p.dead:
		independent=previous.down_elapsed<1.99 and not previous.executed and previous.skip_hold>.95 and p.times_revived==down.times_revived
	if not independent:
		print("BUGTEST_UNSUPPORTED external finish/revive cannot attribute inherited hold ",JSON.stringify(previous));return false
	check(p.downed and not p.dead and max_skip==0,"interact held before fall must not accumulate giveup or cause death without a fresh press")
	print("BUGTEST_PREHELD_PROOF ",JSON.stringify({"agent":"Codex-faisal3/bugtest","standing_before":preheld_witness,"down":down,"previous":previous,"after":after,"max_inherited_skip_hold":max_skip,"normal_enemy_grace":2.0,"qualified_cause":independent,"no_release_between":true}))
	if failures>0:return true
	button(7,JOY_BUTTON_RIGHT_SHOULDER,false);await frames(2)
	check(p.downed and not p.dead and p.skip_hold==0 and not p.skip_release_required,"releasing inherited interact clears actual latch without giving up")
	button(7,JOY_BUTTON_RIGHT_SHOULDER,true)
	var pre:Dictionary={}
	for i in 85:
		if p.dead or not p.downed:break
		pre={"skip_hold":p.skip_hold,"down_elapsed":p.downed_total-p.downed_timer,"executed":p.executed_by!=null}
		await frames(1)
	button(7,JOY_BUTTON_RIGHT_SHOULDER,false);state(p,"new-press-after-inherited-release")
	check(p.dead and not p.downed and p.respawn_total==7 and not pre.is_empty() and pre.skip_hold>.95 and pre.down_elapsed<1.99 and not pre.executed,"fresh one-second hold after inherited release intentionally gives up before enemy grace")
	return true
func _run()->void:
	var expected:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bugtest-user-prefix="):expected=arg.trim_prefix("--bugtest-user-prefix=").replace("\\","/")
	var actual:=OS.get_user_data_dir().replace("\\","/");print("BUGTEST_STORAGE ",JSON.stringify({"agent":"Codex-faisal3/bugtest","actual":actual,"expected":expected}))
	if expected.is_empty() or not actual.begins_with(expected+"/"):quit(92);return
	root.size=Vector2i(1280,720);change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await frames(150);app=current_scene
	check(app!=null and not app.playing and app.main_menu.screen=="title","actual earned-copy package starts normal title")
	if failures>0:finish("PRECONDITION");return
	if not await click("play"):finish("INCOMPLETE_MENU");return
	if not await click("difficulty","Normal"):finish("INCOMPLETE_MENU");return
	await tap(7,JOY_BUTTON_DPAD_RIGHT)
	if not await click("split",false):finish("INCOMPLETE_MENU");return
	if not await click("to_lobby"):finish("INCOMPLETE_MENU");return
	if not await click("start"):finish("INCOMPLETE_MENU");return
	await frames(90)
	check(app.playing and app.locals.size()==1 and app.p1_pad_device==7 and app.bot_difficulty=="Normal","native Normal4v4 single-human pad7 ownership")
	if failures>0:finish("PRECONDITION");return
	var p=app.player;var origin:Vector3=p.global_position;var seen_down:=false;var last_hearts:int=p.hearts
	state(p,"native-match-start")
	for tick in 18000:
		if not app.playing or app.game_over:break
		if p.hearts!=last_hearts:state(p,"normal-HP-change");last_hearts=p.hearts
		if not held_before_fall and not p.downed and not p.dead and absf(p.global_position.x)<40:
			held_before_fall=true;button(7,JOY_BUTTON_RIGHT_SHOULDER,true);await frames(1);preheld_witness=state(p,"native-interact-held-standing-before-fall")
		if p.downed and not seen_down:
			seen_down=true;qualified_case=await window(p)
			if qualified_case:break
			neutral()
			if paused:key(KEY_ESCAPE,true);await frames(1);key(KEY_ESCAPE,false)
			if down_windows>=2:break
		if not p.dead and not p.downed:seen_down=false
		if p.dead or p.downed:neutral();await frames(1);continue
		if app.guide_open:key(KEY_ESCAPE,true);await frames(1);key(KEY_ESCAPE,false)
		var target=null;var best:=INF
		for enemy in app.units:
			if enemy.team==p.team or enemy.dead or enemy.downed:continue
			var dist:float=p.global_position.distance_to(enemy.global_position)
			if dist<best:best=dist;target=enemy
		if target!=null:
			var move:Vector3=steer(p,target.global_position)
			axis(7,JOY_AXIS_LEFT_X,move.x);axis(7,JOY_AXIS_LEFT_Y,move.z)
			# Deliberately stop attacking/dodging; damage still comes only from normal AI.
		if tick%300==0:state(p,"normal-native-pursuit")
		await frames(1)
	neutral();check(p.global_position.distance_to(origin)>.5 or down_windows>0,"native pursuit traverses actual collision world")
	finish("COMPLETE" if qualified_case else "INCOMPLETE_NATURAL_WINDOW")
