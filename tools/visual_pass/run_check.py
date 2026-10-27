"""Agent: Codex-faisal. Isolated, bounded Godot command with retained evidence."""
import argparse, subprocess, os, json, time
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('name'); p.add_argument('--source',default=str(Path(__file__).resolve().parents[2]))
p.add_argument('--exe',default='C:/Tools/Godot/Godot_v4.3-stable_win64_console.exe')
p.add_argument('--out',default='C:/ORY-Cache/qa/crowns-visual-pass-Codex-faisal')
p.add_argument('--timeout',type=int,default=600)
p.add_argument('args',nargs=argparse.REMAINDER)
a=p.parse_args()
out=Path(a.out)/a.name;out.mkdir(parents=True,exist_ok=True)
save=Path('C:/rt')/('cwv-'+a.name);save.mkdir(parents=True,exist_ok=True)
(save/'.crowns-throwaway-user-dir').touch()
env=os.environ.copy();env.update(APPDATA=str(save),CROWNS_TEST_USER_BASE=str(save),CROWNS_CAPTURE_DIR=str(out),CROWNS_VISUAL_OUT=str(out))
extra=a.args[1:] if a.args[:1]==['--'] else a.args
cmd=[a.exe,'--path',a.source,'--log-file',str(out/'engine.log'),*extra]
start=time.monotonic()
r=subprocess.run(cmd,cwd=a.source,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=a.timeout)
(out/'stdout.log').write_text(r.stdout,encoding='utf-8')
body=(out/'engine.log').read_text(encoding='utf-8') if (out/'engine.log').exists() else r.stdout
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=a.source,text=True).strip()
diff=subprocess.check_output(['git','diff','--stat'],cwd=a.source,text=True).strip()
report=dict(agent='Codex-faisal',source=a.source,revision=revision,working_diff=diff,command=cmd,exit=r.returncode,seconds=round(time.monotonic()-start,2),errors=body.count('ERROR:'),script_errors=body.count('SCRIPT ERROR'),passes=body.count('PASS'),failures=body.count('FAIL'),user_data_base=str(save),results=[x for x in body.splitlines() if x.startswith(('RESULT','CAPTURE','MAP_EXPORT','PROF frames'))])
(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)
raise SystemExit(r.returncode)
