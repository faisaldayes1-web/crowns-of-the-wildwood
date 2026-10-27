"""Agent: Codex-faisal/crowns. Rendered runtime comparison, isolated saves."""
from pathlib import Path
import subprocess, os, json, time, hashlib, sys
p=Path(__file__).parent
prior=Path('C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal')
source=Path('C:/Games/crowns-of-the-wildwood')
(p/'isolated.gd').write_text((source/'tools/tests/isolated.gd').read_text())
s=(source/'tools/map_switch_test.gd').read_text().replace('res://tools/tests/isolated.gd',(p/'isolated.gd').as_posix())
s=s.replace('var route := [1, 2, 3, 4, 0, 2, 4, 1, 3, 0, 3, 1, 4, 2, 0, 4, 3, 2, 1, 0]','var route := [3, 0]')
s=s.replace('var matches := [[2, false], [0, false], [1, false], [2, false], [2, true], [0, true], [1, true], [3, false], [4, false], [3, true], [4, true], [0, false]]','var matches := [[0, false], [3, true]]')
s=s.replace('and not couch and not captured.has(v)', 'and not captured.has(v)')
s=s.replace('\tg._finish(0)', '''\t# Exercise the real model replacement path; no game source modification.
\tfor role in [Stats.Role.KNIGHT, Stats.Role.RANGER, Stats.Role.MAGE, Stats.Role.BASE]:
\t\tg.player.set_role(role)
\t\tawait _frames(30)
\t\tcheck(g.player.role == role, "%s: class role %d applied" % [what, role])
\t\tawait RenderingServer.frame_post_draw
\t\troot.get_texture().get_image().save_png(evidence.path_join("map-%d-class-%d.png" % [v, role]))
\tg._finish(0)''')
(p/'rendered.gd').write_text(s)
results=[]
short='--short' in sys.argv
for name,exe in [('official',Path('C:/ORY-Cache/qa/crowns-68-codex-faisal/templates/windows_release_x86_64.exe')),('msvc',prior/'godot/bin/godot.windows.template_release.x86_64.exe')]:
    out=p/(name+'-short' if short else name); out.mkdir(exist_ok=True)
    save=Path('C:/rt')/('c68r-'+name) if short else out/'userdata'
    save.mkdir(exist_ok=True);(save/'.crowns-throwaway-user-dir').touch()
    env=os.environ.copy();env.update(APPDATA=str(save),CROWNS_TEST_USER_BASE=str(save),CROWNS_MAP_EVIDENCE=str(out))
    log=out/'engine.log'
    cmd=[str(exe),'--main-pack',str(prior/'crowns-main.exe'),'--resolution','1280x720','--windowed','--script',str(p/'rendered.gd'),'--log-file',str(log),'--','--debug-unlock']
    start=time.monotonic()
    r=subprocess.run(cmd,env=env,cwd=p,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=600)
    (out/'stdout.log').write_text(r.stdout)
    text=log.read_text() if log.exists() else r.stdout
    result=dict(agent='Codex-faisal/crowns',name=name,exit=r.returncode,seconds=round(time.monotonic()-start,2),command=cmd,errors=text.count('ERROR:'),disconnects=text.count('Attempt to disconnect'),passes=text.count('PASS '),failures=text.count('FAIL '),images=[x.name for x in out.glob('*.png')],sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
    results.append(result);(p/('results-short.json' if short else 'results.json')).write_text(json.dumps(results,indent=2));print(json.dumps(result),flush=True)
