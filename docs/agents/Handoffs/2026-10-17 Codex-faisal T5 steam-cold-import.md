---
agent: Codex-faisal
task: T5 crowns-code / CW-4 T01
status: implementation ready; engine qualification pending
---

# Steam cold-cache import

- Claim `8af53f24fea6242e3d5a227fdfc5172099ec8411` pushed before editing.
- Create the temporary `.godot` directory before writing the extension list; explicitly use `--editor --quit` for the import phase.
- `tools/tests/steam_build_test.sh`: cold and warm cache fixtures PASS using a fake exporter. Checks extension registration, terminating import flags and no development App ID file in shipping output. No real Steam export/upload occurs.
- Full-project import: installed Godot 4.7.2, exit 0, no SCRIPT ERROR / Parse Error / ERROR in the verified log. Sandbox settings-save errors were resolved by rerunning outside the sandbox with workspace-isolated APPDATA. Seed-7 README bot run started; full result pending when this handoff was written.
- Not qualified: required Godot 4.3 + GodotSteam 4.15 final export, Steam client, physical inputs and platform matrix. Claude 2 must review the exact head and perform final export qualification. This is not a release approval.
- No runtime/gameplay/assets changed. #29, #33 and T3 writing branch untouched. Meshy/PixelLab: 0 credits. No installs, merges or uploads.
