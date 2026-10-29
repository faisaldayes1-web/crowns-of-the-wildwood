"""Agent: Codex-faisal/crowns. Build an opt-in external-PCK candidate; never install it."""
import hashlib, json, os, pathlib, shutil, subprocess, time

root = pathlib.Path(__file__).parent
source = pathlib.Path('C:/ORY-Cache/worktrees/crowns-68-current-package')
editor = pathlib.Path('C:/Tools/Godot/Godot_v4.3-stable_win64_console.exe')
template = pathlib.Path('C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal/godot/bin/godot.windows.template_release.x86_64.exe')
exe = root / 'CrownsCandidate.exe'
pack = exe.with_suffix('.pck')
expected = 'dba29f8fae628f56bf2155c7d79a6c9801fffaac799a936a3429edbc0d024d3a'
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
assert digest(template) == expected
records = []
def run(name, command, timeout=900):
    user = root / ('userdata-' + name)
    user.mkdir(exist_ok=True)
    (user / '.crowns-throwaway-user-dir').touch()
    env = dict(os.environ, APPDATA=str(user), CROWNS_TEST_USER_BASE=str(user))
    start = time.monotonic()
    proc = subprocess.run(list(map(str, command)), cwd=root, env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    output = proc.stdout.decode('utf-8', errors='replace')
    (root / (name + '.log')).write_text(output, encoding='utf-8')
    item = dict(name=name, command=list(map(str, command)), exit=proc.returncode,
                seconds=round(time.monotonic()-start, 2), errors=output.count('ERROR:'),
                skeleton_errors=output.count('Attempt to disconnect'),
                passes=output.count('PASS '), failures=output.count('FAIL '),
                result=[line for line in output.splitlines() if line.startswith('RESULT')])
    records.append(item)
    (root / 'results.json').write_text(json.dumps(records, indent=2))
    print(json.dumps(item), flush=True)
    assert proc.returncode == 0, item
    return item

run('export-pack', [editor, '--headless', '--path', source, '--export-pack', 'Windows Desktop', pack])
shutil.copy2(template, exe)
(root / 'provenance.json').write_text(json.dumps(dict(agent='Codex-faisal/crowns',
    game_source='9b985b2', source_claim_commit='e3a657f', template_sha256=digest(template),
    package_exe_sha256=digest(exe), package_pck_sha256=digest(pack),
    package_pck_bytes=pack.stat().st_size, mode='external PCK; local opt-in only'), indent=2))
(root / 'isolated.gd').write_text((source / 'tools/tests/isolated.gd').read_text())
for script in ['menu_flow_test.gd', 'kbm_move_test.gd']:
    fixture = root / script
    fixture.write_text((source / 'tools' / script).read_text().replace(
        'res://tools/tests/isolated.gd', (root / 'isolated.gd').as_posix()))
    run(script[:-3], [exe, '--headless', '--script', fixture, '--', '--debug-unlock'])
run('natural-seed7-bot', [exe, '--headless', '--fixed-fps', '60', '--', '--demo', '--seed=7'])
