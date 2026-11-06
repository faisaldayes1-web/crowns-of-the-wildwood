"""Local Windows release export + fresh-profile boot. Agent: Codex-faisal3.
No uploads; only the child process created here is terminated on slot expiry.
"""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    global ROOT
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--godot', required=True)
    ap.add_argument('--export-home', required=True, help='Existing verified template cache APPDATA')
    ap.add_argument('--until', required=True, help='Hard slot end, ISO8601 with timezone')
    ap.add_argument('--project', help='Read-only comparison checkout; default this project')
    ap.add_argument('--suite', default='settings-1105e')
    args = ap.parse_args()
    if args.project:
        ROOT = Path(args.project).resolve()
    end = datetime.fromisoformat(args.until).timestamp() - 3
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    out = ROOT / ('docs/evidence/crowns-' + args.suite)
    out.mkdir(parents=True, exist_ok=True)
    build = ROOT / 'build' / ('settings-' + source[:7])
    if build.exists():
        raise SystemExit('Use a new source-specific build destination; existing exports are preserved')
    build.mkdir(parents=True)
    (build.parent / '.gdignore').touch()
    exe = build / 'Crowns.exe'
    receipts = []

    def run(label, cmd, env, timeout, engine_log=None):
        remaining = end - time.time()
        if remaining < 2:
            raise SystemExit('Slot ended; no process started')
        started = time.time()
        log = out / (label + '.log')
        print('RUN', label, flush=True)
        with log.open('w', encoding='utf-8') as f:
            f.write(json.dumps({'source': source, 'command': cmd}) + '\n')
            f.flush()
            p = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT,
                                 creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            try:
                code = p.wait(timeout=min(timeout, remaining))
            except subprocess.TimeoutExpired:
                subprocess.run(['taskkill', '/PID', str(p.pid), '/T', '/F'], capture_output=True)
                p.wait(timeout=15)
                code = 124
        raw = log.read_text(encoding='utf-8', errors='replace')
        if engine_log and engine_log.exists():
            raw += engine_log.read_text(encoding='utf-8', errors='replace')
        errors = [l for l in raw.splitlines() if any(t in l for t in
                  ['SCRIPT ERROR', 'ERROR:', 'leaked at exit', 'still in use at exit'])]
        if 'Godot Engine v4.3' not in raw:
            errors.append('Missing engine boot header')
        receipt = dict(label=label, source=source, command=cmd, exit=code,
                       seconds=round(time.time()-started, 3), errors=errors,
                       script_error_count=sum('SCRIPT ERROR' in line for line in raw.splitlines()),
                       log=log.name, engine_log=str(engine_log) if engine_log else None)
        if exe.exists():
            receipt.update(executable=str(exe), sha256=hashlib.sha256(exe.read_bytes()).hexdigest(), bytes=exe.stat().st_size)
        receipts.append(receipt)
        (out / 'release-results.json').write_text(json.dumps(receipts, indent=2)+'\n', encoding='utf-8')
        print(json.dumps(dict(label=label, source=source, exit=code,
                              seconds=receipt['seconds'], error_count=len(errors), errors=errors[:3])), flush=True)
        if code or errors:
            raise SystemExit(1)

    export_env = dict(os.environ, APPDATA=args.export_home,
                      LOCALAPPDATA=str(Path(args.export_home) / 'local'))
    run('release-export', [args.godot, '--headless', '--path', str(ROOT),
                           '--export-release', 'Windows Desktop', str(exe)], export_env, 240)
    if not exe.is_file():
        raise SystemExit('Export missing')
    profile = Path(tempfile.mkdtemp(prefix='c3release-', dir='C:/Temp'))
    boot_env = os.environ.copy()
    for name in ['APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
        p = profile / name.lower()
        p.mkdir()
        boot_env[name] = str(p)
    engine_log = out / ('release-boot-' + source[:7] + '-engine.log')
    run('release-boot', [str(exe), '--windowed', '--resolution', '1280x720',
                         '--max-fps', '60', '--quit-after', '2400', '--log-file', str(engine_log)],
        boot_env, 180, engine_log)
    receipts[-1].update(executable=str(exe), sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                        bytes=exe.stat().st_size, fresh_profile=str(profile))
    (out / 'release-results.json').write_text(json.dumps(receipts, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
