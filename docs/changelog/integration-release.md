# Integration & Release log

Format: see [README.md](README.md). Newest first.

<!-- entries below -->

### 2026-10-15 05:30 UTC · World visual overhaul `d1af0cf`, UI & Art `504af81` · Flag clipping; HOW TO PLAY cards

- **What:** merged into the Steam branch, cherry-picked into the alpha. Overhaul `77a4290`: no tapestries on the Elf keep walls (the green flag stood up through the hedge), Human ones clear of the torch and table, cellar pennants between their torches. UI & Art `57cb0a8`: HOW TO PLAY, six tutorial cards shown once on first launch (setting howto_seen) and from TUTORIAL; clicks under title overlays only reach the overlay's buttons.
- **Conflicts:** none; game code identical on both branches.
- **Tested:** map_switch_test 0 failures on the merged code; full check before the build.
- **Revert:** Steam branch `git revert -m 1 <merge>`; alpha: revert the cherry-picks newest first.

### 2026-10-15 05:20 UTC · Economy `2518b65` + Integration `c865c8c` · LEVEL UP strip; map-switch checks

- **What:** cherry-picked Economy `4e2f189` + `2518b65` into both branches (LEVEL UP strip on the in-match board: points badge, hex skill tiles, Training hex only once it opens). Added tools/map_switch_test.gd (every map pair both ways through SELECT MAP, seven back-to-back matches across the three maps solo and split-screen, checking screen, map, world, one game scene, volume and settings) and tools/net_map_switch_test.gd (an online host switches maps with a joiner in the room).
- **Tested:** map_switch_test 163 checks, 0 failures, no script errors; online host switching 0/2/1/0 with the joiner rebuilt each time the ground changed; online smoke on each of the three maps passes.
- **Revert:** `git revert c865c8c` for the tests; Economy: revert its two cherry-picks.

### 2026-10-15 03:35 UTC · Players getting stuck `6887ea1` · No more getting stuck indoors

- **What:** merged `b42f8be` + `6887ea1` into the Steam branch, cherry-picked into the alpha. Bodies step up lips under 30 cm (`Unit.STEP_HEIGHT`), and a collision-only wedge fills under every flight of stairs. New tools/snag_scan.gd. Snags Wildwood 49 → 11 (none indoors), Ember Pass 34 → 1.
- **Conflicts:** none; game code identical on both branches.
- **Tested:** stuck thread: run.sh 0 failures, 3-minute routing demos on both maps clean; full check here before the build.
- **Revert:** Steam branch `git revert -m 1 <merge>`; alpha: revert the two cherry-picks newest first.

### 2026-10-15 03:30 UTC · World visual overhaul `7c3271e` · Flicker pass (green flag)

- **What:** merged `fada3c5` + `7c3271e` into the Steam branch, cherry-picked into the alpha. `_unfight_coplanar()` moves meshes (never colliders) 6 mm apart wherever two different-material faces shared a plane; the green flag was the base tapestry in the wainscot's plane.
- **Conflicts:** none; game code identical on both branches.
- **Tested:** overhaul thread: zfight pairs 132/132/189 → 0, fingerprints unchanged; full check here before the build.
- **Revert:** Steam branch `git revert -m 1 <merge>`; alpha: revert the two cherry-picks newest first.

### 2026-10-15 03:20 UTC · Economy `9006e41`, Split-screen `64777c8`, UI & Art `b14784d` · Round-2 beta fixes

- **What:** Economy `df055bd` (door shows a small "key REPAIR DOOR · wood 3" pill instead of the action card; nothing at full health) cherry-picked into both branches. Split-screen `fbb8b73` + `64777c8` (draft PR #23: one input device per player, no second keyboard, panes at full window resolution) and UI & Art `a6c6cf5` + `b14784d` (text fits its slot, two body types, no yellow arrow, ribbon capture banner) merged into the Steam branch and cherry-picked into the alpha.
- **Conflicts:** none; game code identical on both branches.
- **Tested:** full check before the build.
- **Revert:** Steam branch `git revert -m 1 <merge>` per group (Economy: revert its two cherry-picks); alpha: revert the cherry-picks newest first.

### 2026-10-15 03:25 UTC · Closable menus `2d9bdfc` · Keyboard movement follows the mouse aim

- **What:** merged Closable menus `ca0699e` + `2d9bdfc` (draft PR #22) into the Steam branch, cherry-picked into the alpha. With keyboard and mouse, W walks toward the cursor (Controls > MOVEMENT "Keyboard movement" switch, saved as settings/move_mode); the hints switch back to keys as soon as the mouse moves after a pad.
- **Conflicts:** none.
- **Tested:** kbm_move_test 0 failed, reload_menu_test OK on the merged code; full check before the build.
- **Revert:** Steam branch `git revert -m 1 <merge>`; alpha: revert the two cherry-picks newest first.

### 2026-10-15 03:10 UTC · Integration `777f953` · Ember Pass stays on SELECT MAP; volume kept after a match

- **What:** picking Ember Pass rebuilds the world and now comes back to SELECT MAP (the menu warm-up used to end on the title, so PLAY looked like it kicked you out). A mouse button still held from the summary's CONTINUE no longer drags the sound slider on the Settings tab the warm-up shows, which set the volume to full. Sliders move only for a press that started on them; clicks are ignored during the warm-up; a button held across a reload is not a new press.
- **Files:** scripts/game.gd (`_warm_up_menus(land_on)`, `menus_warming`, `slider_drag`, `click_was` at start), tools/reload_menu_test.gd (new, needs xvfb).
- **Tested:** reload_menu_test fails on the old code (lands on the title; sound 0.30 → 1.00) and passes now.
- **Revert:** `git revert 777f953` (both branches: the alpha has the cherry-pick).

### 2026-10-14 22:40 UTC · Store `4073682` · Player banners for sale, brighter rarity sparkles

- **What:** cherry-picked Store `7ce0768`, `1a376aa` and their changelog commits (both branches): banner cloth, emblems and frames sold by rarity tier with paging and painted thumbnails; bigger, glowier sparkles on worn Legendary gear. `Stats.banner_rarity()` now reads STORE_ITEMS (UI & Art's stopgap BANNER_RARITY table is gone).
- **Conflicts:** none.
- **Tested:** full check plus touch_close_test, stuck scan, window modes, split-screen 2 and 4 players.
- **Revert:** revert the cherry-picks newest first.

### 2026-10-14 22:05 UTC · UI & Art `aa7db47` · Player banners

- **What:** merged Faisal's player banners: 16 painted backgrounds, 29 more emblems, 8 more frames, and rare/epic/legendary looks (Stats.BANNER_RARITY, hud._banner_fx). stats.gd only appends to the BANNER_* lists and adds the rarity table; no gameplay tunables.
- **Conflicts:** none.
- **Tested:** full check plus touch_close_test, stuck scan, split-screen 2 and 4 players.
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 22:00 UTC · Combat & Balance `e53d46c` · Lighter web impacts, block flinch, attack chains

- **What:** cherry-picked Combat entries 28-30 (both branches): lighter impacts on Medium graphics (`8636cf4`), blocked hits play the Block_Hit flinch then the block resumes (`ce8d525`), basic attack chains step through the class's swings in order (`d4e4980`). Animation and VFX only.
- **Conflicts:** scripts/character_model.gd `attack()` kept the online wrapper (`attack` records for joiners, `_x_attack` plays) with the new chain logic inside `_x_attack`.
- **Tested:** full check plus touch_close_test, stuck scan, split-screen 2 and 4 players.
- **Revert:** revert the cherry-picks newest first.

### 2026-10-14 21:55 UTC · Online pause fix `4a78a69` + web menu click fix `1c719b7`

- **What:** cherry-picked (both branches) from PR #19: the corner MENU/map button no longer pauses an online match for every joiner (offline only, like Esc). From the iPad web build thread: menus catch a click pressed and released between two frames (game._input latches left presses; the menu tick treats the latch as a click). This was Faisal's "menus unresponsive at times" on the web; it helps desktop too.
- **Files:** scripts/game.gd, docs/changelog/*.
- **Conflicts:** none.
- **Tested:** full check plus touch_close_test, stuck scan, split-screen 2 and 4 players.
- **Revert:** revert the cherry-picks newest first.

### 2026-10-14 21:40 UTC · Combat & Balance `163465d` · Heavier hit impacts

- **What:** merged Combat's impacts piece (`a7ec6dd`): punch ring, faction flecks and chips, dust at the victim's feet, knockback skid dust, new hit_thud.wav; particle counts scale with graphics quality (Low skips chips, debris and skid). Visual and sound only.
- **Conflicts:** scripts/fx.gd `hit()` kept the online wrapper (`hit` records for joiners, `_x_hit` draws) and gave both the new `team` argument; scripts/unit.gd kept the stuck fix's `_unstick(delta)` and added the skid block after it; tests/combat_test.gd runs both `_stuck()` (14) and `_impacts()` (15).
- **Tested:** full check plus touch_close_test, stuck scan, split-screen 2 and 4 players.
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 21:25 UTC · Store `8720fc0` + closable iPad menus `3c901cd` (PR #20)

- **What:** cherry-picked (branches were cut from the Steam branch): Store rarity tiers (tiered store cards, Epic sway / Legendary turntable in the preview, sparkle on worn Epic and Legendary gear; no save format change). Closable iPad menus: a tappable X on every panel (LEVEL UP strip, Veteran Training, action card), one action per tap, and Controls > CONTROL LAYOUT (Auto / Keyboard & Mouse / Controller / Touch, saved as settings/control_layout); Auto no longer shows the touch UI on a touch-screen laptop. New tools/touch_close_test.gd.
- **Conflicts:** scripts/touch.gd `_down()` with the stuck-players fix: kept its lost-lift `_up(i)` lines, then the layout check and `set_active(true)`.
- **Tested:** full check plus touch_close_test, stuck scan, split-screen 2 and 4 players.
- **Revert:** `git revert -m 1 <merge>` (Steam branch) or revert the cherry-picks newest first (alpha).

### 2026-10-14 21:10 UTC · UI & Art `e059d15` · Event banners

- **What:** merged UI & Art `e059d15`: event banners for 18 kinds of match news (first blood, gate broken or rebuilt, overtime, vault, veterans, bounty, fire objective and more), shown one at a time. hud.gd only.
- **Conflicts:** none.
- **Tested:** full check (as in the stuck-players entry below).
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 21:00 UTC · Stuck players `8a2eea9` (PR #19) · Nobody stays stuck

- **What:** cherry-picked the "Players getting stuck" fix (`12a638a` → `dce60f6`, changelog `8a2eea9` → `2daa4f7`; the branch was cut from the Steam branch, so it is not merged here): finisher releases when the striker falls, body-swept Blink/Shadow Step, wedge safety net, free-spot respawn, bot follow distance (scripts/unit.gd); iPad stick/aim takeover and release on focus loss (scripts/touch.gd); +6 combat checks; tools/stuck_scan.gd.
- **Tunables:** new BOT_FOLLOW_MIN 2.0, BOT_FOLLOW_MAX 3.2 (scripts/stats.gd).
- **Conflicts:** none.
- **Tested:** full check (import, all group tests, economy, net_smoke, bot matches on both maps, Steam build, both .exe files under wine).
- **Revert:** `git revert 2daa4f7 dce60f6`.

### 2026-10-14 18:45 UTC · UI & Art `78c77d5` · Off-centre icons fixed

- **What:** merged UI & Art `78c77d5`: 53 icons re-centred, the ability bar uses halo-free copies (assets/ui/icons_clean), the corner portrait centres on each class's face (hud.gd `_slot_face`, `_medallion`, loader).
- **Conflicts:** none.
- **Tested:** full check (as in the beta entry below).
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 18:35 UTC · Visual overhaul `2ff02af` (PR #18 candidate 1) · Beta build

- **What:** merged the World visual overhaul candidate 1 for the Steam-ready beta: match-world style profile (softer stone/wood/grass textures, soft-lit foliage, procedural pines with the same colliders, patchy ground detail, blue river with calmer foam, warm day grade). Menus, UI, colliders and stats.gd unchanged (see docs/changelog/visual-overhaul.md).
- **Conflicts:** none.
- **Tested:** full check (import, all group tests, economy, net_smoke, bot matches on both maps, Steam build, both .exe files under wine).
- **Revert:** `git revert -m 1 <merge>` on each branch takes the whole overhaul out.

### 2026-10-14 16:40 UTC · Combat & Balance `8f995ef` · Balance patch 7

- **What:** merged balance patch 7 (scripts/stats.gd only; docs/balance/patch-7.md). Over 96 matches: Elves 29-19 → 25-23.
- **Tunables:** Elves speed 6.15 → 6.05.
- **Conflicts:** none.
- **Tested:** full check (import, all group tests, economy, net_smoke, bot matches on both maps, Steam build, both .exe files under wine).
- **Revert:** `git revert 8f995ef` (patch only) or `git revert -m 1 <merge>`.

### 2026-10-14 16:00 UTC · Economy `6ba18ff` · Wood/ore node pairs always placed

- **What:** merged Economy `6ba18ff`: the mirrored node-pair search reaches 14 m in 16 directions (was 8 m), so the two pairs that were skipped with "no room for a wood/ore node pair" now place (18 nodes on both maps). scripts/economy.gd.
- **Conflicts:** none.
- **Tested:** full check (as in the entry below).
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 15:55 UTC · Combat & Balance `e9bf9f7` · Balance patch 6, cooldown-shade fix

- **What:** merged Combat & Balance up to `e9bf9f7`: balance patch 6 (`a4c4786`, scripts/stats.gd; docs/balance/patch-6.md), cooldown shade no longer draws an untriangulable sliver (`30458d2`, hud.gd; removes the "Invalid polygon data" errors), STALL demo logging only counts bots that want to move (`9ec77f7`), their copy of the `_first()` downed-skip (`db30d12`).
- **Tunables:** Human regen_mult 1.15 → 1.22; Elf Grove Mend cooldown 0.7 → 0.8; Spirit Bloom haste 4 → 3.
- **Conflicts:** tests/combat_test.gd `_first()`, took Combat's `u.get("downed")` form (same behaviour).
- **Tested:** full check (import, all group tests, economy, net_smoke, bot matches on both maps, Steam build, both .exe files under wine).
- **Revert:** `git revert -m 1 <merge>` on each branch; patch 6 alone: `git revert a4c4786`.

### 2026-10-14 13:10 UTC · UI & Art `c2bc6b9` · Promotion card from Faisal's approved mock-up 4

- **What:** merged UI & Art `c2bc6b9`: CLASS PROMOTION card rebuilt from Faisal's approved mock-up 4; skill-row colour fades to black under the + button.
- **Conflicts:** none.
- **Tested:** full check (import, all group tests, economy, net_smoke, bot matches on both maps, Steam build, both .exe files under wine).
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 13:05 UTC · Online & Platforms `5423659` · net_smoke no longer flaky

- **What:** merged Online & Platforms `5423659`: in `--net-test` only, the host fires one harmless arrow at 4 s so the joiner's "shots arrived" check no longer depends on a bot shooting (net_smoke failed about 1 run in 8 on quiet matches).
- **Conflicts:** docs/changelog/online-platforms.md, kept both sides.
- **Tested:** full check (import, all group tests, economy, net_smoke, bot matches on both maps, Steam build, both .exe files under wine).
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 11:30 UTC · UI & Art `86357d0` · Faisal's painted skill strips

- **What:** merged UI & Art `86357d0`: Faisal's 67 painted skill strips behind the skill rows (assets/ui/strips, tools/make_skill_strips.py, hud.gd).
- **Conflicts:** none.
- **Tested:** import, all group tests, economy and online checks, bot matches on both maps, Steam build, both .exe files under wine.
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 10:25 UTC · UI & Art `5477cce` · Promotion card built to Faisal's mock-up

- **What:** merged UI & Art `053a21d` + changelog `5477cce`: CLASS PROMOTION card built to Faisal's mock-up (hud.gd), blurred card backdrops assets/ui/cards/*_blur.png made by tools/make_card_blur.py.
- **Conflicts:** none.
- **Tested:** import, all group tests, economy and online checks, bot matches on both maps, Steam build, both .exe files under wine.
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 09:40 UTC · UI & Art `fe8ceaa` + `6a08fd7` · Promotion card picture, flaky combat test fixed

- **What:** merged UI & Art `411ecac` + changelog `fe8ceaa` (promotion card picture fills the left half with a gradient and glow; hud.gd only). `6a08fd7`: tests/combat_test.gd `_first()` now skips downed bots, so `grab_feedback_once` no longer fails when the demo has already knocked the chosen bot down (it failed about 1 run in 5; 6 of 6 pass after).
- **Conflicts:** none.
- **Tunables:** none.
- **Revert:** `git revert 6a08fd7`; `git revert -m 1 <merge>` for the UI & Art merge.

### 2026-10-14 09:10 UTC · UI & Art `c40a329` · Promotion card restyled after Faisal's reference

- **What:** merged UI & Art `0e50b30` + changelog `c40a329`: CLASS PROMOTION card restyled after Faisal's reference. hud.gd only.
- **Conflicts:** none.
- **Tested:** same full check as the entry below.
- **Revert:** `git revert -m 1 <merge>` on each branch.

### 2026-10-14 08:50 UTC · UI & Art `78e1421` · Kill banner ribbon, centred emblems, richer skill strips

- **What:** merged UI & Art `9a64ae0` + changelog `78e1421`: kill banner restyled as a gold ribbon like YOU FELL, every ability-bar emblem centred, richer skill-strip effects. hud.gd only.
- **Conflicts:** none.
- **Tested:** import, all group tests, economy and online checks, bot matches on both maps, both .exe files under wine (see the thread).
- **Revert:** `git revert -m 1 <merge>` (alpha `release/v0.4.0-alpha`, Steam branch `group/integration-release-g9m95g`).

### 2026-10-14 08:10 UTC · UI & Art `a357a05` and the 2k re-cut · Promotion card, Faisal's sharper UI art

- **What:** merged UI & Art `a357a05` (full-art CLASS PROMOTION card with path tabs, animated skill strips on the SKILLS & UPGRADES board, class shield on the kill banner; hud.gd only) and their re-cut of Faisal's 07:40 sheets (167 PNGs under assets/ui incl. coin, frostweaver, siegewright, Elf/Human base cards, via tools/slice_ui_v2.py; no code).
- **Conflicts:** none.
- **Tested:** import, all group tests, economy and online checks, bot matches on both maps, both .exe files under wine (see the thread).
- **Revert:** `git revert -m 1 <merge>` for each, newest first.

### 2026-10-14 07:20 UTC · UI & Art `4b81c83` · Faisal's upgraded UI art

- **What:** merged UI & Art's cut of Faisal's 06:27 sheets: 157 assets (icons, class shields, crests, logos, banners, class cards incl. new Engineer and Rogue cards, all 53 store thumbnails) via tools/slice_new_ui.py. coin, frostweaver, siegewright, the hex skill tiles and the top-bar strip keep the old art (not on the sheets or not taken).
- **Conflicts:** none.
- **Tested:** see the alpha refresh note in this file's next entry / the thread.
- **Revert:** `git revert -m 1 <merge>` (`git log --merges -1`).
### 2026-10-14 05:40 UTC · Steam build (branch group/integration-release-g9m95g)

- **Why:** Faisal (2026-10-13): Roblox later, "playable on Steam first".
- **What:** GodotSteam 4.15 GDExtension in `tools/steam/godotsteam/` (Windows and Linux 64-bit, Godot ignores the folder); `tools/steam/build_steam.sh` adds it to a temporary copy of the project and exports the new "Windows Steam" preset; `scripts/steam.gd` (autoload SteamHub) starts Steam when it is running and is a no-op otherwise; 10 achievements (match win, each faction's win, capture, revive, finisher, online match, levels 5/10/20); the Steam overlay pauses an offline match; `tools/steam/upload.sh`/`upload.bat` + `app_build.vdf.in` for steamcmd; docs/steam.md (store art sizes, Steam Cloud setup, Faisal's steps).
- **Files:** scripts/steam.gd (new), scripts/game.gd (`_steam_match_end`, `steam_unlock`, level hook), scripts/unit.gd (revive and finisher hooks), project.godot (SteamHub autoload, `[steam]` app_id 0, require_steam on for the `steam` feature only), export_presets.cfg (preset "Windows Steam"), tools/steam/*, docs/steam.md, .gitignore (build/).
- **Tunables:** `steam/app_id` 0 until Faisal has an App ID.
- **Tested:** import clean; tools/tests/run.sh, options menu, menu flow and save tests 0 failures; Wildwood bot match clean; the Steam .exe built with `--dev --app-id=480` plays a match under wine with no Steam client ("Steam not running", no errors). Not tested with a real Steam client: none is available here.
- **Revert:** `git revert <this commit>`; the standalone zip and the web build do not use any of it.

### 2026-10-10 12:45 UTC · Downed & Revive `f6f825e` · Killer banner only on the real death

- **What:** merged Downed & Revive (Faisal 09:57): the downed screen has no "DOWNED BY" card any more; FINISHED BY / SLAIN BY appears only on the real death, redrawn in wood and gold.
- **Conflicts:** none.
- **Tested:** see the next alpha refresh.
- **Revert:** `git revert -m 1 <merge>` (`git log --merges -1`).

### 2026-10-10 12:20 UTC · iPad `f58db73`, Combat `5bf1dcb` · Touch TRAINING slot, balance patch 5

- **What:** iPad web build `7d6c4dc`: touch players get Veteran Training's slot where the G button sits; it was desktop-only before. Combat & Balance `e8f02f9`: balance patch 5 (Elf Glaive armour 0.32 → 0.37, Wind Dash damage 1 → 2 with cooldown 3.5 → 4.5, Vanguard armour 0.42 → 0.45; docs/balance/patch-5.md).
- **Conflicts:** none.
- **Tested:** see the next alpha refresh.
- **Revert:** `git revert -m 1 <merge>` for each, newest first.

### 2026-10-10 11:40 UTC · UI & Art `e0fe3c4`, Economy `b05fc4a`, Combat `191c924` · Faisal's "get everything" build

- **What:** Faisal (11:32) asked for a current build with everything. Merged:
  - UI & Art `e0fe3c4`: the in-match perk-key board is now SKILLS & UPGRADES (Faisal's skills-upgrades reference).
  - Economy `b05fc4a`: Veteran Training overhaul (Faisal 10:41) with a TRAINING slot and panel, and new wood.png and training.png icons.
  - Combat `191c924`: cooldown "not yet" click and a dodge-ready tick.
  - Every other group head (Online, Split-screen, Music, World & Maps `007d782`, Downed & Revive, Store, iPad) was already in.
- **Conflicts:** none.
- **Tested:** see docs/CHANGELOG.md.
- **Revert:** `git revert -m 1 <merge>` for each merge, newest first (`git log --merges -3`).

### 2026-10-10 11:20 UTC · `3cbf766`, `9276184` · Economy wood-only and Veteran Training, HUD tiles inside their rims

- **What:**
  - Economy `facb4de` (`3cbf766`): game-style action card, bare wood counter, field upgrades on the LEVEL UP strip, turret line-of-sight aim, late-game Veteran Training at the hat machine, wood only (ore scrapped, Faisal 09:51).
  - iPad web build `01e717c` (`9276184`): every platform's skill tiles sit inside a drawn hex rim, with the painting clipped to the face, so no sliced rims show.
  - Restored the iPad thread's 10-Oct entries in docs/changelog/online-platforms.md (2a24c42, b1dbfae, 7ae9d09, 2e9a51f), which the earlier "keep the alpha's side" resolutions had dropped.
- **Files:** merges only, plus docs.
- **Tested:** on `3cbf766`: import clean; econ test 0 failed; options menu, menu flow, store, store menu and save tests 0 failures; tools/tests/run.sh 0 failures; net_smoke PASS; bot matches on both maps (Humans 2-0 on both); the .exe under wine. On `9276184`: import clean; options menu and menu flow 0 failures; the .exe under wine.
- **Revert:** `git revert -m 1 9276184`, `git revert -m 1 3cbf766`

### 2026-10-10 10:25 UTC · `044bc8b`, `3f723a1`, `47b58f0`, `6cc027c` · Store players, iPad touch, UI & Art banners, balance patch 4

- **What:** merged four group heads into the alpha:
  - Store `f3bb81a` (`044bc8b`): named players (WHO'S PLAYING? on first launch, PLAYERS button, one save file per player, IMPORT CODE adds a player), gold amount fits its box.
  - iPad web build `9e16538` (`3f723a1`): web caps at a steady 30 FPS when a match runs under 52, bigger touch tiles, touch drag aim assist, G and scoreboard buttons, "Pick class" on locked slots with a PICK A CLASS pointer.
  - UI & Art `04b8fca` (`47b58f0`): one big banner at a time (20 % smaller), notices queue as one small scroll and wait for banners, menus and the downed screen.
  - Combat & Balance `4bf6ee0` (`6cc027c`): balance patch 4 (Human Crossbow cooldown 0.68 → 0.62, Elf Lunar Lance 3 → 4; docs/balance/patch-4.md), ranged hit confirm tick, controller stick aim assist (12° cone, 75 % pull, within attack reach).
- **Conflicts resolved:** `docs/changelog/online-platforms.md` (kept the alpha's side, as the iPad thread asked); `scripts/unit.gd` `_update_player_aim`: touch keeps the iPad's 30° snap (`_auto_aim(along)`), a controller stick uses Combat's `_assist_aim`; both functions kept.
- **Files:** merges only.
- **Tunables:** see each group's changelog (store.md, online-platforms.md, ui-art.md, combat-balance.md entries 17-19).
- **Tested:** see docs/CHANGELOG.md for this refresh.
- **Revert:** `git revert -m 1 <merge>` for any of the four merges above, newest first.

### 2026-10-10 09:55 UTC · `5b70269` · Merged the iPad web build's Medium-by-default web graphics

- **What:** merged `44997a0` from `claude/ipad-web-build-c1oo3k`: in a browser the game starts on Medium (sun shadows, glow, full-resolution 3D) and drops to Low only when a match runs under 26 FPS. Desktop behaviour unchanged, so the Windows zip was not rebuilt; the web zip was.
- **Files:** scripts/game.gd (via merge)
- **Tunables:** web start preset Low → Medium; web auto step-down threshold 26 FPS (desktop stays 40)
- **Tested:** import clean; options menu, menu flow and save tests 0 failures. The iPad thread checked it in Chromium (ONLINE room 8K7E created through the Render relay).
- **Revert:** `git revert -m 1 5b70269`

### 2026-10-10 09:20 UTC · `a238ae5`, `10d71ef`, `b679b8d` · Online play in the alpha, World & Maps trees

- **What:** Faisal chose "Add online" (09:01): merged Online & Platforms (`e8fca2c`, then its catch-up merge `cc92436`, which buffers a joiner's attack taps) so the title's ONLINE button makes and joins 4-letter rooms over Faisal's Render relay `wss://crowns-of-the-wildwood.onrender.com`. Merged World & Maps `007d782` (clump-dome tree crowns, jagged pine tiers, z-fighting audit, wall stubs off the paths).
- **Conflicts resolved:** `character_model.gd` (`play_once` keeps the `recover` argument and is mirrored to joiners), `unit.gd` (attack buffer and skill/dodge input buffer read input through `_tap`/`_held`; economy-card click guard only for the local player), `skill_fx.gd`, `game.gd`, `docs/changelog/online-platforms.md` (both sides kept).
- **Files:** merges only.
- **Tunables:** `online/relay_url` → `wss://crowns-of-the-wildwood.onrender.com` (from Online).
- **Tested:** import clean; options menu, menu flow, store, store menu and save tests 0 failures; `tools/tests/run.sh` 0 failures; `tools/net_smoke.sh` passes over ENet and the relay, locally and against Render; bot matches on both maps; the .exe under wine.
- **Revert:** `git revert -m 1 b679b8d`, `git revert -m 1 10d71ef`, `git revert -m 1 a238ae5` (newest first).

### 2026-10-10 08:55 UTC · `475d3a0`..`a81e452` · Stutter fixes, and every group's newest work in the alpha

- **What:** Faisal (RTX 4090) saw stutter on menus and simple actions, and the iPad needed five taps on PLAY. Causes and fixes: the keep-the-window-alive pump from `14c7815` dropped input every quarter second during play; it now runs only inside a frame already 250 ms long, and never on the web (`475d3a0`, `4f2264e`). The settings save (five file operations) ran on every menu click; on Windows it now writes on a worker thread (`475d3a0`). Menu screens and every combat effect are shown once behind the loading art so their first use does not stall. A graphics card starts on High again. Merged: balance patch 3 (`b8a721d`), UI & Art `4d33ee6` (`02a4d9d`), Combat ranged hit confirm (`a701795`), Economy cheaper turrets and LEVEL UP hat tile (`9cd8a04`), Split-screen layouts PR #16 (`76b326f`), Music orchestral tracks PR #15 (`a81e452`, CREDITS kept both lines). options_menu_test re-finds each touch tile after the strip re-lays out (`cf8100d`).
- **Files:** scripts/game.gd, tools/options_menu_test.gd, see each merge
- **Tunables:** discrete GPU default Medium → High
- **Tested:** all group tests and the combat self-test pass; bot matches on both maps clean; the .exe plays a match and boots to the title with the warm-up under wine.
- **Revert:** `git revert 4f2264e 86f2fb6 475d3a0`; a merge with `git revert -m 1 <merge>`

### 2026-10-10 06:40 UTC · `e79a6f7` · Merged World & Maps' z-fighting fix (flashing Ember Pass doors)

- **What:** Ember Pass causeway and plazas no longer flicker in front of the doors, plus other z-fighting on both maps (World & Maps `5a468b0`). Conflict in scripts/volcano.gd (causeway and plaza heights): took World & Maps' side.
- **Files:** scripts/volcano.gd, see `5a468b0`
- **Tunables:** none
- **Revert:** `git revert -m 1 e79a6f7`

### 2026-10-10 06:10 UTC · `5c9e663` · A maximized window stays maximized after a match

- **What:** After a match (or leaving one) a maximized window shrank to 1920x1080, because the game forced "windowed" whenever full screen was off. It now changes the window only when the Fullscreen setting disagrees with it. `tools/window_mode_test.gd` checks maximized and full screen through a match start and the reload (it fails on the old code).
- **Files:** scripts/game.gd, tools/window_mode_test.gd
- **Tunables:** none
- **Revert:** `git revert 5c9e663`

### 2026-10-10 06:00 UTC · `3c82192`, `696e380` · Smoother play: automatic graphics preset

- **What:** The game logic costs about 7 ms a frame; the High default (Ultra AO, light bounce, 4x MSAA, 8192 shadows) made the Windows build lag. Until the player picks a preset in Settings, the game starts on Medium with a graphics card and Low on built-in graphics, and steps down one preset when it runs under 40 FPS for four seconds (a toast says so). Medium keeps 2x MSAA with low-quality AO; Low uses two sun shadow cascades and no lamp shadows. The FPS counter starts on once. Tests and renders (any command-line flag) keep their preset. Software-renderer frame times at 720p: High 2068 ms, Medium 1649 ms, Low 888 ms.
- **Files:** scripts/game.gd, tools/hitch_probe.gd, tools/frame_time_probe.gd
- **Tunables:** default preset High → automatic (Low / Medium); Medium MSAA 4x → 2x; Low/Medium SSAO quality Ultra → Low; Low sun cascades 4 → 2, lamp shadows off; auto step-down below 40 FPS
- **Revert:** `git revert 696e380 3c82192`

### 2026-10-10 01:33 UTC · `14c7815` · Windows .exe no longer goes "Not Responding" while loading

- **What:** Faisal's Windows PC showed the alpha as "Not Responding" on launch. Building the world, the title screen and a match each held the game for seconds without answering Windows (over 10 s on a first launch in testing). The game now answers Windows every quarter second while it loads. The Windows zip also gains "Play in Compatibility Mode.bat" (OpenGL renderer) as a fallback for unusual graphics drivers. On the alpha branch only.
- **Files:** scripts/game.gd
- **Tunables:** none
- **Tested:** all group tests and a Wildwood bot match pass; the rebuilt .exe opens to the title on Vulkan under wine.
- **Revert:** `git revert 14c7815`

### 2026-10-09 01:49 UTC · `d49bb86` · Released PR #3 as v0.3.1

- **What:** Merged the scoreboard / match summary PR into main after resolving its `scripts/hud.gd` conflict with v0.3.0 (merge `a3f2436` on its branch).
- **Files:** scripts/hud.gd (conflict), see PR #3
- **Tunables:** see v0.3.1 in docs/CHANGELOG.md
- **Revert:** `git revert -m 1 d49bb86`

### 2026-10-08 20:50 UTC · `799a873` · Released PR #1 as v0.3.0

- **What:** Merged the cartoon restyle / HUD PR into main.
- **Files:** see PR #1
- **Tunables:** none
- **Revert:** `git revert -m 1 799a873`

### 2026-10-08 20:43 UTC · `3fb4fad` · Changelog scaffolding

- **What:** Added docs/CHANGELOG.md, docs/changelog/README.md, docs/REVERTING.md; marked `29e5ea8` as the v0.2.0 baseline.
- **Files:** docs/
- **Tunables:** none
- **Revert:** `git revert -m 1 3fb4fad`
