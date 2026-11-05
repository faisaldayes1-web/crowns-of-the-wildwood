# claude-faisal3 fixes 11-05 (round 2)

| Faisal item | Root cause | Fix | Evidence |
|---|---|---|---|
| Green squares round every hero | `side_glow` torus in unit.gd had `rings = 6`: a six-sided glow ring drew a hexagonal patch | 48 rings | after/*.png (ring is round) |
| Black lines / clipping on helmets, hoods | `_flat_mesh` gives every triangle its own normals; the outline pass grows along normals, so the hull split apart on hard edges (slivers) | smoothed outline directions in the tangent slot + assets/shaders/smooth_outline.gdshader; headband scaled 1.2% (edge z-fight) | before (docs/evidence/.../before) / after sheet |
| Engineer: no hammer | the built hammer was a 28 cm head on a haft; Root Maul now a big root-wrapped maul tipped over the shoulder (character_model.gd) | after/*-engineer*.png |
| Engineer deals no damage | covered by tools/combat_input_test.gd (Engineer LMB/J/pad all damage the dummy) | PR #239 |
| Turret build spot (bright green grid) | the Elf/Human yard rug used carpet_color.jpg, a 2x2-framed sheet that tiled as a lime grid; the pad was a flat decal | seamless diamond-weave carpet (tools/make_textures.py make_carpet), raised two-tier turret platform with team rune ring on every map (economy.gd `_platform`) | spots/before-spot2.png, after-spot2.png, after-spot6.png |
| Top score bar | cut-out of the reference art: sparkles, curls, hairlines, hollow stag | drawn in code (clean frame, filled leaf/crown crests), info line sits between the crests | hud/before-hud.png, hud/after-hud.png |
| Portrait clipped | FACE_AT centres were measured on older cards | re-measured per card, 72% crop (88% for wide hats) | hud/after-hud.png |
| Hot-plug | stuck actions survived a pad plug/pull | `_release_stuck_input()` on every connect/disconnect | tools/hotplug_test.gd (SIMULATED joy events, no real pad), CI step |
| Basic attack keycap | said J | LMB on keyboard+mouse, new hint line | hud/after-hud.png |

Not in this PR (next): dialogue screen, class selector cards + Veteran Training panel, Armor/customize menu.
