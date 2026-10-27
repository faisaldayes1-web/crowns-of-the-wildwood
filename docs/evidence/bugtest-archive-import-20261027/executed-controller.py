"""Agent: Codex-faisal3/bugtest. Finite cold import, isolated natural AI match, local export."""
from pathlib import Path
import sys,os,json,datetime as dt,hashlib,subprocess,re,shutil
sys.path.insert(0,'C:/Temp/bugtest');import runner
root=runner.ROOT;repo=Path(sys.argv[sys.argv.index('--repo')+1]);assert repo.resolve()==(root/'crowns-archive-import-fix').resolve()
job=root/'jobs/crowns-archive-import-fix.json';assert not job.exists(),'Adopt existing work rather than launching duplicate'
out=root/'cycles'/dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')/'crowns-archive-import-fix';out.mkdir(parents=True)
d=dict(agent='Codex-faisal3/bugtest',runner_pid=os.getpid(),repo=str(repo),output=str(out),base_source_sha='9b985b200f5ae4c59ef128cb405ea2db6c37cd1b',status='PREPARING',step='admission',started_at=dt.datetime.now(dt.timezone.utc).isoformat(),results=[],scope='Single docs/evidence/.gdignore candidate; cold import and unmodified production AI seed7 full match at fixed60Hz, local Windows release export. No native player inputs, rendering, style approval, physical-controller or performance acceptance.')
def save():runner.atomic_json(job,d);runner.atomic_json(out/'results.json',d)
def hashed(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):h.update(block)
 return h.hexdigest()
def snapshot(folder):return {str(p.relative_to(folder)):hashed(p) for p in folder.rglob('*') if p.is_file()} if folder.exists() else {}
def guard():
 assert not Path('C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE').exists(),'PAUSE retained'
 others=[p for p in runner.checkout_processes(repo) if p['ProcessId']!=os.getpid()];assert not others,others
save()
with runner.locked('game-crowns') as own,runner.locked('engine-laptop3-godot') as slot:
 try:
  assert own and slot;guard();assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()==d['base_source_sha']
  paths=subprocess.check_output(['git','ls-files','-z'],cwd=repo,creationflags=subprocess.CREATE_NO_WINDOW).decode().split(chr(0));before={p:hashed(repo/p) for p in paths if p and (repo/p).is_file()};before['docs/evidence/.gdignore']=hashed(repo/'docs/evidence/.gdignore');runner.atomic_json(out/'source-before.json',dict(agent=d['agent'],files_sha256=before))
  ordinary=Path(os.environ['APPDATA'])/'Godot/app_userdata/Crowns of the Wildwood';ordinary_before=snapshot(ordinary);runner.atomic_json(out/'ordinary-profile-before.json',dict(agent=d['agent'],path=str(ordinary),files=ordinary_before))
  env=os.environ.copy()
  for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME']:
   p=out/'private-profile'/key;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
  manifest=json.loads((root/'tools/godot-4.3-export-templates/verified.json').read_text());assert manifest['official_sha512']==manifest['actual_sha512'];templates=Path(manifest['template_directory']);dest=Path(env['APPDATA'])/'Godot/export_templates/4.3.stable';dest.mkdir(parents=True)
  for name,meta in manifest['files'].items():assert hashed(templates/name)==meta['sha256'];shutil.copyfile(templates/name,dest/name)
  d['profile_env']={k:env[k] for k in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME']};shutil.copyfile(Path(__file__),out/'executed-controller.py');save()
  phases=[('cold-headless-import',[runner.GODOT,'--headless','--editor','--path',repo,'--import','--quit'],1800),('actual-user-data-path',[runner.GODOT,'--headless','--path',repo,'--script',root/'setup/godot_user_path_probe.gd','--','--bugtest-user-prefix='+env['APPDATA']],90),('natural-production-ai-seed7',[runner.GODOT,'--headless','--path',repo,'--fixed-fps','60','--quit-after','45000','--','--demo','--seed=7'],1800),('local-Windows-release-export',[runner.GODOT,'--headless','--path',repo,'--export-release','Windows Desktop',out/'build/Crowns.exe'],2400)]
  for label,args,limit in phases:
   guard();(out/'build').mkdir(exist_ok=True);d.update(status='RUNNING',step=label);save();z=runner.run(args,repo,out/(label+'.log'),limit,env=env,source_repo=repo);body=Path(z['log']).read_text(encoding='utf-8',errors='replace');errors=[line for line in body.splitlines() if re.search(r'^ERROR:|SCRIPT ERROR|Parse Error',line)];warnings=[line for line in body.splitlines() if 'WARNING:' in line];unchanged=all(hashed(repo/p)==h for p,h in before.items());ordinary_unchanged=snapshot(ordinary)==ordinary_before;events=[line for line in body.splitlines() if line.startswith(('RESULT ','STAT ','Capture:','Match over:','Overtime','Battle begins:'))];passed=z['exit']==0 and not errors and unchanged and ordinary_unchanged
   if label=='actual-user-data-path':passed=passed and 'BUGTEST_USER_PATH ' in body
   if label=='natural-production-ai-seed7':passed=passed and any(line.startswith('RESULT ') for line in events) and any(line.startswith('Match over:') for line in events)
   d['results'].append(dict(step=label,status='PASS' if passed else 'FAIL',errors=errors,warnings=warnings,events=events,source_unchanged=unchanged,ordinary_profile_unchanged=ordinary_unchanged,**z));save();assert passed,'Preserve raw import/match/export/guard failure; no later phase'
  player=out/'build/Crowns.exe';assert player.read_bytes()[:2]==b'MZ';d.update(artifact=dict(path=str(player),bytes=player.stat().st_size,sha256=hashed(player)),status='EXITED',step='complete',ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save()
 except BaseException as e:
  import traceback
  d.update(status='EXITED',error=repr(e),ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save();(out/'controller-error.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
