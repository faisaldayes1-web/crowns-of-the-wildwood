# Agent: Codex-faisal3/bugtest. Package-native mouse/key bot; no menu calls/forced layout.
extends SceneTree
var app
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func frames(count: int) -> void:
	for i in count:
		if FileAccess.file_exists("C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE"):
			print("BUGTEST_PAUSED local stop file retained");quit(3);return
		await process_frame
func check(ok: bool,label: String) -> void:
	print("BUGTEST_CHECK ",JSON.stringify({"label":label,"pass":ok}))
	if not ok: failures += 1
func snapshot(label: String) -> void:
	var buttons := []
	if app.hud != null:
		for item in app.hud.menu_buttons:
			buttons.append({"id":item[1],"rect":str(item[0]),"arg":str(item[2])})
	print("BUGTEST_STATE ",JSON.stringify({"label":label,"display":DisplayServer.get_name(),"screen":app.main_menu.screen,"overlay":app.main_menu.overlay,"playing":app.playing,"buttons":buttons}))
func click(id: String,arg_filter=null) -> bool:
	var point := Vector2(-1,-1)
	for item in app.hud.menu_buttons:
		if item[1] == id and (arg_filter==null or item[2]==arg_filter):
			point = item[0].get_center()
			break
	if point.x < 0:
		print("BUGTEST_UNSUPPORTED missing live hit region ",id)
		return false
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await frames(3)
	var down := InputEventMouseButton.new()
	down.position = point
	down.global_position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await frames(3)
	var up := InputEventMouseButton.new()
	up.position = point
	up.global_position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	await frames(30)
	print("BUGTEST_INPUT mouse ",id," at ",point)
	return true
func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
# Agent: Codex-faisal3/bugtest. Native queued pad events; state/positions observed read-only.
func pad_button(device: int, button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)
	print("BUGTEST_INPUT pad-button ",device," ",button," ",pressed)
func pad_tap(device: int, button: JoyButton) -> void:
	pad_button(device,button,true);await frames(3)
	pad_button(device,button,false);await frames(8)
func stick(device: int,value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = value
	Input.parse_input_event(ev)
	print("BUGTEST_INPUT pad-axis ",device," ",value)
func positions() -> Array:
	return app.locals.map(func(u): return u.global_position)
func movement(before: Array,label: String) -> Array:
	var out := []
	for k in app.locals.size():out.append(app.locals[k].global_position.distance_to(before[k]))
	print("BUGTEST_MOVEMENT ",JSON.stringify({"label":label,"meters":out,"positions":str(positions()),"prep":app.prep_left}))
	return out
# Agent: Codex-faisal3/bugtest. Normal native four-pad objective play; no gameplay writes.
var devices := [7,0,1,2]
var human_hits := [[false,false,false,false],[false,false,false,false],[false,false,false,false],[false,false,false,false]]
var barricade_plans := 0
var input_cache := {}
var input_events := 0
var travelled := [0.0,0.0,0.0,0.0]
var class_seen := [false,false,false,false]
var carry_seen := [false,false,false,false]
var down_seen := [false,false,false,false]
var death_seen := [false,false,false,false]
var recovered := [false,false,false,false]
func axis(device: int,which: JoyAxis,value: float) -> void:
	var code := "%d/a/%d"%[device,which]
	if input_cache.has(code) and absf(input_cache[code]-value)<0.015:return
	input_cache[code]=value
	var ev := InputEventJoypadMotion.new();ev.device=device;ev.axis=which;ev.axis_value=value
	Input.parse_input_event(ev);input_events+=1
func button(device: int,which: JoyButton,value: bool) -> void:
	var code := "%d/b/%d"%[device,which]
	if input_cache.get(code,false)==value:return
	input_cache[code]=value
	var ev := InputEventJoypadButton.new();ev.device=device;ev.button_index=which;ev.pressed=value
	Input.parse_input_event(ev);input_events+=1
func neutral(device: int) -> void:
	for a in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:axis(device,a,0.0)
	for b in [JOY_BUTTON_A,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_RIGHT_SHOULDER]:button(device,b,false)
func flat(a: Vector3,b: Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()
func wallet() -> Dictionary:return {"xp":app.account_xp,"gold":app.account_gold,"shards":app.account_shards,"chests":app.account_chests}
func native_key_tap(k: Key) -> void:key(k,true);await frames(3);key(k,false);await frames(8)
func join_normal() -> bool:
	if not await click("play"):return false
	await pad_tap(7,JOY_BUTTON_DPAD_RIGHT)
	check(app.main_menu.p1_pad==7,"normal menu assigns player1 to pad7")
	if not await click("split",true):return false
	if not await click("to_lobby"):return false
	check(app.main_menu.screen=="lobby","normal map opens split lobby")
	for d in [0,1,2]:
		if not app.main_menu.join_pads.has(d):await pad_tap(d,JOY_BUTTON_A)
		var local_slot: int=app.main_menu.join_pads.find(d)+1
		check(local_slot>0 and app.couch_players>=local_slot+1,"pad%d owns normal joined slot"%d)
		var expected_side: int=local_slot%2
		await pad_tap(d,JOY_BUTTON_DPAD_RIGHT if expected_side==1 else JOY_BUTTON_DPAD_LEFT)
		check(app.lobby_sides[local_slot]==expected_side,"pad%d chooses alternating versus team through native input"%d)
		if not app.main_menu.readied[local_slot]:await pad_tap(d,JOY_BUTTON_A)
		check(app.main_menu.readied[local_slot],"pad%d readies normal slot"%d)
	check(app.main_menu.join_pads==[0,1,2],"normal lobby preserves exact joined-pad order")
	if not await click("start"):return false
	await frames(120)
	check(app.playing and app.couch_active and app.locals.size()==4 and app.panes.size()==4,"actual match creates four local actors and panes")
	check(app.bound_pads==devices,"actual match retains all four controller ownership bindings")
	check(app.local_sides==[0,1,0,1],"normal lobby creates two human players per opposing team")
	for t in 2:
		check(app.units.filter(func(u):return u.team==t and u.is_player).size()==2 and app.units.filter(func(u):return u.team==t and not u.is_player).size()==2,"team%d has two humans and two ordinary fill bots"%t)
	return app.playing and app.locals.size()==4
# Read-only dynamic collision geometry; movement/attacks remain native input.
func obstacle_plan(p,leg: Vector3) -> Dictionary:
	var best=null;var reach:=5.0
	for b in app.barricades:
		if not b.is_intact() or absf(p.global_position.y-b.global_position.y)>1.5:continue
		var half: Vector3=b.shape.shape.size*0.5
		var a: Vector3=b.to_local(p.global_position);a.y=0.6
		var z: Vector3=b.to_local(leg);z.y=0.6
		var box:=AABB(Vector3(-half.x-0.55,0,-half.z-0.55),Vector3(half.x*2+1.1,1.5,half.z*2+1.1))
		var distance: float=flat(p.global_position,b.global_position)
		if distance<reach and (box.has_point(a) or box.intersects_segment(a,z)!=null):best=b;reach=distance
	if best==null:return {"leg":leg,"target":null}
	barricade_plans+=1
	if best.team!=p.team:return {"leg":best.global_position,"target":best}
	var half: Vector3=best.shape.shape.size*0.5
	var left: Vector3=best.to_global(Vector3(-half.x-1.6,0,0))
	var right: Vector3=best.to_global(Vector3(half.x+1.6,0,0))
	var detour: Vector3=left if flat(p.global_position,left)+flat(left,leg)<flat(p.global_position,right)+flat(right,leg) else right
	return {"leg":detour,"target":null}
func rows(label: String) -> void:
	var players := []
	for k in app.locals.size():
		var p=app.locals[k]
		players.append({"slot":k,"device":devices[k],"position":str(p.global_position),"team":p.team,"role":p.role,"hearts":p.hearts,"damage":p.damage_dealt,"kills":p.kills,"deaths":p.deaths,"dead":p.dead,"downed":p.downed,"caps":p.captures,"carrying":p.carrying!=null,"travelled":travelled[k]})
	print("BUGTEST_FOUR_MATCH ",JSON.stringify({"label":label,"clock":app.match_clock(),"time_left":app.time_left,"score":app.score,"game_over":app.game_over,"gate_hp":[app.gates[0].hp,app.gates[1].hp],"vault_hp":[app.vaults[0].hp,app.vaults[1].hp],"players":players,"native_events":input_events,"human_hits":human_hits,"barricade_plans":barricade_plans}))
func _run() -> void:
	root.size=Vector2i(1280,720)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await frames(150);app=current_scene
	check(app!=null and app.main_menu!=null and app.hud!=null,"normal packaged menu objects loaded")
	if app==null:quit(1);return
	var before_wallet:=wallet()
	print("BUGTEST_FOUR_WALLET ",JSON.stringify({"phase":"before","wallet":before_wallet,"actual_user_path":OS.get_user_data_dir()}))
	if not await join_normal():quit(92);return
	for i in 1800:
		if app.prep_left<=0:break
		await frames(1)
	check(app.prep_left<=0,"natural fortify phase finishes without prep/time override")
	var previous:=positions();var probes:=positions();var phases:= ["","","",""];var sidesteps:= [0,0,0,0];var side_sign:= [1,-1,1,-1]
	# Fixed60 engine simulation, ordinary production AI/rules. Planning reads
	# route_point and positions; only queued native pad events move or fight.
	for tick in 3600:
		if app.game_over or not app.playing:break
		if app.guide_open:await native_key_tap(KEY_ESCAPE)
		var commands := []
		for k in 4:
			var p=app.locals[k];var d: int=devices[k];var enemy: int=1-p.team
			if p.downed:down_seen[k]=true
			if p.dead:death_seen[k]=true
			if (down_seen[k] or death_seen[k]) and not p.dead and not p.downed and p.hearts>0:recovered[k]=true
			if p.role==1:class_seen[k]=true
			if p.carrying!=null:carry_seen[k]=true
			if p.dead or p.downed:
				neutral(d);continue
			var goal: Vector3;var phase: String
			if p.role==0:goal=app.seals[p.team][1].global_position;phase="class station"
			elif p.carrying!=null:goal=app.thrones[p.team];phase="carry home"
			elif tick<240:goal=Vector3(-0.5 if p.team==0 else 0.5,0,-0.6 if k<2 else 0.6);phase="midfield versus encounter"
			elif app.gates[enemy].hp>0:goal=app.gates[enemy].global_position;goal.y=0;phase="enemy gate"
			elif app.vaults[enemy].hp>0:goal=app.vaults[enemy].lock_pos;phase="enemy vault"
			else:
				goal=app.monarchs[enemy].global_position
				phase="crown pickup" if app.monarchs[enemy].carrier==null else "escort ally carrier"
			if phases[k]!=phase:
				phases[k]=phase;print("BUGTEST_FOUR_PHASE ",JSON.stringify({"slot":k,"phase":phase,"pos":str(p.global_position),"goal":str(goal),"clock":app.match_clock()}))
			var dist: float=flat(p.global_position,goal)
			var leg: Vector3=app.route_point(p.global_position,goal)
			var obstacle:=obstacle_plan(p,leg);leg=obstacle.leg
			var direction:=Vector2(leg.x-p.global_position.x,leg.z-p.global_position.z).normalized()
			var movement: Vector2=direction*minf(0.9,dist/2.0) if dist>1.25 else Vector2.ZERO
			var aim: Vector2=direction;var attack: bool=(phase=="enemy gate" or phase=="enemy vault") and dist<3.3
			if obstacle.target!=null:
				var b=obstacle.target;aim=Vector2(b.global_position.x-p.global_position.x,b.global_position.z-p.global_position.z).normalized();attack=flat(p.global_position,b.global_position)<3.5
			var closest=null;var near:=2.8
			if p.carrying==null and p.role!=0:
				for foe in app.units:
					if foe.team==p.team or foe.dead or foe.downed:continue
					var distance: float=flat(p.global_position,foe.global_position)
					if distance<near:closest=foe;near=distance
			if closest!=null:
				aim=Vector2(closest.global_position.x-p.global_position.x,closest.global_position.z-p.global_position.z).normalized();attack=true
			if tick%12==0:
				if p.global_position.distance_to(probes[k])<0.35 and dist>2.0:sidesteps[k]=5;side_sign[k]=-side_sign[k]
				probes[k]=p.global_position
			if sidesteps[k]>0:
				movement=(movement+Vector2(-direction.y,direction.x)*float(side_sign[k])*0.8).limit_length(1.0);sidesteps[k]-=1
			axis(d,JOY_AXIS_LEFT_X,movement.x);axis(d,JOY_AXIS_LEFT_Y,movement.y);axis(d,JOY_AXIS_RIGHT_X,aim.x);axis(d,JOY_AXIS_RIGHT_Y,aim.y)
			button(d,JOY_BUTTON_A,attack and p.carrying==null)
			button(d,JOY_BUTTON_RIGHT_SHOULDER,(phase=="class station" or phase=="crown pickup") and dist<1.65 and tick%4==0)
			button(d,JOY_BUTTON_X,closest!=null and tick%24==0);button(d,JOY_BUTTON_Y,closest!=null and tick%24==12)
			commands.append({"slot":k,"left":[movement.x,movement.y],"right":[aim.x,aim.y],"attack":attack,"phase":phase})
		await frames(15)
		for k in 4:travelled[k]+=app.locals[k].global_position.distance_to(previous[k]);previous[k]=app.locals[k].global_position
		for victim in 4:
			for attacker in 4:
				if victim!=attacker and app.locals[victim].recent_hitters.has(app.locals[attacker]):human_hits[attacker][victim]=true
		if tick%40==0:rows("normal objective "+str(tick));print("BUGTEST_NATIVE_BATCH ",JSON.stringify(commands))
	for d in devices:neutral(d)
	await frames(3);rows("natural match route ended")
	check(app.bound_pads==devices and app.locals.size()==4 and app.panes.size()==4,"all four actor/controller/pane bindings survive full normal route")
	check(app.local_sides==[0,1,0,1] and app.locals.map(func(p):return p.team)==[0,1,0,1],"opposing team assignments survive actual combat and respawns")
	var opposing_hits:=0;var friendly_hits:=0
	for a in 4:
		for v in 4:
			if human_hits[a][v]:
				if app.locals[a].team==app.locals[v].team:friendly_hits+=1
				else:opposing_hits+=1
	check(friendly_hits==0,"observed native combat never credits friendly local-player hits")
	if opposing_hits>0:check(true,"opposing human controllers damage actual opposing human actors")
	else:print("BUGTEST_UNSUPPORTED opposing human hit credit not observed")
	for k in 4:
		check(travelled[k]>10.0,"player%d travels through actual collision world via owned native pad"%(k+1))
		if class_seen[k]:check(true,"player%d takes actual Knight hat via native RB"%(k+1))
		else:print("BUGTEST_UNSUPPORTED player%d class pickup not qualified"%(k+1))
		if carry_seen[k]:check(true,"player%d naturally picks up enemy crown"%(k+1))
		if app.locals[k].captures>0:check(true,"player%d naturally carries crown home"%(k+1))
		if recovered[k]:check(true,"player%d naturally recovers after down/death"%(k+1))
		if app.locals[k].damage_dealt>0:check(true,"player%d native attacks damage actual enemies"%(k+1))
		else:print("BUGTEST_UNSUPPORTED player%d enemy damage not qualified"%(k+1))
		if not carry_seen[k]:print("BUGTEST_UNSUPPORTED player%d crown pickup not qualified"%(k+1))
		if app.locals[k].captures==0:print("BUGTEST_UNSUPPORTED player%d crown capture not qualified"%(k+1))
	if not app.game_over:
		print("BUGTEST_UNSUPPORTED no natural full match result in bounded900simsecond route")
		print("BUGTEST_RESULT ",JSON.stringify({"failures":failures,"full_match":false,"scope":"Partial fourpad native objective attempt only"}));quit(92 if failures==0 else 1);return
	check(not app.playing and app.summary!=null,"normal full match produces actual result summary")
	var earned:=wallet();print("BUGTEST_FOUR_WALLET ",JSON.stringify({"phase":"earned","wallet":earned,"gain":app.last_match_gain,"reward_gold":app.summary.reward_gold,"reward_shards":app.summary.reward_shards,"winner":app.winner_team,"score":app.score}))
	check(earned.xp==before_wallet.xp+app.last_match_gain and earned.gold==before_wallet.gold+app.summary.reward_gold and earned.shards==before_wallet.shards+app.summary.reward_shards and earned.chests==before_wallet.chests+1,"actual match banks exact XP/rewards and one chest on primary account")
	var old_scene: int=app.get_instance_id()
	await native_key_tap(KEY_R);await frames(8)
	check(app.summary.done(),"normal result R skips actual tally")
	await native_key_tap(KEY_R);await frames(150);app=current_scene
	check(app!=null and app.get_instance_id()!=old_scene and not app.playing and not app.game_over and app.main_menu.screen=="title","normal second result R reloads actual title scene")
	check(wallet()==earned,"normal scene reload retains exact earned account wallet")
	if not await join_normal():quit(92);return
	check(app.prep_left>0 and app.score==[0,0],"normal fourpad rematch starts fresh fortify clock and score")
	check(wallet()==earned,"starting another normal round grants no duplicate match reward")
	print("BUGTEST_RESULT ",JSON.stringify({"failures":failures,"full_match":true,"native_events":input_events,"scope":"Actual unchanged main Windows package, four virtual native pads7/0/1/2, two humans plus two ordinary bots per team, normal mouse lobby, natural fortify/objective/outcome/rewards, native R tally/title/rejoin/rematch start. Read-only navigation/state planning. No direct game/menu/prep/outcome APIs or property writes; no physical/rendered/performance claim. Second round start only, no forced outcome/reward."}))
	quit(0 if failures==0 else 1)
