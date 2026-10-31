"""Agent: Codex-faisal3/bugtest. First issue135 candidate Normal native-input full match; finite controller, no supervisor."""
from pathlib import Path
import ast,datetime as dt,hashlib,json,os,re,shutil,subprocess,sys,traceback,runpy
sys.path[:0]=['C:/Temp/bugtest','C:/Temp/bugtest/setup'];import runner
from source_bound_adoption import efficient_checkout
r=runner.ROOT;read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'));h=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();parentp=r/'jobs/crowns7fd135-candidate-first-api.json';parent=read(parentp);auditp=r/'setup/crowns7fd135-candidate-first-api-independent-audit.json';audit=read(auditp);planp=r/'setup/crowns7fd135-normal-source-plan.json';plan=read(planp);assert parent['status']=='EXITED' and not parent.get('error') and parent['functional_pass'] and audit['native_parent_sha256']==h(parentp)
repo=Path(parent['repo']);jp=r/'jobs/crowns7fd135-normal-native-continuation.json';assert not jp.exists(),'Adopt original source-bound Normal case';now=dt.datetime.now(dt.timezone.utc);out=r/'cycles'/now.strftime('%Y%m%dT%H%M%SZ')/'crowns7fd135-normal-native-continuation';out.mkdir(parents=True)
node=next(n for n in ast.parse((r/'prince_3d2_first_import.py').read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='guard');exec(compile(ast.Module(body=[node],type_ignores=[]),'full-source-and-foreign-adoption-guard','exec'))
_original_guard=guard
def guard():
 _original_guard()
 extra=runpy.run_path(str(r/'setup/adopt-titleab-chief-foreign.py'))
 assert not extra['active'],'Preserve actual foreign title A/B controller across engine gaps and Chief source import children'
d=dict(agent='Codex-faisal3/bugtest',runner_pid=os.getpid(),status='PREPARING',started_at=now.isoformat(),repo=str(repo),source_sha=parent['source_sha'],output=str(out),results=[],parent_job=str(parentp),parent_job_sha256=h(parentp),parent_audit=str(auditp),plan=str(planp),plan_sha256=h(planp),source_files=parent['original_files'],native_input_kind='Queued virtual joypad/key/mouse InputEvents consumed by production input, not physical devices',rendered=False,PNG=0,source_edits=False,export_created=False,scope='First exact issue135 candidate fresh Normal fullmatch, two native virtual players7/0 and normal4v4 bots. Actual private OS userdir before input, actual full prep20/match600/overtime120 horizon and920s wall bound, no fixed-fps or clock/health/position/progression/outcome grants. Natural outcome may be win/loss/draw; source summary reward exactly once, native Continue/titleEXIT and separate restart. Read-only geometry and source route planner. No source/art edit, seeded profile, build/rendered/device/audio/performance/full20ending acceptance.')
ordinary=Path(os.environ['APPDATA'])/'Godot/app_userdata'
def hashes(root):return {str(p.relative_to(root)):h(p) for p in root.rglob('*') if p.is_file()} if root.exists() else {}
def save():runner.atomic_json(jp,d);runner.atomic_json(out/'results.json',d)
def stats(files):return {p:(Path(p).stat().st_size,Path(p).stat().st_mtime_ns) for p in files}
def custody(full=False):
 assert h(parentp)==d['parent_job_sha256'] and h(planp)==d['plan_sha256'] and hashes(ordinary)==d['ordinary_before']
 assert all(h(p)==v for p,v in d['frozen_files'].items())
 if full:
  assert all(h(repo/p)==v for p,v in d['source_files'].items()),'Current source changed'
  assert all(h(p)==v for p,v in d['protected_files'].items()),'Prior evidence/profile/source changed'
 else:assert stats(d['source_stats'])==source_stats and stats(d['protected_stats'])==protected_stats,'Current/prior file metadata changed; stop and classify, no restore'
def step(label,args,env,limit=180):
 guard();custody();d.update(status='RUNNING',step=label);save();z=runner.run(args,repo,out/(label+'.log'),limit,env=env,source_repo=repo);text=Path(z['log']).read_text(encoding='utf-8',errors='replace');z.update(step=label,errors=[v for v in text.splitlines() if re.search(r'^ERROR:|^USER ERROR:|SCRIPT ERROR|Parse Error',v)])
 for key,tag in [('checks','BUGTEST_CHECK'),('results','BUGTEST_RESULT'),('wallets','BUGTEST_FOUR_WALLET'),('states','BUGTEST_DUO_STATE'),('events','BUGTEST_NATIVE_EVENT'),('matches','BUGTEST_FULL_MATCH'),('storage','BUGTEST_STORAGE'),('normal_quits','BUGTEST_NORMAL_QUIT')]:z[key]=[json.loads(v.split(tag+' ',1)[1]) for v in text.splitlines() if v.startswith(tag+' ')]
 z['unsupported']=[v for v in text.splitlines() if v.startswith('BUGTEST_UNSUPPORTED')];d['results'].append(z);save();guard();custody();print(label,z['exit'],len(z['errors']),len(z['checks']),flush=True);return z,text
save()
try:
 with runner.locked('game-crowns') as own,runner.locked('engine-laptop3-godot') as engine:
  assert own and engine;guard();assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()==d['source_sha']==plan['source_sha']
  assert subprocess.check_output(['git','rev-parse','origin/main'],cwd=runner.tester_repo('crowns'),creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()==plan['parent_main']
  bot=out/'executed-normal-match.gd';restart=out/'executed-earned-restart.gd';shutil.copyfile(plan['fixture'],bot);shutil.copyfile(plan['restart'],restart);shutil.copyfile(__file__,out/'executed-controller.py');assert h(bot)==plan['fixture_sha256'] and h(restart)==plan['restart_sha256']
  interruption=read('C:\\Temp\\bugtest\\setup\\crowns2fea-native-interruption-20261031T035924Z\\classification.json');assert interruption['classification']=='INTERRUPTED_INCOMPLETE'
  interrupted=read(r/'jobs/crowns7fd135-normal-native.json');assert interrupted['status']=='INTERRUPTED'
  protected=dict(parent['protected_files']);protected.update({str(p):h(p) for p in Path(parent['output']).rglob('*') if p.is_file()});protected[str(parentp)]=h(parentp);protected[str(auditp)]=h(auditp)
  earned=read(r/'jobs/prince3d2-char-resource-api-v2.json')['protected_earned_files'];protected.update({p:h(p) for p in earned})
  for name in ['idle13-natural-play','idle13-stage3-play']:
   prior=read(r/'jobs'/(name+'.json'));profile=Path(prior['expected_persistent_path']);protected.update({str(p):h(p) for p in profile.rglob('*') if p.is_file()});protected[str(r/'jobs'/(name+'.json'))]=h(r/'jobs'/(name+'.json'))
  protected[interruption['original_job_archive']]=h(interruption['original_job_archive'])
  protected.update(interruption['preserved_artifacts']);protected[str(r/'jobs/crowns7fd135-normal-native.json')]=h(r/'jobs/crowns7fd135-normal-native.json')
  protected['C:\\Temp\\bugtest\\setup\\crowns2fea-native-interruption-20261031T035924Z\\classification.json']=h('C:\\Temp\\bugtest\\setup\\crowns2fea-native-interruption-20261031T035924Z\\classification.json')
  frozen={str(p):h(p) for p in [Path(__file__),out/'executed-controller.py',bot,restart,Path(plan['fixture']),Path(plan['restart']),r/'setup/godot_user_path_probe.gd',r/'setup/adopt-titleab-chief-foreign.py',auditp]}
  d.update(ordinary_before=hashes(ordinary),protected_files=protected,frozen_files=frozen,fixture=str(bot),fixture_sha256=h(bot),restart_fixture=str(restart),restart_sha256=h(restart),engine_sha256=h(runner.GODOT),profile_copy=False)
  d['source_stats']={str(repo/p):v for p,v in d['source_files'].items()};d['protected_stats']=dict(protected);source_stats=stats(d['source_stats']);protected_stats=stats(d['protected_stats']);save();custody(full=True)
  env=dict(os.environ)
  for key in list(env):
   if key.startswith(('CW_','CROWNS_','HD_','PRO_','PT_','C1_','POK_')):env.pop(key)
  for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME']:
   p=out/'fresh-private-profile'/key;p.mkdir(parents=True);env[key]=str(p)
  d['profile_env']={k:env[k] for k in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME']};save();c=read(r/'checkpoint.json');c.update(updated_at=dt.datetime.now(dt.timezone.utc).isoformat(),stage='CROWNS7FD135_CANDIDATE_NORMAL_FULLMATCH_INFLIGHT',inflight=str(jp),inflight_job=str(jp),latest_session_progress=str(jp));runner.atomic_json(r/'checkpoint.json',c)
  prefix=[runner.GODOT,'--headless','--audio-driver','Dummy','--path',repo]
  z,text=step('FIRST-actual-private-OS-userdir-before-any-play',prefix+['--script',r/'setup/godot_user_path_probe.gd','--','--bugtest-user-prefix='+env['APPDATA']],env,90);paths=[json.loads(v.split('BUGTEST_USER_PATH ',1)[1]) for v in text.splitlines() if v.startswith('BUGTEST_USER_PATH ')];assert z['exit']==0 and not z['errors'] and len(paths)==1 and Path(paths[0]['actual']).resolve().is_relative_to(Path(env['APPDATA']).resolve());actual=Path(paths[0]['actual']);assert not (actual/'profiles').exists() and not list(actual.glob('*.cfg'));d['actual_private_userdata']=paths[0];save()
  for label,path in [('FIRST-distinct-Normal-observer-parse',bot),('FIRST-distinct-earned-restart-observer-parse',restart)]:
   z,_=step(label,prefix+['--check-only','--script',path],env,120);assert z['exit']==0 and not z['errors'],'Local fixture parse failure before match; preserve, classify tester, no game claim'
  z,_=step('FIRST-native-Normal-fullmatch',prefix+['--script',bot,'--','--bugtest-user-prefix='+env['APPDATA'],'--bugtest-user-actual='+str(actual).replace('\\','/')],env,1300)
  d['native_fullmatch_functional_pass']=z['exit']==0 and len(z['results'])==1 and z['results'][0]['failures']==0 and z['results'][0]['full_match_qualified'] and z['results'][0]['difficulty']=='Normal' and bool(z['checks']) and all(v['pass'] for v in z['checks']) and len(z['storage'])==1 and Path(z['storage'][0]['actual'])==actual and len(z['normal_quits'])==1 and len(z['matches'])==1;save()
  if d['native_fullmatch_functional_pass']:
   expected=out/'actually-earned-wallet.json';runner.atomic_json(expected,dict(z['results'][0]['wallet']));d['wallet_after_match']=z['results'][0]['wallet'];d['actual_profile_after_match']=hashes(actual);shutil.copytree(actual,out/'actual-earned-profile-after-match');save()
   q,text=step('FIRST-separate-process-earned-userdir-proof',prefix+['--script',r/'setup/godot_user_path_probe.gd','--','--bugtest-user-prefix='+env['APPDATA']],env,90);paths2=[json.loads(v.split('BUGTEST_USER_PATH ',1)[1]) for v in text.splitlines() if v.startswith('BUGTEST_USER_PATH ')];assert q['exit']==0 and not q['errors'] and len(paths2)==1 and Path(paths2[0]['actual'])==actual
   q,_=step('FIRST-separate-process-actual-earned-restart',prefix+['--script',restart,'--','--expected-wallet='+str(expected),'--bugtest-user-prefix='+env['APPDATA']],env,240);d['restart_functional_pass']=q['exit']==0 and len(q['results'])==1 and q['results'][0]['failures']==0 and bool(q['checks']) and all(v['pass'] for v in q['checks']) and len(q['wallets'])==1 and q['wallets'][0]['wallet']==d['wallet_after_match'] and Path(q['wallets'][0]['actual_user_path'])==actual;save()
  guard();custody(full=True);d.update(status='EXITED',ended_at=dt.datetime.now(dt.timezone.utc).isoformat(),functional_pass=d['native_fullmatch_functional_pass'] and d.get('restart_functional_pass',False),raw_status='FAIL' if any(z['errors'] or z['exit'] for z in d['results']) else 'PASS',private_profile_files=hashes(actual),source_originals_ordinary_prior_unchanged=True,next_action='Independently audit actual Normal engine clock/typed device events/world movement/source reward/summary/normal EXIT and actual earned profile/restart plus all source/cache/prior/ordinary custody. Preserve raw renderer/shutdown diagnostics and first controller/oracle failures. Planner limitations are unsupported, not automatic game bugs. No green replay, source edits, rendered/device/performance or fulllevel20 acceptance.');save();print(json.dumps({k:d.get(k) for k in ['status','error','functional_pass','raw_status','output']}))
except BaseException as e:
 d.update(status='EXITED',error=repr(e),ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save();(out/'controller-error.txt').write_text('Agent: Codex-faisal3/bugtest\n'+traceback.format_exc());raise
