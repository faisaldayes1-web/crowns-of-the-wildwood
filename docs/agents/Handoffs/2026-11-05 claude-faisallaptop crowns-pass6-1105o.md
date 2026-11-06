---
agent: claude-faisallaptop
task: cf-crowns-pass6-1105o (from claude-faisal)
---
# Pass 6 handoff

**Rendering leftovers, fixed.**
- Twilight pool rim "slivers": not geometry and not the outline. They were the kerb's shadow stair-stepping across the transparent water (shadow-map texels). `assets/shaders/water.gdshader` now has `shadows_disabled` (also applies to the river water on the other maps). Before/after crops: docs/evidence/crowns-pass6-1105o/spots (before/ vs wsd/).
- Wildwood boulder streaks: self-shadow acne from the sun's bias. `sun.shadow_bias` 0.03 -> 0.08, `shadow_normal_bias` 1.5 -> 2.2 in `_build_world_sky` (game.gd). Tested 0.1/1.5, 0.03/3.0 and 0/0 first; the chosen pair is clean with no peter-panning visible. Crops: p6x A/B in the PR description frames x4-se-flank-nw (before/ vs after/ wildwood).
- Not fixed: tiny dark hairlines on a few Twilight kerb-brick tops (texture seams, not a rendering fault); moonlit x8 capture eye sits inside a pine canopy (capture camera, not the map).

**Capture grid on all five maps** (24 map shots + HUD shot each, 1080p, Moonlit with --debug-night): docs/evidence/crowns-pass6-1105o/after/<map>/ (+ before/ for Twilight and Wildwood ground shots). Contact sheets reviewed; no new defects found.

**HUD/UI audit against Faisal's complaints** (screenshots in docs/evidence/crowns-pass6-1105o/ui and hud, 1080p): class picker cards are HD busts, no green box (class-banner.jpg); Veteran Training is the wooden board (veteran-training.jpg); Armor menu has live 3D turntable, rendered item thumbnails, 4x2 paged grid (armor-0..5, armor-hat-page2); Level Up strip matches the skill bar plate (hud/p6_levelup_toast_1080p.jpg); player portrait not clipped; Elves shield filled green with leaf. All six already done, nothing to fix. Original complaint images were not on this machine; compared against the descriptions in the mail.

**Windowed class playtest, one match per map** (tools/class_playtest.gd, real input path, LMB held on the target, Knight/Ranger/Mage/Healer/Engineer/Rogue in turn, 900 s clock at 3x): maps 0,1,3,4 finished with only the 6 class-change notes (no stuck, sinking or damage-without-fight). Map 2 first run crashed at engine start (exit 139, `shader_rd.cpp _save_to_cache` file handle null, before any game code; did not repeat on two reruns, unexplained, probably another Godot process writing the shader cache). Its rerun logged ~690 "below the world" notes: false positive, the Ember spawn is the cellar floor (CELLAR_Y -2.4). Driver fixed (cellar floor counts as ground, logs once). Frames show Ember playing normally. Caveat: the driver keeps the player at home on every map, so these matches exercise class abilities and the HUD, not map traversal; the bots decided the scores (0-7 to 0-8 for Humans on most maps).

**Gate:** release export, fresh APPDATA per run, title (900 frames) and `--play --map=0..4` (2400 frames): all exit 0, 0 SCRIPT ERROR / exceptions. Logs docs/evidence/crowns-pass6-1105o/boot/.
