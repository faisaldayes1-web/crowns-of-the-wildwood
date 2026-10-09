# World & Maps log

Format: see [README.md](README.md). Newest first.

Branch `group/world-maps-5djtj1`, draft PR #7. Based on the combined build (PRs #1–#4 as merged in
`e5ba404`), so Ember Pass bases are in scope. Nothing here touches the HUD or UI.

<!-- entries below -->

### 2026-10-09 02:40 UTC · `(stamped by the next entry)` · Base remaster: Wildbloom courtyard, crystal crown altar, Human stone counterpart

- **What:** Both castles follow Faisal's five-zone sheet (spawn area → courtyard → outer defence → main gate → inner castle and crown room), on both maps, without moving any lane the bots use.
  - **Courtyard (the spawn hall behind the keep):** the Elves' walls are now topped with trimmed hedge instead of merlons; a cobbled lane runs from the spawn circle to the stairs; three raised flower beds, a crate stack and a cask line the south wall; stag pennants hang between the wall crystals; four stone fire pillars ring the spawn circle with two banner poles behind it; a timber palisade runs round the outside of the Elf courtyard (Wildwood only). The Humans get the same lane, beds (in stone kerbs), stores, fire pillars and lion banner poles, with their grey stone walls kept.
  - **Spawn area:** the spawn circle sits on a glowing rune disc in the team colour (it was a rug).
  - **Crown room:** the Elves' pedestal and cushion are gone; the crown rests on a green crystal cluster on a moonstone plinth, flanked by a pair of gold antlers, inside a trimmed hedge ring with blooms (open towards the doors), with a stag crest on the back wall and no empty throne. The Humans keep the carved pedestal, velvet cushion and throne, and gain a ring of short stone pillars with gold caps and lion pennants. Both throne rooms get stone fire pillars at their four outer corners (they were lantern/torch stands).
  - **Main gate:** a tall faction pennant hangs on the outer face of each gatehouse tower (it was a small shield banner).
  - **Ember Pass:** the same structure; hedges become dark basalt rubble and the flower beds hold glowing embers; no palisade (lava).
- **Files:** scripts/game.gd (new `_hedge_mat`, `_add_hedge_blob`, `_add_hedge_run`, `_add_hedge_ring`, `_add_flower_bed`, `_add_antler`, `_add_crown_altar`, `_add_dais_ring`, `hedge_tops` flag; `_add_wall`, `_build_throne_room`, `_polish_keep`, `_build_cellar`, `_build_castle`)
- **Tunables:** none in stats.gd. Layout: spawn-ring fire pillars at x +12/+17 m behind the back wall, z ±3.6; banner poles at x +17.2, z ±6.2; hedge ring radius 2.85 (gap 52° towards the doors); Human pillar ring radius 2.9 (gap 50°)
- **Gameplay, unchanged (for Faisal to decide, see the thread):** the class stations, upgrade station and NPC guide stay downstairs in the protected spawn hall as before; the sheet draws the courtyard upstairs and the spawn area as a separate protected zone. Nothing is solid in the new dressing except the fire pillars and the crate stack, so the capture circle, the stairs lane and the class row are untouched.
- **Tested:** `--check-only`; `--audit` 63 overlaps on Wildwood (same as before the change), 16 on Ember Pass; 30 s headless bot match on each map with no script errors (see the next entry if that changed). Renders: `game/groups/world-maps/base-*-before.png` / `base-*-after.png`
- **Revert:** `git revert <hash>`

### 2026-10-09 02:10 UTC · `b5e89e4` · Bring in the combined build with Ember Pass

- **What:** Merged the combined branch (`e5ba404`: PRs #1–#4, the web/iPad build work) into the group branch so the base remaster covers both maps. Two conflicts in `scripts/game.gd`: the Elf keep palette flags now sit beside Ember Pass's `soot`/`tex_swap` (both kept); the Elf throne room keeps its clean moonstone cornice (no leaf tufts) from the palette commit.
- **Files:** everything the combined branch carried; hand-merged `scripts/game.gd`.
- **Tunables:** none
- **Tested:** `--check-only` compiles; `--audit` baseline re-run below with the remaster.
- **Revert:** `git revert -m 1 b5e89e4`

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
