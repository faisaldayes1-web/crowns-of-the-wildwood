# Integration & Release log

Format: see [README.md](README.md). Newest first.

<!-- entries below -->

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
