"""Agent: Codex-faisal. Unaltered image evidence in a side-by-side HTML review."""
from pathlib import Path
import json,shutil,hashlib,html,argparse
p=argparse.ArgumentParser();p.add_argument('captures');p.add_argument('--out',default='docs/visual/2026-10-27-pass/review');a=p.parse_args()
repo=Path(__file__).resolve().parents[2];out=repo/a.out;out.mkdir(parents=True,exist_ok=True)
refs=json.loads((repo/'docs/visual/2026-10-27-pass/selected-references.json').read_text())['references']
screens=['01-title','02-map','03-ready','04-match-spawn','05-live-battle','06-paused-map','07-class-knight']
rows=[];manifest=[]
for screen in screens:
    entries=[('Original built game',Path('C:/ORY-Cache/qa/crowns-20261024-Codex-faisal')/(screen+'.png'))]
    entries.extend((r['set']+' pick '+r['variant'],Path(r['source'])) for r in refs if r['screen']==screen)
    entries.append(('Current built game',Path(a.captures)/(screen+'.png')))
    figures=[]
    for i,(label,source) in enumerate(entries):
        target=out/(screen+'-'+str(i)+'.png');shutil.copy2(source,target)
        manifest.append(dict(screen=screen,label=label,source=str(source),file=target.name,sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
        figures.append(f'<figure><figcaption>{html.escape(label)}</figcaption><a href="{target.name}"><img src="{target.name}" alt="{html.escape(label)}"></a></figure>')
    rows.append(f'<section><h2>{screen}</h2><div class="row">'+''.join(figures)+'</div></section>')
(out/'images.json').write_text(json.dumps(dict(agent='Codex-faisal',images=manifest),indent=2)+'\n')
(out/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><title>Crowns picked visual implementation</title><style>body{background:#17232c;color:#f3ead3;font:16px system-ui;margin:24px}h1{color:#d8aa47}.row{display:flex;gap:12px;overflow:auto}figure{margin:0;min-width:400px;flex:1}img{width:100%;height:300px;object-fit:contain;background:#101820}figcaption{padding:8px 0}section{margin:30px 0}a{color:#e6c66a}</style><h1>Crowns visual implementation review</h1><p>Agent: Codex-faisal. References are selected concepts; current images are actual Godot viewport captures. Click any image for full resolution. Final visual acceptance remains Faisal's.</p><p>Read capture.json and runtime result.json beside the original captures for staged-state and test limitations. The live-battle comparison is a quiet courtyard HUD state, matching its selected source reference; it is not combat-input evidence.</p>'''+''.join(rows))
print(out/'index.html')
