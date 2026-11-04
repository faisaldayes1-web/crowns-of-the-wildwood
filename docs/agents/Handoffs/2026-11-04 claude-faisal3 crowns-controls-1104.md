# Crowns controls verification, click-to-move sidestep, shorter match-start warm-up

Agent: claude-faisal3. Task `crowns-controls-1104` from claude-faisal (coordinator), branch `claude-faisal3/crowns-controls-1104` from main 37ad43a. Note: the Agent Board claim row is added in this PR, not pushed ahead of the edits (rule 2); the files touched are listed in it and none is claimed by another agent.

## 1. Controls (camera-relative, Diablo-style PC mouse, couch)
Codex-faisal's controls (PR "camera-relative controls", `scripts/player_movement.gd`) were already merged. This task verified them with **real injected input in a real match** and fixed what that found.

- New `tools/controls_live_test.gd` (windowed; the headless root viewport is 64x64 so mouse coordinates do not map): real `Input.warp_mouse` + injected mouse buttons, wheel and keys through the game's own camera and ground ray. Checks: click walks to the point and stops there; holding LMB keeps walking and turns round when the cursor goes to the other side; releasing leaves no goal; Shift+LMB attacks in place (no goal, only the melee lunge); wheel tick force-moves with attack suppressed; W/A/S/D walk up/left/down/right **on screen** whatever the hero faces; a direction key cancels a click goal; couch 2: mouse in pane 1 walks player 1 only, a click over pane 2 moves nobody, seat 2 has no mouse. Result: **0 failures** (`logs/controls_live_test.log`). `tools/pad_split_test.gd` (4-pad couch routing) and `tools/pad_nav_test.gd` pass unchanged.
- **Bug found and fixed.** A click straight behind a pillar corner left the hero pressed against it for a second and then dropped the goal. Reproduced at the Wildwood spawn: the hero starts at (-85.5, -4) with a stone brazier pillar just east; clicking 5 m east stopped 3.36 m short (`logs/controls_live_test_OLD_player_movement.log`). `PlayerMovement` now sidesteps along the obstacle (75 degrees off the goal for 0.25 s, once to each side), and still ends a goal behind a real wall within ~2.2 s (was ~1.5 s) because it gives up when sidestepping brings it no 0.5 m closer. After: arrives 0.17 m off.
- New pure-logic `tools/player_movement_test.gd` (27 checks, in CI): camera-relative directions for yaws 0/30/90/180/-135 and a pitched camera, analog magnitude, click goal, hold-to-follow, key cancel, Shift attack-in-place, force move/pulse, pillar sidestep (fails on old code: stops 5.0 m short), long walk after a sidestep still arrives, endless wall is dropped in 2.2 s.
- `tools/kbm_move_test.gd` asserted the superseded "W walks toward the cursor" rule (4 FAILs on main); it now asserts the camera-relative contract and passes. It is not in CI.
- Not changed: bindings and defaults (click-to-move default, WASD opt-in under Controls, wheel/M4 force move, Shift hold). Evidence: `controls_demo.webp` (short clip, frames every 5th render frame), `01_click_walking.jpg`, `02_shift_attack_in_place.jpg`, `03_wasd.jpg`, `04_couch_start.jpg`, `05_couch_after.jpg`.

## 2. Menu-to-match load, frame time, memory
Machine: Intel Arc iGPU, 1920x1080, vsync on, Godot 4.3 Forward+, `tools/match_start_run.gd --world-behind --probe-press=25 --probe-live=6` (world already built behind the title, like a player who has looked at the title for a while). Isolated user dir, so the Godot shader cache is cold each run. Raw PROBE lines in `perf/`.

Heaviest map by geometry is index 3 (16.1 M primitives, 6.6 k mesh instances, 128 omni lights; map 4 15.3 M; map 0 13.5 M; map 2 6.9 M).

| Map | PLAY to match visible, before | after |
|---|---|---|
| 3 (heaviest) | 3.15, 3.18, 3.18 s (+3.22, 3.26, 3.22 s replicate) | 2.50, 2.58, 2.53 s (+2.48, 2.54 s on 15 s runs) |
| 0 | 3.26 s | 2.60 s |
| 2 | 2.55 s | 2.28 s |
| 4 | 3.40 s | 3.29 s |

Change: `scripts/game.gd` `_warm_up_world` drew **two** frames at each of its 21 camera spots under the loading art; it now draws one (42 to 21 drawn frames). Measured saving is ~0.7 s, i.e. ~35 ms per dropped frame; I did not verify inside the engine that the first draw does all the pipeline work, only that live hitching did not change in 15 s windows. Live frames are unchanged: map 3 over a 15 s live window, before 17.9 / 18.0 fps and after 17.7 / 17.9 fps, one frame over 100 ms in three of four runs, worst 93-139 ms before vs 125 ms after (`perf/*long*`).

Frame time and memory: **unchanged, no improvement claimed.** Live frames on map 3 are ~55 ms (18 fps) on this iGPU, GPU-draw bound (draw 20-40 ms; 2.6-3.2 k draw calls, 15.7 M primitives); video memory ~1.05-1.10 GB on every map. `tools/gfx_cost_probe.gd` (new) switches omni lights, SSAO, SSIL, glow, HUD, render scale, cascades and shadow distance off one at a time on map 3; the base-to-base drift (up to 18 ms) was larger than any single effect (omni lights 2-13 ms, SSAO 5-7 ms, SSIL -1 to 11 ms, HUD -6 to 9 ms across repeats), so none is a trustworthy target on this machine. Needs a quiet GPU or a second machine.

Also seen, not changed: from PLAY at t=0 the first ~0.5 s are 200 ms CPU chunks (match build) and ~0.8 s are 80-130 ms GPU frames (first draw of the world, shader/pipeline work), then 30-60 ms frames until the art fades.

## 3. Maps
- The translucent pale bands over the Twilight cobbles (reported in the previous PR) are the **fortify barrier**: one additive 0.3 x 6 x 84 m wall down the middle (alpha 0.22), seen at an angle during prep. Not a rendering bug.
- Real remaining spot, **not fixed**: on map 3 (Stonekeep winter) the east cobble road ends ~100 px short of the courtyard floor with a rounded end, and the courtyard's snow verge has a rough, jagged edge (`docs/evidence/claude-faisal3-crowns-push-1104/after_m3_road.jpg`, right middle). Left alone: needs a road-generator change plus before/after captures on all lane maps; I did not want to land it blind.
- Wildwood crate stacks on the road remain by design. No map changes in this PR.

## Not tested / limits
- No real controllers, no touch, no packaged export, no online/net tests, no real human feel pass; the live test injects events.
- `tools/codex_faisal_movement_test.gd`: 24 pass, 3 FAIL (`legacy test save written`, `migration preserves...`, `second load preserves...`), before and after this change; its save fixture looks stale against the stricter save validation from the save-recovery PR. Not in CI, not touched.
- `tools/controls_live_test.gd` is windowed-only and is not in CI. `tools/gfx_cost_probe.gd` is a local tool.
- Load numbers are one machine, one GPU, shared with other agents' jobs (3 runs per map-3 cell; 1 per other cell).
