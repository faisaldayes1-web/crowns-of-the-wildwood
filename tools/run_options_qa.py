"""Serial native evidence runner. Agent: Codex-faisal3, cf-crowns-settings-1105e.

Run only inside the operator's acquired Godot slot. Each process has its own
throwaway save directory and this checkout's own import cache. No builds upload.
"""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import struct
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/crowns-settings-1105e"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--godot", required=True)
    ap.add_argument("--stage", choices=["import", "boot", "tests", "captures", "bot", "all"], default="all")
    ap.add_argument("--test", action="append", choices=["options_test", "steam_ready_test", "settings_restart_test", "kbm_move_test", "options_menu_test", "pad_nav_test", "menu_flow_test", "couch_audio_test"])
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--until", help="hard engine-slot end as ISO8601 with timezone; reserves 3 seconds for cleanup")
    args = ap.parse_args()
    slot_end = datetime.fromisoformat(args.until).timestamp() - 3 if args.until else None
    OUT.mkdir(parents=True, exist_ok=True)
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    results = []

    def run(label, command, timeout=400, capture_dir=None):
        if slot_end is not None:
            remaining = slot_end - time.time()
            if remaining < 2:
                raise SystemExit("Engine slot ended; no new process launched")
            timeout = min(timeout, remaining)
        tracked = subprocess.check_output(["git", "ls-files", "scripts", "tools/" + label + ".gd", "tools/run_options_qa.py", "project.godot"], cwd=ROOT, text=True).splitlines()
        source_files = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in tracked}
        profile = Path(tempfile.mkdtemp(prefix="c3cs-", dir="C:/Temp"))
        (profile / ".crowns-throwaway-user-dir").touch()
        env = os.environ.copy()
        for name in ["APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            target = profile / name.lower()
            target.mkdir()
            env[name] = str(target)
        env["CROWNS_TEST_USER_BASE"] = str(profile)
        if capture_dir:
            env["CROWNS_CAPTURE_DIR"] = str(capture_dir)
        cmd = [args.godot, "--path", str(ROOT)] + command
        if args.verbose:
            cmd.append("--verbose")
        print("RUN", label, flush=True)
        started = time.time()
        log = OUT / (label + ".log")
        flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        with log.open("w", encoding="utf-8") as f:
            f.write(json.dumps({"source": source, "command": cmd, "user_data": str(profile)}) + "\n")
            f.flush()
            p = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT, creationflags=flags)
            try:
                code = p.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                # Only terminate the process this runner created.
                # The Windows console executable owns a GUI child as well.
                if os.name == "nt" and p.poll() is None:
                    subprocess.run(["taskkill", "/PID", str(p.pid), "/T", "/F"], capture_output=True)
                else:
                    p.terminate()
                p.wait(timeout=30)
                code = 124
        raw = log.read_text(encoding="utf-8", errors="replace")
        bad = [line for line in raw.splitlines() if any(token in line for token in ["SCRIPT ERROR", "Parse Error", "ERROR:", "FAIL ", "FAIL  ", "leaked at exit", "still in use at exit"])]
        if label == "bot-seed7" and not ("\nRESULT winner=" in raw and "\nSTAT " in raw):
            bad.append("Bot did not reach a final RESULT and STAT report")
        if capture_dir:
            expected = ["before-settings"] if label.startswith("before-") else ["after-" + t for t in ["gameplay", "video", "audio", "controls", "accessibility"]]
            requested = command[command.index("--resolution") + 1]
            dimensions = tuple(map(int, requested.split("x")))
            for name in expected:
                png = capture_dir / (name + ".png")
                if not png.exists() or struct.unpack(">II", png.read_bytes()[16:24]) != dimensions:
                    bad.append("Missing or wrongly sized capture: " + str(png))
        result = {"label": label, "source": source, "exit": code, "seconds": round(time.time() - started, 2), "errors": bad, "log": log.name, "profile": str(profile),
                  "files": source_files, "slot_end": args.until}
        results.append(result)
        (OUT / (args.stage + "-results.json")).write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: v for k, v in result.items() if k != "files"}), flush=True)
        if code or bad:
            raise SystemExit(1)

    if args.stage in ["all", "import"]:
        run("import", ["--headless", "--editor", "--import"], timeout=600)
    if args.stage in ["all", "boot"]:
        run("fresh-boot", ["--headless", "--max-fps", "60", "--quit-after", "2400"], timeout=600)
    if args.stage in ["all", "tests"]:
        for test in ["options_test", "steam_ready_test", "settings_restart_test", "kbm_move_test", "options_menu_test", "pad_nav_test", "menu_flow_test", "couch_audio_test"]:
            if args.test and test not in args.test:
                continue
            run(test, ["--headless", "--fixed-fps", "60", "--script", "tools/" + test + ".gd"], timeout=600)
    if args.stage in ["all", "captures"]:
        for width, height in [(1280, 720), (1920, 1080), (2560, 1440)]:
            for before in [True, False]:
                label = ("before-" if before else "after-") + str(height) + "p"
                run(label, ["--resolution", f"{width}x{height}", "--script", "tools/options_capture.gd", "--"] + (["--before"] if before else []), capture_dir=OUT / str(height))
    if args.stage in ["all", "bot"]:
        run("bot-seed7", ["--headless", "--fixed-fps", "60", "--quit-after", "45000", "--", "--demo", "--seed=7"], timeout=1200)


if __name__ == "__main__":
    main()
