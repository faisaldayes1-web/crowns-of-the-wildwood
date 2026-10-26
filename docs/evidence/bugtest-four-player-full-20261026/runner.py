"""Agent: Codex-faisal3/bugtest. Finite headless packaged controller-route qualification."""
import sys,json,os,datetime as dt,hashlib,shutil,subprocess,re
from pathlib import Path
sys.path.insert(0,'C:/Temp/bugtest');import runner
r=runner.ROOT;repo=runner.tester_repo('crowns');out=r/'cycles'/dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')/'crowns';out.mkdir(parents=True);job=r/'jobs/crowns-packaged-four-full.json';state=dict(agent='Codex-faisal3/bugtest',runner_pid=os.getpid(),status='PREPARING',repo=str(repo),output=str(out),started_at=dt.datetime.now(dt.timezone.utc).isoformat(),results=[])
def save():runner.atomic_json(job,state);runner.atomic_json(out/'results.json',state)
def hashes(root):return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()} if root.exists() else {}
def guard():
 if Path('C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE').exists():raise RuntimeError('PAUSE retained')
 if runner.checkout_processes(repo):raise RuntimeError('Preserve adopted Crowns group')
with runner.locked('engine-laptop3-godot') as slot:
 if not slot:raise SystemExit('Godot busy')
 with runner.locked('game-crowns') as own:
  if not own:raise SystemExit('Crowns busy')
  ordinary=Path(os.environ['APPDATA'])/'Godot/app_userdata';before=None
  try:
   guard();source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True,creationflags=subprocess.CREATE_NO_WINDOW).strip();exp=next(g for g in json.loads((r/'jobs/godot-native-exports.json').read_text())['games'] if g['game']=='crowns');base=Path(exp['output']);exe=base/'build/crowns.exe'
   if source!=exp['source_sha']:raise RuntimeError('Package no longer current')
   dirty=subprocess.check_output(['git','diff','--name-only','--','project.godot','scripts','scenes'],cwd=repo,text=True,creationflags=subprocess.CREATE_NO_WINDOW,stderr=subprocess.DEVNULL).strip()
   if dirty:raise RuntimeError('Preserve changed production source')
   for rel,meta in exp['artifacts'].items():
    if hashlib.sha256((base/rel).read_bytes()).hexdigest()!=meta['sha256']:raise RuntimeError('Package hash changed')
   before=hashes(ordinary);env=os.environ.copy();profile=out/'isolated-profile'
   for k in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME']:
    d=profile/k;d.mkdir(parents=True);env[k]=str(d)
   bot=out/'crowns-four-full.gd';shutil.copy2(r/'setup/crowns_four_full_input.gd',bot);state.update(status='RUNNING',source_sha=source,artifacts=exp['artifacts'],package=str(exe),source_files_sha256={f:hashlib.sha256((repo/f).read_bytes()).hexdigest() for f in ['project.godot','scripts/game.gd','scripts/menu.gd']},bot_sha256=hashlib.sha256(bot.read_bytes()).hexdigest(),ordinary_root=str(ordinary),ordinary_hashes_before=before);save()
   def execute(label,args,timeout):
    guard();state['step']=label;save();res=runner.run([exe,'--headless',*args],exe.parent,out/(label+'.log'),timeout,env,source_repo=repo);text=Path(res['log']).read_text(encoding='utf-8',errors='replace');errors=[x for x in text.splitlines() if re.search(r'SCRIPT ERROR|Parse Error|^ERROR:',x)];checks=[json.loads(x.split('BUGTEST_CHECK ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_CHECK ')];results=[json.loads(x.split('BUGTEST_RESULT ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_RESULT ')];res.update(step=label,status='PAUSED' if res['exit']==3 else 'BLOCKED' if res['exit']==92 else 'PASS' if res['exit']==0 and not errors else 'FAIL',errors=errors,error_count=len(errors),input_checks=checks,input_results=results,input_scenario_passed=res['exit']==0 and bool(results) and all(x['failures']==0 for x in results));state['results'].append(res);save();return res,text
   res,text=execute('actual-packaged-user-path',['--script',r/'setup/godot_user_path_probe.gd','--','--bugtest-user-prefix='+env['APPDATA']],45);paths=[json.loads(x.split('BUGTEST_USER_PATH ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_USER_PATH ')];qualified=res['status']=='PASS' and len(paths)==1 and Path(paths[0]['actual']).resolve().is_relative_to(Path(env['APPDATA']).resolve());state['storage_qualification']=dict(qualified=qualified,records=paths);save()
   if not qualified:raise RuntimeError('Actual user path unqualified; no gameplay input')
   execute('native-four-player-full-match',['--script',bot,'--fixed-fps','60'],960)
   state.update(status='EXITED',ended_at=dt.datetime.now(dt.timezone.utc).isoformat(),overall_status='PASS' if all(x['status']=='PASS' for x in state['results']) else 'FAIL',limits='Headless exact current package and native engine queued virtual pad events plus normal UI mouse only. No forced menu/split/start/prep/outcome API. Fullmatch/rematch/reward scope only when actual BUGTEST_RESULT full_match true; no physical controller/connection/disconnection/rendered/style/performance acceptance. Engine errors retain overall FAIL even if input assertions pass.');save();print(json.dumps(dict(output=str(out),status=state['overall_status'],results=[dict(step=x['step'],status=x['status'],checks=len(x['input_checks']),input_scenario_passed=x['input_scenario_passed'],errors=x['error_count'],seconds=x['seconds']) for x in state['results']])))
  except Exception as e:state.update(status='EXITED',error=repr(e),ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save();raise
  finally:
   if before is not None:
    after=hashes(ordinary);state.update(ordinary_hashes_after=after,ordinary_unchanged=before==after);save()
    if before!=after:raise RuntimeError('Ordinary Godot files changed')
