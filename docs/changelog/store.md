# Store group changelog

Branch `group/store-1qlkih`, based on the UI & Art branch (`group/ui-art-z3px4x`, 80a9913) because the
store lives in the main menu (PR #2) and spends the match gold and Match Chests that branch already
banks (`game.account_gold`, `account_chests`). The draft PR targets `group/ui-art-z3px4x`, so its diff
is the store alone. Every commit on this branch has an entry here with what changed, the files, old →
new values for any tunable, and the line that undoes it. Renders are under
`/mnt/project-files/game/groups/store/`.

Rules the store keeps:
- Looks only. Nothing sold changes health, damage, speed, cooldowns or costs, so balance is untouched.
- Gold only (Match Gold from the end-of-match rewards). No real money. Shards are banked but not spent
  yet. The Economy group's in-match wood and ore are a separate currency and are not touched.
- Everything that was free before stays free; only new entries appended to the tables are sold.

Tests:
- `godot --headless --path . --script tools/store_test.gd` (ownership, buying, chests, save rules, a
  model built with every hat, cape, armour tint and weapon skin).
- `godot --headless --path . --script tools/store_menu_test.gd` (clicks through the store screen).
- `tools/options_menu_test.gd` (UI & Art's) still passes: it now owns every store item first.

---

## 2026-10-09 — the STORE: spend match gold on cosmetic hero items, open Match Chests

Commit: `bb72065`

What changed:
- **STORE screen** (main menu): reached from a new STORE plank under EXIT on the title and from a gold
  purse under the account chip. Six tabs down the left (HAIR, ARMOUR, CAPES & DYES, HATS, WEAPONS,
  BANNERS) with owned/total counts, the hero in 3D in the middle wearing whatever card is picked (try
  before you buy; the hero turns round for capes), a grid of rarity-framed cards on the right with the
  price or OWNED / EQUIPPED, and a card underneath with BUY (price) / EQUIP / TAKE OFF. Buying spends
  the gold, wears the item at once and pops a PURCHASED! ribbon.
- **Match Chests**: the chest the match summary hands out each match is now opened in the store's
  top-left box. A chest gives one item you do not own yet, picked by rarity weight (Common 60, Rare 28,
  Epic 10, Legendary 2), shown on a reveal card; with everything owned it pays 150 gold.
- **Stock (45 items)**: 6 hair colours, 6 armour tints (recolour the metal plates), 5 capes and a long
  scarf (hang on every class in the cape dye; replace the pack's own capes), 6 cape dyes, 7 hats (worn
  with no class hat on), 6 weapon skins (recolour every class's weapons and shields, three glow), and
  banner pieces (2 backgrounds, 4 emblems, 3 frames).
- **Create Your Character**: store colours, dyes and banner pieces you do not own show locked with the
  price; clicking one opens the store on it. The ARMOR tab gained rows for ARMOUR TINT, HAT, CAPE &
  SCARF and WEAPON SKIN. Hair colours and dyes are laid out four to a row to fit twelve.
- **Saves**: `owned_items` (profile) and `hero_hat` / `hero_cape` / `hero_outfit` / `hero_weapon`
  (settings) in `user://controls.cfg`. Anything worn but not owned (a hand-edited save) is taken off on
  load.

Tunables (new, `scripts/stats.gd`): prices by rarity Common 300 / Rare 600 / Epic 1200 / Legendary 2500
gold (`RARITIES`); `CHEST_GOLD` 150; free entries `HERO_HAIR_FREE` 6, `HERO_TRIM_FREE` 6,
`BANNER_BG_FREE` 8, `BANNER_EMBLEM_FREE` 14, `BANNER_FRAME_FREE` 5. Match gold is unchanged
(200 loss / 250 draw / 300 win), so a Common item is one to two matches and a Legendary about ten.

Files: `scripts/store.gd` (new: catalogue rules + screen), `scripts/store_gear.gd` (new: hats, capes,
scarf, armour tint, weapon skin on the model), `scripts/stats.gd`, `scripts/game.gd`,
`scripts/menu.gd`, `scripts/menu_stage.gd`, `scripts/character_model.gd`, `scripts/hud.gd` (banner
editor locks only), `tools/store_test.gd` (new).

Undo: `git revert bb72065`

## 2026-10-09 — merge UI & Art's menus and hair styles; three hair styles go on sale; purse fix

Commit: `78fa3c0` (merge of `origin/group/ui-art-z3px4x` at 19dadd1)

What changed:
- UI & Art's four modelled hair styles are in. Classic and Ponytail stay free; **Long (Common),
  Braids (Rare) and Bun (Rare)** are sold in the store's HAIR tab and show locked with their price in
  Create Your Character (`HERO_HAIR_STYLE_FREE` = 2).
- Fix: the title's gold purse sat under the close button of the Credits / Tutorial / Progress
  overlays and caught that click (opened the store instead of closing). It is not clickable under an
  overlay now.
- `tools/options_menu_test.gd` owns every store item before clicking the character screen and
  tracks the new gear fields; new `tools/store_menu_test.gd`.

Undo: `git revert -m 1 78fa3c0` (keeps the store, drops UI & Art's merge and the hair-style sales).

## 2026-10-09 — clearer weapon and armour cards; softer tints and glows

Commit: _pending_

What changed:
- Weapon cards draw a sword in the skin's metal and armour cards a breastplate in the tint (the small
  painted icons read as dark blobs).
- Armour tints keep 20 % of the original metal shading; weapon skins brighten less (×1.3 → ×1.15).
- Weapon glow: Frostbite 0.6 → 0.3, Ember 0.8 → 0.35, Shadow 0.6 → 0.3.
- Testing flags: `--debug-gold=N`, `--debug-chests=N`, `--debug-own=kind:i,…` (owned and worn; also
  with `--play`), `--debug-store=kind:i`, `--debug-store-buy`, `--debug-store-chest`.

Files: `scripts/store.gd`, `scripts/store_gear.gd`, `scripts/stats.gd`, `scripts/game.gd`.
