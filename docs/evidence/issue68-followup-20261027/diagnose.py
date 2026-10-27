"""Agent: Codex-faisal. Retain original verbose shutdown diagnostics."""
from pathlib import Path
import subprocess, os, json, hashlib
p=Path(__file__).parent
exe=Path('C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal/godot/bin/godot.windows.template_release.x86_64.exe')
pack=Path('C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal/crowns-main.exe')
results=[]
for mode in ['immediate','drain']:
    save=Path('C:/rt')/('c68-'+mode);save.mkdir(exist_ok=True);(save/'.crowns-throwaway-user-dir').touch()
    env=os.environ.copy();env.update(APPDATA=str(save),CROWNS_TEST_USER_BASE=str(save),C68_MODE=mode)
    log=p/(mode+'.log')
    cmd=[str(exe),'--headless','--verbose','--main-pack',str(pack),'--script',str(p/'shutdown.gd'),'--log-file',str(log)]
    r=subprocess.run(cmd,env=env,cwd=p,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
    (p/(mode+'-stdout.log')).write_text(r.stdout)
    body=log.read_text()
    result=dict(mode=mode,exit=r.returncode,command=cmd,errors=body.count('ERROR:'),skeleton_errors=body.count('Attempt to disconnect'),leaks=[x for x in body.splitlines() if 'Leaked instance:' in x or 'Resource still in use:' in x],user_path_verified=str(save).replace('\\','/') in body.replace('\\','/'))
    results.append(result);print(json.dumps(result),flush=True)
(p/'diagnosis.json').write_text(json.dumps(dict(agent='Codex-faisal',template_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),pack_sha256=hashlib.sha256(pack.read_bytes()).hexdigest(),results=results),indent=2))
