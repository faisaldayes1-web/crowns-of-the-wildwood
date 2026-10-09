# World & Maps log

Format: see [README.md](README.md). Newest first.

Branch `group/world-maps-5djtj1`, draft PR #7. Based on the combined build (PRs #1–#4 as merged in
`e5ba404`), so Ember Pass bases are in scope. Nothing here touches the HUD or UI.

<!-- entries below -->

### 2026-10-09 04:55 UTC · `742471f` · Merge UI & Art's open Elf courtyard (c5afec8)

- **What:** Merge of `origin/group/ui-art-z3px4x` (the Wildwood Elf class courtyard rebuilt at ground level: `cellar_floor(team)`, `_in_cellar` now bounded in x and tested against that floor, the barricade rule uses `_in_cellar`, day light grade changed). Two conflicts in `scripts/game.gd` in `_build_cellar`, resolved so their `open` courtyard branch (stations under the pavilion, Upgrade Station in the south-east corner, Guide by the passage) and the Humans' sunken hall with its workshop corner (south-west) and Guide (north-west) each keep their own branch; the Human and both Ember Pass cellars take the old path unchanged.
- **Files:** scripts/game.gd (merge), plus their files (assets/textures/pavers_color.jpg, tools/make_textures.py, docs/changelog/ui-art.md)
- **Tunables:** none of ours
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 3 min bot matches: Wildwood doors 130/32 at 90 s, 0/0 at 150 s; Ember Pass unseeded run stayed 200/199 to 150 s, so re-run with `--seed=5` on this merge (doors 154/200 at 90 s, 154/155 at 120 s, Elves capture at 147 s, no bot holding position in any snapshot) and on the pre-merge commit f0b7e09 (128/200 at 90 s, 0/200 at 120 s): same behaviour, the quiet run was variance
- **Revert:** `git revert -m 1 742471f`

### 2026-10-09 04:00 UTC · `a24e1aa` · Merge UI & Art's Elf overhaul (7e37f9f) so both bases share light, materials and wall heights

- **What:** Merge of `origin/group/ui-art-z3px4x` (their Elf base overhaul: soft wrapped shading, blurred shadows, day grade, finer ink lines, regenerated stone/flagstone/hedge textures, layered crown pedestal, waist-high Elf parapets). Eight conflicts in `scripts/game.gd`, all resolved so each faction keeps its own rule: `_add_wall` keeps the Human plinth and their `hedge_tops or mossy` hedge row; the crown room's side walls use their `wall_h`/`wall_t` for the Elves and `_room_wall_h` for the Humans; the keep's side walls use their `kh` (1.4 for Elves) with the Human south wall at 1.3; pennants, torches, tapestries and the keep torch follow the same split; the Upgrade Station keeps their Elf workshop corner (north-west) and the Human one (south-west).
- **Files:** scripts/game.gd (merge), plus their files (scripts/monarch.gd, tools/make_textures.py, assets/textures/*, assets/shaders/ink_outline.gdshader, docs/changelog/ui-art.md)
- **Tunables:** none of ours; theirs are in docs/changelog/ui-art.md
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 3 min bot matches: Wildwood doors 97/144 at 60 s, 0/106 at 90 s, Humans score at 120 s; Ember Pass doors 161/200 at 90 s, 59/194 at 150 s
- **Revert:** `git revert -m 1 a24e1aa`

### 2026-10-09 05:45 UTC · `f0906f7` · Human base opened up and made chunky (Faisal's 03:34 brief, Human side)

- **What:** The Human base on both maps follows the new visual brief, faction-flavoured (grey ashlar, dark timber, blue cloth with gold, lion).
  - **Open courtyard:** the camera-facing (south) walls are lowered so the game camera sees in: the yard's south outer wall is a 1.5 m parapet (was 3 m), the keep's south wall a 1.3 m wall (was 2.6 m, its side door keeps no lintel), and the crown room's south wall a 1.1 m balustrade (was 2.3 m), so the crown, its dais and anyone in the room stay visible. All of them keep their colliders; the vault doors, capture ring, stairs and lanes are untouched. Things that hung on those walls above the new height are gone or moved: the keep's south tapestries, wall torches and hung shield, the chapel's stained-glass window (now a lit gold panel on the altar's back), the crown room's south pennants.
  - **Chunky stonework:** every full-height Human wall (outer ring, courtyard) stands on a darker plinth course; every Human wall carries a thick pale cornice with a dark bevel line under it; the towers get a plinth and a string course.
  - **Fitted runners with the lion:** the yard runner, the keep's arch-to-throne rug and the spawn hall runner each carry the lion emblem.
  - **Class stations:** each Human alcove shows its class icon on a gold roundel over the drape.
  - **Workshop corner:** the upgrade station moved to the spawn hall's south-west corner with a stocked shelf, crates and a cask round it; the Guide takes the north-west corner; the weapon rack moved along to make room.
- **Files:** scripts/game.gd (new `_room_wall_h`; `_build_castle`, `_build_throne_room`, `_polish_keep`, `_add_wall`, `_add_tower`, `_add_class_alcove` Human branch, `_build_cellar`, `_furnish_keep` Human branches)
- **Tunables:** Human south walls: yard WALL_H 3.0 → 1.5, keep KEEP_H 2.6 → 1.3, crown room ROOM_H 2.3 → 1.1 (`_room_wall_h`); plinth 0.4 high, +0.18 a side; cornice 0.3 high, +0.12 a side; upgrade pad (bx+1.1, −5.0) → (bx+1.4, +5.2), Guide z 5.2 → −5.2, weapon rack x bx+4.0 → bx+6.4
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 3 min bot matches: Wildwood doors 0/198 at 120 s (151/198 at 150 s after a rebuild), Ember Pass doors 181/0 at 120 s, Elves score 1-0 at 150 s. Renders: `game/groups/world-maps/human-*.png`
- **Revert:** `git revert <hash>`

### 2026-10-09 05:15 UTC · `6ccf861` · Merge UI & Art's courtyard-bed move

- **What:** Merged `group/ui-art-z3px4x` at `e4c6c24` (their Elf flower beds moved off the hidden south-wall strip; their merge of our 965ecd3 with the agreed `_polish_keep` split). Clean merge, nothing of ours changed.
- **Files:** scripts/game.gd, docs/changelog/ui-art.md (theirs)
- **Tunables:** none of ours
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 3 min bot matches: Wildwood doors 29/113 at 150 s, Ember Pass 178/106
- **Revert:** `git revert -m 1 6ccf861`

### 2026-10-09 05:05 UTC · `4b8f815` · Lions that read as lions; the drill yard moved into view

- **What:** From the game camera (steep, from the south) the grey block lions read as rubble, so the stone lion is now cream stone with a gold disc mane and gold collar, and the gate pair is a third bigger. The barracks' drill yard (weapon rack, archery target, two sparring dummies) stood against the south wall, where the game camera never sees it: the camera looks over that wall's top, which hides the first ~2.5 m of floor behind it (the Elves' flower beds on the same wall are hidden the same way, told UI & Art). The drill yard now stands 3 m off the wall, in view; the two lion crests on that wall are gone (same reason).
- **Files:** scripts/game.gd (`_add_stone_lion`, `_dress_human_castle`, `_build_cellar` Human branch)
- **Tunables:** gate lions scale 1.0 → 1.3 at (fx−2.6, ±6.8); drill props z hz−0.9…1.6 → hz−3.2…3.6
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 3 min Wildwood bot match: doors 101/192 at 90 s, Elf door down at 120 s. Renders: `game/groups/world-maps/human-*.png`
- **Revert:** `git revert 4b8f815`

### 2026-10-09 04:45 UTC · `965ecd3` · Merge UI & Art's Elf pass D and their raider fix

- **What:** Merged `group/ui-art-z3px4x` at `d52a8e1`. UI & Art had found the same corner-pillar trap (their b678241) and moved the four pillars to the keep's archway wall and back wall; this branch had turned them into torches (47c7d81). Resolution in `_polish_keep`: Elves get UI & Art's fire pillars, Humans keep plain corner torches, because the Human keep already has iron braziers at the archway and a weapon rack and shelf on the back wall where those pillars would stand. Also took their Elf pass D (crown room terrace with stairs, turret pads, hedge line outside the Elf front wall); the vault-door lions stay removed.
- **Files:** scripts/game.gd (hand-merged `_polish_keep`, `_build_throne_room`), docs/changelog/ui-art.md (theirs)
- **Tunables:** none of ours
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 3 min bot matches: Wildwood seed 5 doors 168/100 at 60 s, Elves score 1-0 at 120 s; Ember Pass doors 161/196 at 150 s; UI & Art's seed-5 Mage on the rampart stairs did not recur here
- **Revert:** `git revert -m 1 965ecd3`

### 2026-10-09 04:30 UTC · `47c7d81` · Bot routing fix: both teams were stuck behind the throne room

- **What:** Since the base remaster (`1eb78a4`) the bots of both teams never left their keeps: the four stone fire pillars at the throne room's outer corners were solid and sat exactly on the gallery-corner waypoints that `_around_throne_room` sends everyone through, so a 5 min bot match ended 0-0 with both gates untouched (the 30 s checks only saw bots still choosing classes). The corner pillars are torches again (as before the remaster). Three of this morning's Human props were also on or beside bot lanes and moved: the lions guarding the sanctuary ward now stand tight against the keep's back wall either side of the opening (they replace the two torches there), the parade-ground pillars moved up by the gatehouse (x in+2.0 / in+3.5, z ±6.2) off the yard-to-rampart diagonal and the Engineers' turret pads, and the pair of lions flanking the vault doors is gone (it sat on the entrance-hall lane). The Humans' wall-hung gold sword and shield moved 0.55 m along the back wall to clear a lion.
- **Files:** scripts/game.gd (`_polish_keep`, `_build_cellar` Human ward, `_build_throne_room`, `_dress_human_castle`, `_furnish_keep` Human branch)
- **Tunables:** none in stats.gd. Throne-room corner lights `_add_stone_brazier` → `_add_torch` (both teams, both maps); ward lions (bx−2.0, ±2.45) → (bx−0.7, ±2.4); yard pillars x in+3.0/6.6, z ±6.7 → x in+2.0/3.5, z ±6.2; Human back-wall shield z 3.2 → 3.75
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 3 min bot matches: Wildwood doors 126 / 0 at 120 s and Elves score 1-0 at 150 s (the crown reaches UI & Art's raised Elf throne); Ember Pass doors 197 / 168 at 150 s (both teams out and attacking; the bigger map takes longer). The before/after comparison that found it: `b5e89e4` doors 24/0 at 150 s vs `8fb3a0e` 200/200.
- **Revert:** `git revert 47c7d81` (brings the stuck bots back)

### 2026-10-09 04:00 UTC · `(fast-forward)` · Take UI & Art's Elf passes C/D

- **What:** `group/ui-art-z3px4x` at `b08d25d` already contained our `8fb3a0e`, so this branch fast-forwarded onto it (no merge commit): Elf crown room raised 0.9 on a terrace with stairs, hedge run outside the Elf front wall, turret pads. Nothing of ours changed. Checked for our scope: the Elf gate, wall ring and courtyard footprint are unchanged, so the approach routes and bridges still meet them; the raised throne is below the 2 m rampart threshold in `_route_leg`, so bot routing needs no change.
- **Files:** scripts/game.gd, docs/changelog/ui-art.md (theirs).
- **Tunables:** none of ours.
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 30 s bot matches on both maps with no script errors; a 5 min Wildwood bot match to see crowns scored at the raised Elf throne (result in the next entry).
- **Revert:** their commits, listed in docs/changelog/ui-art.md (`git revert <hash>` each), or `git reset --hard 8fb3a0e` on a fresh branch.

### 2026-10-09 03:45 UTC · `62e1c2b` · Merge UI & Art's Elf base pass A

- **What:** Merged `group/ui-art-z3px4x` at `d1528f5` (UI & Art now owns the Wildwood Elf base end to end: hedge walls, cream sandstone, timber class stalls, stag runners, altar court, stronger light and ink) so this branch's renders show both groups' work together. One conflict: both groups added a function at the same spot in `scripts/game.gd` (`_dress_human_castle` / `_dress_elf_courtyard`); both kept.
- **Files:** everything UI & Art's branch carried (23 files); hand-merged `scripts/game.gd`.
- **Tunables:** none of ours. (UI & Art's map-wide light/ink values are in their log, docs/changelog/ui-art.md.)
- **Tested:** `--check-only`; `--audit` Wildwood 1 / Ember Pass 0; 30 s bot matches on both maps.
- **Revert:** `git revert -m 1 62e1c2b`

### 2026-10-09 03:35 UTC · `835cc71` · One cobble style map-wide: the Forest and River paths

- **What:** The two flank approach routes to each castle (the Forest Path to the north bridge, the River Path to the south bridge) were loose stones in dirt; they are now laid in the same tan cobbles as the main road, fraying into the meadow at the edges, so every road on the Wildwood matches the courtyard reference. Widths and bends are unchanged (the bots' lanes are the same).
- **Files:** scripts/game.gd (`_build_world`, flank paths)
- **Tunables:** flank path material `_stones(true)` (loose) → `_stones()`
- **Tested:** `--check-only`; `--audit` Wildwood 1 (unchanged)
- **Revert:** `git revert 835cc71`

### 2026-10-09 03:25 UTC · `84766ad` · Human base identity: stone lions, ballistae, parade ground, drill yard

- **What:** The Humans' castle now reads as its own faction against the Elves' hedge-and-crystal sanctuary (Faisal 00:14: "the bases should really feel more unique"), on both maps. **Main gate:** two stone lions sit on plinths outside the gate, a lion crest hangs on the parapet over it, and a timber ballista stands on each gatehouse tower (the sheet's outer-defence turrets, decorative). **Courtyard (the yard):** one long royal runner from the gate to the keep's archway, flanked by two pairs of stone pillars with gold caps, lion crests and blue pennants (a parade ground). **Inner castle:** a pair of lions guards the sanctuary ward at the top of the spawn stairs, and a smaller pair flanks the Crown Vault doors. **Spawn area (the barracks yard):** a blue runner from the spawn circle to the stairs (the Elves keep cobbles); the south wall is a drill yard instead of flower beds: a weapon rack, an archery target, two straw sparring dummies and two lion crests between the torches. **Ember Pass:** the Elves' courtyard walls and crown-altar ring are trimmed hedge there too (they were basalt rubble), so the Elf base reads as a green oasis on the ash, matching Faisal's courtyard targets; the Human changes above apply on Ember Pass as well.
- **Files:** scripts/game.gd (new `_box_at`, `_add_stone_lion`, `_add_ballista`, `_add_training_dummy`, `_dress_human_castle`; Human branches in `_build_castle`, `_build_cellar`, `_build_throne_room`; `_hedge_mat`)
- **Tunables:** none in stats.gd. Layout (Human yard): pillars at x in+3.0 / in+6.6, z ±6.7; gate lions at x fx−2.5, z ±6.7; ward lions at x bx−2.0, z ±2.45 (scale 0.8); vault lions at front−1.35, z ±2.3 (scale 0.72). Nothing new sits on a lane: gate→archway (|z| < 3.5), yard→rampart stairs (z ±9.5), spawn lane (|z| < 1.6).
- **Tested:** `--check-only`; `--audit` Wildwood 1 (unchanged), Ember Pass 0; 30 s headless bot matches on both maps with no script errors. Renders: `game/groups/world-maps/human-*-after.png`
- **Revert:** `git revert 84766ad`

### 2026-10-09 02:55 UTC · `ed70e0a` · Clipping audit: 63 overlaps down to 1

- **What:** Every prop that cut into a wall, a building, a fence or another prop on the Wildwood is moved or placed smarter. Rocks on the river bank keep clear of the mills; the bank reeds stand on the cobble strip instead of inside the stone kerb; the mills sit 0.6 m further up the bank; field rocks avoid trees, ruins, crates, fences and landmarks, and their companion stone sits beside instead of inside them; the road crates' cask stands clear of the stack; the shrine benches moved off the fence posts; the barrow's gravestones, lantern and candles stand clear of the crypt; the boulder by the east road moved 2.5 m south so its pebbles miss the crates; big trees keep 5.4 m between trunks and all trees keep clear of placed props; the spawn hall's first wall crystal/torch (it sat over the shelves) is gone. The audit itself now ignores a prop's own walk-around blocker, furniture standing inside the throne room, and bottles on shelves (all by design).
- **Files:** scripts/game.gd (`_audit_clipping`, `_add_river`, `_add_river_plants`, `_add_watermills`, `_add_field_rocks`, `_add_crates`, `_add_road_lanterns`, `_add_barrow`, `_add_boulder`, `_add_cover` boulder list, `_tree_spot_ok`, `_build_cellar`)
- **Tunables:** bank-rock mill exclusion |z|−25.5 > 5.5 → |z|−30 > 5.5; reeds x RIVER_HALF+0.5 → +1.3; mills x RIVER_HALF+3.2 → +3.8; field rocks |z| ≥ 6 → ≥ 7.5, tree clearance 2.5 → 2.8 (3.8 big), companion offset (0.9, 0.5) → (1.7, 1.0); road cask offset 1.5 → 1.75; bench (ISLAND_R+4.5, 4.2) → (ISLAND_R+3.2, 4.6); big-tree spacing 3.6 → 5.4; boulder (33, −8) → (33, −10.5)
- **Tested:** `--audit` Wildwood 63 → 1 (two pine crowns touching by 22 cm at (62.7, −32.4), left as natural foliage); Ember Pass 16 → 0 real (the 6 "vault" lines were furniture inside the throne room, now excluded)
- **Revert:** `git revert ed70e0a`

### 2026-10-09 02:40 UTC · `1eb78a4` · Base remaster: Wildbloom courtyard, crystal crown altar, Human stone counterpart

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
- **Revert:** `git revert 1eb78a4`

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
