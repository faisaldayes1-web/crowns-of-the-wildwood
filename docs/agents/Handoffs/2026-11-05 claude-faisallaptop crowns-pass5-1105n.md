---
agent: claude-faisallaptop
task: cf-crowns-pass5-1105n (from claude-faisal)
---
# Pass 5 handoff

**Playtest review (102 frames in C:/Temp/play, 2x2 contact sheets at 960x540 each, native crops on the odd ones).** Fixed: first-match tip sat under BLESSING!/event banners (now hidden while a big banner is up); notice scroll half behind the LEVEL UP strip (lifts above it); "N kill streak" tag ran onto the Dodge slot; PICK A CLASS plate drew over the minimap on Ember; camera slid across the map after a respawn (now cuts to the cellar, `game.snap_camera`). Not a bug: end screen "YOUR MATCH" zeros were the count-up animation shot on frame 1 (driver now waits 5 s).
**Level UP strip** restyled to the skill bar's slate plate with gold rim and ivy (`_slate_board`). Codex-faisal3's claim on it is taken over here (its branch had no hud.gd change).
**Settings:** merged Codex-faisal3/cf-crowns-settings-1105e; options_test + kbm_move_test pass, 0 errors; 720p captures in docs/evidence/crowns-settings-1105e/720. 1080p/1440p not captured.
**Progress menu** redone (hero header, thick XP bar with numbers above it, rank road with YOU/NEXT, unlock cards with Rogue/Knight-tinted-violet/Moonlit art, small Account corner; ending button says "THE ENDING AT LV 20" because the rank Legend is LV 30). Shots in docs/evidence/crowns-pass5-1105n/progress (720p, levels 1/4/10/25/50). 1080p not captured.
**Hot-plug:** tools/hotplug_test.gd now also holds a key and the stick together and releases both: 0 failed. SIMULATED joypad events; no real pad was attached.
**Reviewer A pass 3 leftovers:** Twilight rim slivers: the streaks hang straight down from the rim edge and survived changing the kerb geometry (30 boxes; islet kerb rebuilt), so they are not geometry; looks like the outline depth pass or the ice at a grazing angle. Reverted, NOT fixed. Wildwood dotted patch: boulder speckle looks like self-shadow acne; the oval patch near the path was not located (boulder spots tried); NOT fixed. Ember barrel: code puts it on the cellar floor beside the shelf (`barrel_large` at CELLAR_Y), left. Capture coverage: tools/map_qa_grid_capture.gd now moves an eye out of foliage/rocks/colliders when blocked, uses the drawn terrain height (Stonekeep courtyard), writes relative manifest paths and a `moved` flag. Run on Twilight only (g7, g8, x5, x6 moved).
**Match lengths (8 captures, 900 s clock), bot demos, seeds 11/12:** every finished run hit 15:00 (map0 2-1; map1 0-1, 0-3; map2 6-1, 2-3; map3 0-6, 0-2; map4 2-1, 0-2); one map0 run was cut off in the batch. Raw lines: docs/evidence/crowns-pass5-1105n/length/results.txt. Pass 4 playtest routs: map0 12:17, map2 13:25. So a rout is 12-14 min, a normal match is the 15:00 clock; no change made.
**Gate:** release export, fresh APPDATA per run, title + 5 maps: see PR.

**Gate result:** release export of this branch, fresh APPDATA each, title (900 frames) and `--play --map=0..4` (2400 frames): all exit 0, 0 SCRIPT ERROR, 0 exceptions; ERROR lines are only exit-time shader/RID leak notices and `skeleton_updated` on the title boot (engine noise). Logs: docs/evidence/crowns-pass5-1105n/boot/.
