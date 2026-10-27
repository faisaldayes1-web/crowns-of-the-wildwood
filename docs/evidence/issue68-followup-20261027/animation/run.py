"""Agent: Codex-faisal/characters. Headless by default; --render requires root GPU authorization."""
from pathlib import Path
import os,sys,subprocess,json,hashlib
base=Path(__file__).parent
exe=Path('C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal/godot/bin/godot.windows.template_release.x86_64.exe')
pack=Path('C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal/crowns-main.exe')
render='--render' in sys.argv
save=Path('C:/rt')/('c68-anim-render' if render else 'c68-anim-headless')
save.mkdir(parents=True,exist_ok=True)
(save/'.crowns-throwaway-user-dir').touch()
env=os.environ.copy();env.update(APPDATA=str(save),CROWNS_TEST_USER_BASE=str(save),C68_RENDER_SEQUENCE='1' if render else '0')
mode='rendered' if render else 'headless'
cmd=[str(exe),*(['--resolution','1280x720'] if render else ['--headless']), '--main-pack',str(pack),'--script',str(base/'animation.gd'),'--log-file',str(base/(mode+'.engine.log'))]
r=subprocess.run(cmd,cwd=base,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
(base/(mode+'.stdout.log')).write_text(r.stdout)
body=(base/(mode+'.engine.log')).read_text()
if (base/'animation-result.json').exists():
    (base/(mode+'-result.json')).write_bytes((base/'animation-result.json').read_bytes())
report=dict(agent='Codex-faisal/characters',command=cmd,appdata=str(save),exit=r.returncode,engine_errors=body.count('ERROR:'),skeleton_disconnects=body.count('Attempt to disconnect'),warnings=[x for x in body.splitlines() if 'WARNING:' in x or 'resources still' in x],exe_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),pack_sha256=hashlib.sha256(pack.read_bytes()).hexdigest())
(base/(mode+'-run.json')).write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
sys.exit(r.returncode)
