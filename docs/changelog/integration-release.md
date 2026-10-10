# Integration & Release log

Format: see [README.md](README.md). Newest first.

<!-- entries below -->

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
