# claude-faisal3 combat / match length / jitter P0 (11-05)

## Combat
Root cause: unit.gd local_controls() routed the PC basic attack through game.non_primary_attack_held(), which explicitly excludes MOUSE_BUTTON_LEFT, and the default scheme (pc_movement="click") used LMB only for click-to-move goals. A keyboard+mouse player had J and nothing on the mouse. Pad was unaffected.
Fix: default WASD + LMB (hold) basic attack aimed at the cursor; J stays. Click-to-move is the opt-in "click" scheme. Old saves migrate (controls_rev=2). The pad drives everything when it was the last device (pad_active, already swapped on the last press).
projectile.gd:169 bare free() -> queue_free() (fresh-boot parse error reported by Codex-faisal2 on the 050bc28 export; not reproducible from source or a pack here, fixed regardless).
Test: tools/combat_input_test.gd (CI step "Combat through the real input path"): Knight, Ranger, Mage, Engineer (Root Maul), Rogue, Healer: LMB, J and pad (RT + right stick) basic attacks and every damaging skill hurt a dummy. 0 failed x3.
Capture: after-lmb-ranger.png (windowed, Ranger, shot fired with LMB at the cursor, `--smoke-match --smoke-role=2 --smoke-dist=5`).

## Match length (bot raids, headless, 3+2 runs)
Before (first to 2, 600 s): 375 s (2-0), and two 0-0 draws into overtime at 615/642 s.
After first-to-4 / 900 s: 953 s (2-2 + overtime), 687 s (0-4), 605 s (0-4).
Shipped first-to-5 / 900 s: both runs reached the 15 min clock (3-1 and 0-2, leader wins). Humans play slower than bots, so a casual raid lands 12-15 min.
TDM: first to 60 kills / 900 s (a bot match made 43 kills in 600 s, 21-22 a side, so 60 is about 14 min).

Pre-existing, not from this change: tools/controls_live_test.gd fails 3 checks on plain main too (scenery 5 m east / ground ray), and is not in CI.

## Jitter (60 Hz physics on a >60 Hz screen)
Godot 4.3 has no 3D physics interpolation. Units now draw at visual_position() (last two physics positions blended by the physics fraction) and the camera follows it. Probe: `--jitter-probe --probe-frames=200` at ~100 fps. Before: 88-91 of 199 frames did not advance the hero and 108-111 double-stepped. After: 0-1 stalled, 0-6 double.
Idle look left/right: facing now turns with lerp_angle (24/s) and a cursor within 0.9 m of the hero no longer re-aims it.
