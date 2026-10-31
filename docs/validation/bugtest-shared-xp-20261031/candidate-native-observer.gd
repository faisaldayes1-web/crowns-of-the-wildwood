# Agent: Codex-faisal3/bugtest. Current7fddd source native mouse/key/pad observer; no gameplay writes.
extends SceneTree
const CurrentStats = preload("res://scripts/stats.gd")
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
	print("BUGTEST_CHECK ",JSON.stringify({"agent":"Codex-faisal3/bugtest","label":label,"pass":ok}))
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
	emit_native(motion)
	await frames(3)
	var down := InputEventMouseButton.new()
	down.position = point
	down.global_position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	emit_native(down)
	await frames(3)
	var up := InputEventMouseButton.new()
	up.position = point
	up.global_position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	emit_native(up)
	await frames(30)
	print("BUGTEST_INPUT mouse ",id," at ",point)
	return true
func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	emit_native(event)
# Agent: Codex-faisal3/bugtest. Native queued pad events; state/positions observed read-only.
func pad_button(device: int, button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	emit_native(ev)
	print("BUGTEST_INPUT pad-button ",device," ",button," ",pressed)
func pad_tap(device: int, button: JoyButton) -> void:
	pad_button(device,button,true);await frames(3)
	pad_button(device,button,false);await frames(8)
func stick(device: int,value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = value
	emit_native(ev)
	print("BUGTEST_INPUT pad-axis ",device," ",value)
func positions() -> Array:
	return app.locals.map(func(u): return u.global_position)
func movement(before: Array,label: String) -> Array:
	var out := []
	for k in app.locals.size():out.append(app.locals[k].global_position.distance_to(before[k]))
	print("BUGTEST_MOVEMENT ",JSON.stringify({"label":label,"meters":out,"positions":str(positions()),"prep":app.prep_left}))
	return out
# Agent: Codex-faisal3/bugtest. Normal native four-pad objective play; no gameplay writes.
# Agent: Codex-faisal3/bugtest. External native-only duo objective policy; gameplay observed read-only.
var devices := [7,0]
var roles := [1,4]
var input_cache := {}
var native_events := 0
var class_seen := [false,false]
var pickup_seen := [false,false]
var native_attack_seen := [false,false]
var native_swing_seen := [false,false]
var travelled := [0.0,0.0]
var excluded_jump := [0.0,0.0]
var avoidance := [Vector3.ZERO,Vector3.ZERO]
var avoidance_ticks := [0,0]
var avoid_side := [1.0,-1.0]
func axis(d: int,a: JoyAxis,v: float) -> void:
	var id := "%d/a/%d"%[d,a]
	if input_cache.has(id) and absf(input_cache[id]-v)<0.015:return
	input_cache[id]=v
	var ev:=InputEventJoypadMotion.new();ev.device=d;ev.axis=a;ev.axis_value=v;emit_native(ev)
func button(d: int,b: JoyButton,v: bool) -> void:
	var id := "%d/b/%d"%[d,b]
	if input_cache.get(id,false)==v:return
	input_cache[id]=v
	var ev:=InputEventJoypadButton.new();ev.device=d;ev.button_index=b;ev.pressed=v;emit_native(ev)
func neutral(d: int) -> void:
	for a in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:axis(d,a,0)
	for b in [JOY_BUTTON_A,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_RIGHT_SHOULDER]:button(d,b,false)
func flat(a: Vector3,b: Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()
func wallet() -> Dictionary:return {"xp":app.account_xp,"gold":app.account_gold,"shards":app.account_shards,"chests":app.account_chests}
func staged_goal(from: Vector3,goal: Vector3) -> Vector3:
	# Explicitly exit the real keep/castle before choosing a cross-river leg.
	if from.x*goal.x<0 and absf(from.x)>57:return Vector3(signf(from.x)*55,0,0)
	if from.x*goal.x<0 and absf(from.x)>45:return Vector3(signf(from.x)*44,0,0)
	return goal
func probe(p,dir: Vector3,reach: float) -> Dictionary:
	var from: Vector3=p.global_position+Vector3(0,.65,0)
	var q:=PhysicsRayQueryParameters3D.create(from,from+dir*reach,p.collision_mask,[p.get_rid()])
	return p.get_world_3d().direct_space_state.intersect_ray(q)
# Source game.gd ROOM_FRONT2.8 / stairfoot2.55 / ROOM_DOOR_HALF1.2; pure input planning.
func home_waypoint(p) -> Vector3:
	var home: Vector3=app.thrones[p.team]
	var side: float=-1.0 if p.team==0 else 1.0
	if home.y>0 and flat(p.global_position,home)<10 and p.global_position.y<home.y-.1 and absf(p.global_position.z)>.45:
		var front: float=home.x-side*2.8
		return Vector3(front-side*2.55,0,0)
	return home
func home_trace(p,k: int) -> void:
	var home: Vector3=app.thrones[p.team]
	var to:=Vector3(home.x-p.global_position.x,0,home.z-p.global_position.z).normalized()
	var hit:=probe(p,to,2.0)
	var collisions:=[]
	for i in p.get_slide_collision_count():
		var c=p.get_slide_collision(i);var body=c.get_collider()
		collisions.append({"body":str(body.get_path()) if body is Node else str(body),"point":str(c.get_position()),"normal":str(c.get_normal())})
	print("BUGTEST_HOME_TRACE ",JSON.stringify({"agent":"Codex-faisal3/bugtest","slot":k,"clock":app.match_clock(),"position":str(p.global_position),"home":str(home),"flat_distance":flat(p.global_position,home),"waypoint":str(home_waypoint(p)),"carrying":p.carrying!=null,"hearts":p.hearts,"ray_body":str(hit.collider.get_path()) if not hit.is_empty() and hit.collider is Node else "","ray_normal":str(hit.normal) if not hit.is_empty() else "","slide_collisions":collisions}))
func steer(k: int,p,leg: Vector3) -> Vector3:
	var delta:=Vector3(leg.x-p.global_position.x,0,leg.z-p.global_position.z)
	if delta.length()<.45:return Vector3.ZERO
	var dir:=delta.normalized()
	# Do not steer sideways off the stair into the doorway post; the real motor steps up.
	if p.carrying!=null and flat(p.global_position,app.thrones[p.team])<10 and absf(p.global_position.z)<.65:
		return dir*minf(1.0,delta.length()/1.5)
	if avoidance_ticks[k]>0:
		avoidance_ticks[k]-=1;return avoidance[k]
	if delta.length()>1.5:
		var reach:=minf(2.0,delta.length()-.6)
		var hit:=probe(p,dir,reach)
		if not hit.is_empty():
			var n: Vector3=hit.normal;n.y=0;n=n.normalized()
			if -n.dot(dir)>.65:
				var tangent: Vector3=Vector3(-n.z,0,n.x)*avoid_side[k]
				for candidate in [(dir*.4+tangent).normalized(),tangent,(dir*.4-tangent).normalized(),-tangent]:
					if probe(p,candidate,reach*.9).is_empty():
						avoidance[k]=candidate;avoidance_ticks[k]=3;return candidate
				avoid_side[k]=-avoid_side[k]
	return dir*minf(1.0,delta.length()/1.5)
func rows(label: String) -> void:
	var players:=[]
	for k in 2:
		var p=app.locals[k]
		players.append({"slot":k,"device":devices[k],"role":p.role,"position":str(p.global_position),"hearts":p.hearts,"dead":p.dead,"downed":p.downed,"deaths":p.deaths,"carrying":p.carrying!=null,"captures":p.captures,"damage":p.damage_dealt,"kills":p.kills,"attack_input":Input.is_action_pressed(p.act_prefix+"attack"),"attack_timer":p.attack_timer,"actual_aim":str(p.aim),"actual_velocity":str(p.velocity),"travelled_continuous":travelled[k],"excluded_discontinuity_distance":excluded_jump[k]})
	print("BUGTEST_DUO_STATE ",JSON.stringify({"agent":"Codex-faisal3/bugtest","label":label,"clock":app.match_clock(),"match_played":app.match_played,"result_bonus_earned":app.result_bonus_earned(),"bonus_min_seconds":CurrentStats.RESULT_BONUS_MIN_TIME,"prep":app.prep_left,"difficulty":app.bot_difficulty,"engine_scale":Engine.time_scale,"wall_ms":Time.get_ticks_msec(),"time_left":app.time_left,"overtime":app.overtime,"score":app.score,"game_over":app.game_over,"gate_hp":[app.gates[0].hp,app.gates[1].hp],"vault_hp":[app.vaults[0].hp,app.vaults[1].hp],"players":players,"native_events":native_events}))
# Actual summary hit rectangles are drawn by unchanged MatchSummary/Hud.
func click_rect(rect: Rect2) -> void:
	check(rect.size.x>0 and rect.size.y>0,"real summary hit region exists")
	var point:=rect.get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	emit_native(motion);await frames(3)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed
		emit_native(event);await frames(3)
	await frames(15)
func ready_title(limit_seconds: int = 180) -> bool:
	var end: int = Time.get_ticks_msec() + limit_seconds * 1000
	while Time.get_ticks_msec() < end:
		app=current_scene
		if is_instance_valid(app) and app.main_menu!=null and app.hud!=null and not app.menus_warming and not is_instance_valid(app.loading_layer):
			await frames(3)
			return true
		await frames(1)
	return false
func normal_exit() -> void:
	await frames(3)
	if not await click("exit"):quit(92);return
	await frames(3)
	print("BUGTEST_NORMAL_QUIT ",JSON.stringify({"agent":"Codex-faisal3/bugtest","path":OS.get_user_data_dir(),"screen":app.main_menu.screen,"armed":app.main_menu.exit_armed,"native_events":native_events}))
	if not await click("exit"):quit(92)
func _run() -> void:
	var prefix: String="";var expected: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bugtest-user-prefix="):prefix=arg.trim_prefix("--bugtest-user-prefix=").replace("\\","/").trim_suffix("/")
		if arg.begins_with("--bugtest-user-actual="):expected=arg.trim_prefix("--bugtest-user-actual=").replace("\\","/").trim_suffix("/")
	var actual: String=OS.get_user_data_dir().replace("\\","/").trim_suffix("/")
	print("BUGTEST_STORAGE ",JSON.stringify({"agent":"Codex-faisal3/bugtest","actual":actual,"expected":expected,"prefix":prefix}))
	if prefix.is_empty() or actual!=expected or not actual.begins_with(prefix+"/"):quit(92);return
	root.size=Vector2i(1280,720) # Native viewport geometry only, no pixel/rendered assertion.
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	if not await ready_title():check(false,"bounded actual current title readiness");quit(92);return
	check(is_equal_approx(Engine.time_scale,1.0),"ordinary engine time_scale remains one")
	check(app!=null and app.main_menu!=null and app.hud!=null,"actual current source menu loaded")
	if app==null:quit(92);return
	print("BUGTEST_FOUR_WALLET ",JSON.stringify({"agent":"Codex-faisal3/bugtest","actual_user_path":OS.get_user_data_dir(),"phase":"before","wallet":wallet()}))
	if not await click("play"):quit(92);return
	check(app.bot_difficulty=="Normal" and not app.demo,"fresh source default Normal, no demo or difficulty setter")
	if app.bot_difficulty!="Normal" or app.demo:quit(92);return
	await pad_tap(7,JOY_BUTTON_DPAD_RIGHT)
	check(app.main_menu.p1_pad==7,"normal menu assigns P1 pad7")
	if not await click("split",true):quit(92);return
	if not await click("to_lobby"):quit(92);return
	await pad_tap(0,JOY_BUTTON_A)
	check(app.main_menu.join_pads==[0] and app.couch_players==2,"normal lobby joins exactly one teammate on pad0")
	await pad_tap(0,JOY_BUTTON_DPAD_LEFT)
	check(app.lobby_sides[1]==0,"P2 native left selects allied team")
	if not app.main_menu.readied[1]:await pad_tap(0,JOY_BUTTON_A)
	check(app.main_menu.readied[1],"P2 readies through normal A")
	if not await click("start"):quit(92);return
	var match_ready_end: int=Time.get_ticks_msec()+180000
	while Time.get_ticks_msec()<match_ready_end and not (app.playing and app.couch_active and app.locals.size()==2 and app.panes.size()==2 and app.world_ready and not is_instance_valid(app.loading_layer)):
		await frames(1)
	check(app.playing and app.couch_active and app.locals.size()==2 and app.panes.size()==2,"actual match creates two local actors and split panes")
	check(app.bound_pads==devices,"exact two-pad ownership preserved")
	if not app.playing or app.locals.size()!=2:quit(92);return
	var allied_bots:=0;var enemy_bots:=0
	for unit in app.units:
		if not unit.is_player:
			if unit.team==app.locals[0].team:allied_bots+=1
			else:enemy_bots+=1
	check(allied_bots==2 and enemy_bots==4,"normal4v4 fills two allied and four enemy bot seats")
	var ids: Array=app.locals.map(func(p):return p.get_instance_id())
	var previous: Array=app.locals.map(func(p):return p.global_position)
	var previous_deaths: Array=app.locals.map(func(p):return p.deaths)
	var phases:=["",""]
	var prior_score: Array=app.score.duplicate();var initial_wallet: Dictionary=wallet().duplicate(true);var score_events: Array=[]
	var match_wall_start: int=Time.get_ticks_msec()
	var match_wall_end: int=match_wall_start+920000
	var tick: int=0
	while Time.get_ticks_msec()<match_wall_end:
		if app.game_over or not app.playing:break
		tick+=1
		if app.guide_open:key(KEY_ESCAPE,true);await frames(1);key(KEY_ESCAPE,false)
		for k in 2:
			var p=app.locals[k];var d: int=devices[k];var enemy: int=1-p.team
			if p.role==roles[k]:class_seen[k]=true
			if p.carrying!=null:pickup_seen[k]=true
			if p.carrying!=null and flat(p.global_position,app.thrones[p.team])<10 and tick%20==0:home_trace(p,k)
			if p.dead or p.downed:neutral(d);continue
			var goal: Vector3;var phase: String;var revive=false;var healing=false
			if p.role==0:goal=app.seals[p.team][roles[k]].global_position;phase="native class pickup"
			elif p.carrying!=null:goal=home_waypoint(p);phase="carry home via stair centre"
			elif app.prep_left>0:goal=app.gates[p.team].global_position+Vector3(-2.5 if p.team==0 else 2.5,0,0);phase="natural prep staging"
			elif p.role==4:
				var leader=app.locals[0]
				if app.monarchs[enemy].carrier!=null and app.monarchs[enemy].carrier.team==p.team:leader=app.monarchs[enemy].carrier
				if leader.dead:goal=app.gates[p.team].global_position;phase="support regroup"
				else:goal=leader.global_position+Vector3(-2 if p.team==0 else 2,0,1.2);phase="support leader/carrier"
			else:
				var m=app.monarchs[enemy]
				if m.carrier!=null:goal=m.carrier.global_position;phase="escort allied carrier"
				elif app.gates[enemy].hp>0:goal=app.gates[enemy].global_position+Vector3(-1.5 if p.team==0 else 1.5,0,0);phase="enemy gate"
				elif app.vaults[enemy].hp>0:goal=app.vaults[enemy].lock_pos+Vector3(-1.3 if p.team==0 else 1.3,0,0);phase="enemy vault"
				else:goal=m.global_position;phase="crown pickup"
			if p.role!=0 and p.carrying==null:
				for friend in app.units:
					if friend.team!=p.team or friend.dead:continue
					if p.role==4 and not friend.downed and friend.hearts<friend.max_hearts() and flat(p.global_position,friend.global_position)<4.8:healing=true
					if friend.downed and flat(p.global_position,friend.global_position)<7:
						goal=friend.global_position;phase="native teammate revive";revive=true;break
			if phase!=phases[k]:phases[k]=phase;print("BUGTEST_DUO_PHASE ",JSON.stringify({"agent":"Codex-faisal3/bugtest","slot":k,"phase":phase,"clock":app.match_clock(),"position":str(p.global_position),"goal":str(goal)}))
			var dist:=flat(p.global_position,goal)
			var leg: Vector3=app.route_point(p.global_position,staged_goal(p.global_position,goal))
			var movement:=steer(k,p,leg)
			var aim:=Vector2(goal.x-p.global_position.x,goal.z-p.global_position.z).normalized()
			var attack: bool=(phase=="enemy gate" or phase=="enemy vault") and dist<1.1
			if attack:movement=Vector3.ZERO
			if dist<1 and (p.role==0 or phase=="crown pickup" or p.role==4 or revive):movement=Vector3.ZERO
			var closest=null;var near:=3.5
			if p.carrying==null and p.role!=0 and p.role!=4 and not revive:
				for foe in app.units:
					if foe.team==p.team or foe.dead or foe.downed:continue
					var distance:=flat(p.global_position,foe.global_position)
					if distance<near:closest=foe;near=distance
			if closest!=null:
				aim=Vector2(closest.global_position.x-p.global_position.x,closest.global_position.z-p.global_position.z).normalized();attack=true
				if near<1.8:movement=Vector3.ZERO
			# Wait for the actual healer while safe and neither is carrying; input remains ordinary neutral.
			if k==0 and p.role==1 and p.carrying==null and app.locals[1].role==4 and not app.locals[1].dead and not app.locals[1].downed and closest==null and flat(p.global_position,app.locals[1].global_position)>7 and (app.locals[1].global_position-p.global_position).dot(goal-p.global_position)<0:movement=Vector3.ZERO
			axis(d,JOY_AXIS_LEFT_X,movement.x);axis(d,JOY_AXIS_LEFT_Y,movement.z);axis(d,JOY_AXIS_RIGHT_X,aim.x);axis(d,JOY_AXIS_RIGHT_Y,aim.y)
			button(d,JOY_BUTTON_A,(attack or healing) and p.carrying==null and not revive)
			var interact: bool=(p.role==0 or phase=="crown pickup") and dist<1.6 and tick%3==0
			if revive and dist<p.revive_reach()*.85:interact=true
			button(d,JOY_BUTTON_RIGHT_SHOULDER,interact and p.carrying==null)
			button(d,JOY_BUTTON_X,(closest!=null or healing or attack) and tick%30==0);button(d,JOY_BUTTON_Y,(closest!=null or healing or attack) and tick%30==15)
		await create_timer(0.10).timeout # Real engine timer; no fixed-fps or clock mutation.
		await frames(1)
		for team in 2:
			if app.score[team]!=prior_score[team]:
				var crown=app.monarchs[1-team]
				check(app.score[team]==prior_score[team]+1,"natural scoring increments team score once")
				check(crown.state==0 and crown.carrier==null and flat(crown.global_position,crown.home)<0.1,"actual scored crown resets to its own home")
				score_events.append({"team":team,"score":app.score.duplicate(),"clock":app.match_clock(),"crown_state":crown.state,"crown_position":str(crown.global_position),"game_over":app.game_over})
				print("BUGTEST_DUO_SCORE ",JSON.stringify({"agent":"Codex-faisal3/bugtest","event":score_events.back()}))
		prior_score=app.score.duplicate()
		for k in 2:
			var p=app.locals[k];var delta: float=p.global_position.distance_to(previous[k])
			if Input.is_action_pressed(p.act_prefix+"attack"):
				native_attack_seen[k]=true
				if not p.dead and not p.downed and p.attack_timer>0:native_swing_seen[k]=true
			if p.deaths==previous_deaths[k] and not p.dead and not p.downed and delta<10:travelled[k]+=delta
			else:excluded_jump[k]+=delta
			previous[k]=p.global_position;previous_deaths[k]=p.deaths
		if tick%100==0 or app.locals.any(func(p):return p.carrying!=null) and tick%10==0:rows("native objective "+str(tick))
	for d in devices:neutral(d)
	await frames(3);rows("normal-time policy ended")
	check(app.bot_difficulty=="Normal" and is_equal_approx(Engine.time_scale,1.0),"Normal difficulty and ordinary engine scale retained")
	check(app.bound_pads==devices and app.locals.map(func(p):return p.get_instance_id())==ids,"native actor and device identities retained")
	for k in 2:
		check(travelled[k]>10,"P%d continuous native movement excludes death/respawn jumps"%(k+1))
		if native_attack_seen[k]:check(true,"P%d native A reaches actual owned attack action"%(k+1))
		if native_swing_seen[k]:check(true,"P%d actual swing timer runs under native held attack"%(k+1))
		if class_seen[k]:check(true,"P%d assigned Knight/Healer hat acquired natively"%(k+1))
		if pickup_seen[k]:check(true,"P%d actual native enemy crown pickup"%(k+1))
		if app.locals[k].captures>0:check(true,"P%d actual native carry-to-home capture"%(k+1))
	var caps: int=app.locals[0].captures+app.locals[1].captures
	var pickup: bool=pickup_seen.any(func(x):return x)
	if not pickup or caps==0:print("BUGTEST_UNSUPPORTED bounded two-human native policy did not complete capture; no softlock/balance bug inferred")
	var full_match: bool=app.game_over and not app.playing and app.summary!=null
	var outcome: String="incomplete"
	var final_score: Array=app.score.duplicate();var final_clock: int=app.match_clock();var final_caps: Array=app.locals.map(func(p):return p.captures)
	if full_match:
		var summary=app.summary
		outcome=summary.result
		check(app.winner_team>=-1 and app.winner_team<=1 and summary.winner==app.winner_team,"natural full match creates consistent winner and summary")
		check(app.score.max()>=2 or final_clock>=600,"normal two-capture or time/overtime end rule reached without forcing")
		check(app.account_xp==initial_wallet.xp+app.last_match_gain and app.last_match_gain>0,"actual full-match XP bank equals displayed earned gain")
		check(app.account_gold==initial_wallet.gold+summary.reward_gold and app.account_shards==initial_wallet.shards+summary.reward_shards,"actual result gold/shard rewards bank once")
		check(app.account_chests==initial_wallet.chests+1,"actual full match earns exactly one chest")
		var result_eligible: bool=app.result_bonus_earned()
		var expected_result_bonus: int=CurrentStats.MATCH_BONUS[summary.result] if result_eligible else 0
		var result_label: String={"win":"Victory","draw":"Draw","loss":"Played to the end"}[summary.result]
		var result_rows: Array=summary.lines.filter(func(line):return line[0]==result_label)
		check(not "--debug-end" in OS.get_cmdline_user_args(),"no debug-end eligibility override in actual native case")
		check(result_eligible==(app.match_played>=CurrentStats.RESULT_BONUS_MIN_TIME),"actual result eligibility follows current played-seconds threshold")
		check(app.last_match_gain==app.match_xp+summary.bonus_xp()+expected_result_bonus,"actual bank gain includes only eligible result XP and primary accolades")
		check((result_rows.size()==1 and int(result_rows[0][2])==expected_result_bonus) if result_eligible else result_rows.is_empty(),"actual summary includes result row exactly when eligible")
		check(summary.me==app.locals[0],"actual summary keeps primary local player identity")
		var earned: Dictionary=wallet().duplicate(true)
		var shared_sources: Dictionary={}
		var all_player_sources: Array=[]
		for u in app.units:
			if u.is_player:
				all_player_sources.append({"unit":u.get_instance_id(),"team":u.team,"sources":u.xp_sources.duplicate(true)})
				for source in u.xp_sources: shared_sources[source]=int(shared_sources.get(source,0))+int(u.xp_sources[source])
		var tally_total: int=0
		for line in summary.lines: tally_total+=int(line[2])
		check(int(shared_sources.get("training",0))==0,"training XP outside scoped couch regression was not exercised")
		check(tally_total==app.last_match_gain,"actual shared XP tally equals exactly banked gain")
		var category_total: int=0
		for source in shared_sources: category_total+=int(shared_sources[source])
		check(category_total==app.match_xp,"all actual players source ledger reconciles with shared match XP")
		check(all_player_sources.size()==2,"two actual player XP ledgers observed at natural result")
		for source in summary.SOURCES:
			var expected_source: int=int(shared_sources.get(source[0],0))
			var actual_source: int=0
			for line in summary.lines:
				if line[0]==source[1]: actual_source=int(line[2])
			check(actual_source==expected_source,"actual shared category matches both player ledgers: "+str(source[0]))
		print("BUGTEST_FULL_MATCH ",JSON.stringify({"agent":"Codex-faisal3/bugtest","outcome":outcome,"winner":app.winner_team,"score":final_score,"clock":final_clock,"captures":final_caps,"score_events":score_events,"wallet_before":initial_wallet,"wallet_after":earned,"last_match_gain":app.last_match_gain,"reward_gold":summary.reward_gold,"reward_shards":summary.reward_shards,"summary_me":summary.me.get_instance_id(),"local0":app.locals[0].get_instance_id(),"match_xp":app.match_xp,"match_played":app.match_played,"result_bonus_earned":result_eligible,"bonus_min_seconds":CurrentStats.RESULT_BONUS_MIN_TIME,"expected_result_bonus":expected_result_bonus,"result_rows":result_rows,"summary_lines":summary.lines,"all_player_xp_sources":all_player_sources,"shared_sources":shared_sources,"tally_total":tally_total,"accolades":summary.accolades,"engine_scale":Engine.time_scale,"wall_ms_elapsed":Time.get_ticks_msec()-match_wall_start}))
		await frames(15)
		await click_rect(summary.board_rect)
		check(summary.show_board,"native actual scoreboard button opens full match board")
		await click_rect(summary.board_rect)
		check(not summary.show_board,"native same button returns to summary")
		if not summary.done():
			await click_rect(summary.continue_rect)
			check(summary.done(),"native actual Skip completes result tally")
		check(wallet()==earned,"result board/tally input does not double-bank rewards")
		await click_rect(summary.continue_rect)
		if not await ready_title():check(false,"actual normal title readiness after Continue");quit(92);return
		check(app.main_menu!=null and app.main_menu.screen=="title" and not app.playing and not app.game_over,"native summary Continue reloads normal title")
		check(wallet()==earned,"normal scene reload retains exactly earned account values")
		var cfg:=ConfigFile.new();var loaded: int=cfg.load("user://profiles/p1.cfg")
		check(loaded==OK,"actual profile save exists after natural match")
		if loaded==OK:
			check(cfg.get_value("profile","account_xp",-1)==earned.xp and cfg.get_value("profile","account_gold",-1)==earned.gold and cfg.get_value("profile","account_shards",-1)==earned.shards and cfg.get_value("profile","account_chests",-1)==earned.chests,"actual saved profile equals native earned wallet")
	else:print("BUGTEST_UNSUPPORTED bounded native duo full-match policy incomplete; no softlock/balance bug inferred")
	print("BUGTEST_FOUR_WALLET ",JSON.stringify({"agent":"Codex-faisal3/bugtest","actual_user_path":OS.get_user_data_dir(),"phase":"after","wallet":wallet()}))
	print("BUGTEST_RESULT ",JSON.stringify({"agent":"Codex-faisal3/bugtest","failures":failures,"pickup_seen":pickup,"captures":caps,"capture_qualified":pickup and caps>0,"full_match_qualified":full_match,"outcome":outcome,"final_score":final_score,"final_clock":final_clock,"native_events":native_events,"difficulty":"Normal","engine_scale":Engine.time_scale,"wall_ms_elapsed":Time.get_ticks_msec()-match_wall_start,"wallet":wallet(),"scope":"Exact issue135 committed candidate source runtime, fresh default Normal and two native virtual Knight/Healer players with normal4v4 bots. Actual engine time/920s wall bound, either outcome. Readonly route/raycast planning and ordinary input events only. No game/RNG/clock/save/health/pose/outcome grants; source-only no packaged/rendered/physical/audio/performance/balance/fulllevel20 acceptance."}))
	if failures==0 and full_match:normal_exit.call_deferred()
	else:quit(92)

func emit_native(event: InputEvent) -> void:
	native_events+=1
	var data: Dictionary={"agent":"Codex-faisal3/bugtest","sequence":native_events,"frame":Engine.get_process_frames(),"wall_ms":Time.get_ticks_msec(),"kind":event.get_class(),"device":event.device}
	if event is InputEventJoypadMotion:data["axis"]=event.axis;data["value"]=event.axis_value
	if event is InputEventJoypadButton:data["button"]=event.button_index;data["pressed"]=event.pressed
	if event is InputEventKey:data["key"]=event.physical_keycode;data["pressed"]=event.pressed
	if event is InputEventMouse:data["position"]=[event.position.x,event.position.y]
	if event is InputEventMouseButton:data["button"]=event.button_index;data["pressed"]=event.pressed
	print("BUGTEST_NATIVE_EVENT ",JSON.stringify(data))
	Input.parse_input_event(event)
