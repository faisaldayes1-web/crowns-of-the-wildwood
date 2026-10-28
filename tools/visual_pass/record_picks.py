"""Agent: Codex-faisal. Bind direct owner selections to unchanged source bytes."""
from pathlib import Path
import json, hashlib

gallery = Path('C:/ORY-Cache/style-options/crowns-goals')
out = Path(__file__).resolve().parents[2] / 'docs/visual/2026-10-27-pass'
manifest = json.loads((gallery / 'options.json').read_text())
picks = {'GAME': {'01-title':'A','02-map':'A','04-match-spawn':'D','05-live-battle':'A','06-paused-map':'B','07-class-knight':'B'},
         'UI': {'01-title':'D','02-map':'A','03-ready':'A','04-match-spawn':'C','05-live-battle':'C','06-paused-map':'C','07-class-knight':'C'}}
records = []
for group, screens in picks.items():
    for screen, variant in screens.items():
        option = next(o for o in manifest['options'] if o['set']==group and o['screen']==screen and o['variant']==variant)
        path = gallery / option['file']
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if option.get('sha256') and digest != option['sha256']:
            raise ValueError(f'Gallery hash mismatch: {path}')
        records.append(dict(id=option['id'],file=path.name,source=str(path),sha256=digest,screen=screen,set=group,variant=variant))
out.mkdir(parents=True,exist_ok=True)
(out/'selected-references.json').write_text(json.dumps(dict(agent='Codex-faisal',authority='Faisal direct session instruction 2026-10-27, picks dated 2026-10-25',status='selected; implementation acceptance pending',references=records),indent=2)+'\n')
print(f'Bound {len(records)} selected references to verified bytes')
