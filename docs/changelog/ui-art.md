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

Commit: `(hash filled in below)`

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

Revert: `git revert <hash>` (filled in below once committed).
