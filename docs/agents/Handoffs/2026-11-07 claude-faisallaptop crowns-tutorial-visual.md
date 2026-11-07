---
agent: claude-faisallaptop/crowns-tutorial-visual
task: crowns-tutorial-visual (from claude-faisallaptop coordinator, 2026-11-07)
---
# First-time tutorial text and map visual pass

## 1. First-time player, wiped profile (1920x1080)
Driven by NEW `tools/firsttime_capture.gd` (no user args, so the game shows its real
first-launch flow: WHO'S PLAYING, HOW TO PLAY cards, MORE QUESTIONS, map pick, a match on
map 0 with the first-match tips, a Knight hat taken at the station, a full talk with the
Wildwood Guide). Frames: `docs/evidence/crowns-tutorial-visual-1107/before/` and `after/`
(same step numbers).

**Fixed (text only):**
- HOW TO PLAY card 2 and the GOAL chat line said "walk onto a glowing class station". A
  player takes a class by pressing interact (F) at its hat. Now says so, names the five open
  classes and the Rogue's account-level-10 unlock (from `Stats.UNLOCK_LEVEL`).
- "Two captures win" on card 4, the guide's objective answer and the GOAL chat line. The game
  is first to `Stats.CAPTURES_TO_WIN` (8), with a 15-minute clock and overtime on a tie. The
  numbers now come from Stats.
- Card 1 read "Press Q and E fire your class skills" (broken grammar, and Q/E are locked on a
  plain soldier). Now: "Click to attack. SPACE dodges. Once you wear a class hat, press Q and E
  to use its two skills." The guide's fight answer says the same.
- Mouse keys: the guide answers and tips said "LMB attacks", "Knights hold RMB". Now "Left
  Click" / "Right Click" like the cards. The card's "Press Left Click" became "Click".
- Tips: the ability tip on a plain soldier now says "Dodge: SPACE. Put on a class hat to unlock
  Q and E"; the goal tip mentions the vault lock.
- Guide intro: class line says to grab a hat; the Upgrade Station line sits next to the
  experience it spends; Engineers are listed; the last line mentions the vault lock.
- Guide answers for classes, upgrading and where to go ran a line past the talk panel at
  1080p (the panel does not clip). Cut to four lines each (Rogue added to classes).

**Found, not fixed (hud.gd / class panels, other owners):** mailed to claude-faisal3:
`docs/agents/Inbox/2026-11-07 1500 claude-faisallaptop to claude-faisal3 - first-time HUD findings.md`.
Short version: the hud.gd onboarding line "Q and E skills unlock as you level" is wrong (they
come with the hat); the Knight skill bar's RMB slot sits under the R slot at 1080p; the name tag
overlaps the "LOCKED · ACCOUNT LEVEL 10" prompt; Veteran Training pops up on the first hat at
Level 1; a promotion card description runs past its card; the guide panel doesn't fit long text.

## 2. Map visual pass (all five maps)
- Match-camera captures at the nine fixed stations of `tools/ground_capture.gd` on maps 0-4,
  1080p, contact sheets in `.../sheets/sheet-map0..4.jpg` (full frames kept locally, not
  committed). Headless `tools/map_prop_audit.gd` on maps 0-4.
- **Nothing small and safe to fix was found.** No floating props or texture mismatches in the
  frames. List:
  1. A dark jagged line along the fortify barrier at the Stonekeep (map 3) and map 4 crossings
     in the ground captures (`.../ground/map3-c-crossing.jpg`, `map4-c-crossing.jpg`). A targeted
     probe (fortify, wall hidden, barrier hidden, battle) did **not** reproduce it
     (`.../sheets/stonekeep-barrier-probe.jpg`). Looks like a transient render artifact in the
     first seconds of a match; needs a frame-by-frame look.
  2. `map_prop_audit` map 4: one bush 0.51 m from a low wall at (-17.4, 5.1).
  3. The CI clutter audit (`--audit`) reports 12-18 kit trees clipping per map (autumn trees
     around the Human castle, x 58-82, on map 0). **Identical on clean main dfe110d**, so it is
     not from this branch; owner of the forest kit should look (CI has been failing in 0 s on
     every push, so nobody saw it).
  4. A "[F] CHOP WOOD (n left)" prompt overlaps the player's name tag when standing by a tree
     (`.../ground/map4-i-south-edge.jpg`).

## Tests (local, Godot 4.3, throwaway user dirs)
Clean import 0 script errors. The CI headless set (scripted in my run, list in the PR):
tips, selftest, combat input, hotplug, smoke, movement, spawn warm, ice, graveyard, cloud paths,
pad kind/unplug/nav, options menu, menu flow, store menu, save write/recovery/save, settings
restart, steam ready, options, legend, split HUD, unit allocation, shared XP, rock mesh, batch
primitive, full seeded bot match: all pass, except
- `--audit` maps 0,1,3,4 and moonlit: kit-tree CLIPs, identical counts on clean main (above);
- pad_nav_test (68) and options_menu_test (280) print `character_model.gd:1027
  surface_get_format` SCRIPT ERRORs with 0 assertion failures: identical counts on clean main.
Not run: rendered xvfb loading/world-behind gates (Linux CI only).

## Release export + fresh-profile boot (source 6319bb7, origin/main dfe110d merged)
`--export-release "Windows Desktop"` to C:/Temp/cl2-cr-ud-tut/build/6319bb7/Crowns.exe (not
committed, not uploaded; sha256 f82c043e...35c3). Each boot with a brand-new APPDATA and
LOCALAPPDATA, windowed 1280x720: title (900 frames) and `--play --map=0..4` (2400 frames):
all exit 0, **0 SCRIPT ERROR**. Only engine noise (Skeleton3D disconnect warnings on the title,
one shader RID leak at exit). Logs in `.../boot/`.
After-frames re-taken on this source (`.../after/`).

## Credits
No Meshy or PixelLab credits spent.

Agent: claude-faisallaptop/crowns-tutorial-visual
