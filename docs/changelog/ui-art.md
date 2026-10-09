# UI & Art group changelog

Branch `group/ui-art-z3px4x`, based on PR #1 (`claude/project-thread-xtp3z5`, commit 528e75b) so the
menus share the approved in-match HUD style. Every commit on this branch has an entry here with
what changed in plain words, the files touched, old → new values for any tunable, and the exact
line that undoes it. Renders for each visual change are under
`/mnt/project-files/game/groups/ui-art/` (project files), named `<change>-before.png` /
`<change>-after.png`.

Integration notes:
- PR #3 moves the scoreboard table into `scripts/scoreboard.gd` (`Scoreboard.draw_overlay(hud)` /
  `draw_table`). Whichever lands second: the Tab panel frame below is `hud._menu_panel(rect,
  "SCOREBOARD")` + `_crest_shield` + `_info_banner`, and the team blocks use `hud._leather` and
  `hud._score_band(band, SCORE_BANDS[t])`; port those calls into `scoreboard.gd` and drop the
  `_draw_scoreboard_table` body from `hud.gd`.
- The in-match HUD and the match summary screen were not touched (owned by the showcase thread).

---

## 2026-10-09 — pause menu, Settings and Tab panel in the HUD style; class pick-up banner; rank-up flourish

Commit: `3c2d934`

What changed:
- **Pause menu / Options**: the navy plate is now the HUD's leather-black frame in a brass rim with gold
  corner braces and ivy sprigs, the title (PAUSED / OPTIONS) on a wood-brown cloth band under a small
  crown, tabs as parchment (open) or leather (closed) pills in the Lilita One face, a round
  ring-button close, and MAIN MENU as a red cloth button. Cards and rows inside every tab (Map,
  Scoreboard, Classes, Upgrades, Controls) use the same leather plates and gold section headings.
- **Settings**: SOUND/MUSIC sliders are leather tracks with a glossy fill and a gold knob; toggles
  are leather chips with a brass-rimmed green/gold switch; BOTS and the graphics preset are gold
  band buttons when chosen; section headings (DISPLAY, BOTS, TEAM CALLS, GAMEPAD) in gold Lilita
  One with a brass rule.
- **Tab panel (scoreboard)**: same frame, titled SCOREBOARD, the two faction heater shields either
  side, the score/clock line on a parchment info banner, each team block headed by its cloth band
  (red Elves / blue Humans, like the top bar), alternating row stripes, the player's row on
  parchment.
- **Class pick-up banner** (new): when a player puts on a class hat, a ribbon in the class colour
  pops in under the top bar for 3 s: "YOU ARE NOW / ELF KNIGHT", a glossy hex tile with the class
  icon above it, and a parchment scroll naming the kit (attack, Q, E with their keys).
- **Rank-up flourish** (new, replaces the plain "LEVEL UP!" card): on every level a laurel
  medallion with the new level sits in a turning gold light burst (two ray layers + a ring that
  races out), a gold ribbon reads RANK UP!, and a parchment scroll says "Level N · +1 perk point ·
  R to spend it". A class promotion (choosing a variant) uses the same flourish with PROMOTED! and
  the variant name; the medallion shows the variant icon. Level-ups also fire a brighter 3D flash
  at the player's feet.
- Render flags for testing: `--debug-class` (class banner), `--debug-promote` (promotion
  flourish); `--debug-levelup` still shows the level flourish.

Files touched: `scripts/hud.gd` (menu style helpers `_menu_panel`, `_leather`, `_parchment`,
`_menu_tab`, `_hud_button`, `_section`, `_slider`; banners `_cloth_ribbon`, `_scroll_hint`,
`_twinkles`, `_draw_class_banner`, `_draw_rankup_flourish`; restyled `_draw_game_menu`, `_close`,
`_menu_*`, `_toggle`, `_draw_scoreboard_overlay`, `_draw_scoreboard_table`; `_draw_levelup_card`
removed), `scripts/game.gd` (`levelup_text`, debug flags), `scripts/unit.gd` (`class_banner`,
`CLASS_BANNER_TIME`, promotion/level-up hooks), `scripts/seal.gd` (starts the class banner),
`docs/changelog/ui-art.md`.

Tunables: `unit.gd CLASS_BANNER_TIME` new = 3.0 s; `hud.gd CLASS_BANNER_TIME` 3.0 s (same value,
for the pop timing); flourish length unchanged at `game.levelup_timer = 3.2` s. No gameplay
numbers changed.

Renders: `menu-pause-before/after.png`, `menu-settings-before/after.png`,
`tab-panel-before/after.png`, `class-banner-after.png`, `rankup-after.png`,
`promoted-after.png`.

Revert: `git revert 3c2d934`

---

## 2026-10-09 — visual overhaul, pass 1: ground, flowers, trees, Elf castle hedges and lamps

Commit: `731b6e5`

Faisal's references (project files, game/reference-renders/): `elf-base-interior-target-2026-10-08.png`,
`elf-courtyard-target-2026-10-08.png`; `ember-pass-current-2026-10-08.jpeg` is the current build for
contrast. Art layer only: no base layout, geometry or station positions changed (World & Maps owns
those), and no HUD/UI change.

What changed:
- **Meadow grass** (`tools/make_textures.py make_grass`): deeper, more saturated green, less lime, so
  the flowers and units read on top of it.
- **Cobble paths** (`make_stepping_stones`): 4 stones per tile instead of 5 (bigger), rounder, cream
  and tan instead of orange-tan, and the joints are packed earth (lighter) instead of dark mud.
- **Courtyard flags** (`make_flagstone`): cream sandstone squares with a pale tan grout instead of
  deep yellow with a dark brown joint; the mossy (Elf) and grey (Human) variants follow.
- **Flowers**: 3200 blooms instead of 1400, mostly white daisies, then cornflower blue and
  buttercup yellow, a few pink/red; fewer glowing elf blooms (12% instead of 30% on the elf side).
  Grass tufts: 9000 instead of 8000, shorter (scale 1.4/1.0/1.4 instead of 1.6 all round) and in the
  meadow's own green.
- **Trees**: the lavender wildwood canopies are now pink blossom (hue 0.9) like the courtyard
  target's cherry; the mint ones a deeper green.
- **Elf castle walls** are trimmed box hedges (new `_hedge()` material, `make_hedge` texture) instead
  of bark, with a lighter clipped top; leaf tufts stay instead of merlons.
- **Elf castle lights**: lanterns are warm lamplight (1.0, 0.85, 0.6 @ 0.8) instead of pale green
  (0.85, 1.0, 0.78 @ 0.9); tower globes and wall crystals are softer teal (0.7, 1.0, 0.85 @ 0.7 and
  0.6 instead of 0.55, 1.0, 0.85 @ 1.2 and 1.1), so the yard no longer reads green.
- **Day light**: ambient 0.13 → 0.16; sun (1.0, 0.87, 0.7) @ 1.35 → (1.0, 0.9, 0.74) @ 1.45.
- **Stag emblem**: `tools/make_emblems.py stag()` draws the Elves' stag head in gold (matches the top
  bar's shield); Elf banners and crests use it (`_faction_emblem(0)` → "stag"; the great tree is now
  the alternate, the moon is unused).

Files touched: `tools/make_textures.py`, `tools/make_emblems.py`, `scripts/game.gd` (`_add_ground_detail`,
`_add_tree_grown`, `_add_lantern`, `_add_tower`, `_add_wall_torch`, `_add_wall`, `_hedge`, `_faction_emblem`,
day lighting in `_apply_time_of_day`), regenerated `assets/textures/{grass,flagstone*,path*}` plus new
`assets/textures/hedge_*` and `assets/textures/emblems/stag.png`. Regenerate with
`python3 tools/make_textures.py make_grass make_flagstone make_paths make_hedge` and
`python3 tools/make_emblems.py`, then `godot --headless --path . --import`.

Tunables (old → new): flowers 1400 → 3200; tufts 8000 → 9000, tuft scale 1.6 → (1.4, 1.0, 1.4); elf
bloom share 0.3 → 0.12; ambient_light_energy 0.13 → 0.16; sun 1.35 → 1.45; lantern light
(0.85,1.0,0.78)@0.9 → (1.0,0.85,0.6)@0.8; tower globe light 1.2 → 0.7; wall crystal light 1.1 → 0.6;
path stones per tile 5 → 4.

Renders: `world-courtyard-before/after.png`, `world-elf-castle-before/after.png` beside the references.

Revert: `git revert 731b6e5`, then regenerate the textures as above.

---

## 2026-10-09 — visual overhaul, pass 2: Elf keep walls, yard, blossoms; chunky faceted Elves; death screen

Commit: `ece3b24`

What changed:
- **Elf keep interior**: the untinted elven "stone" (keep walls, throne room, pillars) is now the
  same trimmed hedge as the outer walls instead of bark, so the base interior reads as the green,
  grown hall of the interior target; tinted pieces (caps, stairs, posts) stay bark. The Elf yard
  flags are near-white cream (0.97, 0.96, 0.9) instead of a green-grey tint (0.8, 0.82, 0.72).
- **Flowers**: bloom emission is a faint neutral lift (0.5, 0.5, 0.45 @ 0.18) instead of teal
  (0.3, 0.6, 0.7 @ 0.25), so the daisies are white, not blue. Pink blossom trees are one wild tree
  in eight instead of one in four.
- **Elf character look** (Faisal's create-character reference, 2026-10-09): every unit's meshes are
  rebuilt faceted (flat-shaded, each triangle with its own normal) so the low-poly angles read
  crisp; a bone pose scale makes the head bigger (1.22), the hands oversized mittens (1.3) and the
  boots big (1.25), with the hand slots scaled back (0.8) so weapons keep their size; Elf villagers
  wear the hooded tunic model (humans stay bare-headed); the pointed ears sit a little closer in.
  No gameplay numbers changed (hit shapes are unchanged; the scale is visual only).
- **Death screen** (new, replaces the plain "SLAIN BY" card): a dark red wash with vignette, a
  crimson ribbon reading YOU FELL, a laurel medallion whose gold ring drains with the respawn
  timer and shows the seconds (or OVERTIME), "RESPAWNING IN" under it, a parchment line "Back at
  your castle cellar · ranks lost from level N", and the killer card below titled SLAIN BY in the
  HUD face. The respawn countdown stays visible the whole time. The "You fell at level" announce
  moved from the centre banner to the chat log so it does not fight the screen.
- The class pick-up ribbon sits 28 px lower so the class tile clears the objective line.

Files touched: `scripts/game.gd` (`_ashlar`, `_build_castle` yard flags, `_add_ground_detail`
emission, `_add_tree_grown`), `scripts/character_model.gd` (`CHUNKY`, `_flat_mesh`, `flat_cache`,
villager scene, ear offset), `scripts/unit.gd` (`respawn_total`, `fell_level`, announce →
chat), `scripts/hud.gd` (`_draw_death_screen`, `_draw_killer_card` title, banner offset),
`docs/changelog/ui-art.md`.

Tunables (old → new): Elf yard flag tint (0.8, 0.82, 0.72) → (0.97, 0.96, 0.9); bloom emission
(0.3, 0.6, 0.7) @ 0.25 → (0.5, 0.5, 0.45) @ 0.18; blossom trees 1 in 4 → 1 in 8; bone scales
head 1.0 → 1.22, hands 1.0 → 1.3, hand slots 1.0 → 0.8, feet 1.0 → 1.25; ears x 0.5 → 0.46,
y 0.25 → 0.22; class banner y 186 → 214. Respawn times unchanged.

Renders: `world-elf-castle-pass2.png`, `world-courtyard-pass2.png`, `characters-after.png`,
`death-screen-before/after.png` (before = the old SLAIN BY card from `art/` pass-1 era is not
available; the previous build's card is described above).

Revert: `git revert ece3b24`

---

## 2026-10-09 — pause map fits its panel; promotion announce moved to chat

Commit: `e05dd11`

What changed:
- **Pause menu MAP tab**: the valley map keeps its 58:26 shape but is sized to leave room for the
  legend and the quest line inside the panel (the second legend row and the quest line used to sit
  under the MAIN MENU footer). Wildwood trees past the valley's edge are no longer drawn outside
  the map frame (they were scattered over the whole panel).
- **Promotion**: the centre "You are now a Vanguard!" announce no longer doubles the PROMOTED!
  flourish; the line goes to the chat log instead.

Files touched: `scripts/hud.gd` (`_menu_overview`, `_draw_map`), `scripts/unit.gd` (`choose_variant`),
`docs/changelog/ui-art.md`. No tunables changed.

Renders: `menu-pause-before.png` → `menu-pause-after.png`.

Revert: `git revert e05dd11`

---

## 2026-10-09 — death screen: old "You fell!" label switched off

Commit: `b259ad8`

What changed: the plain yellow "You fell! / Respawning in N" label (`game.respawn_label`) stayed
on over the new death screen; it is now kept hidden, the HUD screen carries the countdown. The
`--debug-killed` render flag kills the player 45 frames before the shot instead of 5 so the
screen has faded in (gameplay fade-in unchanged at 0.4 s).

Files touched: `scripts/game.gd` (`_update_respawn_timer`, debug flag timing),
`docs/changelog/ui-art.md`. No tunables changed.

Renders: `death-screen-after.png`.

Revert: `git revert b259ad8`

---

## 2026-10-09 — merged PR #2's main menu (create-your-character screen) into this branch

Commit: `75cd987` (merge commit, no squash)

Why: Faisal's 00:24 ask is the create-your-character screen and the Elf look. That screen lives in
PR #2's branch (`claude/project-thread-lndv4w`: scripts/menu.gd, menu_stage.gd, the throne-room
stage, Lilita One menu art), so this branch now carries PR #2 and the character-screen polish
lands on top of it. Conflicts resolved: `scripts/game.gd` sun shadows keep this branch's crisp
cartoon shadows (shadow_blur 0.3, no PCSS) over PR #2's soft 1.0; `scripts/character_model.gd`
keeps both the chunky bone scales and PR #2's `_add_face`; `assets/CREDITS.md` keeps both lists.
Also in this commit's follow-up: the pause map leaves 100 px (was 78) under it so the quest line
clears the footer.

Revert: `git revert -m 1 75cd987` (drops PR #2 from this branch again; Integration should instead
merge PR #2 first and retarget this PR).

---

## 2026-10-09 — create-your-character screen toward the reference; faceted heads kept

Commit: `027f43b`

Faisal's reference (project files): `game/reference-renders/create-character-target-2026-10-09.png`.
PR #2 already had the screen's bones (throne room stage, left category list Appearance / Hair /
Face / Armor / Colors / Emblem, right option panel with body type, skin tone, hair style, hair
colour, face style, eye colour, facial markings and preview emblem, Elf / Human buttons, Confirm).

What changed:
- **Left category list**: an ivy vine climbs its left edge; the open category shows a gold
  chevron at its right end.
- **Option panel**: the open category's name sits on a wood plaque over the panel's top edge with
  ivy sprigs at both ends instead of plain white text inside the panel.
- **Throne room light**: the hall's ambient light is warmer and a touch brighter
  ((0.5, 0.44, 0.42) @ 0.45 → (0.62, 0.5, 0.4) @ 0.55) for the reference's candle-lit look.
- **Faceted meshes keep their heads**: the flat-shaded copies from pass 2 had no index array, so
  PR #2's `Face.clean_head` failed and the hero stood headless on this screen; the copies are
  re-indexed (facets survive since vertices with different normals stay separate).
- Render flag `--debug-preview-team=N` picks the hero's side on this screen.

Still placeholders (as in PR #2): hair styles 2–5 are locked slots ("new hair styles arrive in a
later update"); the HAIR / FACE / ARMOR / COLORS / EMBLEM categories open their own panels but the
Appearance panel already carries the reference's rows. Nothing new was added to gameplay.

Files touched: `scripts/menu.gd` (`_draw_character`), `scripts/menu_stage.gd` (`_set_mood` hall),
`scripts/character_model.gd` (`_flat_mesh`), `scripts/game.gd` (render flag), `docs/changelog/ui-art.md`.

Tunables (old → new): hall ambient (0.5, 0.44, 0.42) @ 0.45 → (0.62, 0.5, 0.4) @ 0.55.

Renders: `create-character-before.png` (PR #2 as merged, Human) → `create-character-after.png` (Elf).

Revert: `git revert 027f43b`

---

## 2026-10-09 — merged World & Maps' branch (base remaster, combined PRs #1-#4, web build); scope: this group now owns the Wildwood Elf base

Commit: `5304307` (merge commit, no squash)

Why: Faisal (02:01) wants the Elf base's design, roads and build quality to match his reference,
not only the surfaces; the coordinator moved the whole Wildwood Elf base (layout, geometry, crown
room, class stations, courtyard paths, props, materials, lighting) to this group. World & Maps'
branch carries the combined build (PRs #1-#4, the web build) and their base remaster
(`1eb78a4`, `ed70e0a`), so it was merged in to build on. Agreed split (cross-session message to
World & Maps 02:05): this group edits the `mossy` / `elf_castle` / team 0 branches of
`_build_castle`, `_build_cellar`, `_furnish_cellar`, `_furnish_keep`, `_build_throne_room`,
`_polish_keep`, the Elf materials and a new `_build_elf_base`; World & Maps keeps the Human base,
Ember Pass, roads, bridges, routing and the clipping audit; shared helpers stay untouched.

Conflicts resolved: Elf lantern / tower globe / wall crystal lights keep this branch's warm and
soft colours (their moon-blue `ELF_GLOW` at 1.1-1.2 was brighter and colder than the reference);
hedge wall tops keep the clipped hedge block plus their `hedge_tops` courtyard blobs; the Elf
yard keeps cream flags; `hud.gd` takes their `scoreboard.gd` / `match_summary.gd` split and the
new keyed map legend while keeping this branch's menu style helpers (the Tab panel frame now
comes from `Scoreboard.draw_overlay`, so the leather/band styling must be ported into
`scripts/scoreboard.gd` next); `unit.gd` keeps `respawn_total` / `fell_level` and their
"down to level N" line (sent to chat, not the centre banner, so it does not fight the death
screen).

Tested: `--check-only` on game/hud/unit/scoreboard/menu/volcano; 400-frame headless bot match
with no script errors.

Revert: `git revert -m 1 5304307`.

---

## 2026-10-09 — Elf base pass A: the Wildwood Elf base toward Faisal's reference (palette, class stalls, runners, courtyard stores, altar court, light)

Commit: `bbfabb6`

Faisal (02:01): "its not just textures and small flowers but the overall design of the base and
roads and quality. Make it look exactly like the reference." References: `game/reference-renders/
elf-base-interior-target-2026-10-08.png`, `elf-courtyard-target-2026-10-08.png`,
`elf-base-layout-target-2026-10-09.jpeg`. This group now owns the Wildwood Elf base (see the merge
entry above); nothing here touches the Human base, Ember Pass or roads.

What changed (Elf base only, `elf_castle` / team 0 branches):
- **Palette back to the reference**: Elf walls are trimmed hedge (untinted `_ashlar` under
  `elf_castle`), trims are cream sandstone (not moonstone or heartwood); `_moonstone()` is now
  cream sandstone marble (0.96, 0.93, 0.86) for every caller; `_moon_silver()` is gold; Elf floors
  are cream sandstone squares (0.97, 0.96, 0.9); `ELF_GLOW` crystals are green (0.6, 1.0, 0.72)
  instead of moon-blue.
- **Class stations** (`_add_elf_class_stall`): each Elf station is a timber frame with a dark
  hanging name board on chains, a green banner with the class icon under it, a hedge behind, and a
  hexagonal timber platform under the pedestal, as in the interior reference. The Humans keep the
  stone alcoves.
- **Courtyard** (`_dress_elf_courtyard`): green stag runners from the spawn circle to the stairs
  and along the class row (new `_add_emblem_decal` lays the faction beast on a rug), a stocked
  potion shelf and a round map table by the south wall, a wildwood tree in the corner, bushes in two
  corners; the mushrooms moved from x 6.6 to 4.9 to clear the tree.
- **Crown room**: the Elf floor is cream sandstone inside a hedge-green border, with green stag
  runners out to the side walls and the back around the crystal altar; the timber lintel replaces
  the moonstone one.
- **Light and ink** (both maps, art layer): ambient 0.16 → 0.19, SSAO intensity 1.6 → 2.0,
  saturation 1.2 → 1.25, contrast 1.05 → 1.1, ink line thickness 1.4 → 1.6.

Files touched: `scripts/game.gd` (`_ashlar`, `_flagstone`, `_moonstone`, `_moon_silver`, `ELF_GLOW`,
`_build_throne_room`, `_add_class_alcove`, new `_add_elf_class_stall`, `_icon_mat`, `_class_icon_name`,
`_add_emblem_decal`, `_dress_elf_courtyard`, `_furnish_cellar`, `_build_cellar`, environment and day
light), `assets/shaders/ink_outline.gdshader`, `docs/changelog/ui-art.md`.

Tunables (old → new): ambient 0.16 → 0.19; ssao_intensity 1.6 → 2.0; saturation 1.2 → 1.25;
contrast 1.05 → 1.1; ink thickness 1.4 → 1.6; ELF_GLOW (0.62, 0.8, 1.0) → (0.6, 1.0, 0.72).
No gameplay numbers changed; station, spawn and lane positions unchanged.

Tested: `--check-only`; `--audit` 1 overlap on the Wildwood (the same pine pair as before, none
added); 300/600-frame headless bot matches with no script errors.

Renders: `elf-base-passA-castle.png`, `elf-base-passA-courtyard.png`, `elf-base-passA-throne.png`
and `compare-elf-base-reference-vs-passA.png`.

Revert: `git revert bbfabb6`

---

## 2026-10-09 — Elf base pass B: cobbled yard lane with lawns, trees and fire pillars; leaf wall tops; courtyard lawn; stag decals fixed

Commit: `f5d39ef` (then merge `0b12837` of World & Maps' 8fb3a0e: Human identity, cobbled flank paths)

What changed (Elf base only):
- **Yard** (`_dress_elf_yard`, courtyard reference): a cobbled lane from the gate to the keep's arch
  with the stag at its middle, lawns with raised flower beds and bushes either side, a wildwood tree
  in each inner corner (off the lane and the rampart-stair routes), and a stone fire pillar either
  side of the arch.
- **Wall tops**: every Elf merlon is a leaf tuft again; the cream caps from the moonstone pass read
  as white balls from above in the pass A render.
- **Courtyard**: a lawn with a flower bed beside the spawn circle's south side; the map table moved
  from x 12.6 to 10.4 so it clears that bed (audit clean on the Elf side).
- **Stag decals** on the runners sit 5-8 cm above the rug (0.11 / 0.15) instead of 6 mm: they were
  depth-fighting the rug and did not show.

Files touched: `scripts/game.gd` (`_build_castle` team 0 hook, new `_dress_elf_yard`, `_add_wall`,
`_dress_elf_courtyard`, `_build_throne_room`), `docs/changelog/ui-art.md`. No tunables.

Tested: `--check-only`; `--audit` 1 overlap on the Wildwood (the pre-existing pine pair);
900-frame headless bot match clean; after the merge a 300-frame match clean.

Renders: `elf-base-passB-castle.png`, `elf-base-passB-courtyard.png`, `elf-base-passA-throne.png`.

Revert: `git revert ae919cd` (and `git revert -m 1 0b12837` for the merge).

---

## 2026-10-09 — Elf base pass C: readable station boards, framed crown-room hedges, softer crown glow, rampart fire pillars

Commit: `ae919cd`

What changed (Elf base only):
- **Class station boards**: the timber name board is 2.2 × 0.62 (was 1.9 × 0.5) and the class name
  now sits in front of it, turned to the camera (billboard, font 72), so it reads from the top-down
  view; in pass A it was inside the board and invisible.
- **Crown room**: timber door posts and timber corner posts with caps frame the hedge walls (the
  reference's framed hedges); the crown's room light is 0.6 (was 1.2) and the altar's green light
  0.9 (was 1.4), so the crystal altar is no longer washed out.
- **Outer defence**: a stone fire pillar on the outer half of the rampart deck either side of the
  gatehouse (the layout sheet's upper-level defence), clear of the archer posts and stair tops.
- **Yard lane** (fb9c9f7, before this entry): lane and lawns lifted 2 cm above the yard flags so
  they no longer show in patches; the cobble tint cooled to (0.82, 0.8, 0.74).

Files touched: `scripts/game.gd` (`_add_elf_class_stall`, `_add_class_alcove` label,
`_build_throne_room`, `_add_crown_altar`, `_dress_elf_yard`), `docs/changelog/ui-art.md`.

Tunables (old → new): crown room light 1.2 → 0.6 (Elves); altar light 1.4 → 0.9.

Tested: `--check-only`; `--audit` 1 overlap (the pre-existing pine pair); 600-frame headless match
clean.

Renders: `elf-base-passC-courtyard.png`, `elf-base-passC-throne.png`, `elf-base-passC-castle.png`.

Revert: `git revert ae919cd`

---

## 2026-10-09 — Elf base pass D: the crown room upstairs, turret pads, hedge line (layout sheet)

Commit: `d2bf681`

What changed (Elf base only; the Human side is untouched):
- **Crown room upstairs**: the Elves' crown room now stands on a sandstone terrace 0.9 m above the
  keep floor (`ROOM_RAISE`), with a wide flight of stairs between timber cheek walls from the keep
  hall up to the vault doors; its hedge walls, posts, cornice, rugs, decals, crests, crystals and
  chests all ride the terrace. The keep's arch-to-throne rug is Humans-only now (the stairs take its
  place). The throne/crown position is `thrones[0] = (-63.5, 0.9, 0)`; scoring is a flat distance so
  captures are unaffected, and the bots' throne-room routing box already spans the height.
- **Turret spots** (the sheet's outer-defence turrets): a round sandstone pad with a gold ring at each
  of `turret_spots(0)` (two on the rampart, two in the yard), new `_add_turret_pad`.
- **Fence line**: a trimmed hedge run along the outside foot of the front wall from the gate approach
  to each corner (decor, not solid); the yard-side bush there was dropped. The rampart fire pillars
  moved out to z ±10 so they clear the turret spots.
- Shared code touched, no-op for the Humans: `vault.gd` places the doors at `throne.y`;
  `_polish_keep` pennants add `throne.y`.

Files touched: `scripts/game.gd` (`ROOM_RAISE`, `_build_castle`, `_build_throne_room`,
`_polish_keep`, `_dress_elf_yard`, `_add_turret_pad`), `scripts/vault.gd`, `docs/changelog/ui-art.md`.

Tunables (old → new): `ROOM_RAISE` new 0.9 (Elves; 0 keeps the old ground-level room); rampart fire
pillars z ±(DOOR_HALF+4.6) → ±(CASTLE_HALF_Z−2.0).

Tested: `--check-only` on game.gd and vault.gd; `--audit` 1 overlap (the pre-existing pine pair);
headless bot matches (seed 3, 200 s; seed 5, full length) with no script errors. The full match
ended 0-0 with both teams' raiders idling in their own keeps behind the crown room from t=30 s;
the same seed on the pass C commit (ae919cd) does exactly the same, so it is not this pass (under
investigation, see the next entry).

Renders: `elf-base-passD-throne.png`, `elf-base-passD-castle.png`.

Revert: `git revert d2bf681`

---

## 2026-10-09 — Fix: bot raiders trapped behind the crown room in both keeps (0-0 matches)

Commit: `b678241`

What was wrong: since the World & Maps merge (5304307) every headless bot match ended 0-0 with no
gate damage. Both teams' raiders came up the spawn stairs, headed for the gate straight through the
throne room's back wall (the route gives the gate, not the gallery corner, from there), slid along
the wall as designed, and ran into the new solid stone fire pillar standing 8 cm off the room's
outer corner, which closed the corner between wall and gallery. They oscillated there for the whole
match. Traced with a per-bot probe print and a solid-box dump behind the room; main (799a873) and
this branch before the merge (ece3b24) were fine.

Fix (shared `_polish_keep`, both teams): the four fire pillars moved off the room's corners to the
keep's archway wall (`kx + side*1.0, ±(KEEP_DOOR_HALF+2.4)`) and the keep's back wall
(`bx - side*1.0, ±(ROOM_HALF_Z+0.85)`), where nothing routes. No routing code touched (World & Maps
owns it; told them).

Tested: `--check-only`; `--audit` unchanged (1 pre-existing pine overlap); seed-5 match: raiders out
of both keeps by t=30 s, doors 110/198 at t=60 s (were 200/200 for 600 s before).

Files touched: `scripts/game.gd` (`_polish_keep`), `docs/changelog/ui-art.md`.

Revert: `git revert b678241` (brings the 0-0 matches back)

---

## 2026-10-09 — Merge World & Maps (f95a3ea): their raider fix supersedes ours

World & Maps fixed the same trap on their branch (47c7d81) by turning the four corner fire pillars back
into non-solid `_add_torch` torches, the pre-merge look. Merged their branch and took their torches
over our moved braziers (conflict in `_polish_keep`), keeping our terrace heights (`fy`/`throne.y`)
on the throne-room banner, light and pennants; their removal of the Human stone lions inside the
throne room's doors is taken as is. Seed-5 match after the merge: doors 120/200 at t=60 s, no script
errors, audit unchanged. Reverting our own fix commit above is no longer needed (its lines are gone).

---

## 2026-10-09 — Merge World & Maps (965ecd3): `_polish_keep` split, Elves keep the moved fire pillars

Their merge of our branch resolved `_polish_keep` as: Elves get our archway/back-wall stone fire
pillars, Humans keep plain corner torches (their props hold those wall spots). Taken as is so both
branches read the same; our terrace heights (`fy`/`throne.y`) are intact. Seed-5 match after the
merge: doors 200/176 at t=60 s (Elves raiding), no script errors.

---

## 2026-10-09 — Elf courtyard: hidden south-wall flower beds moved into view

Commit: `b4c6aa2`

World & Maps found that the game camera looks over the south (+z) wall of the sunken courtyard and
the wall's top hides the first ~2.5 m of floor behind it, so the three Elf flower beds at z = hz−1.4
(pass A) were never seen in play. Now one bed at z = hz−2.9 by the west end; the two further along
are dropped (the lawn, its own bed and the round table already dress that visible strip).

Files touched: `scripts/game.gd` (`_build_cellar`, team 0 beds), `docs/changelog/ui-art.md`.
Tunables (old → new): Elf courtyard beds at x 3.4/11.0/14.4, z hz−1.4 → one bed at x 3.4, z hz−2.9.
Tested: `--check-only`; `--audit` unchanged (1 pre-existing pine overlap).

Revert: `git revert b4c6aa2`

---

## 2026-10-09 — Elf base overhaul to the reference (Faisal's 03:30 / 03:34 brief): graphics, architecture, materials, pedestal, stations, workshop

Commit: `7e37f9f`

Faisal (03:30): "keep using the render as a reference, can you improve the graphics"; (03:34) the
nine-point overhaul brief (shapes/proportions, open the base, replace the noisy green materials,
rebuild the floors, lighting and depth, crown focal point, functional areas, controlled detail,
consistency). This commit covers points 1-7 and the lighting; point 8 follows.

What changed:
- **Lighting (both maps' day light)**: soft lambert-wrap shading on every material instead of
  two-band toon (`_toon_mat`); PCSS soft shadows (sun `light_angular_distance` 0 → 1.2,
  `shadow_blur` 0.3 → 1.2); day ambient 0.19 → 0.27 (sky contribution 0.25 → 0.3), saturation
  1.22 → 1.12, contrast 1.1 → 1.06, sun 1.45 → 1.3 at −44° (was −38°), warmer-less-yellow sun
  colour, glow 0.7 → 0.6; SSAO radius 1.0 → 1.3, intensity 2.0 → 2.6; ink line thickness 1.6 → 1.25.
- **Materials**: the Elf castle's untinted "stone" is cream sandstone, never the hedge texture
  (`_ashlar`, `_add_wall`); hedges are leaf-blob runs along every Elf wall top; the hedge texture
  itself is now overlapping leaf clumps (`make_hedge`), the sandstone bricks cream with soft tan
  joints (`make_stone`), the paving three big soft-edged blocks per tile with restrained seams
  (`make_flagstone`, also regenerates the moss and grey variants).
- **Architecture (Elves only)**: crown-room side and back walls are a 1.3 m, 0.7 m-thick sandstone
  parapet with hedge on top (sight ray at 1.0 m and shots at 1.1 m still blocked); the front wall
  with the vault doors stays full height; chunky 0.8 m timber corner posts with caps. The keep's
  side walls are a 1.4 m parapet with hedge tops (`kh`), corner pillars shortened to match, wall
  torches lowered, tapestries and wall pennants/crests dropped on the low walls. Footprints and
  collision unchanged; bots route as before.
- **Crown focal point**: round layered sandstone pedestal with two gold bands under the crystals and
  antlers (replaces the moonstone block); dais tiers 0.14 m tall (were 0.1); crystal emission
  1.6 → 1.1; the crown's resting aura 0.7 scale / 0.2 alpha (was 1.0 / 0.35, `monarch.gd`, both
  teams).
- **Stations and workshop**: class banners in each class's own colour with the gold hem; thicker
  stall posts (0.32) and beam; a workshop corner round the Upgrade Station (shelves with bottles,
  crates, a barrel) against the courtyard's west wall.
- **After the first renders**: both keep galleries paved in the same sandstone (were planks and
  moonstone); the crown's room light 0.6 → 0.3, its gold emission 0.9 → 0.5 and resting beam alpha
  0.2 → 0.12 (`monarch.gd`, both teams); foliage tops HSV hue 0.26 → 0.31, value 0.68-0.8 →
  0.52-0.62 on every leaf blob and canopy (`_leaf_material`); stag banner frames at the crown
  court's back corners.

Files touched: `scripts/game.gd`, `scripts/monarch.gd`, `tools/make_textures.py`,
`assets/textures/{hedge,stone,stone_moss,flagstone,flagstone_moss,flagstone_grey}_{color,normal}.jpg`,
`assets/shaders/ink_outline.gdshader`, `docs/changelog/ui-art.md`.

Tested: `--check-only` (game.gd, monarch.gd); `--audit` 1 overlap (pre-existing pines), 269 props;
seed-5 bot matches: doors 169/200, then 172/198 at 60 s on the final state (raiders out, crown
room reachable). Renders: `elf-base-overhaul-*.png` (debug and in-play cameras) and the
`compare-*-overhaul.png` side-by-sides in game/groups/ui-art/.

Revert: `git revert 7e37f9f` then `python3 tools/make_textures.py make_hedge make_stone make_flagstone`
is NOT needed (the textures are committed; the revert restores them).

## 2026-10-09 — Elf class-selection courtyard rebuilt as an open garden (Faisal's 04:08 brief)

Commit: `c5afec8`. Scope: ONLY the Wildwood Elves' class-selection courtyard (the former
"cellar" behind the Elf keep); the Human cellar and both Ember Pass cellars are untouched.

- **Ground level, not sunken**: new `cellar_floor(team)` returns 0.0 for the Wildwood Elves
  (−2.4 everywhere else). `_in_cellar` now bounds the courtyard in x as well (depth < 19 m) and
  tests `y < floor + 2`, so spawn protection, "defending home", the projectile sanctuary rule and
  the barricade rule ("Not in the cellar", now via `_in_cellar`) behave as before on every map.
  `cellar_stairs`, `_route_leg` and unit spawns use `cellar_floor`. Bots route out through the
  castle passage as before (seed-5 match: all five Elves out by 30 s, hats taken).
- **Composition** (`_build_cellar` open branch, `_add_elf_courtyard_fence`,
  `_dress_elf_open_courtyard`): the 3.3 m hedge walls are gone; the edge is a 0.3 m sandstone kerb
  with a timber picket fence on it round three sides, plus an unseen 1.4 m collider so nothing
  walks or shoots in (sight ray 1.0 m, shots 1.1 m). A solid paved sill fills the ground gap under
  the old stairs' top. One stag runner from the spawn circle to the passage, one along the class
  row; lawn with two planting beds along the south fence; the workshop (Upgrade Station board,
  bench, barrels, shelves, crates) grouped in the south-east corner; the Guide by the passage;
  nothing loose in the middle. Eight trees with layered crowns (`_add_canopy_tree`) and clipped
  bushes frame the fence from outside.
- **Stations** (`_add_elf_class_station`, `_add_elf_station_canopy`, `seal.gd`): six stations
  centred on the courtyard 2.85 m apart under a pavilion: seven 0.36 m timber posts with capped
  tips in front and seven taller behind the fence, beams and rafters, an emerald canvas that sags
  per bay, rising to the back, with a scalloped hem and gold band. Each station: octagonal
  sandstone slab, bevelled second tier, bronze band, carved cream pedestal with a gold cap
  (`seal.gd`, `lift` 0.2 m) and the class hat; behind it a thick dark name board on iron chains
  over an emerald panel with gold hems, a soft disc of the class colour and the class emblem. The
  alcove runes, second ring and light are dropped for these stations; the hat's own ring is
  smaller (0.8–0.96) and quieter (alpha 0.45, emission 0.8).
- **Materials**: new `pavers` texture (`tools/make_textures.py make_pavers`): staggered cream
  sandstone slabs with rounded corners and soft bevels, one tile per 4.5 m (`_pavers()`).
- **Lighting** (`_apply_map_variant` day): ambient 0.27 → 0.21, saturation 1.12 → 1.08, contrast
  1.06 → 1.08, sun 1.3 → 1.42 at −46° (was −44°), shadow opacity 0.9 → 0.92, shadow blur and
  angular distance 1.2 → 0.8; SSAO radius 1.3 → 1.1, intensity 2.6 → 3.2.

Files: `scripts/game.gd`, `scripts/seal.gd`, `tools/make_textures.py`,
`assets/textures/pavers_{color,normal}.jpg` `docs/changelog/ui-art.md`.

Tested: `--check-only` (game.gd, seal.gd); `--audit` 1 overlap (the pre-existing pines), 262
props; seed-5 90 s match (Elves on the floor, out by 30 s); Ember Pass `--map=2` still builds the
sunken Elf cellar; full seed-7 match: Elves 2-0 at 137 s (captures work). Renders: `elf-courtyard-rebuild-*.png` and
`compare-elf-courtyard-reference-vs-rebuild.png` in game/groups/ui-art/.

Revert: `git revert c5afec8`.

## 2026-10-09 — Elf base decluttered, one paving stone throughout (Faisal 06:00: "both sides equally cluttered… front textures not uniform")

Commit: `70f43e1`. Elf side only (the Humans' side is World & Maps'); no map-wide pass.

- **One paving**: the yard, the keep floor, both galleries and the crown-room floor now use the
  courtyard's `_pavers()` (were cream flagstone, moonstone-tinted flagstone at 0.75, flagstone,
  flagstone), so the base reads as one stone from the gate to the crown. The door apron outside
  the gate and the road are shared map code (World & Maps) and unchanged.
- **Yard decluttered** (`_dress_elf_yard`, `_build_castle`): removed the cobble lane, the two
  lawns, four flower beds, two bushes by the gate, two lanterns, the two rampart fire pillars,
  the hedge runs along the outside of the front wall, and the four bushes against the walls.
  Kept: the two corner trees, the two fire pillars at the keep's arch, the four turret pads, the
  gate torches, banner frames and tower pennants. Both teams now lay one runner with the faction
  emblem from the gate to the archway (the Elves had a short rug at the arch plus a decal on the
  lane).

Files: `scripts/game.gd`, `docs/changelog/ui-art.md`. Tested: `--check-only`; `--audit` 1 overlap
(the pre-existing pines), 261 props; seed-5 90 s match: doors 118/110 at 60 s.
Renders: `elf-front-declutter-before.png` / `-after.png` and `compare-elf-front-before-vs-after.png`
in game/groups/ui-art/.

Revert: `git revert 70f43e1`.

## 2026-10-09 — Elf crown room: Faisal's circled clutter removed (08:17 annotated screenshot)

Commit: `3a57415`. Elf side only; merged World & Maps first (their Human clutter removal,
path z-fight fix, road fences).

- Removed the timber corner posts on the Elf crown room ("random clipping into wall") and the
  hedge runs along its wall tops ("random greenery"); the walls now take a plain cream sandstone
  cap like the Humans'.
- Removed both stag banner frames at the crown court's back corners ("random sign").
- Removed the lilac mushrooms in the crown room, the moon shrine and the study ("random
  objects"), and the two loose rugs in the study and armoury behind the crown room.

Files: `scripts/game.gd`, `docs/changelog/ui-art.md`. Tested: `--check-only`; `--audit` 1
overlap (pre-existing pines), 250 props; seed-5 90 s match doors 102/36 at 60 s.
Renders: `elf-crown-room-declutter-after.png` in game/groups/ui-art/.

Revert: `git revert 3a57415`.

## 2026-10-09 — Elf class courtyard: Faisal's circled notes (08:18 annotated screenshot)

Commit: `8caeef4`. Merged World & Maps first (their grove replacing the camp west of the
courtyard fence, his note 4).

- **"Names of classes are clipping"**: the names sat on boards along the pavilion's top edge,
  which the game camera cuts off. Each name now stands just in front of its station's base
  (billboarded, y 0.3, 1.35 m forward); the name boards are gone and the emblem panel gets a
  dark timber frame instead.
- **"Wrong way for the upgrade station"**: moved from the south-east corner by the exit to the
  class row's near end, (bx − 1.6, 0, −4.0), board backing onto the row, anvil facing the room.
  The row runner now starts past it (13.0 m long, was 16.2). The Guide is back at (bx − 1.3, 0,
  5.2).
- **"Random green texture box?"**: removed the lawn strip and both planting beds along the south
  fence, and the orphaned shelves, bottles, crates and barrel that stood there.

Files: `scripts/game.gd`, `docs/changelog/ui-art.md`. Tested: `--check-only`; `--audit` 1
overlap (pre-existing pines), 245 props; seed-5 90 s match doors 171/0 at 60 s.

Revert: `git revert 8caeef4`.

## 2026-10-09 — Elf yard: corner trees removed (Faisal 08:21 "giant blobs… inside the building")

Commit: `0afd162`. The two wildwood trees in the Elf yard's back corners (one pink, at about
x −55, z ±7.8) are gone from `_dress_elf_yard`; the yard keeps the arch fire pillars, turret pads
and the runner. World & Maps removed the leafy canopy blobs on the Elf towers in `_add_tower`.

Files: `scripts/game.gd`, `docs/changelog/ui-art.md`. Tested: `--check-only`; `--audit` 1 overlap,
245 props; seed-5 90 s match doors 163/14 at 60 s.

Revert: `git revert 0afd162`.

## 2026-10-09 — Elf courtyard: upgrade station faces the spawn, banners face the castle wall (Faisal 08:35)

Commit: `bcdae1e`. New `_turn_since(c0, a0, pivot, yaw)` turns everything a builder just added
(children and audit boxes) about a pivot. `_add_upgrade_pad` and `_add_banner_pole` take an
optional `yaw` (default 0 = unchanged, so the Humans, Ember Pass and door banners are untouched).
- Upgrade Station (Wildwood Elves): moved from (bx − 1.6, 0, −4.0) to (bx − 2.8, 0, −3.4) and
  turned to face the spawn circle (yaw ≈ −74°): anvil toward the spawning players, board and
  workbench backing onto the castle wall. Its second cask sits 0.25 m further out (they touched
  once turned).
- Stag banners by the spawn circle (bx − 17.2, z ±6.2): turned 90° so their backs are to the west
  fence and they face across the courtyard to the castle wall.

Files: `scripts/game.gd`, `docs/changelog/ui-art.md`. Tested: `--check-only`; `--audit` 1 overlap
(pre-existing pines), 245 props; seed-5 120 s match: Human gate 32 at 90 s, crown taken by 120 s.

Revert: `git revert bcdae1e`.
