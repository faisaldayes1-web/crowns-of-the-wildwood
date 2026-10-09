# Online & Platforms changelog

Every commit from the Online & Platforms group, newest last. Each entry says what changed, the files
it touched, any tunable that moved (old → new), and the exact line that undoes it.

A commit cannot contain its own hash, so each entry is written in the commit it describes and its
hash is filled in by the group's next commit (a hash-only edit to this file, which needs no revert
of its own). To undo a change, run its revert line on the branch, then re-run `tools/net_smoke.sh`.

---

## 2026-10-08 20:55 UTC · `7953c44` · Online play plan

- **What:** wrote the plan for online play: ENet direct-IP first, then Steam networking and
  lobbies through GodotSteam; host-authoritative model (clients send inputs, the host simulates
  and sends 20 Hz snapshots); what is replicated now and later; slots and teams; matchmaking; the
  six online milestones N1-N6; builds and the smoke test. Also starts this changelog.
- **Files:** `docs/online-plan.md` (new), `docs/changelog/online-platforms.md` (new)
- **Tunables:** none
- **Revert:** `git revert 7953c44`

## 2026-10-09 01:50 UTC · `2133d77` · ENet host / join, step one

- **What:** online play over direct IP. New **ONLINE** row on the title screen (HOST / STOP,
  JOIN / LEAVE, and a box for the host's address). The host runs the whole match; a joiner's game
  rebuilds the host's world from the host's world seed, takes a bot's slot (first on the other
  side, then alternating), sends its stick, aim and buttons every physics frame, and draws the
  host's 20 Hz snapshots (units, hearts, energy, classes, deaths, monarchs, doors, vaults, score,
  clock, fortify timer, game over). Bots keep playing for the host; a joiner who leaves hands
  their unit back to a bot. Online matches do not pause. Command line: `-- --host[=port]`,
  `-- --join=ip[:port]`, `--net-test`. New headless smoke test `tools/net_smoke.sh` (passes:
  host and joiner each saw their own unit, the other player and the bots move). README has a
  new "Online play" paragraph. The world is now built from `Net.world_seed` (still random per
  run; `--seed=N` keeps its old meaning) so host and joiner build identical maps.
- **Files:** `scripts/net.gd` (new), `project.godot` (Net autoload), `scripts/game.gd`,
  `scripts/unit.gd`, `scripts/hud.gd`, `scripts/heal_orb.gd`, `tools/net_smoke.sh` (new),
  `README.md`, `docs/changelog/online-platforms.md`
- **Tunables (new, in `scripts/net.gd`):** `DEFAULT_PORT` 24560, `MAX_CLIENTS` 8,
  `SNAPSHOT_EVERY` 3 physics frames (20 Hz). Bot difficulty text on the title moved under the
  BOTS buttons (was to their right) to make room for the ONLINE row.
- **Revert:** `git revert 2133d77`
## 2026-10-08 22:35 UTC · `ad2abae` · iPad web build: world visible, letterbox on first visit

- **What:** the browser build (played in Safari on an iPad) showed only the sky and the HUD once a
  match started, and on a first visit the menus ran off the sides of the screen. Three fixes:
  the engine's threaded scene culling never runs on a no-threads web build, so every mesh was
  culled; culling now stays on the main thread (`threaded_cull_minimum_instances` raised so the
  threaded path is never taken). The 4:3 letterbox and the Medium graphics cap for the web are now
  applied before the saved-settings file is read, so a first visit with no saved file gets them
  too. On the web the 3D view uses FXAA with no multisampling and no 3D scaling (the iPad draws at
  2x pixel density). Also a crash-log fix: `_show_loading` no longer calls `queue_free` on a
  loading screen that was already freed.
- **Published:** the build is on the `gh-pages` branch, served at
  https://faisaldayes1-web.github.io/crowns-of-the-wildwood/ (re-export with
  `godot --headless --export-release "Web" out/index.html` and push the files to `gh-pages`
  with a `.nojekyll` file to update it). A zip of the same files is in the project files under
  `game/web-build/`.
- **Files:** `project.godot`, `scripts/game.gd`
- **Tunables:** `rendering/limits/spatial_indexer/threaded_cull_minimum_instances` 1000 (default) → 1000000; web only: `msaa_3d` 4x → off, `scaling_3d_scale` 1.0 (unchanged)
- **Tested:** Chromium with an iPad user agent, touch emulation and a 1180x820 landscape viewport
  on the exported build: title taps, Select Map, Ready Up, a match with the Elf spawn cellar and
  class stations drawn, the move stick and the attack pad.
- **Revert:** `git revert ad2abae`

## 2026-10-08 23:05 UTC · `a270b18` · Web: no spot-light shadow in the menu hall

- **What:** the menu hall's key light cast a shadow that WebGL rejects on the Compatibility
  renderer (hundreds of "textures can not be used with multiple targets" console warnings and no
  shadow anyway). The shadow is now off in the browser build only; desktop keeps it.
- **Files:** `scripts/menu_stage.gd`
- **Tunables:** none
- **Revert:** `git revert a270b18`

## 2026-10-09 03:31 UTC · `7efb455` · Merged the showcase thread's web fixes

- **What:** the "Current build showcase" thread fixed the same two web problems on its own branch
  (culling override as a web-only setting, letterbox in `_ready`); merged so both branches agree.
  Kept its `_ready` block and web-only override, dropped this branch's duplicates, kept the
  post-load graphics cap, FXAA-only web view and the menu hall shadow fix. `9291713` then merged
  `main` (docs only).
- **Files:** `project.godot`, `scripts/game.gd`
- **Tunables:** `threaded_cull_minimum_instances` 1000000 → (web only) 100000000
- **Revert:** `git revert -m 1 7efb455`

## 2026-10-09 04:50 UTC · `3e1aea7` · iPad web build runs faster: a quarter of the draw calls, baked HUD art

- **What:** Faisal: "it feels very laggy still" on the iPad. Measured in an iPad-emulating Chromium,
  a match frame issued ~10,200 WebGL draw calls, two thirds of them shadow passes (the sun's four
  cascades and five cube-map lamp shadows redrew every caster each frame) and ~1,400 of them the
  HUD, which rebuilt ~900 polygons of minimap art every frame. Now ~2,700 draw calls a frame, and
  the per-frame script time of the HUD is down by about half.
  - Browser only (`OS.has_feature("web")`): the sun uses one orthogonal shadow map over 50 m
    instead of four cascades over 70 m, read with a hard (one-tap) filter from a 2048 atlas;
    room lights and camp fires cast no shadow (WebGL never rendered them anyway); mesh instances
    under 0.8 m stop casting shadows after the world is built (`_trim_web_shadows`, 8,530 → 5,858
    casters); the 3D view renders at half the canvas size (`scaling_3d_scale` 0.5, the iPad's
    2x pixel density becomes one 3D pixel per screen point; the HUD stays full density); a first
    visit starts on the Low preset (no glow, small atlases; Settings can raise it to Medium); bots
    think every other physics tick and repeat their last move in between; the touch overlay
    redraws on finger events, not every frame; anisotropic filtering 8 → 4.
  - All platforms: the minimap's painted chart and its bronze ring, and the screen frame with
    its ivy, are drawn once into textures by a copy of the HUD inside a `SubViewport`
    (`_bake` / `_layer` in `scripts/hud.gd`) and re-drawn only when their key changes (Ember
    Pass's lava chart four times a second); the live HUD draws the textures and only what moves
    (units, potions, doors, the shrine pulse). The frame's texture carries premultiplied alpha,
    so it is shown by a `TextureRect` with that blend mode. Wheat fields never cast shadows.
  - New test aid: `-- --perf` prints frame-time monitors every five seconds (process and physics
    time, draw calls, objects, primitives, node count) and, once, a census of nodes by class,
    shadow casters and blended mesh instances. Useful in the browser console too.
- **Files:** `project.godot`, `scripts/game.gd`, `scripts/hud.gd`, `scripts/touch.gd`,
  `scripts/unit.gd`
- **Tunables (web only):** `directional_shadow_mode` 4 splits → orthogonal;
  `directional_shadow_max_distance` 70 → 50; directional atlas 4096 → 2048, filter soft medium →
  hard; positional atlas 2048 → 1024 and lamp shadows off; `scaling_3d_scale` 1.0 → 0.5; default
  preset Medium → Low (cap stays Medium); `anisotropic_filtering_level` 8 → 4; bot think 60 → 30 Hz.
  Desktop: unchanged apart from the baked HUD layers and the wheat.
- **Tested:** `--check-only` on every changed script; a headless `--play --perf` match; the
  exported build in Chromium with an iPad user agent and touch emulation: draw calls per frame
  10,249 → ~2,750 (shadow pass 6,500 → 1,150, HUD 1,400 → 345, 3D ~1,000 → ~650), the software
  renderer's frame time 3.4 s → 0.7 s, screenshots of the minimap, frame and panel unchanged to
  the eye, no new console errors. Not yet measured on a real iPad.
- **Revert:** `git revert 3e1aea7` (restores the old shadows, per-frame HUD drawing and
  full-density 3D on the web)

## 2026-10-09 06:50 UTC · `e9fcddf` · iPad stutter: the HUD paints once, not every frame

- **Why:** Faisal (06:04): "a lot of stutter and lag and anytime I tap anything there's a
  delay". A timed native match showed the HUD script spending ~5.5 ms every frame repainting
  the player panel (2.9 ms), the top bar (1.1 ms) and the chat (0.9 ms); in the browser's
  WebAssembly that is roughly two to three times longer, so most of a 60 fps frame went on
  redrawing pictures that had not changed. Taps are read once per frame, so a slow frame is a
  slow tap.
- **What:**
  - All platforms: the player panel's art (hearts, portrait, laurels, level plate, ability
    tiles, keycaps, names, the right-hand buttons, the corner buttons, the strip's board) and
    the top bar (banners, names, scores, clock, the line under it) are baked into textures with
    the existing `_bake` helper and shown by `TextureRect`s behind the HUD (`_layer`). They are
    re-drawn only when what they show changes (`_panel_key`, `_topbar_key`: a heart lost, a slot
    coming ready, the clock's second). The live pass paints only the energy and XP bars, the
    cooldown shades and numbers, cost tags, rank pips and the status tags; glows that sit under
    the tiles (perk/drop glow, ready flash, the crown button's pulse) go on an underlay control
    beneath the baked layers. `_plate` keeps its `StyleBoxFlat`s in a cache, and word-wrapped
    chat lines are remembered (`_wrap`).
  - Web only: the Low preset (the default in a browser) turns the sun's shadow off; Medium
    brings it back. The frame counter is on by default in a browser (Settings: FPS turns it off).
    `max_lights_per_object.web` = 4.
- **Files:** `project.godot`, `scripts/game.gd`, `scripts/hud.gd`, `docs/changelog/online-platforms.md`
- **Tunables:** web Low: sun `shadow_enabled` true → false; `show_fps` default false → true on
  web; `rendering/limits/opengl/max_lights_per_object.web` 8 → 4.
- **Tested:** `--check-only` on the changed scripts; a 40 s headless `--play` match: HUD draw
  time 5.5 ms → 1.1 ms a frame, the panel layers re-baked twice and the top bar about once a
  second; the exported build in Chromium (iPad user agent, touch) side by side with the
  previous build at the same moment: WebGL draw calls per frame 3,240 → 1,130, primitives
  1.0 M → 0.4 M, software-renderer frame time −25 %, HUD identical to the eye apart from the
  "FPS" number, no console errors. Not yet measured on a real iPad.
- **Revert:** `git revert e9fcddf`

## 2026-10-09 12:05 UTC · `8fc8fa2` · Online group catches up with the v0.4.0 alpha

- **What:** merged `release/v0.4.0-alpha` (new menus, downed and revive, economy, store, strict
  4v4, iPad web fixes) into the Online & Platforms branch so online play is built against the
  current game. Conflicts in `game.gd`, `heal_orb.gd`, `README.md` and this changelog resolved by
  keeping both sides. ENet links now tolerate long frames: each peer's timeout is raised so a
  match start that takes several seconds to build no longer drops the joiner. Smoke test passes.
- **Files:** merge of `release/v0.4.0-alpha`; `scripts/net.gd` (`_relax_timeout`)
- **Tunables:** ENet peer timeout limit 32 / min 5000 ms / max 30000 ms (Godot defaults) → 64 / 20000 ms / 60000 ms
- **Revert:** `git revert -m 1 8fc8fa2` (undoes the merge and the timeout change)

## 2026-10-09 12:00 UTC · `9a786cf` · Room relay: online play that works in a browser

- **What:** browsers (the iPad web build) cannot open ENet's UDP links, so online play can now go
  through a small WebSocket relay. New `server/relay.js` (Node, one dependency `ws` 8.18.0, plus a
  `Dockerfile`): CREATE gives a 4-letter room code (no 0/O/1/I), JOIN with the code; the relay
  only forwards packets (joiners to the host, the host to any joiner), pings every 20 s to drop
  dead links, and answers `GET /` with a health line. New `scripts/relay_peer.gd`, a
  `MultiplayerPeerExtension` over one WebSocket, so the game's existing RPCs run on it unchanged.
  `Net.create_room()` / `Net.join_room(code)`; command line `--relay=URL`, `--room-create`,
  `--room-join=CODE`. `tools/net_smoke.sh` now runs the host/join test over both ENet and the
  relay (it starts the relay itself); both pass.
- **Files:** `server/relay.js`, `server/package.json`, `server/package-lock.json`, `server/Dockerfile`,
  `server/.gitignore` (new), `scripts/relay_peer.gd` (new), `scripts/net.gd`, `scripts/game.gd`,
  `tools/net_smoke.sh`
- **Tunables (new):** relay `PORT` 8787, `MAX_PEERS` 8 joiners per room, `MAX_ROOMS` 500, packet cap
  64 KB; game `Net.DEFAULT_RELAY` `ws://127.0.0.1:8787` (set `online/relay_url` in
  `project.godot` once the relay is hosted)
- **Revert:** `git revert 9a786cf`

## 2026-10-09 12:07 UTC · `5bedad8` · Online N2: joiners see and do everything

- **What:** a joiner's game now shows the whole fight, not only people moving, and a joiner can
  do everything a local player can.
  - **Controls:** a joiner's unit runs the same code as a local player (`unit._stick/_held/_tap`
    read either the devices or the joiner's network input), so revive, finisher, give up when
    downed, R ability (ability_3), grabbing, hats, economy interactions and dodge all work. Menus
    on the host no longer block a joiner's controls.
  - **Effects, animations, sounds:** the host records every effect (`fx.gd`, `skill_fx.gd`),
    model animation (`character_model.gd`), 3D sound (`sfx.play`, except footsteps, which each
    screen makes itself), popup, pillar, flash, screen shake and hit flash, and sends them
    reliably once a frame; joiners replay them. Nested effects are recorded once (`Net.depth`).
  - **Projectiles:** arrows, spells and turret bolts fly on joiners' screens (inert copies; the
    host decides hits and its impact effects come across).
  - **Turrets, traps, blessings, planted barricades:** built on joiners' screens with a net id,
    updated (health, level) and removed from the snapshot; joiners arriving mid-match get the
    ones already standing.
  - **Snapshot additions:** downed state, bleed-out and revive bars, kill feed, economy (team
    wood and ore, upgraded hat machines, what each soldier carries, tree and ore stocks), health
    potions, barricade health, the Ember Pass fire point.
  - **Messages:** announcements are global or personal (`announce(text, to)`); personal ones (hat
    taken, potion, blessing, fire form, barricade raised, revive toasts) reach only that player.
    KILL! card, "killed by" card and crown ribbons reach joiners. Chat from a joiner goes through
    the host; team chat only reaches that team.
  - **Looks:** class variants, gear rank and each player's own hero colours show on every screen.
  - **Inert copies on joiners' screens:** turrets, traps, blessings, potions, barricades, doors,
    vaults, economy, resource regrowth and the fire point only act on the host.
  - **Smoke test:** now also has the joiner swing and chat, runs 40 s of match, and requires
    effects, animations, sounds, shots, looks and the chat line to arrive. Passes over ENet and the
    relay (ENet: 421 events in 40 s, relay: 524).
- **Files:** `scripts/net.gd`, `scripts/game.gd`, `scripts/unit.gd`, `scripts/fx.gd`,
  `scripts/skill_fx.gd`, `scripts/character_model.gd`, `scripts/sfx.gd`, `scripts/projectile.gd`,
  `scripts/turret.gd`, `scripts/trap.gd`, `scripts/blessing.gd`, `scripts/barricade.gd`,
  `scripts/gate.gd`, `scripts/vault.gd`, `scripts/economy.gd`, `scripts/resource_node.gd`,
  `scripts/volcano.gd`, `scripts/heal_orb.gd`, `scripts/seal.gd`
- **Tunables:** none (gameplay numbers unchanged)
- **Revert:** `git revert 5bedad8`

## 2026-10-09 13:00 UTC · `HASH-PENDING` · ONLINE screen: create a room, join by code

- **What:** online play is now reachable from the menus, by touch, so it works on an iPad.
  - **Title:** the STORE plank under EXIT is now two half planks, **STORE** and **ONLINE** (a
    small drawn globe, green while connected). The unopened-chest count moved to a red tag on
    STORE's corner.
  - **PLAY ONLINE screen** (`menu.gd` `_draw_online`): CREATE A ROOM on the left shows the
    4-letter code in big boxes, how many friends joined and their names, then **CHOOSE MAP** (the
    usual Select Map > Ready Up > START MATCH) or CLOSE ROOM. JOIN A ROOM on the right has four
    code boxes, a letter pad of the relay's 32 code letters, DELETE and JOIN; a keyboard can type
    the code too (Backspace, Enter). The connection status shows under both panels.
  - A joiner waits on this screen ("Waiting for the host to start the match"); PLAY on the title
    brings a joiner back here instead of to Select Map. If the host leaves, the joiner lands here
    with the reason.
  - When the host's world rebuilds (a map with other ground, or back from a match), joiners are
    sent the world again (`Net.rewelcome`) so their map matches.
  - `print("NET ready")` once the title is up, for the browser test.
  - **New test:** `tools/web_net_test.js` runs the web export in two Chromium pages against a
    local relay: through the menus as two iPads would, then the full `--net-test`.
  - README Online section and `docs/online-plan.md` now describe rooms instead of typing an IP.
- **Files:** `scripts/menu.gd`, `scripts/menu_stage.gd`, `scripts/game.gd`, `scripts/net.gd`,
  `tools/web_net_test.js`, `README.md`, `docs/online-plan.md`
- **Tunables:** none
- **Revert:** `git revert HASH-PENDING`
