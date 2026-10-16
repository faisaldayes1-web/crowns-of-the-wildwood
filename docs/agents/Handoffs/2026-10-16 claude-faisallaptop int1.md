---
agent: claude-faisallaptop
task: CW-2 integration + 2 new maps + visual pass + lag fix (night queue 2026-10-16)
pr: https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/31
branch: claude-faisallaptop/int1
---
# Handoff: int1 (claude-faisallaptop, 2026-10-16)

## What changed
- **Integration:** PRs #8, #13, #9, #6 and #17 were merged into `claude-faisallaptop/int1` in that order with merge commits (no rebase). Conflicts were only in `stats.gd`/`store.gd` (kept #8's Wildwood store collection and NEW ribbon, which #13 lacked), one `game.gd` hunk (kept #13's `slider_drag`/`menus_warming`) and the changelogs (kept both; #8's entry where both logged the same merge). #4 is not included because it overlaps #17. Its 3 Ember Pass castle commits that #17 lacks (690a07e, bff5758, 13c6327) are still open on #4. CW-1 (issue #25) had not landed: Codex's cloud environment was never created, so I worked out the order myself. #8 contains almost everything, and #17 is entirely inside #6 apart from one merge of main.
- **New maps:** Stonekeep Fortress (winter) and Twilight Grove (dusk), `Stats.MAPS` 3 and 4, both on the Wildwood layout (same routes, colliders and bot paths). Code is in `scripts/visual/season.gd`: colour grade, ground textures, light, snow drifts, ice floes, snowmen, mushroom rings and motes. The SELECT MAP cards that said COMING SOON now open them, and the minimap follows the season.
- **Visual pass:** drifting air on every map (pollen, fireflies, embers, snow, motes) and a brighter moon in the Moonlit Wildwood.
- **Lag:** static batching (`scripts/static_batch.gd`), a warm-up under the loading art (models and shaders), split-screen budget (HUD redraws, shadows), lighter default primitives, GPU ambient particles, and small caches. Details are in `docs/changelog/int1-maps-perf.md` and the PR.

## Tested
- Headless import: no script errors.
- `--demo --selftest` combat checks: 0 failures.
- `tools/map_switch_test.gd -- --debug-unlock`, extended to all five maps (16 picks, 12 back-to-back matches including split screen): 325 checks, 0 failures.
- A 6-minute headless bot match per map with batching on, 0 script errors: Wildwood Elves 2-0 (t=219), Moonlit full 6 min 0-0, Ember Pass Humans 2-0 (t=200), Stonekeep Humans 2-0 (t=234), Twilight full 6 min 1-0.
- `tools/batch_safety_scan.gd` on all five maps (two seeds on Wildwood and Moonlit): nothing the batcher merges moves, hides, is freed or changes material during a whole match.
- Profiles (`tools/match_profile.gd`, 1920x1080, High, vsync off) and screenshots: see the PR.

## Not tested
- Online play on the new maps (ENet/relay; `tools/net_map_switch_test.gd` and `net_smoke.sh` were not run). A joiner builds the world from the host's `map_variant`, so it should work, but it is unverified.
- The web/iPad build. Batching also runs there; GPU particle conversion and the warm-up are desktop-only.
- Real gamepads in split screen (the 4-player runs used idle local players with bots around them).
- A cold shader cache: the warm-up sweep was not measured on a fresh install. The first run of the day showed 13 stalls of ~0.5 s before the warm-up existed.

## Next steps
- Faisal: review and merge #31; decide whether Stonekeep and Twilight should unlock at an account level like Moonlit (they're open to everyone now); decide what happens to #4's 3 castle commits.
- Perf, if wanted: 4-player split still has 1% lows of 26–29 fps under load. The HUD redraws (~4.5 ms per HUD in my measurement) and model rebuilds (~7 ms) are the next things to cut.

## Spend
- Meshy / PixelLab: none. Installs: none (Godot 4.3-stable was already at C:\Users\faisa\Tools\Godot_4.3).
