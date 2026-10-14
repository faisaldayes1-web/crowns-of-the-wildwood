# World style spec (visual overhaul, 2026-10-14)

Target: Faisal's "Crowns of the Wildwood Visual Style Guide" (copy at
`/mnt/project-files/game/visual-overhaul/reference/style-guide-2026-10-14.png`),
used as the unified artistic target, not as an asset sheet. The town/spawn
panel is ignored (spawn is inside the castle). Character models, camera, UI,
geometry and collision are unchanged.

All values live in `scripts/visual/style_profile.gd`. Builders read them only
while the match world is built (`game.world_style`), and the light grade is
applied only once a match starts (`game.style_live`), so the menus, title
diorama and castle-hall menu stage keep their old look.

## Grammar

| Surface | Rule |
|---|---|
| Scale | path stone ~0.8 m, river cobble ~0.15 m, wall block ~0.5 x 0.8 m, floor slab ~1.3 m, plank ~0.25 m |
| Edges | soft rounded bevels; joints mid-value (never black ink lines in the texture) |
| Normals | 0.4–0.7 of the old strength (`TEX[*].normal`) |
| Roughness | 0.9–1.0 on stone, timber, bark, grass, leaves; only metal, gold and water shine |
| Paths | warm tan stones in packed earth, moss creeping into some joints |
| Plaza / courts | warm tan flag rings with brown joints; muted kerb (no red brick) |
| Castle blocks / floors | close range of shades per block, gentle top light, light mottling |
| Foliage | one HSV ramp from shaded underside to warm yellow-green tips; soft wrapped light; leaf tufts; light silhouette rim |
| Pines | the same ramp, cooler and a step darker; autumn/gold pines use the autumn ramp |
| Ground detail | flowers and tufts in noise patches with open lawn between (1900 flowers, 5500 tufts, was 3200/9000) |
| Water | saturated blue (shallow 0.22,0.54,0.90 / deep 0.08,0.34,0.80); foam keeps to banks |
| Decoration glow | ambient decor emission capped at 1.2; gameplay cues keep their own glow |

## Light grades (applied at match start)

| Map | Change |
|---|---|
| Wildwood day | warm sun (1.0,0.9,0.74) at 1.45, ambient 0.22 (0.58,0.64,0.86), saturation 1.15, contrast 1.1, warm fog tint, fill 0.12 |
| Moonlit Wildwood | ambient 0.5, moon 0.55, fill 0.14 |
| Ember Pass | ambient 0.34; otherwise its own volcano light |

## Files

- `scripts/visual/style_profile.gd` — the table above.
- `tools/make_style_textures.py` — writes `assets/textures/style/` (does not touch `assets/textures/` or any UI art). Rerun, then `godot --headless --path . --import`.
- `assets/shaders/leaf_soft.gdshader` — match-world foliage. `leaf.gdshader` is unchanged for the menus.
- `assets/shaders/water.gdshader` — new `open_foam` uniform, default 1.0 (old look); the match world sets 0.25.
- `scripts/game.gd` — `world_style` / `style_live` gates, `_style_light()`, `_tree_bark()`, procedural autumn pines over the hidden Halloween pine props (colliders kept), ground detail in 24 m MultiMesh cells.
- `tools/world_fingerprint.gd`, `tools/perf_probe.gd` — verification.

## Rollback

Everything is one branch. To turn the look off without reverting, set
`world_style = true` to `false` in `game.gd` `_ready` and drop the
`_style_light()` call in `_apply_map_variant`. To remove it, `git revert` the
overhaul commits (see `docs/changelog/visual-overhaul.md`).
