"""Codex-faisal/gameplay_review; Root review and a current windowed lease REQUIRED.
One owned finite Godot child. Never run automatically by source preparation.
"""
from pathlib import Path
import argparse, datetime, hashlib, json, os, re, stat, subprocess, time

D = Path(__file__).resolve().parent
H = D.parents[2]
FIXTURE_SHA = 'a96234b042cd2bfd108fc2c6ba9d8f983e227e276746ede7e8dd96976c05b309'
ENGINE_SHA = '8c54c617d4837958f2d5ee5020e900820db52371d5c826d9e6b5e5de1e939a1e'
PINS = {
  "project.godot": {
    "raw": "660bd969ee1d633b327581d266647200b6016db34dc235172cd1adff99abe815",
    "lf": "ffe5028df79707129ace921a5700784de4ad0852421505416770552516800f3f"
  },
  "scripts/barricade.gd": {
    "raw": "e08ef53df0a663420988441f964ea06c27295be27b667102e20b3db634741c5e",
    "lf": "441b2c389d78800fce5e90e119e12281feed560ad1dbd0eb8cc8bddb42389788"
  },
  "scripts/blessing.gd": {
    "raw": "44ebe7891e35d3f52dcbdf4ccfc2f69caa6e4d4806a46fab41332f3e4ec82564",
    "lf": "1ec7722c969a34bf8d3f15ca63c6ce4746e27693b3a1a1d797d2327de138c6a8"
  },
  "scripts/character_model.gd": {
    "raw": "038fb76f2537c4395be3ac821bfba9ac1a59efb9d768935266a0b30cd52a5390",
    "lf": "034a461c348da33876a7a20a3b52d9f9abc2048cdfc05dbdf9b9cb75290e7ee6"
  },
  "scripts/critter.gd": {
    "raw": "90edee31c00a7765988c4f139cab435d80adfe41fab8652045d8f55a0d83dcaa",
    "lf": "67846f8a2e1587e01431784dd3ef8e7273e75e5379936ed768a1212ea0e2825d"
  },
  "scripts/economy.gd": {
    "raw": "cbf2c28a96c7ac1af79108c27f9d6cc9cfa9f56a89f0c42c03d797c6ba3ff8f0",
    "lf": "baa393255112b2fab4134e1702852a7cbaf59c1ab70cadb00414ebbd562cb1eb"
  },
  "scripts/face.gd": {
    "raw": "5645fb9a8017604ad8827c08f7f24dc785b9a04127894802f6f6946d8d64d9b9",
    "lf": "582dd38b024be67294dfe49b63595a168dddd600cac7cfc2d8cd6a6956b5a1b8"
  },
  "scripts/fx.gd": {
    "raw": "f0f5cb2e8c14bca70969b25b805fc4951489ef49703a66ed3fb88eccb9f8a466",
    "lf": "f0f5cb2e8c14bca70969b25b805fc4951489ef49703a66ed3fb88eccb9f8a466"
  },
  "scripts/game.gd": {
    "raw": "5a2993e4d70ff81a8a21578872ecd0d5d4164710826a7ac42bff467545b21965",
    "lf": "5a2993e4d70ff81a8a21578872ecd0d5d4164710826a7ac42bff467545b21965"
  },
  "scripts/gate.gd": {
    "raw": "6c306f6a63b94225bfe48728ac18026d46e0d166b21479f6dfaee77a124d523a",
    "lf": "be873d942ae6b82ab31b615017ad9091c085ddebe43ea7b213efdd55f948b0a4"
  },
  "scripts/guide.gd": {
    "raw": "152d023b2bf0abc41cb6156f0cc60076a8edddb298c71558ad2a3f7036931f38",
    "lf": "cf5297b949209d486e6b6924d31f54a2b31a1121601f745e7bfe0b19af41b60b"
  },
  "scripts/headless_mesh_lifetime.gd": {
    "raw": "b0d0d400b34302386a13f1e19a496444c5d77cf4bc5ff3ef45a95f71ab0bb105",
    "lf": "8d6cf1dcaabc18ed75b22e79062024e20db6bc4503520767c198b2b889e3fbbd"
  },
  "scripts/heal_orb.gd": {
    "raw": "ff92e003be39768cf942462d5851ff571fec3a7f97dd8eb39da396333536e580",
    "lf": "f6f41e1d2dedb07b46a6086270acc0b6ec59eb8031ff6975d44c93b0b62a871e"
  },
  "scripts/hud.gd": {
    "raw": "e8dd43f7048a54701e0dd3ed9a0edb95f133560cdfea264cefb863daaa5568b0",
    "lf": "e8dd43f7048a54701e0dd3ed9a0edb95f133560cdfea264cefb863daaa5568b0"
  },
  "scripts/match_summary.gd": {
    "raw": "24b8e14b83423df31106cbed3a60421420725f064ccc8fa3d843515a276b499e",
    "lf": "97b6c533a3964cd9bdff1dfc4a28d18743d39ce4a65a262e25970bbeee3461e8"
  },
  "scripts/menu.gd": {
    "raw": "a0addae4e31079e19d551d6c5feebce29c191d3757490398fd8f1f062e4bfd2c",
    "lf": "7274f732b5a9e7f2cabdec5d26a52134e149392aed3602ae4a86bf27b720f89c"
  },
  "scripts/menu_stage.gd": {
    "raw": "0a23a2a6fad38d2d869e9af159da307ce15e8d58b28603bdea0e4a54da4b002f",
    "lf": "5a93716595a0b97c5cffc65b9a445a6c4d24e68dbee4f171fcda6be5716830c7"
  },
  "scripts/monarch.gd": {
    "raw": "87723dccb3257a27d8d7970b20bf7ea4427d99d8e301cbd29392f91d53d90a3d",
    "lf": "278ecc63ba1ef9008714e328632c76b30a07569d2b472e6cceffae1dff440f92"
  },
  "scripts/outfit_flair.gd": {
    "raw": "ec65a480fd781ef903498b959d791fd9903c8da008dc174b35461b3ae364b05a",
    "lf": "cd70c130e7880e65b318e076edbdd7ece06eba3625a60fd64c83b7413a6e947b"
  },
  "scripts/player_movement.gd": {
    "raw": "ef0a7de44e4bbf3589fd3d29678045cc5626946ccb1dfc72810473ecd7d2a6e4",
    "lf": "ef0a7de44e4bbf3589fd3d29678045cc5626946ccb1dfc72810473ecd7d2a6e4"
  },
  "scripts/projectile.gd": {
    "raw": "c4d43eef77b18684d7a7fbd6fe46557e69232a6b35a5d055f72c6edb88224d80",
    "lf": "3b5f0bf95b3a15a7d985d95b4a9c065ed802568f192e1d66d7e5120e0585acaa"
  },
  "scripts/resource_node.gd": {
    "raw": "aed2e1461093c5ad97845ef9825a30fb8f181f9be0b761d134d3e3820dcaf07c",
    "lf": "74b9fbbaac841ea618c700e49fec1628b079c99f6fdc63c21ca4dee111340452"
  },
  "scripts/save_file.gd": {
    "raw": "46638dfb0fdd39a5d6f4a53a45f05c215eb1340636d2522b1f4d9c8560d3f983",
    "lf": "5d88af87216fb65ad2e35b646f8b214cf5c16ccf63a754312ef331f40d164efc"
  },
  "scripts/scoreboard.gd": {
    "raw": "a3293d4685b93c4e87f9a92f288b297faa8aca95edef880d4f9341b0c794e8f7",
    "lf": "86660c32cafd3f18f20dc1627f0d890daee4599419f89e5289d6f3d7e389c3c3"
  },
  "scripts/seal.gd": {
    "raw": "aec65c321f56b52fd47376dab2288a863f09483505ae22d42d71e5e11b960b63",
    "lf": "14eaf900a11bbae2db583053b320a80466cdc8808a88174f9ecc632f479e96c8"
  },
  "scripts/sfx.gd": {
    "raw": "e16965cee9dea5db724fa5fa654bbd5b6b6b70821ebb457a47c6dfebce39b2b5",
    "lf": "4f0baec1ad9703c0cb6dd0d92bfa8fa24967186d62f75d7449f36e299fda8bf8"
  },
  "scripts/skill_fx.gd": {
    "raw": "5877593dc966d98a8713bebf575c2495c7cf35275422b29889130091b6b5d365",
    "lf": "ed55d3c8163f1764a90e429ab2d280d8ffe41f4bb1ec2dfa8593d8640db92d89"
  },
  "scripts/static_batch.gd": {
    "raw": "d2bc5489ea9df76a86b3bd83bdd8f92789883031e6ec3a0622570ab5a0a7957e",
    "lf": "8a25da20955544b68235ccba3164268e67799772330e7c72a95a2309dfee8110"
  },
  "scripts/stats.gd": {
    "raw": "33dabb236720f5d2919299655867e41e67e2a06141d948ccdffd7675f4e68772",
    "lf": "e722176a6e6116bdf66097d2b4c93ee77e0fa71595083732238b5a89e4317538"
  },
  "scripts/store.gd": {
    "raw": "dcfc621c61d0f27861d1b5308e09e03dc91120f0bfa693583c8d5657d361dedf",
    "lf": "afc3a9bea36affacc7aa56d7acec14cd0ac7da85abacfe61c81f617d4aee98d7"
  },
  "scripts/store_gear.gd": {
    "raw": "d5b4b638d31744368aae35296cfcc956f21cf0b7185d0db1ea976c30598350a8",
    "lf": "22bded201931b8e30530b5ae76edc1187f481f10a1eca24f3b9e7172d0187c26"
  },
  "scripts/title_diorama.gd": {
    "raw": "9a3d643c45f0e181059bb3179e48853340571c9b475497cc2876dfaa1c6bcc3e",
    "lf": "dfdcaeb379fda2b7861505129d3a6f75faa9b4603111eb930bc60c9c7e53c37f"
  },
  "scripts/touch.gd": {
    "raw": "550c6b0c84c0fcfdb734b7785b58b8187d8f68ea57d525baaf784f8ca2f5655f",
    "lf": "3310748874547e90dc6042bd5ed586f5c71952c9efb2b6dea8974936a15a9d8a"
  },
  "scripts/trap.gd": {
    "raw": "bc689ec769cd7545dec310b95b48e5f2bf79e8af33c7727d7bd13d9a3de493ac",
    "lf": "85e10ec290ea2f33e99fb05ad910480ead9196b47cd9356fe551b1722b050632"
  },
  "scripts/turret.gd": {
    "raw": "73ce95c72b836738c413a892fb22960f44b068a712779790a45c375065a737c4",
    "lf": "92c6c5cdaa7821003235b315370015b4915183d699ebb8fd03709f7d6375ecd9"
  },
  "scripts/unit.gd": {
    "raw": "0beb6d1bdc5268db24640c7beace8b6161a59234493eca4824dd99b5f44b9153",
    "lf": "0beb6d1bdc5268db24640c7beace8b6161a59234493eca4824dd99b5f44b9153"
  },
  "scripts/vault.gd": {
    "raw": "7f807f2854cee01d3d422d3c3b09e92a458795a986af102992c618968a412fda",
    "lf": "c6550bd88b550c70724753c4c587f3df107c1a5910d66879997efd9effebe16d"
  },
  "scripts/visual/carved_block.gd": {
    "raw": "1b9913ed5977a85021b73b1de411968ff1f99cffa2ca2a248388178cbbf68fd6",
    "lf": "904f576498a692bf2d55351ac5bf00e63b323b7ad9ddbe63da8a4b410a87a83d"
  },
  "scripts/visual/character_material_profile.gd": {
    "raw": "ef78af23574a0b67f43e4a86557a13751046025b9efad6abb909501cefbe81fd",
    "lf": "6ff9e593289089f6139602fddc4f469bb93aef7cc17a2ae463a8a476b73ebe8e"
  },
  "scripts/visual/season.gd": {
    "raw": "cdb0f888ba118700fdfaedf497893a817fd127de209f58026f2262bd8b29aac2",
    "lf": "9e9b793746a0f121cfad52cb2e004e9f5b85b6ea731172629322274e055d7091"
  },
  "scripts/visual/style_profile.gd": {
    "raw": "f7e02f43e54c35f6ac72440b89d65d595c8f7bea08fa997d5647465b36f550f6",
    "lf": "f7e02f43e54c35f6ac72440b89d65d595c8f7bea08fa997d5647465b36f550f6"
  },
  "scripts/volcano.gd": {
    "raw": "a4643b7cc2654448576d9e1a44de374cff75dd6faa9a1638f76e00d0a98db1a1",
    "lf": "0ac016b15eda39847cb3216f9584b0504b3ac9e4debede8eca52d7a3fbf7ee16"
  }
}
ENGINE = Path('C:/Tools/Godot/Godot_v4.3-stable_win64_console.exe')
PROFILE = Path('C:/Temp/cm6j')
TASK = 'T-2fc4d3bca959'
ERROR = re.compile(r'(?m)^\s*(?:USER )?(?:ERROR|SCRIPT ERROR|Parse Error):')
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')

def raw_error(text):
    return bool(ERROR.search(ANSI.sub('', text)))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def norm(path):
    return os.path.normcase(os.path.abspath(path))

def safe_ancestors(path):
    for item in [path, *path.parents]:
        if item.exists():
            flags = getattr(item.lstat(), 'st_file_attributes', 0)
            assert not item.is_symlink() and not flags & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400), f'Reparse path: {item}'

def input_snapshot(work):
    result = {}
    for rel, pin in PINS.items():
        target = work / rel
        assert target.is_file(), rel
        data = target.read_bytes()
        result[rel] = {'raw': hashlib.sha256(data).hexdigest(), 'lf': hashlib.sha256(data.replace(b'\r\n', b'\n')).hexdigest()}
        assert result[rel] == pin, f'Exact source drift: {rel}'
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--worktree', required=True, type=Path)
    parser.add_argument('--execute-reviewed-sha', required=True)
    args = parser.parse_args()
    assert os.name == 'nt'
    fixture = D / 'codex_faisal_fx_retirement_probe.gd'
    assert args.execute_reviewed_sha == FIXTURE_SHA == sha(fixture), 'Review hash mismatch'
    assert sha(ENGINE) == ENGINE_SHA, 'Different Godot binary'
    work = args.worktree.resolve(strict=True)
    state = json.loads((H/'workforce-control/workforce/state.json').read_text(encoding='utf-8'))
    task = state['tasks'][TASK]
    job = task['engine_job']
    assert state['host'] == task['owner'] == 'Codex-faisal'
    assert 'engine:desktop1:godot' in task['resources']
    assert job['mode'] == 'windowed' and norm(job['worktree']) == norm(work) and norm(job['user_data']) == norm(PROFILE), 'Exact current windowed lease missing'
    before = input_snapshot(work)
    assert not PROFILE.exists(), 'Fresh cm6j required; preserve old data'
    assert not (D/'actual-result.json').exists()
    log_paths = [D/'actual-stdout.log', D/'actual-stderr.log', D/'actual-player.log']
    assert all(not p.exists() for p in log_paths), 'Preserve prior execution logs'
    safe_ancestors(PROFILE)
    safe_ancestors(D)
    PROFILE.mkdir(parents=True)
    env = os.environ.copy()
    for key, suffix in {'APPDATA':'app', 'LOCALAPPDATA':'local', 'XDG_CONFIG_HOME':'xdg-config', 'XDG_DATA_HOME':'xdg-data', 'XDG_CACHE_HOME':'xdg-cache'}.items():
        child = PROFILE/suffix
        child.mkdir()
        env[key] = str(child)
    command = [str(ENGINE), '--path', str(work), '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--windowed', '--resolution', '960x540', '--log-file', str(log_paths[2]), '--script', str(fixture), '--', '--fx-user-root=C:/Temp/cm6j']
    receipt = {'agent':'Codex-faisal', 'task':TASK, 'started':now(), 'fixture_sha256':FIXTURE_SHA, 'runner_sha256':sha(Path(__file__)), 'engine_sha256':ENGINE_SHA, 'command':command, 'inputs_before':before, 'profile':str(PROFILE), 'game_acceptance':False}
    child = None
    reason = None
    offsets = {p:0 for p in log_paths}
    tails = {p:'' for p in log_paths}
    began = time.monotonic()
    try:
        with log_paths[0].open('xb') as out, log_paths[1].open('xb') as err:
            child = subprocess.Popen(command, cwd=work, env=env, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
            receipt['pid'] = child.pid
            while child.poll() is None:
                for path in log_paths:
                    if not path.exists():
                        continue
                    with path.open('rb') as stream:
                        stream.seek(offsets[path])
                        block = stream.read()
                        offsets[path] = stream.tell()
                    text = tails[path] + block.decode('utf-8', errors='replace')
                    if raw_error(text):
                        reason = 'First raw native/script error: '+path.name
                        break
                    tails[path] = text[-4096:]
                if reason:
                    child.kill() # ONLY our Popen-owned handle, never name/PID discovery.
                    break
                if time.monotonic()-began >= 40:
                    reason = '40second external owned-process deadline'
                    child.kill()
                    break
                time.sleep(0.05)
            receipt['exit'] = child.wait(timeout=5)
    except Exception as exc:
        reason = repr(exc)
    finally:
        if child is not None and child.poll() is None:
            child.kill()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                reason = (reason or '') + '; owned cleanup did not confirm exit'
        if child is not None:
            receipt['exit'] = child.returncode
        receipt['ended'] = now()
        receipt['elapsed_seconds'] = time.monotonic()-began
    texts = {p.name:p.read_text(encoding='utf-8', errors='replace') if p.exists() else '' for p in log_paths}
    combined = '\n'.join(texts.values())
    records = []
    malformed = []
    for number, line in enumerate(texts['actual-stdout.log'].splitlines(), 1):
        if line.startswith('C1_FX_RETIREMENT '):
            try:
                records.append(json.loads(line.removeprefix('C1_FX_RETIREMENT ')))
            except json.JSONDecodeError:
                malformed.append({'line':number, 'line_sha256':hashlib.sha256(line.encode()).hexdigest()})
    terminals = [r for r in records if r.get('op') == 'terminal']
    receipt.update(launcher_failure=reason, raw_errors=raw_error(combined), malformed_records=malformed, actual_forward_vulkan=any('Vulkan ' in line and ' - Forward+ - ' in line for line in combined.splitlines()), terminal_records=terminals, phase_names=[r.get('name') for r in records if r.get('op')=='phase'], raw_hashes={p.name:sha(p) if p.exists() else None for p in log_paths})
    try:
        receipt['inputs_after'] = input_snapshot(work)
        receipt['inputs_unchanged'] = receipt['inputs_after'] == before
    except Exception as exc:
        receipt['inputs_unchanged'] = False
        receipt['input_after_error'] = repr(exc)
    last = terminals[-1] if terminals else {}
    receipt['diagnostic_completed_clean'] = bool(child is not None and receipt.get('exit') == 0 and not reason and not malformed and not receipt['raw_errors'] and receipt['actual_forward_vulkan'] and receipt['inputs_unchanged'] and last.get('status')=='COMPLETE_DIAGNOSTIC_NOT_GAME_ACCEPTANCE' and last.get('all_actual_effect_timers_retired') and last.get('effect_children_before_world_free')==0 and last.get('draw_count',0)>=4)
    receipt['limits'] = 'Diagnostic only, no material failure resolved/fullgame/performance claim. Any raw error remains failed evidence; no retry, backend switch, profile/cache deletion or source patch.'
    (D/'actual-result.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'diagnostic_completed_clean':receipt['diagnostic_completed_clean'], 'exit':receipt.get('exit'), 'raw_errors':receipt['raw_errors'], 'failure':reason, 'result':str(D/'actual-result.json')}))
    return 0 if receipt['diagnostic_completed_clean'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
