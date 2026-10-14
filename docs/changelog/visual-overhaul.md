# World visual overhaul (branch `claude/visual-overhaul-f5rskl`, PR #18)

Faisal's brief 2026-10-14 11:00 and style guide 11:10. Spec: [../visual/style-spec.md](../visual/style-spec.md).

### 2026-10-14 · `1bffc9f` · Calmer open-water foam, style spec

- **What:** River foam keeps to the banks in matches (open-water patches read as white clouds on the deeper blue). The menus' water keeps the old foam (uniform default 1.0).
- **Files:** assets/shaders/water.gdshader, scripts/game.gd, scripts/visual/style_profile.gd, docs/visual/style-spec.md
- **Tunables:** `WATER_OPEN_FOAM` 0.25 (new; 1.0 = old look)
- **Tested:** Forward+ and Compatibility renders; fingerprints unchanged
- **Revert:** `git revert 1bffc9f`

### 2026-10-14 · `0b6eea6` · Match-world style profile

- **What:** One art direction for the match world, gated on `world_style` (build) and `style_live` (match light), so menus and UI are untouched. Softer style copies of stone, slab, path, rosette, rock, cobble, timber, bark and grass textures; soft-lit foliage shader with leaf tufts and one colour ramp; procedural pines replace the low-poly Halloween pine props (props hidden, colliders kept); flowers and tufts in patches, built as culled 24 m MultiMesh cells; blue river; warm day grade.
- **Files:** scripts/game.gd, scripts/visual/style_profile.gd, assets/shaders/leaf_soft.gdshader, assets/textures/style/*, tools/make_style_textures.py, tools/world_fingerprint.gd, tools/perf_probe.gd
- **Tunables:** all in scripts/visual/style_profile.gd (new). Ground detail FLOWERS 3200 → 1900, TUFTS 9000 → 5500; decor glow 3.0 → 1.2; day ambient 0.21 → 0.22, saturation 1.08 → 1.15, contrast 1.08 → 1.1, sun 1.42 → 1.45.
- **Tested:** full headless suite as baseline; world fingerprint identical on Wildwood and Ember Pass; protected UI/stats/RPC hashes identical
- **Revert:** `git revert 0b6eea6` (revert `1bffc9f` first)
