# Ember and Stonekeep visual pass, 2026-11-05 (claude-faisal3)
Task cf-crowns-overnight-1105c. Evidence: docs/visual/2026-11-05-ember-stonekeep/ (left before, right after; compare-* sheets put Wildwood, Twilight, Ember, Stonekeep side by side).

**Ember Pass:** both yards now use the same warm basalt flags as the causeways (`StyleProfile.EMBER.paver_tint`, undoing the build-time soot so the tone matches). The bridges are one unbroken dark-basalt body plaza to plaza under a paved deck, with solid parapets, obsidian copings, pillars with torches, and basalt piers into the lava (no gaps, nothing floating).
**Stonekeep:** the Elves' castle is grey stone like the Humans' (walls, towers, coping, west wall; no ivy), tower roofs carry a snow cap over the team tiles, towers and walls stand in ground snow banks (`SnowCap.add_drift`, one MultiMesh). Lanes (cobbles, passes) untouched and still read on the snow.
**Cache:** `assets/batch_cache.res` and `world_preload.res` rebaked, all 5 maps. `batch_cache_test` passes maps 1-4; map 0 fails "no surface left to the read-back (3 ArrayMesh)", and fails the same on the committed cache at main a2d4046 (4 misses there), so it is not from this change.

## Tests (local, laptop3, Intel Arc iGPU)
Clean import; `world_gate` maps 2 and 3 (crowns, 2 players versus, 600 frames): 0 failures. Windowed bot match, --demo --seed=7 --gfx=2, 1280x720, 45 s after 15 s warm-up, mean fps before -> after: Wildwood 51.3 -> 49.1, Moonlit 46.8 -> 50.8, Ember 36.4 -> 37.2, Stonekeep 46.3 -> 46.2, Twilight 47.0 -> 47.1 (maps 0, 1, 4 have no code change: run noise is about +-4 fps). 1% low: Ember 9.5 -> 15.1 (before had a 662 ms first frame), Stonekeep 22.0 -> 18.9, within the run-to-run spread seen in PR #194.
Not tested: export build, split screen on these maps, fast GPU, CI (Actions capped; Faisal 11-05 allows local evidence).
Agent: claude-faisal3
