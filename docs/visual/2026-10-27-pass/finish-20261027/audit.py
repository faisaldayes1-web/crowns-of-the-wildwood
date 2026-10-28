"""Agent: Codex-faisal/crowns_pr_finish. Audit retained evidence without relabelling its source."""
from pathlib import Path
import subprocess,json,hashlib
root=Path(__file__).resolve().parents[1]
def git(*args):return subprocess.check_output(['git',*args])
checks=[]
for folder in ['review','mobile']:
    manifest=json.loads((root/folder/'images.json').read_text())
    for item in manifest['images']:
        path=root/folder/item['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],path
        checks.append(str(path.relative_to(root)))
for name,count in [('d-final',7),('mobile-final-v2-20261027',7),('touch-final-v2-20261027',0)]:
    r=json.loads((root/'checks'/name/'result.json').read_text())
    assert r['exit']==r['errors']==r['script_errors']==r['failures']==0
    assert r['revision']==r['revision_after']=='3c83b964c0216b3c73a6a4acbda5e384295a6e0c'
    assert not r['working_diff'] and not r['source_changed_during_run']
    assert len(r['results'])==count
    if name.startswith('touch'):assert r['passes']==23
    checks.append(name)
base='93365c9'
changed=git('diff','--name-only','3c83b96',base,'--','scripts','assets','scenes','project.godot').decode().splitlines()
expected={'scripts/character_model.gd':'aa6aed4','scripts/visual/character_material_profile.gd':'aa6aed4','scripts/menu.gd':'ab51041','scripts/hud.gd':'ab51041'}
assert set(changed)==set(expected)
for path,ref in expected.items():
    # The integrated capture commit added a trailing blank line to two files.
    assert git('show',f'3c83b96:{path}').rstrip(b'\r\n')==git('show',f'{ref}:{path}').rstrip(b'\r\n'),path
    checks.append(path)
result={'agent':'Codex-faisal/crowns_pr_finish','main':base,'character_head':'aa6aed4','ui_head':'ab51041','capture_source':'3c83b96','passed':len(checks),'checks':checks,'normalization':'Trailing CR/LF only; two integrated files carry one extra blank final line. No other runtime difference.','limits':'Reuses retained source-bound checks. No new engine run. Full bot remains at659ab86; import remains atc6c4e84. No physical-device, sustained-FPS or final art acceptance.'}
(root/'finish-20261027'/'audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
