"""Agent: Codex-faisal3/bugtest. Fresh merged main0963 Windows export and actual-path-gated fullmatch native routes."""
import sys,json,os,datetime as dt,hashlib,shutil,subprocess,re,time
from pathlib import Path
sys.path.insert(0,'C:/Temp/bugtest');import runner
r=runner.ROOT;meta=json.loads((r/'setup/crowns-main-0963-prepared.json').read_text());repo=Path(meta['repo']);out=r/'cycles'/dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')/'crowns';out.mkdir(parents=True);job=r/'jobs/crowns-main-0963-native.json';state=dict(agent='Codex-faisal3/bugtest',runner_pid=os.getpid(),status='PREPARING',repo=str(repo),output=str(out),started_at=dt.datetime.now(dt.timezone.utc).isoformat(),results=[])
def save():runner.atomic_json(job,state);runner.atomic_json(out/'results.json',state)
def hashes(root):return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()} if root.exists() else {}
def guard():
 if Path('C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE').exists():raise RuntimeError('PAUSE retained')
 start=time.monotonic()
 while True:
  active=runner.checkout_processes(repo)
  if not active:break
  state['adopted_inflight']=active;save()
  if time.monotonic()-start>300:raise RuntimeError('Preserved engine children using checkout; resume existing work, no refresh')
  time.sleep(5)
  if Path('C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE').exists():raise RuntimeError('PAUSE retained')
 state.pop('adopted_inflight',None)
with runner.locked('engine-laptop3-godot') as slot:
 if not slot:raise SystemExit('Godot busy')
 with runner.locked('game-crowns') as own:
  if not own:raise SystemExit('Crowns busy')
  ordinary=Path(os.environ['APPDATA'])/'Godot/app_userdata';before=None
  try:
   guard();head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True,creationflags=subprocess.CREATE_NO_WINDOW).strip()
   if head!=meta['source_sha']:raise RuntimeError('Source advanced')
   if subprocess.check_output(['git','diff','--name-only','--','project.godot','scripts','scenes','assets'],cwd=repo,text=True,creationflags=subprocess.CREATE_NO_WINDOW).strip():raise RuntimeError('Preserve changed runtime source')
   state.update(source_sha=head,source_files_sha256={f:hashlib.sha256((repo/f).read_bytes()).hexdigest() for f in ['project.godot','scripts/game.gd','scripts/menu.gd']},status='RUNNING');before=hashes(ordinary);state['ordinary_before']=before;save()
   def env_for(label):
    env=os.environ.copy()
    for k in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME']:
     d=out/'profiles'/label/k;d.mkdir(parents=True,exist_ok=True);env[k]=str(d)
    return env
   def execute(label,cmd,cwd,env,timeout):
    guard();state['step']=label;save();res=runner.run(cmd,cwd,out/(label+'.log'),timeout,env,source_repo=repo);text=Path(res['log']).read_text(encoding='utf-8',errors='replace');errors=[x for x in text.splitlines() if re.search(r'^ERROR:|SCRIPT ERROR|Parse Error',x)];checks=[json.loads(x.split('BUGTEST_CHECK ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_CHECK ')];summaries=[json.loads(x.split('BUGTEST_RESULT ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_RESULT ')];res.update(step=label,status='PASS' if res['exit']==0 and not errors else 'PAUSED' if res['exit']==3 else 'FAIL',errors=errors,error_count=len(errors),input_checks=checks,input_results=summaries,input_scenario_passed=res['exit']==0 and bool(summaries) and all(x['failures']==0 for x in summaries));state['results'].append(res);save();return res,text
   build_env=env_for('build');manifest=json.loads((r/'tools/godot-4.3-export-templates/verified.json').read_text());assert manifest['actual_sha512']==manifest['official_sha512'];templates=Path(manifest['template_directory']);dest=Path(build_env['APPDATA'])/'Godot/export_templates/4.3.stable';dest.mkdir(parents=True)
   for name,h in manifest['files'].items():
    assert hashlib.sha256((templates/name).read_bytes()).hexdigest()==h['sha256'];shutil.copy2(templates/name,dest/name)
   res,_=execute('import',[runner.GODOT,'--headless','--editor','--path',repo,'--import'],repo,build_env,300)
   if res['exit']!=0:raise RuntimeError('Import failed')
   if res['errors']:
    if not all('EBGaramond' in x or 'custom project font' in x for x in res['errors']):raise RuntimeError('Unexpected import errors')
    res['classification']='First fresh font cache startup diagnostics retained, clean confirmation required';save();res,_=execute('import-confirm',[runner.GODOT,'--headless','--editor','--path',repo,'--import'],repo,build_env,300)
    if res['status']!='PASS':raise RuntimeError('Import confirmation failed')
   exe=out/'build/crowns.exe';exe.parent.mkdir();res,_=execute('windows-export',[runner.GODOT,'--headless','--path',repo,'--export-release','Windows Desktop',exe],repo,build_env,300)
   if res['status']!='PASS' or not exe.exists():raise RuntimeError('Export failed')
   state['artifacts']={str(p.relative_to(out)):dict(bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in exe.parent.iterdir() if p.is_file()};save()
   for variant,source in [('four-versus',r/'setup/crowns_four_versus_input.gd'),('four-coop',r/'setup/crowns_four_full_input.gd')]:
    env=env_for(variant);bot=out/(variant+'.gd');shutil.copy2(source,bot);state.setdefault('bots',{})[variant]=dict(path=str(bot),sha256=hashlib.sha256(bot.read_bytes()).hexdigest());save()
    res,text=execute(variant+'-actual-user-path',[exe,'--headless','--script',r/'setup/godot_user_path_probe.gd','--','--bugtest-user-prefix='+env['APPDATA']],exe.parent,env,45);paths=[json.loads(x.split('BUGTEST_USER_PATH ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_USER_PATH ')];qualified=res['status']=='PASS' and len(paths)==1 and Path(paths[0]['actual']).resolve().is_relative_to(Path(env['APPDATA']).resolve());state.setdefault('storage_qualification',{})[variant]=dict(qualified=qualified,records=paths);save()
    if not qualified:raise RuntimeError('Actual candidate user path unsafe')
    route,text=execute('native-'+variant,[exe,'--headless','--script',bot,'--fixed-fps','60'],exe.parent,env,960)
    expected_path=Path(paths[0]['actual']).resolve();wallets=[json.loads(x.split('BUGTEST_FOUR_WALLET ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_FOUR_WALLET ')]
    actual_paths=[Path(x['actual_user_path']).resolve() for x in wallets if x.get('actual_user_path')];route['actual_game_path_matches_probe']=bool(actual_paths) and all(x==expected_path for x in actual_paths)
    route['full_match_qualified']=route['input_scenario_passed'] and bool(route['input_results']) and all(x.get('full_match') is True for x in route['input_results']) and route['actual_game_path_matches_probe'] and all(x['pass'] for x in route['input_checks'])
    route['unsupported_lines']=[x for x in text.splitlines() if 'BUGTEST_UNSUPPORTED' in x];route['wallets']=wallets;save()
    if not route['full_match_qualified']:raise RuntimeError('Actual fullmatch/native route incomplete; retain raw result and do not qualify')
    if hashes(ordinary)!=before:raise RuntimeError('Ordinary userdata changed; stop further input')
    if any(hashlib.sha256((repo/f).read_bytes()).hexdigest()!=h for f,h in state['source_files_sha256'].items()):raise RuntimeError('Source changed after build')
    if any(hashlib.sha256((out/f).read_bytes()).hexdigest()!=h['sha256'] for f,h in state['artifacts'].items()):raise RuntimeError('Package artifact changed')
   routes=[x for x in state['results'] if x['step'].startswith('native-')];state.update(status='EXITED',ended_at=dt.datetime.now(dt.timezone.utc).isoformat(),input_scenarios_passed=len(routes)==2 and all(x['full_match_qualified'] for x in routes),overall_status='PASS' if all(x['status']=='PASS' for x in state['results']) else 'FAIL',limits='Fresh exact mergedmain0963 Windows package, no sourcealias. Actual packaged userpath beforeeach input route and actualgamepath readback matches; ordinaryGodotuserdata hashes unchanged. Normal mouse/native queuedvirtualJoypad events; natural20s prep/fixed60 simulation, no game/menu/prep/resource/outcome API writes. Fullmatch/rematchstart only if actualfullmatch true, no second fullmatch/physicalcontroller/connection/rendered/style/animation/performance acceptance. KnownSkeleton/shutdown errors retain overallFAIL; no fabricated captures, no duplicate issue.');save();print(json.dumps({'output':str(out),'status':state['overall_status'],'input_scenarios_passed':state['input_scenarios_passed'],'steps':[dict(step=x['step'],status=x['status'],seconds=x['seconds'],checks=len(x['input_checks']),errors=x['error_count'],input_scenario_passed=x['input_scenario_passed']) for x in state['results']]}))
  except Exception as e:state.update(status='EXITED',error=repr(e),ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save();raise
  finally:
   if before is not None:
    after=hashes(ordinary);state.update(ordinary_after=after,ordinary_unchanged=before==after);save()
    if before!=after:raise RuntimeError('Ordinary Godot files changed')
