extends SceneTree
## Agent: Codex-faisal3/bugtest. Synthetic MatchSummary API regression only.
## No Game scene, input, account/save mutation, earned play or rendered capture.
const Summary = preload("res://scripts/match_summary.gd")
const Stats = preload("res://scripts/stats.gd")
class FakeUnit extends RefCounted:
	var is_player := false
	var team := 0
	var role := 0
	var last_role := 0
	var mastery := {}
	var variants := {}
	var xp_sources := {}
	var kills := 0
	var deaths := 1
	var assists := 0
	var captures := 0
	var giant_kills := 0
	var healing := 0
	var best_streak := 0
class FakeSfx extends RefCounted:
	func ui(_name): pass
class FakeGame extends RefCounted:
	var units := []
	var demo := false
	var sfx = FakeSfx.new()
	var bonus_eligible := true
	func result_bonus_earned(): return bonus_eligible
	func unit_score(u): return u.kills
class TextSpy extends RefCounted:
	var font: Font = ThemeDB.fallback_font
	var bar_font: Font = ThemeDB.fallback_font
	var strings := []
	func _plate(_r,_fill,_edge,_radius,_border): pass
	func _icon(_name,_pos,_radius,_col,_dim=false): pass
	func _text(_pos,text,_size,_color,_align=0,_width=-1,_outline=0): strings.append(text)
	func draw_rect(_rect,_color,_filled=true,_width=-1): pass
	func draw_line(_a,_b,_color,_width=-1): pass
	func draw_circle(_p,_r,_color): pass
	func draw_string_outline(_font,_pos,_text,_align,_width,_size,_outline,_color): pass
	func draw_string(_font,_pos,text,_align,_width,_size,_color): strings.append(text)
var failed := 0
var count := 0
func check(ok:bool,label:String):
	count += 1
	if not ok: failed += 1
	print("BUGTEST_API_CHECK ",JSON.stringify({"agent":"Codex-faisal3/bugtest","pass":ok,"name":label}))
func unit(player:bool, sources:Dictionary, side:int=0):
	var u=FakeUnit.new();u.is_player=player;u.xp_sources=sources.duplicate(true);u.team=side
	return u
func total(s)->int:
	var n:=0
	for line in s.lines: n+=int(line[2])
	return n
func capture(g,u,winner:int):
	var s=Summary.new();s.capture(g,u,winner);return s
func _initialize(): call_deferred("run")
func run():
	var p=unit(true,{"combat":70,"siege":22})
	var bot=unit(false,{"combat":9000});bot.kills=40
	var g=FakeGame.new();g.units=[p,bot]
	var s=capture(g,p,0)
	check(total(s)==392,"single player:92 earned plus300 victory; bot XP excluded")
	check(s.me==p and s.mvp==bot,"primary player and actual MVP retained")
	check(s.reward_gold==Stats.MATCH_GOLD.win and s.reward_shards==Stats.MATCH_SHARDS.win,"single player existing rewards retained")
	var secondary=unit(true,{"combat":11,"support":13},1)
	secondary.captures=1;secondary.giant_kills=1
	g.units=[p,secondary,bot]
	var primary_before=p.xp_sources.duplicate(true)
	var secondary_before=secondary.xp_sources.duplicate(true)
	s=capture(g,p,1)
	check(total(s)==216,"two couch players:92+24 shared earned plus100 loss")
	check(s.lines.has(["Combat","vanguard",81]) and s.lines.has(["Support","mend",13]),"XP categories aggregate both players including opposite sides")
	check(s.me==p and s.accolades.is_empty() and s.bonus_xp()==0,"secondary accolades never replace or augment primary accolades")
	check(p.xp_sources==primary_before and secondary.xp_sources==secondary_before,"capturing summary never changes either player XP")
	check(s.result=="loss" and s.reward_gold==200 and s.reward_shards==15,"result and reward amounts unchanged")
	s.set_account(0,216)
	var spy=TextSpy.new();s._xp_panel(spy,Rect2(459,178,362,458),100.0)
	check(spy.strings.has("+216 XP"),"production tally emits fully counted shared TOTAL text (no rendering)")
	var third=unit(true,{"crown":25});var fourth=unit(true,{"takedowns":50,"support":7},1)
	g.units=[p,secondary,third,fourth,bot];s=capture(g,p,-1)
	check(total(s)==348,"four couch players:198 shared earned plus150 draw")
	check(s.lines.size()<=7 and s.lines.has(["Support","mend",20]),"existing five-category layout remains within seven rows")
	g.bonus_eligible=false;s=capture(g,p,-1)
	check(total(s)==198,"upstream GP06 ineligible result: earned shared XP only")
	check(not s.lines.has(["Draw","guard",150]),"upstream GP06 suppresses result bonus row")
	g=FakeGame.new();g.demo=true;g.units=[bot];s=capture(g,null,0)
	check(s.me==bot and s.lines.has(["Combat","vanguard",9000]),"bot demo retains MVP-only illustrative XP")
	g=FakeGame.new();s=capture(g,null,-1)
	check(s.me==null and total(s)==150,"empty summary retains result-only behavior")
	print("BUGTEST_API_RESULT ",JSON.stringify({"agent":"Codex-faisal3/bugtest","checks":count,"failures":failed,"scope":"Synthetic production capture/panel text API only; no actual gameplay/account/save/rendered acceptance. Training category outside this couch regression."}))
	quit(1 if failed else 0)
