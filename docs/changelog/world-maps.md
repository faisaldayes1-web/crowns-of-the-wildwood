# World & Maps group changelog

Every commit on the World & Maps branch (`group/world-maps-5djtj1`) gets an entry here,
committed together with the change it describes. Newest entries at the bottom.

**Base:** this branch starts from PR #1's head (`528e75b`, branch
`claude/project-thread-xtp3z5`, the cartoon art-style + HUD restyle work), because the
world look we are polishing (cartoon restyle, crown objective, keeps, cobble paths) only
exists there, not on `main`. Merge PR #1 first; this PR then merges cleanly on top.
Nothing here touches Ember Pass (PR #4) or HUD styling.

Each entry lists: date/time (UTC), short hash, what changed, files touched,
old → new values for any tunable, and the revert line.

To undo one change: run its revert line. To undo the whole group: revert the
commits newest-first, or close the PR.

---

## 2026-10-08 20:55 UTC: group setup

- **What:** created this changelog. No game change.
- **Files:** `docs/changelog/world-maps.md`
- **Tunables:** none
- **Revert:** `git revert <hash of the "World & Maps: start changelog" commit>` (harmless; the file only documents)

## 2026-10-09 01:45 UTC: Elf keep reads as wood and moonstone, not green

- **Commit:** "Elf keep: warm heartwood walls, moonstone trim and floors, moon-blue crystal light" (hash recorded in the next entry's header; also in the PR's commit list)
- **What:** the Elf castle was a flat green wash (green walls, green vine ledges, green leaf
  merlons, green moss floors and rugs, green-teal light). Now the walls are warm living
  heartwood, every cornice/coping/merlon/pillar cap/dais ring is pale moonstone, the yard,
  keep and throne-room floors are moonstone flags, the inlay rings are moon silver, and
  the crystals, lanterns, tower globes and room lights glow moon-blue instead of teal-green.
  Green stays on the team banners, rugs, canopies and the occasional leaf tuft.
- **Files:** `scripts/game.gd` (`_ashlar`, `_flagstone`, new `_moonstone`/`_moon_silver`,
  `_add_wall`, `_add_tower`, `_add_wall_torch`, `_add_crystal`, `_add_lantern`,
  `_add_trunk_pillar`, `_add_chandelier`, `_build_throne_room`, `_furnish_keep`,
  `_polish_keep`, `_build_castle`), new `elf_castle` flag set while the Elf castle builds.
- **Tunables (old → new):**
  - Elf wall bark tint `Color(0.72, 0.7, 0.58)` → `ELF_BARK = Color(0.8, 0.62, 0.47)`
  - Elf trim: `_elf_leaf()` green → `_moonstone()` (`ELF_MOONSTONE = Color(0.84, 0.87, 0.95)` on the marble texture)
  - Elf crystal/lantern/tower light `Color(0.55, 1.0, 0.85)` → `ELF_GLOW = Color(0.62, 0.8, 1.0)`
  - Crystal albedo `(0.5, 0.95, 0.85)` → `(0.66, 0.8, 1.0)`, emission `(0.3, 0.9, 0.7)` → `(0.4, 0.62, 1.0)`
  - Elf room light `Color(0.95, 0.92, 0.7)` → `Color(0.96, 0.92, 0.86)`
  - Yard/keep floors `flagstone_moss` → `flagstone` tinted `ELF_MOONSTONE * 0.88`
  - Throne room floor `bark` + `flagstone_moss` → `wood_dark (0.9, 0.74, 0.6)` + moonstone
  - Keep planks tint `(0.8, 0.85, 0.7)` → `(0.92, 0.78, 0.64)`; wainscot `_moss()` → dark wood `(0.78, 0.62, 0.5)`
  - Royal round rug `_moss()` → team carpet darkened 0.45; dais rings `_elf_leaf(true)` → `_moon_silver()`
  - Moon-pool water `(0.5, 0.9, 0.95)` → `(0.6, 0.78, 1.0)`
  - Throne-room wall-top leaf blocks: removed
- **Renders:** `game/groups/world-maps/elf-keep-before.png` / `elf-keep-after.png`
- **Depends on:** PR #1 (the branch base); nothing in Ember Pass or the HUD.
- **Revert:** `git revert <hash>` (one commit, self-contained)
