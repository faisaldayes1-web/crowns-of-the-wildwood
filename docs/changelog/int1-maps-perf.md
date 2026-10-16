# int1: integration, two new maps, visual pass, lag fix (claude-faisallaptop)

Branch `claude-faisallaptop/int1`, one PR for Faisal (2026-10-16 night queue). Newest entry at the top.

### 2026-10-16 ~11:00 UTC · int1 · Lag fix, Stonekeep Fortress, Twilight Grove, visual pass

- **What (lag):**
  - `scripts/static_batch.gd` (new) merges the static scenery at match start: ~8,300 separate meshes become ~1,300, one per material per 24 m cell; 2,085 duplicate materials collapse to ~520. Clouds, water wheels, the fortify barrier, Ember Pass's core and its recoloured ring are tagged `no_batch` and stay as they are. Primitives left at Godot's 64-segment default are re-tessellated for their size: 248 default spheres had been half of the world's triangles. Long-lived ambient CPU particles become GPU particles (desktop only).
  - `game._warm_up_world`: under the loading art, every class and promotion model is built once per team, then the camera sweeps the map, so first-use shader compiles and model loads (0.5 s stalls on a fresh install, 55-65 ms per first model) happen before the fight.
  - Split screen: pane HUDs redraw on alternate frames, staggered; only the window's HUD runs `menu_tick` (it ran once per pane too); with 3-4 panes, lamp cube shadows are off in the panes and the sun uses 2 cascades.
  - Small fixes: `Face.hair_color` cached (it read the skin back from the GPU on every model rebuild); `key_label` cached for 0.5 s; `world_style` stays on during the match, so runtime props use the style textures instead of loading the originals from disk mid-fight.
- **What (maps):** Stonekeep Fortress (winter) and Twilight Grove (dusk), both on the Wildwood layout (`scripts/visual/season.gd`, new): a seasonal colour grade (team colours and glowing cues kept), snow / dusk-meadow ground textures (`tools/make_textures.py make_snow make_twilight_grass`), their own light, snowfall, snow drifts, ice floes and snowmen; glowing mushroom rings, blooms and motes. `Stats.MAPS` indices 3 and 4; the SELECT MAP cards that said COMING SOON now open them, and the lobby's map tiles fit five.
- **What (visual pass):** drifting air on every map (pollen by day, fireflies at night, embers and ash on Ember Pass, snow, dusk motes); a brighter moon and ambient in the Moonlit Wildwood (`StyleProfile.NIGHT` 0.5/0.55/0.14 → 0.6/0.75/0.2).
- **Files:** scripts/static_batch.gd, scripts/visual/season.gd (new); scripts/game.gd, scripts/hud.gd, scripts/menu.gd, scripts/stats.gd, scripts/face.gd, scripts/volcano.gd, scripts/visual/style_profile.gd; assets/textures/snow_*, grass_twilight_*; tools/make_textures.py, tools/map_switch_test.gd; tools/match_profile.gd, render_ab.gd, cost_ab.gd, hud_ab.gd, mesh_census.gd, batch_safety_scan.gd, model_bench.gd (new).
- **Tunables:** `StaticBatch.CELL` 24 m, `MAX_VERTS` 200,000; `--no-batch` turns batching off for A/B tests; `Season.AIR` (particles per map).
- **Tested:** see the PR (headless import, combat self-test, map switch test across 5 maps, a 6-minute bot match per map, batch safety scans per map, profiles, screenshots).
- **Revert:** `git revert` the int1 commits after the merges; `--no-batch` alone turns batching off.
