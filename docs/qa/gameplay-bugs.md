Codex-faisal2 · cf-crowns-qa-1105f: independent release gameplay QA, 2026-11-05.

Status: **NOT ACCEPTED**. Fresh boot failed before a playable match. No full match, class, keyboard/mouse, pad, or split-screen pass is claimed. No game code edited.

Authority: current user task and `C:/Temp/CROWNS-RELEASE-QA-PLAN-1105.md`, roles 3/6. User acceptance: “LMB basic attack aimed at the cursor” and “length should be 12-15 min, not 2.” Host mail `1793902635-e5af84` identifies the baseline export as source `050bc28`, built `20261105-0649`, and requests testing it while a newer export is prepared.

## GP-001 — P0 — Delivered Windows export cannot compile the game on fresh boot

- Status: **runtime reproduced**, 2026-11-05 18:20:02 UTC, PID 16120; all maps/modes blocked before selection.
- Artifact: `CrownsOfTheWildwood.exe`, 198247648 bytes, SHA256 `7c534a84f6968e004fca63455862484b59e1372942f8edbd35f9695b6dc6978f`, supplied at `C:/Temp/crowns-build-0649-050bc28/`.
- Environment: Godot `4.3.stable.official.77dcf97d8`, Vulkan Forward+, NVIDIA GeForce RTX 5080 Laptop GPU.
- Repro: launch this EXE with a new empty child-process `APPDATA` and `LOCALAPPDATA` directory (actual `C:/Temp/cqa1105f`), using `--windowed --resolution 1280x720 --log-file C:/Temp/cqa1105f/runtime.log`. Do not alter an existing player's save.
- Expected: fresh title screen and playable match without script compilation errors.
- Actual: `Parse Error: Function "free()" not found in base self.` at `res://scripts/projectile.gd:169`; `Compile Error` in `game.gd`; `Failed to load script "res://scripts/game.gd" ... "Compilation failed"`. Subsequent `Invalid Task ID` and repeated Skeleton3D disconnect errors are preserved in the raw log; causal independence is not established.
- Evidence: [raw boot log](../evidence/reviewA-1105/baseline-050bc28/runtime.log), [launch identity](../evidence/reviewA-1105/baseline-050bc28/launch.json). No screenshot is claimed: Computer Use denied access to this app.
- Owner routing: mailed claude-faisal; corrected export and fresh-profile boot required before gameplay recheck. Terminated only the owned failed process after preserving the log; this is not a clean product shutdown pass.

## GP-002 — P1 — Fresh-default PC primary click follows a movement path instead of direct cursor-aimed attack

- Status: **source confirmed; runtime reproduction pending GP-001**. Source reviewed: `a93e5b47d2f093554c8f28548e2011598fdb53eb`; do not equate this source with the older export.
- Repro to run: fresh profile, select a map, obtain Ranger or Mage, point at ground beyond an enemy, press LMB without Shift; repeat over the enemy, at an empty location, while holding movement, and in both PC movement settings. Record projectile appearance, trajectory and actual damage separately.
- Expected: basic attack fires toward the cursor under the user's release acceptance requirement.
- Source evidence: `game.gd:306-307` defaults `pc_movement="click"`, `combine_move_attack=false`; `Unit.local_controls()` calls `game.non_primary_attack_held()` on PC; `game.gd:4665-4666` excludes `MOUSE_BUTTON_LEFT`; `PlayerMovement.resolve()` selects an ordinary primary click as a movement goal. Force-hold can turn primary into attack, which does not satisfy ordinary LMB behavior.
- Related aim check: `Unit._update_player_aim()` overrides aim with the selected attack target's position; verify cursor aiming after the fix. No separate runtime defect asserted yet.
- Owner: claude-faisal3, notified by mail `1793902697-cc9d7f`. Retest both factions, all six classes plus unclassed, all three actions and both input routes. Simulated pad evidence must be labelled simulated.

## GP-003 — P1 — Match timers and early scoring rules do not implement the requested 12–15 minute target

- Status: **source confirmed; natural duration not measured**. Source reviewed: `a93e5b47d2f093554c8f28548e2011598fdb53eb`.
- Repro to run: fresh normal-difficulty match in Crown Raid and Team Deathmatch on each map; measure wall time and game time from FIGHT to results, record team size, score, bot difficulty, outcome, overtime, pauses and input device. Repeat the two-minute scenario if seen. Do not force scores, damage, kills, clocks or simulation speed.
- Expected: normal matches meet the user's 12–15 minute target.
- Source evidence: `stats.gd:404` sets `MATCH_TIME=600`; `stats.gd:419` sets `TDM_TIME=600`; Crown Raid ends immediately on two captures, and TDM immediately on 30 kills. `_end_on_time()` ends an untied match after its 10-minute clock. Overtime is 120 seconds for Crown Raid and 60 for TDM only on ties. No minimum-duration condition appears in `_score_capture()` or `tdm_kill()`.
- Limits: these rules establish a requirements discrepancy, not a measured two-minute match or a specific balance fix. Increasing the clock alone cannot establish natural 12–15 minute matches.
- Owner: claude-faisal3, notified by mail `1793902697-cc9d7f`.

## Remaining acceptance

Every map/mode/class/input combination remains untested. Required movement checks: idle facing left/right, jitter, sliding, corners/stuck recovery, ramps and hills. Required combat checks: basic/Q/E initiation, visible projectile or effect, cursor/pad aim, actual hit/damage or intended support/build effect, cooldown/cost, death/respawn and class switching. Required match checks: bots, natural outcome/duration, results/rematch and split-screen input/HUD separation. Physical pad access is unverified; no simulated or physical pad run has occurred.
