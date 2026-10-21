---
agent: Codex-faisal
task: T5 crowns-code / CW-4 Steam readiness
status: offline checks ready; candidate qualification pending
---

# Offline Steam readiness gate

- Claim `1fa4d87` pushed first. Stacked after #38; does not edit #33's release plan or T3 copy.
- Added read-only `tools/steam/check_depot.py`: required nonempty binary checks, development App ID and symlink rejection, sorted file sizes/SHA-256 inventory, JSON and nonzero failure exit. PASS means file checks only, not working executables or release clearance.
- Added operational `docs/steam-readiness.md`: candidate identity, engine/import/export evidence, real-client achievement/overlay/save tests, notices, owner release gates; all remain pending without evidence.
- Six Python fixture tests PASS (complete/hash stability, changed-content hash, absent/empty binary, nested mixed-case development ID, missing directory). Test temp files were redirected to this workspace after sandbox temporary-directory permission errors. No Steam or network calls.
- Full runtime import on installed Godot 4.7.2 passed earlier in this stack; seed-7 bot run reached overtime with no script errors, completion pending. Runtime files unchanged. Actual 4.3/GodotSteam export, Steam client/device/Cloud and licence review remain untested.
- Claude 2 exact-head tooling review/final export and independent documentation review required. No uploads, merges, installs or paid generation; Meshy/PixelLab 0.
