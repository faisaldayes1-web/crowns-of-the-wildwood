# World & Maps log

Format: see [README.md](README.md). Newest first.

Branch `group/world-maps-5djtj1`, draft PR #7. Based on the combined build (PRs #1–#4 as merged in
`e5ba404`), so Ember Pass bases are in scope. Nothing here touches the HUD or UI.

<!-- entries below -->

### 2026-10-09 02:10 UTC · `(merge: hash stamped by the next entry)` · Bring in the combined build with Ember Pass

- **What:** Merged the combined branch (`e5ba404`: PRs #1–#4, the web/iPad build work) into the group branch so the base remaster covers both maps. Two conflicts in `scripts/game.gd`: the Elf keep palette flags now sit beside Ember Pass's `soot`/`tex_swap` (both kept); the Elf throne room keeps its clean moonstone cornice (no leaf tufts) from the palette commit.
- **Files:** everything the combined branch carried; hand-merged `scripts/game.gd`.
- **Tunables:** none
- **Tested:** `--check-only` compiles; `--audit` baseline re-run below with the remaster.
- **Revert:** `git revert -m 1 <merge hash>`

### 2026-10-09 01:50 UTC · `d5b4301` · River: clustered lily pads with water lilies, stone fire pillars at the bridges

- **What:** The 34 small single lily discs down the river are now 22 clusters of 2–4 notched pads (two greens) hugging the banks, half with a pink or white water lily. Both flank bridges get a square stone pillar with a fire bowl at each of their four corners on the banks (the target art), outside the railings and clear of the bots' bridge lane; they replace the torch stands the big bridge had.
- **Files:** scripts/game.gd (`_add_river`, new `_lily_pad_mesh`, `_add_water_lily`, `LILY_CLUSTERS`)
- **Tunables:** lily discs `34` singles → `LILY_CLUSTERS` 22 clusters; pad radius 0.3–0.48 → 0.42–0.78 (×0.8 satellites); bridge lights: torch stands (big bridge only) → `_add_stone_brazier` ×4 on both bridges
- **Tested:** `--check-only`; `--audit` 63 overlaps before and after (none added). Renders: `game/groups/world-maps/river-before.png` / `river-after.png`
- **Revert:** `git revert d5b4301`

### 2026-10-09 01:45 UTC · `fdac26f` · Elf keep reads as wood and moonstone, not green

- **What:** The Elf castle was a flat green wash (green walls, vine ledges, leaf merlons, moss floors and rugs, teal light). Walls are now warm living heartwood; every cornice, coping, merlon, pillar cap and dais ring is pale moonstone; the yard, keep and throne-room floors are moonstone flags; the inlay rings are moon silver; crystals, lanterns, tower globes and room lights glow moon-blue. Green stays on the team banners, rugs, canopies and the odd leaf tuft.
- **Files:** scripts/game.gd (`_ashlar`, `_flagstone`, new `_moonstone`/`_moon_silver`, `_add_wall`, `_add_tower`, `_add_wall_torch`, `_add_crystal`, `_add_lantern`, `_add_trunk_pillar`, `_add_chandelier`, `_build_throne_room`, `_furnish_keep`, `_polish_keep`, `_build_castle`; new `elf_castle` flag)
- **Tunables:** Elf wall bark tint (0.72, 0.7, 0.58) → `ELF_BARK` (0.8, 0.62, 0.47); Elf trim `_elf_leaf()` → `_moonstone()` (`ELF_MOONSTONE` (0.84, 0.87, 0.95) on the marble texture); Elf light (0.55, 1.0, 0.85) → `ELF_GLOW` (0.62, 0.8, 1.0); crystal albedo (0.5, 0.95, 0.85) → (0.66, 0.8, 1.0), emission (0.3, 0.9, 0.7) → (0.4, 0.62, 1.0); Elf room light (0.95, 0.92, 0.7) → (0.96, 0.92, 0.86); yard/keep floors `flagstone_moss` → `flagstone` × `ELF_MOONSTONE` 0.88; throne-room floor bark + moss flags → dark wood (0.9, 0.74, 0.6) + moonstone; keep planks (0.8, 0.85, 0.7) → (0.92, 0.78, 0.64); wainscot `_moss()` → dark wood (0.78, 0.62, 0.5); royal rug `_moss()` → team carpet darkened 0.45; dais rings `_elf_leaf(true)` → `_moon_silver()`; moon-pool water (0.5, 0.9, 0.95) → (0.6, 0.78, 1.0); throne-room wall-top leaf blocks removed
- **Tested:** `--check-only`; `--audit` unchanged (63). Renders: `game/groups/world-maps/elf-keep-before.png` / `elf-keep-after.png`
- **Revert:** `git revert fdac26f`

### 2026-10-08 20:55 UTC · `4ab658a` · World & Maps: start changelog

- **What:** Created this log. No game change.
- **Files:** docs/changelog/world-maps.md
- **Tunables:** none
- **Revert:** `git revert 4ab658a` (documentation only)
