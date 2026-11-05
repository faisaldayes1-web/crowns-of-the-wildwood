Codex-faisal2 · cf-crowns-qa-1105f: Reviewer A / gameplay task log.

Analysis only. No game code edits. Reviewer B issue lists have not been read.

## Authority and source

- User task: roles 3 and 6 of `C:/Temp/CROWNS-RELEASE-QA-PLAN-1105.md`.
- Report branch: `qa/reviewA-1105`; initial source `a93e5b47d2f093554c8f28548e2011598fdb53eb`; ownership claim `25b70f4` published before reports.
- Central queue refreshed to `4bc763a`, host `claude-faisal`. Task admission requested by mail `1793902562-d2f427`. Host reply `1793902635-e5af84`: existing `T-e2e8657e7019` prevents a second card; record own task log and mail milestones. No fabricated queue start or reservation.
- Godot 3D. User explicitly permits exported-build playback without editor reservation. No Unity or Godot editor launched.

## Visual coverage

Capture contract: each map needs 16 overhead cells (4x4), eight ground views (bases, centre, bridges/lanes and edges), and one HUD frame at 1920x1080. Capture owner is claude-faisallaptop. Review each full-resolution frame; assign each distinct issue map/cell/filename/pixel rectangle/severity. Top-left image origin; bounds `(x1,y1)-(x2,y2)`. Static suspicion of z-fighting needs a second frame or motion evidence before claiming flicker.

P0: blocks use or safe traversal; P1: major visible defect/UI obstruction; P2: local clear defect; P3: minor artifact. One issue per line; retain issue IDs through recaptures, mark fixed only against named new evidence. Two clean full passes per map are required; missing views never count as clean.

| Map index | Map | Complete capture sets reviewed | Clean full passes | Status |
|---|---|---:|---:|---|
| 0 | Wildwood | 0 | 0/2 | awaiting capture branch |
| 1 | Moonlit Wildwood | 0 | 0/2 | awaiting capture branch |
| 2 | Ember Pass | 0 | 0/2 | awaiting capture branch |
| 3 | Stonekeep Fortress | 0 | 0/2 | awaiting capture branch |
| 4 | Twilight Grove | 0 | 0/2 | awaiting capture branch |

## Checkpoints

- 2026-11-05: read plan first; isolated sparse review checkout excludes Reviewer B reports. Remote had no `qa/captures-1105` at preflight and subsequent dependency check. Mail `1793902576-0eea8f` requests per-map capture manifest/source/dimensions.
- Source preflight: reported LMB attack and 600-second match-clock discrepancies to claude-faisal3 (`1793902697-cc9d7f`); runtime reproduction pending, no game changes.
- Host delivered baseline export from `050bc28`, built `20261105-0649`. New main is `a93e5b4`; newer export expected after P0 combat fix.
- 18:20:02 UTC: launched baseline PID16120 with isolated fresh child-process APPDATA/LOCALAPPDATA `C:/Temp/cqa1105f`. No player's profile moved, copied, overwritten or deleted. Boot produces projectile parse error and game script compile failure; GP-001 is runtime reproduced.
- Computer Use returned `Computer Use was not approved to use crownsofthewildwood`. No screenshot/input succeeded. Requested app access through this session; did not bypass the gate.
- Preserved raw boot log and artifact hash; closed only owned failed process. No match, class, pad, split-screen, screenshot review or clean pass claimed.
- Supplemental follow-up: inspected two pre-existing local WEBP frames (Wildwood 805x746, Stonekeep 1308x773). Logged two suspected intersections and one visible world-label overlap, with pixel bounds and unknown-source/grid caveats. These are not current capture sets or full review passes. Did not copy the Stonekeep desktop notification into repository evidence.
- Host requested a read-only startup audit in mail `1793902973-15a2b8`. Searched all 56 checked-out `scripts/**/*.gd` files for unqualified `free(...)`; only `projectile.gd:169` matched. No additional compile failure proven; no headless/editor launch without a slot.
- Reports/evidence published in `7ba9819`; supplementary visual lists in `d6dad9b`. Host milestone receipt `1793903108-2ee76f`; gameplay fixer receipts `1793903058-6217c2` and `1793903309-08d932`. Initial visual-list mail hit a Git synchronization error; serialized retry delivered as `cf-crowns-reviewA-supp-1105f` at 18:30:01 UTC.
- Host mail `1793903290-2046be` independently reports current-main `a93e5b4` fails the new fresh-export boot gate on the projectile call. Crowns smoke-match hook is assigned to claude-faisal3; Reviewer A remains analysis-only.
- Source follow-up located Stonekeep's paired courtyard rubble and health pickups 1.2 world units apart; added world coordinates and mesh-bound confirmation request to VA-SK-001. Source proximity is not a substitute for current rendered confirmation.
- No gameplay code, scenes, assets or Reviewer B reports changed. Branch diff contains only the own appended claim, QA reports/coverage and raw startup evidence. Raw log trailing whitespace is retained verbatim; documentation diff checks pass.

## Next executable steps

1. Fetch capture branch once published, inspect all 25 expected frames per map, publish `visual-bugs-<map>.md`, mail claude-faisallaptop, and repeat on each recapture.
2. Receive fixed export with source identity, verify hash and fresh boot using a new isolated save directory. Obtain app access before interactive input.
3. Run the complete natural playthrough coverage and mail combat/movement/length findings to claude-faisal3; keep physical and simulated pad evidence distinct.
4. Mail claude-faisal at every milestone. No release signoff until coverage and two clean visual passes per map are complete.
