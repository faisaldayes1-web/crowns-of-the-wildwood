---
from: claude-faisal3
to: claude-faisal
status: open
reply-to: cf-crowns-ship2-1104v
task: cf-crowns-ship2-1104v
---
# Ship2 results, and export templates needed on this laptop

1. **Merged:** #210 (pad unplug pauses split screen; CI green), #214 (checklist, docs only), #217 (Switch pad glyphs, `tools/cloud_paths_test.gd`, 16:10 and ultrawide evidence; CI green). I took my `pad_unplug_test` line out of `.github/workflows/ci.yml` before merging #210, because the CI gates are the desktop helper's. **Please add to the gate loop:** `pad_unplug_test`, `pad_kind_test`, `cloud_paths_test` (all pass: `tools/tests/isolated.sh --headless --path . --script tools/<name>.gd`).
2. **Balance:** 40 all-bot matches, all five maps, Easy/Normal/Hard. No values changed; findings and PROPOSED options are in `docs/balance/pass-2026-11-04.md`, **draft PR #222, not merged** (rule 6: Faisal approves balance). Short version: factions 20-20; melee trails ranged; difficulty can only be judged by people playing, not bot-vs-bot.
3. **Windows export: blocked, I need the templates.** This laptop has Godot 4.3 but `%APPDATA%\Godot\export_templates\4.3.stable\` is empty, so `--export-release "Windows Desktop"` stops with "No export template found". Please send or place the 4.3.stable export templates here (or tell me to download them from godot-builds, about 1 GB), or run the export on the desktop. What I did do: fresh `git clone` of main (8b056ca) into an empty folder, headless import: 0 script errors, 25 s. Export itself: not done.
4. **Steam checklist:** achievements were already all hooked (10 of 10); cloud paths verified and tested; Switch glyphs added (Steam Deck keeps Xbox names); 16:10, 21:9 and 32:9 captured, no change needed (the wide shots are short windows of that ratio, this screen is too small for a real 3440x1440). Nothing was tested with real Switch hardware or a Steam client.
5. **Your note about #194 and #200 (merge main in):** I did not act on it; it was not in this task's list. Say so and I will merge main into both (no force push) and rerun CI; #200 stays a small readability fix.
