# Dedicated Crowns visual pass handoff

Agent: Codex-faisal. 2026-10-27. Not a final visual-acceptance claim.

## Reviewable delivery

- World and title: PR76, `Codex-faisal/world/crowns-picked-pass`.
- Character materials: PR77, `Codex-faisal/characters/crowns-picked-pass`.
- Menus/HUD: draft PR78, `Codex-faisal/ui/crowns-picked-pass`.
- Tooling and evidence: draft PR79, `Codex-faisal/crowns-visual-evidence`.
- Skeleton runtime acceptance continues separately in PR75; no runtime replacement or main merge.

All PRs target main0963f03 and were checked mergeable. World precedes UI because the new title controls require its clean backdrop. The combined integration is `Codex-faisal/crowns-visual-pass` at C:/ORY-Cache/worktrees/crowns-visual-pass. The evidence branch contains no combined gameplay implementation; it has tools, records, screenshots and the actual map export.

Read COMPARISONS.md, MOBILE.md and REVIEW.md for seven screens, source revisions and remaining target gaps. The phone images explicitly predate the last touch sizing update. No picks were marked accepted or vaulted.

## Completed validation

Clean import; seven desktop captures; seven phone-size captures; 25 menu-flow assertions; 16 character-material checks; actual4096px clean/labelled map export plus bounds; stable full bot match completed naturally Elves2–0 at simulated375 with zero errors. Raw logs/results are retained. Existing menu-anchor warnings are visible in the raw menu log.

The first rendered touch fixture passed23 assertions but logged a finished-Tween startup error. The test used a five-frame startup guess; a bounded readiness wait is now committed, pending rerun. Never describe the initial touch run as clean. Final touch sizing is a source-reviewed change, not yet renderer-qualified.

## External engine gate

Coordinator message1793089749-451c8d requires assignment/reservation for admitted taskT-2bd6888b5d56 before more Godot starts, including nonperformance captures. Verified task in published shared-workforce branch is proposed/unassigned. The current root ID has a different active faces task; do not reassign or release that other session's work. Requested coordinator register/assign dedicated Codex-faisal/world (or Crowns validation worker). All helpers are idle; no Godot process remains. No queue takeover or queue edit was made.

Final run configuration: source C:/ORY-Cache/worktrees/crowns-visual-pass; output C:/ORY-Cache/qa/crowns-visual-pass-Codex-faisal; per-run isolated saves under C:/Temp/cwv-crowns-final. Runner now enforces logged-error failure and records revision before/after execution.

Once the coordinator reserves the lane, run serially:

1. Fresh desktop and844x390 touch capture sets with tools/crowns_visual_capture.gd (`-- --capture-touch` for phone).
2. tools/menu_flow_test.gd and tools/touch_close_test.gd rendered; inspect any engine errors, not just assertion counts.
3. Natural bot combat capture fixture C:/ORY-Cache/qa/crowns-combat-capture-Codex-faisal/capture.gd with `-- --demo --no-prep --seed=7 --debug-end`; bounded90seconds, native camera, no forced hit/crown state. Fixture neutralizes the debug-end early finish hook.
4. Inspect images, update comparisons/mobile files and result records, and only then clear draft status on78/79. Do not claim physical mobile performance from desktop rendering.

## Costs and provenance

No paid API, Meshy, PixelLab or ComfyUI generation. One built-in imagegen precise-object edit removes UI/logo from selected titleA. Generated file copied to C:/ORY-Cache/style-options/crowns-clean-title-Codex-faisal/title-a-clean-v1.png, then integrated separately as assets/ui/menu/title_picked_a_clean.png. Full prompt/source/hash is in world PR's title-backdrop-provenance.json. External generation credit spend: zero.

Reports to claude-faisal were sent throughout the run, most recently with PR76–79, the exact reservation paths, and zero active Godot processes. Continue hourly while actively running.
