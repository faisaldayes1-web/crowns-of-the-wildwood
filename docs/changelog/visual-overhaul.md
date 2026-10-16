# World visual overhaul (branch `claude/visual-overhaul-f5rskl`, PR #18)

Faisal's brief 2026-10-14 11:00 and style guide 11:10. Spec: [../visual/style-spec.md](../visual/style-spec.md).

### 2026-10-15 · `77a4290` · Flags no longer clip

- **What:** Faisal circled the green Elf keep flag as clipping: it stood up through the hedge on the waist-high Elf keep wall, with the carrot crate and crystal torch in front of it. The Elves' keep walls get no tapestry now (their second one was already skipped for the same reason). A check of every flag on both maps found three more: the Humans' first keep tapestry now hangs between the two wall torches (narrower, 1.5 → 0.9 m), the second hangs above the long table instead of behind it (bottom 0.5 → 1.25 m), and the cellar pennants sit between the torches (5.3/9.0/12.9 → 7.2/11.0/14.8 m) instead of over them.
- **Files:** scripts/game.gd
- **Tested:** no visual cuts into any flag cloth in the keeps (probe of every rod-and-cloth flag); world fingerprints identical; zfight `--all` still 0 different-material pairs; full test suite passes; Forward+ renders of both keeps.
- **Revert:** `git revert 77a4290`

### 2026-10-15 · `fada3c5` · Flicker pass (beta feedback)

- **What:** Faisal's beta note "there is a green flag texture error, try to do a pass and fix all flashing stutter texture errors". The green and blue base tapestries had their cloth face exactly in the plane of the wall panel behind them, so the two fought and flashed as the camera moved. A new `_unfight_coplanar()` pass runs once after the match world is built and separates every visible pair of different-material faces that share a plane: thin cloths, trims and rugs step 6 mm out; thicker blocks pull only the shared face 6 mm back. It repeats on the moved world (up to four rounds) so no move creates a new pair. Undersides are skipped (the camera never sees them). Only meshes move; colliders, routes and anchors are untouched.
- **Files:** scripts/game.gd, tools/zfight_audit.gd (new `--all` lists every pair, not just the top 120)
- **Tunables:** none (6 mm step, 8 cm thin limit, both in `_unfight_round`)
- **Tested:** tools/zfight_audit.gd seed 7: Wildwood 357 → 193 pairs, Ember Pass 413 → 199; pairs of different materials (the ones that visibly flash) 132 → 0 on Wildwood and Moonlit Wildwood, 189 → 0 on Ember Pass (`--all`; what is left is same-material pieces and the gate HP bars, which draw on top by design). World fingerprints identical to the beta on all three maps; full test suite passes; Forward+ renders of both bases and both flags.
- **Revert:** `git revert fada3c5`

### 2026-10-14 · `1c16c1a` · Deeper river shallows

- **What:** The river's light patches sit closer to its deep blue.
- **Files:** scripts/visual/style_profile.gd, docs/visual/style-spec.md
- **Tunables:** `WATER_SHALLOW` (0.34,0.70,0.96) → (0.22,0.54,0.90)
- **Tested:** bridge render; fingerprints unchanged
- **Revert:** `git revert 1c16c1a`

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
