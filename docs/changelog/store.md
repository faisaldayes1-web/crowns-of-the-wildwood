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

Commit: `855b259`

What changed:
- Weapon cards draw a sword in the skin's metal and armour cards a breastplate in the tint (the small
  painted icons read as dark blobs).
- Armour tints keep 20 % of the original metal shading; weapon skins brighten less (×1.3 → ×1.15).
- Weapon glow: Frostbite 0.6 → 0.3, Ember 0.8 → 0.35, Shadow 0.6 → 0.3.
- Testing flags: `--debug-gold=N`, `--debug-chests=N`, `--debug-own=kind:i,…` (owned and worn; also
  with `--play`), `--debug-store=kind:i`, `--debug-store-buy`, `--debug-store-chest`.

Files: `scripts/store.gd`, `scripts/store_gear.gd`, `scripts/stats.gd`, `scripts/game.gd`.

Undo: `git revert 855b259`

## 2026-10-09 — store icons rendered from the real hero model

Commit: `bedc7be` (after merging `origin/group/ui-art-z3px4x`)

What changed:
- 53 new item icons in `assets/ui/store/<kind>_<index>.png` (256×256, transparent): every hat, hair
  style and hair colour on the hero's head, every cape and cape dye from behind, every armour tint on a
  Knight, every weapon skin on the Knight's sword and shield. They are renders of the same models the
  game uses, so the icon shows exactly what you buy.
- Store cards draw the icon large (most of the card) over a soft glow in the rarity colour, with the
  name and price underneath; the chest reveal card shows it bigger too. Small swatches (Create Your
  Character rows) and banner pieces keep the drawn glyphs.
- Re-render after changing a model: `xvfb-run -a -s "-screen 0 1280x1280x24" godot --path .
  --rendering-driver vulkan --resolution 768x768 --script tools/render_store_icons.gd [-- --only=hat]`
  then `godot --headless --path . --import`. A hand-painted PNG dropped in under the same name replaces
  a render.

Files: `scripts/store.gd`, `tools/render_store_icons.gd` (new), `assets/ui/store/` (new).

Undo: `git revert bedc7be`

## 2026-10-09 — store fits the screen (Faisal's circled gold box and BUY button)

Commit: `149effe`

What changed (all in `scripts/store.gd`, positions in the 1280×720 canvas):
- Gold box: Rect2(1012, 24, 240, 62) → (1012, 14, 240, 58); subtitle "GOLD · +200 to +300 a match" →
  "GOLD · +200-300 a match" (it ran past the box's edge). Match Chests box moved up the same way.
- Card panel: (832, 110, 430, 480) → (832, 122, 430, 452), so its HAIR/HATS plaque no longer touches the
  gold box.
- Detail card: (832, 600, 430, 110) → (832, 586, 430, 106); it now ends 28 px above the screen's bottom.
- BUY / EQUIP button: (end − 196, +20, 180×62) → (end − 202, +22, 170×54), so the green button's arrows
  stay inside the card.

Undo: `git revert 149effe`

## 2026-10-09 — saved progress: safe saves, a reset bug, export/import codes

Commit: `d40c3c4`

Faisal 11:46: "add a way to save progress for the leveling".

What changed:
- **Bug fixed:** RESET TO DEFAULT on the Controls tab deleted the whole save file, so it wiped the
  account level, XP, gold, chests and store items along with the key bindings. It now resets only the
  `[controls]` section.
- **Safe saves** (`scripts/save_file.gd`): the save is written to `controls.cfg.tmp`, read back, the old
  save is kept as `controls.cfg.bak`, then the new one replaces it. A save that will not load (cut off
  by a crash or power loss) falls back to the `.bak`.
- Also saves when the window is closed and on EXIT; a "Progress saved" notice after each match.
  (It already saved after every match, purchase and change; a match quit halfway still earns nothing.)
- **PROGRESS screen** (title, account chip): a SAVED PROGRESS row with EXPORT CODE and IMPORT CODE. The
  code (~550 characters, `CROWNS1-…`, with a checksum) holds the account (level XP, gold, shards,
  chests, store items) and the hero/banner looks, not the device's settings or controls. On the web
  EXPORT downloads `crowns-progress.txt` and shows the code to copy, and IMPORT asks for it to be
  pasted; on desktop they use the clipboard. IMPORT replaces the account and keeps the old save as
  `controls.cfg.before-import`.
- Checked in the web build (Chromium, Playwright): the save is still there after the browser is
  closed and reopened, EXPORT downloads the code, and IMPORT on another browser profile brought in
  level 7 / 9876 gold.

Tests: new `tools/save_test.gd` (17 checks: restart, damaged save, reset keeps progress, codes, an
altered code is refused); `tools/options_menu_test.gd` taps EXPORT CODE / IMPORT CODE.

Files: `scripts/save_file.gd` (new), `scripts/game.gd`, `scripts/menu.gd`, `tools/save_test.gd` (new),
`tools/options_menu_test.gd`.

Undo: `git revert d40c3c4`

## 2026-10-10 — the gold amount fits its box; no "+200-300 a match" line

Commit: `135b76c` (branch restarted from `release/v0.4.0-alpha` at a94aab8 after PR #14 merged)

Faisal 09:02: "the gold is not fully showing in numberbox when ur in the main menu it clips out also take
out the (200-300 each match.)"

What changed:
- Title purse and the store's gold box shrink the number's text size until it fits (`menu.fit_size`), and
  write it with commas (`menu.gold_text`: 1234567 → "1,234,567 GOLD").
- The store's gold box no longer has the "GOLD · +200-300 a match" line; "1,234,567 GOLD" sits centred.

Files: `scripts/menu.gd`, `scripts/store.gd`.

Undo: `git revert 135b76c`

## 2026-10-10 — named players: progress saved per player

Commit: `71ca08f`

Faisal 09:03: "Make sure the game saves progress everytime you play, connecting your progress to a name
and saving the data".

What changed:
- **One save per player**: `user://profiles/<id>.cfg` (`p1`, `p2`, …) holds that player's name, level XP,
  gold, shards, chests, store items, hero look and banner. `controls.cfg` keeps this device's settings and
  key bindings plus `[profiles] current`, and still a copy of the current player's data. Every save (after
  each match, purchase, equip and change, on EXIT and on closing the window) writes both through the
  safe write (`.tmp`, read back, `.bak`, rename).
- **Nobody loses progress**: an existing save becomes the first player (named after the hero name).
- **First launch** opens WHO'S PLAYING? on the title with the name field ready (typing on PC; on iPad
  tapping the field opens the browser's name box). Only on a plain launch: tests and renders with flags
  skip it.
- **PLAYERS** button under the gold on the title: the list of players with level, rank and gold;
  PLAYING marks the current one (tap the name to rename); PLAY AS switches (the hero, gold and items
  change at once); + NEW PLAYER starts one at level 1; DELETE asks SURE? and removes another player (never
  the one playing). Up to 6 players.
- **Codes carry the name**, and IMPORT CODE now adds the code's player next to the others instead of
  replacing the one playing.

Tests: `tools/save_test.gd` +9 checks (own file, new player starts empty, switching keeps each apart, a
restart carries on as the last player, the list, the code's name, delete rules, import adds a player);
`tools/options_menu_test.gd` opens PLAYERS.

Files: `scripts/save_file.gd`, `scripts/game.gd`, `scripts/menu.gd`, `tools/save_test.gd`,
`tools/options_menu_test.gd`.

Undo: `git revert 71ca08f` (the profile files stay on disk and are ignored; controls.cfg still holds the
current player's data).

## 2026-10-14 — Epic and Legendary items look expensive

Commit: `2dc1ab1` (branch restarted from the Steam beta `group/integration-release-g9m95g` at b0e261f)

Faisal 20:46: "for the expensive rare items make them look visually different so it entices sales".

What changed:
- **Store cards by tier** (`scripts/store.gd` `_card`): Common as before; Rare adds a thin brass line inside
  the frame; Epic adds a glow that breathes, a light band sweeping across every 3.4 s, three twinkling
  sparkles and an EPIC tag on the top edge; Legendary adds slow golden rays turning behind the item, six
  sparkles, a sweep every 2.4 s, brass corner braces and a LEGENDARY tag. The detail card under the grid
  gleams the same way for Epic and Legendary.
- **Preview**: the hero sways side to side for an Epic pick and turns slowly all the way round for a
  Legendary one.
- **Worn sparkle** (`scripts/store_gear.gd` `aura`, called from `character_model.gd`): Epic (violet, 10
  motes) and Legendary (gold, 18 larger motes) hats, capes, armour tints and weapon skins sparkle round the
  head, back, chest or sword hand — in the menus and in matches. CPUParticles3D, so it runs on the web
  build too.
- No price, stat or save change.

Tests: `tools/store_test.gd` +3 (Legendary gear sparkles, Common/Rare does not, Epic weapon does).

Files: `scripts/store.gd`, `scripts/store_gear.gd`, `scripts/character_model.gd`, `tools/store_test.gd`.

Undo: `git revert 2dc1ab1`

## 2026-10-14 — Player banners in the store, by rarity

Commit: `7ce0768` (after merging UI & Art's banner set, `aa7db47`)

Faisal 20:48: "player banners".

What changed:
- **Banners are store items** (`scripts/stats.gd`): every banner cloth (8-25), emblem (14-46) and frame
  (5-15) past the free ones is a `STORE_ITEMS` row, with UI & Art's tiers (Legendary cloth 23-25, emblems
  45-46, frames 13-15; Epic cloth 19-22, emblems 34-41, frames 7, 11, 12). `BANNER_RARITY` is gone;
  `Stats.banner_rarity()` reads `STORE_ITEMS`, so the kill banner's fancier look follows the store tier.
- **Three new tabs** (`scripts/store.gd`): BANNER CLOTH, EMBLEMS, FRAMES. Every tab now lists Legendary
  first, then Epic, Rare, Common; nine cards a page with < BACK / MORE > and PAGE n / m.
- **Real art on the cards**: cloth and frame cards show the painted banner cloth instead of a vector glyph.
- **In-match sparkle readable**: worn Epic/Legendary motes are bigger (0.2 / 0.28) and drawn mixed, not
  additive, so they show on bright ground; the menu hero scales them to 0.4x (`scripts/menu_stage.gd`).
- No price or save change; prices come from the tier (300/600/1200/2500).

Tests: `tools/store_menu_test.gd` +3 (rarest first, MORE turns the page, page 2 shows the tenth item).

Files: `scripts/stats.gd`, `scripts/store.gd`, `scripts/store_gear.gd`, `scripts/menu_stage.gd`,
`tools/store_menu_test.gd`.

Undo: `git revert 7ce0768`

## 2026-10-14 — Worn sparkles readable from the match camera

Commit: `1a376aa`

Rarity motes are larger (Epic 0.32, Legendary 0.45, Legendary 24 motes), tinted rather than white, with a
soft dark halo so they show on pale stone; the menu hero scales them to 0.3x. `scripts/store_gear.gd`,
`scripts/menu_stage.gd`.

Undo: `git revert 1a376aa`

## 2026-10-15 — The Wildwood collection (new stock in the overhaul's look)

Commit: `d808bc2` (after merging the Steam beta at 79dc7e2)

Faisal 06:33: "is there any new items to the store using the new asset style?"

What changed: 16 new items in soft, rounded storybook shapes using the world overhaul's foliage, river and
autumn colours.
- **Hats** (`HERO_HATS` 8-12): Acorn Cap (Common), Toadstool (Rare), Autumn Crown (Epic), Stag Antlers
  (Epic), Wildwood Sovereign (Legendary: tall gilded leaf points, a glowing river-blue stone, its own fireflies).
- **Capes** (`HERO_CAPES` 6-9): Moss Shawl (Common), Autumn Cloak (Rare, falling-leaf hem), Riverweave Cape
  (Epic, glowing wave hem and foam), Firefly Mantle (Legendary, night cloth sewn with glowing motes, gold hem,
  fireflies drifting off it).
- **Armour tints** (`HERO_OUTFITS` 7-9): Mossy (Common), Riverstone (Rare), Autumn Leaf (Epic).
- **Weapon skins** (`WEAPON_SKINS` 7-10): Oakheart (Common), Riverglass (Rare), Autumn Gold (Epic), Firefly
  (Legendary).
- **NEW ribbon**: items in `Stats.STORE_NEW` show a green NEW tag on their card until bought.
- Icons `assets/ui/store/{hat_8..12,cape_6..9,outfit_7..9,weapon_7..10}.png` rendered from the model by
  `tools/render_store_icons.gd`; Faisal's painted icons for the older items were left as they are.

Files: `scripts/stats.gd`, `scripts/store.gd`, `scripts/store_gear.gd`, `assets/ui/store/*`.

Undo: `git revert d808bc2`

## 2026-10-15 — Cape dye on every character; customizer gear tiles fit

Commit: `f757e2c`

Faisal 17:51: "make sure all the color trims apply to all characters and character customizer works."

What changed:
- **The dye barely showed before**: it only repainted one small trim cell of each skin, so a Rose dye left
  the base bodies, Rangers, Rogues, Engineers and most promotions looking team-coloured. Now the KayKit
  capes (Knight_Cape, Rogue_Cape) take the dye over their whole cloth (`CELLS[*].cloth`, `cape_cloth` key in
  `customised_skin`), and every class and promotion wears the neck wrap in a chosen dye
  (`OutfitFlair.dress(..., any_class)`). Tunics and hoods keep the team colour so sides still read. TEAM
  (dye 0) is unchanged.
- **ARMOR tab**: with 13 hats and 11 weapon skins the gear tiles were squeezed on top of each other. They
  now wrap at ten a line (`menu.GEAR_COLS`, 36x34 tiles); the LOOK row is a little shorter to make room.
- `tools/trim_check.gd` renders every playable look (3 builds, 6 classes at rank 1 and 3, 12 promotions),
  both factions, front and back, in a dye.

Tests: `store_test` +1 (every class, rank and promotion takes the dye); `store_menu_test` +1 (ARMOR tiles
never overlap and stay above CONFIRM; failed before the fix).

Files: `scripts/character_model.gd`, `scripts/outfit_flair.gd`, `scripts/menu.gd`, `tools/trim_check.gd`,
`tools/store_test.gd`, `tools/store_menu_test.gd`.

Undo: `git revert f757e2c`

## 2026-10-15 — Customizer spacing

Commit: `3029782`

ARMOR tab row labels sat on the tiles above them: rows are now 56 px apart (36 per wrapped line, tiles
36x32) and the RANK buttons are 30 tall so everything stays inside the panel. COLORS tab: the note under
the dyes overlapped the last row's names; it moved down 28 px and now says the dye colours the cape and
neck wrap. `scripts/menu.gd`, `tools/store_menu_test.gd` (tiles must end above y 590).

Undo: `git revert 3029782`
