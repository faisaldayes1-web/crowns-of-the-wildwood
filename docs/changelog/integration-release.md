# Integration & Release log

Format: see [README.md](README.md). Newest first.

<!-- entries below -->

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
