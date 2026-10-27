"""Agent: Codex-faisal3/bugtest. Finite local-only export after separately classified normal-match shutdown error."""
from pathlib import Path
import json,sys,os,subprocess,hashlib,re,datetime as dt,shutil
sys.path.insert(0,'C:/Temp/bugtest');import runner
r=runner.ROOT;repo=Path(sys.argv[sys.argv.index('--repo')+1]);assert repo.resolve()==(r/'crowns-archive-import-fix').resolve();source=json.loads((r/'jobs/crowns-archive-import-fix.json').read_text());out=Path(source['output']);job=r/'jobs/crowns-archive-local-export.json';assert not job.exists()
d=dict(agent='Codex-faisal3/bugtest',runner_pid=os.getpid(),repo=str(repo),output=str(out/'local-export'),status='PREPARING',step='admission',source_sha=source['base_source_sha'],started_at=dt.datetime.now(dt.timezone.utc).isoformat(),results=[],scope='Local canonical Windows release export only; original match diagnostic FAIL preserved, no player launch or binary upload.')
dest=Path(d['output']);dest.mkdir();save=lambda:(runner.atomic_json(job,d),runner.atomic_json(dest/'results.json',d))
def hashed(p):return hashlib.sha256(p.read_bytes()).hexdigest()
save()
with runner.locked('game-crowns') as own,runner.locked('engine-laptop3-godot') as slot:
 try:
  assert own and slot;assert not Path('C:/Temp/ory-remote/Codex-faisal3-bugtest.PAUSE').exists();active=runner.checkout_processes(repo);assert not active,active
  assert source['status']=='EXITED' and len(source['results'])==3 and source['results'][0]['status']=='PASS' and source['results'][1]['status']=='PASS'
  match=source['results'][2];assert match['exit']==0 and any(x.startswith('RESULT ') for x in match['events']) and match['errors']==['ERROR: 10 resources still in use at exit (run with --verbose for details).'];assert match['source_unchanged'] and match['ordinary_profile_unchanged']
  before=json.loads((out/'source-before.json').read_text())['files_sha256'];assert all(hashed(repo/p)==h for p,h in before.items());env=os.environ.copy();env.update(source['profile_env']);shutil.copyfile(Path(__file__),dest/'executed-controller.py');d.update(status='RUNNING',step='local-Windows-release-export');save()
  z=runner.run([runner.GODOT,'--headless','--path',repo,'--export-release','Windows Desktop',dest/'Crowns.exe'],repo,dest/'local-Windows-release-export.log',2400,env=env,source_repo=repo);body=Path(z['log']).read_text(encoding='utf-8',errors='replace');errors=[x for x in body.splitlines() if re.search(r'^ERROR:|SCRIPT ERROR|Parse Error',x)];unchanged=all(hashed(repo/p)==h for p,h in before.items());d['results'].append(dict(step='local-Windows-release-export',status='PASS' if z['exit']==0 and not errors and unchanged else 'FAIL',errors=errors,source_unchanged=unchanged,**z));save();assert z['exit']==0 and not errors and unchanged
  artifact=dest/'Crowns.exe';assert artifact.read_bytes()[:2]==b'MZ';d.update(status='EXITED',step='complete',artifact=dict(path=str(artifact),sha256=hashed(artifact),bytes=artifact.stat().st_size),ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save()
 except BaseException as e:
  d.update(status='EXITED',error=repr(e),ended_at=dt.datetime.now(dt.timezone.utc).isoformat());save();raise
