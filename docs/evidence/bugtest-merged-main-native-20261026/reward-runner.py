"""Agent: Codex-faisal3/bugtest. Reuse COPIED earned tester profile, native loot/restart."""
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys,time
sys.path.insert(0,'C:/Temp/bugtest')
import runner
r=runner.ROOT;repo=r/'crowns-main-0963-full';cycle=r/'cycles'/dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')/'crowns';cycle.mkdir(parents=True)
job=r/'jobs/crowns-main-0963-reward.json';data=dict(agent='Codex-faisal3/bugtest',runner_pid=os.getpid(),status='PREPARING',output=str(cycle),started_at=dt.datetime.now(dt.timezone.utc).isoformat(),results=[])
def save():runner.atomic_json(job,data);runner.atomic_json(cycle/'results.json',dict(data,name='crowns'))
def hashes(base):return {str(p.relative_to(base)):hashlib.sha256(p.read_bytes()).hexdigest() for p in base.rglob('*') if p.is_file()}
def guard():
 if Path('C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE').exists():raise RuntimeError('PAUSED; retained stop file')
 start=__import__('time').monotonic()
 while runner.checkout_processes(repo):
  if __import__('time').monotonic()-start>300:raise RuntimeError('Preserve adopted source/engine children; resume existing work')
  __import__('time').sleep(5)
  if Path('C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE').exists():raise RuntimeError('PAUSE retained')
with runner.locked('engine-laptop3-godot') as slot:
 if not slot:raise SystemExit('Preserve busy Godot engine')
 with runner.locked('game-crowns') as own:
  if not own:raise SystemExit('Preserve busy Crowns game')
  original=None;before=None;ordinary=Path(os.environ['APPDATA'])/'Godot/app_userdata';ordinary_before=hashes(ordinary)
  try:
   guard();prior=json.loads((r/'jobs/crowns-main-0963-native.json').read_text());source=Path(prior['output']);qualified=json.loads((source/'results.json').read_text());actual=next(v for v in qualified['results'] if v['step']=='native-four-coop')
   if prior['status']!='EXITED' or not actual.get('input_scenario_passed'):raise RuntimeError('Prior native objective not complete/qualified')
   if not actual['input_results'][0].get('full_match') or len(actual['input_checks'])<45 or not all(c['pass'] for c in actual['input_checks']):raise RuntimeError('Require actual full four-player outcome and input qualification')
   exp=dict(output=prior['output'],source_sha=prior['source_sha'],artifacts=prior['artifacts']);base=Path(exp['output']);exe=base/'build/crowns.exe'
   sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True,creationflags=subprocess.CREATE_NO_WINDOW).strip()
   if sha!='0963f03bc52f7dcca786e2a3bc3703a74b7edde2' or sha!=qualified['source_sha'] or sha!=exp['source_sha']:raise RuntimeError('Source/package mismatch')
   for rel,meta in exp['artifacts'].items():
    if hashlib.sha256((base/rel).read_bytes()).hexdigest()!=meta['sha256']:raise RuntimeError('Changed packaged artifact')
   data.update(status='RUNNING',source_sha=sha,source_repo=str(repo),original_native_full_match=str(source),artifacts=exp['artifacts']);save()
   original=source/'profiles/four-coop';before=hashes(original);profile=cycle/'isolated-profile';shutil.copytree(original,profile)
   data['original_profile_hashes_before']=before
   env=os.environ.copy()
   for key in ('APPDATA','LOCALAPPDATA','XDG_DATA_HOME'):env[key]=str(profile/key)
   bot=cycle/'crowns-reward-bot.gd';shutil.copy2(r/'setup/crowns_main_reward_input.gd',bot);data['input_bot_sha256']=hashlib.sha256(bot.read_bytes()).hexdigest()
   def execute(step,args):
    guard();res=runner.run([exe,'--headless',*args],exe.parent,cycle/(step+'.log'),120,env,source_repo=repo)
    text=Path(res['log']).read_text(errors='replace');errors=[x for x in text.splitlines() if re.search(r'SCRIPT ERROR|Parse Error|^ERROR:',x)]
    res.update(step=step,status='PASS' if res['exit']==0 and not errors else ('BLOCKED' if res['exit']==92 else 'FAIL'),errors=errors,input_checks=[json.loads(x.split('BUGTEST_CHECK ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_CHECK ')],input_results=[json.loads(x.split('BUGTEST_RESULT ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_RESULT ')])
    data['results'].append(res);save();return res,text
   res,text=execute('actual-packaged-user-path',['--script',r/'setup/godot_user_path_probe.gd','--','--bugtest-user-prefix='+env['APPDATA']])
   paths=[json.loads(x.split('BUGTEST_USER_PATH ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_USER_PATH ')]
   ok=res['status']=='PASS' and len(paths)==1 and Path(paths[0]['actual']).resolve().is_relative_to(Path(env['APPDATA']).resolve());runner.atomic_json(cycle/'storage-qualification.json',dict(qualified=ok,records=paths))
   if not ok:raise RuntimeError('Actual copied-profile storage not qualified; no UI launch')
   p1=Path(paths[0]['actual'])/'profiles/p1.cfg';expected=cycle/'expected-earned-profile.cfg';shutil.copy2(p1,expected)
   for step,extra in [('native-earned-chest-open',[]),('native-reward-restart',['--bugtest-reward-restart'])]:
    res,text=execute(step,['--script',bot,'--fixed-fps','60','--','--expected-profile='+str(expected),*extra])
    res['input_scenario_passed']=res['exit']==0 and bool(res['input_results']) and all(x['failures']==0 for x in res['input_results'])
    res['wallets']=[json.loads(x.split('BUGTEST_WALLET ',1)[1]) for x in text.splitlines() if x.startswith('BUGTEST_WALLET ')]
    save()
    if not res['input_scenario_passed']:break
    expected=cycle/'expected-opened-profile.cfg';shutil.copy2(p1,expected)
   data['overall_status']='PASS' if all(v['status']=='PASS' for v in data['results']) else 'FAIL'
   data.update(status='EXITED',ended_at=dt.datetime.now(dt.timezone.utc).isoformat(),limits='Fresh main0963 Windows package; native fixture differs from retained original only by PAUSE guard. COPY of genuine four-player natural-defeat earned tester save, native mouse UI only. Original profile hash-guarded. No seeded XP/gold/chests, direct store/gameplay API or rendered/physical-device claim. Engine diagnostics retained separately.');save()
  except Exception as e:
   data.update(status='EXITED',error=repr(e),ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save();raise
  finally:
   if original is not None and before is not None:
    after=hashes(original);data['original_profile_hashes_after']=after;data['original_profile_unchanged']=before==after;save()
    if before!=after:raise RuntimeError('Original earned profile unexpectedly changed')
   ordinary_after=hashes(ordinary);data['ordinary_unchanged']=ordinary_after==ordinary_before;save()
   if ordinary_after!=ordinary_before:raise RuntimeError('Ordinary userdata changed')
