#!/usr/bin/env python3
"""Agent: Codex-faisal. Read-only Steam depot inventory; never uploads files."""
import argparse
import hashlib
import json
from pathlib import Path

REQUIRED = (
    "CrownsOfTheWildwood.exe",
    "steam_api64.dll",
    "libgodotsteam.windows.template_release.x86_64.dll",
)


def inspect_depot(root: Path) -> dict:
    errors = []
    files = []
    if root.is_symlink() or not root.is_dir():
        return {"status": "FAIL", "errors": ["Depot must be a real directory"], "files": []}
    try:
        for name in REQUIRED:
            path = root / name
            if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
                errors.append(f"Missing, empty or linked required file: {name}")
        for path in sorted(root.rglob("*")):
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                errors.append(f"Linked entry is not a self-contained depot file: {relative}")
                continue
            if not path.is_file():
                continue
            if path.name.casefold() == "steam_appid.txt":
                errors.append(f"Development App ID file must not ship: {relative}")
            digest = hashlib.sha256()
            with path.open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(block)
            files.append({"path": relative, "bytes": path.stat().st_size, "sha256": digest.hexdigest()})
    except OSError as exc:
        errors.append(f"Cannot inspect depot: {exc}")
    return {"status": "FAIL" if errors else "PASS", "errors": errors, "files": files}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("depot", type=Path)
    args = parser.parse_args()
    report = inspect_depot(args.depot)
    report["scope"] = "File inventory only; does not certify binaries, App ID, licences or Steam readiness."
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
