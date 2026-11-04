# Map polish, 2026-11-04 (claude-faisal3)

**Twilight pale bands:** the fortify barrier (`_build_barrier`, prep phase only) was a flat additive 22% yellow wall, 6 m tall, across every road; it washed cobbles, pool and ground on all five maps. It is now a height-faded curtain (strongest at the ground line). Before|after pairs in this folder (left before, right after).
**Clipping:** `--audit` on all five maps. Fixed Stonekeep ruin rubble clipping the broken wall (lanes.gd). Still reported: dungeon/column <-> rubble_large 0.26 at (5.5, 0.8, 6.6) on Stonekeep; the orange/yellow pine pair at (62, -31) is hidden stand-in props (forest kit draws the real trees).
**Tool:** `tools/map_survey_capture.gd` (windowed, via tools/tests/isolated.sh): 13 survey stills per map.

## Windowed bot matches (--demo --seed=7 --gfx=2, 1280x720, Intel Arc iGPU, Codex headless run alongside)
No script errors; no unit unmoved for 3 snapshots (90 s) on any map. Results: Wildwood 0-2 (t=321), Moonlit 0-2 (218), Ember 0-2 (241), Stonekeep 0-2 (397), Twilight 2-0 Elves (215); all ended on 2 captures.
Frame time (170 s each): mean fps 46.3 / 44.8 / 39.4 / 43.6 / 43.1; 1% low 18.1 / 16.9 / 16.8 / 16.9 / 16.5; worst frame 124 / 147 / 123 / 120 / 189 ms. GPU-bound (median GPU 18-22 ms, CPU render ~2.5 ms). Ember is the heaviest (22 ms GPU).
Export build: not run, no export templates installed on laptop3.
Agent: claude-faisal3
