# Combat & Balance changelog

Every commit from the Combat & Balance group gets an entry here, newest at the
bottom. Each entry says what changed in plain words, the files touched, every
tunable's old → new value (tunables live in `scripts/stats.gd`), the bot
batches that back it (seeds, map, result), and the line that undoes it.

A commit cannot contain its own hash, so each entry is written in the commit it
describes and its hash is filled in by the next commit on the branch.

Branch: `group/combat-balance-pjmygt`, cut from `claude/project-thread-hu6d1n`
(the combined build: PRs #1-#4 merged on top of `main` 29e5ea8), because
Ember Pass, the Fire forms and the batch tools in `tools/balance` exist only
there and not on `main` yet.

Checks: `tools/tests/run.sh` (headless combat tests, exit code = failures).
Batches: `MAP=<0 Wildwood | 2 Ember Pass> tools/balance/runbatch.sh <tag> <seeds>`,
then `python3 tools/balance/agg.py <tag>`.

---

## 1. Venom Fang slows again

- **When:** 2026-10-08 21:05 UTC
- **Commit:** `90af014`
- **What:** The Assassin Rogue's Venom Fang never slowed anyone. Melee base
  attacks only passed the fire-form burn to the target and dropped every other
  on-hit effect, so the `slow` on the attack did nothing (arrows and spells
  carried it fine). Melee swings now pass `slow` as well as `burn`. Added a
  headless test, `tests/combat_test.gd`, run by `tools/tests/run.sh`
  (`--demo --selftest`): Venom Fang hits and slows for its 0.8 s, the slow is
  still on halfway and gone after, a second cut refreshes rather than stacks,
  Knight and bare-fist swings do not slow, and dying clears the slow.
  Before the fix the test failed 3 of 9 checks (slows, lasts, no-stack);
  after it passes 9 of 9. `runbatch.sh` takes `MAP=` to pick the map.
- **Files:** `scripts/unit.gd` (`_attack`, melee branch), `scripts/game.gd`
  (`--selftest` hook), `tests/combat_test.gd` (new), `tools/tests/run.sh`
  (new), `tools/balance/runbatch.sh` (`MAP=`), `docs/changelog/combat-balance.md`.
- **Tunables:** none changed. Venom Fang `slow` stays 0.8 s (now actually applied;
  slowed units move at ×0.55).
- **Batches:** the six-seed baselines in entry 2 run with this fix in.
- **Revert:** `git revert 90af014`

## 2. Fire form shows up in the batch logs

- **When:** 2026-10-08 21:25 UTC
- **Commit:** `341a026`
- **What:** Logging only, no gameplay change. Demo `KILL` lines now end with
  `kfire=` (the killer was in Ember Pass fire form) and `burn=` (the killing
  heart was a fire-form burn going off). `agg.py` prints a "fire form" line:
  fire-form kills by class, share of all kills, burn finishers, and fire kills
  on base soldiers. Needed for the Fire form re-check.
- **Files:** `scripts/unit.gd` (`burn_tick`, KILL line), `tools/balance/agg.py`,
  `docs/changelog/combat-balance.md`.
- **Tunables:** none.
- **Batches:** none needed (log output only); `tools/tests/run.sh` 9/9 pass.
- **Revert:** `git revert 341a026`

## 3. Wildwood six-seed baseline

- **When:** 2026-10-08 21:28 UTC
- **Commit:** `1155cfd`
- **What:** Results only, no gameplay change. Wildwood baseline, seeds
  1001-1006: Elves 3, Humans 3; captures E5 H6; kills E202 H195; 1 overtime;
  average 332 s; 0 script errors. Table and class numbers in
  `docs/balance/baselines-2026-10-08.md`. Ember Pass baseline, the Humans
  lean fix and the Fire form re-check are paused (Faisal 21:25 UTC: all focus
  on the iPad build; no further tasks without his input).
- **Files:** `docs/balance/baselines-2026-10-08.md` (new), `docs/changelog/combat-balance.md`.
- **Tunables:** none.
- **Batches:** tag `bwild`, MAP=0, seeds 1001-1006, at `90af014`.
- **Revert:** `git revert 1155cfd`

## 4. Combat feel: hit effects, slash arcs, spell blasts, heals, auras

- **When:** 2026-10-09 00:25 UTC (Faisal 2026-10-08 23:58: particle effects,
  colour on hit, healing/spell/splash effects, better combat feel)
- **Commit:** `6356f8f`
- **What:** Looks only; no balance number changed and the bot brain, movement
  and timers are untouched.
  - New `scripts/fx.gd`: one effects node under the game. Soft glowing motes,
    spark streaks, smoke puffs and tumbling chips (CPU particles), plus flares,
    ground shockwave rings, glows, spell runes, scorch marks and heal beams,
    all from generated gradient textures. Works the same in the Compatibility
    renderer the iPad web build uses.
  - Every landed hit: a flare and sparks thrown away from the attacker, styled
    by what hit (sword, fists, Venom Fang, arrow, arcane, fire, frost, holy,
    dark, nature, heavy blows), a white-hot rim flash then a red tint easing
    back (was a flat red for 0.15 s), a squash-and-spring on the body, and a
    short hit stop (the animation holds 0.07 s, 0.11 s for two hearts; the
    attacker's holds 0.06 s when a swing lands). Blocks throw blue sparks;
    armour glances flash.
  - Melee swings draw a crescent slash that sweeps across the aim and
    alternates sides (was a flat white box for 0.12 s); heavy weapons get a
    wider, longer arc. Wind Dash/Charge/Backstab leave a streak and an arc;
    Cleave draws a full spin.
  - Area hits (Fireball, Ice Burst, Bramble Burst, splash bolts) draw
    `Fx.blast`: flare, shockwave ring, sparks, embers/ice shards/leaves/motes,
    smoke and a scorch mark that fades over a few seconds. Fire and frost
    blasts shake the camera nearby.
  - Spells leave a spinning rune circle under the caster (Fireball, Smite,
    Blessing, Curse, Holy Bubble, Blink, guard abilities like Barkskin).
  - Heals: green glow on the ground, rising motes, floating "+" crosses and a
    thread of light from the healer.
  - Status auras while they last: green venom drips (slowed), light rising
    round the feet (rooted), wind streaks (haste), blue motes (guard).
  - Falls: dust puff, team-coloured sparks, a wisp rising.
  - When you kill someone the camera kicks (0.28) and your swing holds a beat.
  - "SLOWED" pops once when the slow starts, not on every cut that refreshes it.
  - `game.spawn_splash`, `spawn_ring`, `spawn_burst` and `spawn_swing` now draw
    through `fx.gd`, so older effects (doors, turrets, potions, traps) get the
    softer look too.
- **Shared files touched:** `scripts/game.gd` (the four `spawn_*` bodies above,
  a `const Fx` line, and a `--fxshow` hook next to `--play`). No scene,
  material, shader or texture files changed.
- **Files:** `scripts/fx.gd` (new), `scripts/unit.gd`, `scripts/projectile.gd`,
  `scripts/game.gd`, `tests/combat_test.gd` (9 new checks: hit drawn, flash on
  and off, hit stop on and off, slow aura on and off, blasts and heals drawn,
  effects freed within 4 s), `tests/fx_showcase.gd` (new, scripted effects
  run for captures), `docs/changelog/combat-balance.md`.
  Also merges `claude/project-thread-hu6d1n` e5ba404 (web build tweaks) into
  this branch first (merge commit 770376c).
- **Tunables:** none in `scripts/stats.gd`. New look-only constants in
  `unit.gd`: `FLASH_TIME` 0.22 s (old flash 0.15 s).
- **Checks:** `tools/tests/run.sh` 18/18 pass. 120 s bot matches on Wildwood
  and Ember Pass (seed 7): no script errors (one existing Ember Pass HUD
  "Invalid polygon data" engine error, not from this change).
- **Capture:** `godot --path . --rendering-driver opengl3 --fixed-fps 30
  --write-movie out.png --quit-after 175 -- --play --fxshow --shot-frame=99999`
  (Compatibility renderer); results in project files `game/combat-feel/`.
- **Revert:** `git revert 6356f8f`

## 5. Walls and doors stop every shot

- **When:** 2026-10-09 09:50 UTC (Faisal 2026-10-09 09:11: "we shouldn't be
  able to shoot projectiles through walls and the door, you can stand over
  and shoot but that's it")
- **Commit:** `d53d4e0`
- **What:** Two leaks closed.
  - Shots only collided with the world and the *enemy's* door layer, so a
    side's arrows, bolts and fireballs flew straight through its own door,
    its back door and its sanctuary ward. Every shot now stops on walls,
    either team's door, gate, vault door and ward; it still flies past its
    own team's turrets. The flight ray also catches a shot that starts
    touching a wall (`hit_from_inside`).
  - Splash (Fireball, Ice Burst, Bramble Burst, splash bolts) hurt everyone
    in its radius "walls or no walls", so a blast on the outside of a wall
    hit defenders behind it. A blast now only reaches people it can see: a
    wall or door between them shields them.
  - Shooting over a wall from the rampart is unchanged (tested).
- **Files:** `scripts/projectile.gd` (`query_mask`, flight ray, `_clear_to`,
  `_burst`), `tests/combat_test.gd` (4 new checks), `tests/fx_showcase.gd`
  (`--fxwall` capture), `docs/changelog/combat-balance.md`. Also merges
  `claude/project-thread-hu6d1n` 0ca54e0 (web build fixes) first.
- **Tunables:** none. Projectile collision mask `1 | enemy door layer` →
  `1 | 4 | 8`.
- **Checks:** `tools/tests/run.sh` 22/22 pass. New: 192 arrows fired across
  both castles from outside in and from the yard out (both teams) never fly
  through anything solid (before the fix 14 flew through their own doors);
  a Human Ranger on the rampart still hits an Elf on the field below; a
  fireball on the outside of the Human front wall catches a Human outside it
  and spares one just inside (before the fix it hit both).
- **Bots still raid doors** (3-minute demo matches, seeds 21-22):
  Wildwood 2 + 2 doors broken (before: 2 + 1), Ember Pass 1 + 1 (before:
  0 + 1); no script errors.
- **Capture:** `-- --play --fxshow --fxwall` (Compatibility renderer); in
  project files `game/combat-feel/shots-stop-at-door-*`.
- **Revert:** `git revert d53d4e0`

## 6. Strictly 4v4

- **When:** 2026-10-09 10:05 UTC (Faisal 2026-10-09 09:14: "change the game to
  strictly 4v4 for now")
- **Commit:** `0c1cd37`
- **What:** Every match is 4 Elves against 4 Humans, players and bots
  together; bots take every seat a player leaves empty. Couch split-screen
  (1-4 players) no longer grows a side past 4 (it used to be the bigger of the
  team size and the local players on that side). An older saved team size is
  ignored. SELECT MAP's TEAM SIZE row is now one fixed "4v4" box ("Bots fill
  any empty seats"); the 1v1-5v5 choices are gone. The bot lineup is the
  first four of `LINEUP`: Knight, Ranger, Mage, Healer (the Engineer, 5th,
  no longer appears as a bot, so bots build no turrets). `--team-size=` stays
  as a testing flag (1-4). The online branch (PR #6) sizes teams from
  `TEAM_SIZE` too, so it follows this once merged.
- **Files:** `scripts/game.gd` (`TEAM_SIZE`, `team_size`, match setup, settings
  load), `scripts/menu.gd` (TEAM SIZE row, `team_size` action),
  `docs/changelog/combat-balance.md`.
- **Tunables:** `TEAM_SIZE` 5 → 4 (game.gd); default `team_size` 5 → 4,
  menu choice 1-5 → fixed 4.
- **Batches:** full bot matches, seeds 31-32: Wildwood (`t4wild`) Elves 1,
  Humans 1; Ember Pass (`t4ember`) Elves 1, Humans 1; 4 units a side in every
  STAT block; captures E4 H4, kills E63 H55, doors broken 1-3 a match, average
  223 s, 0 script errors. `tools/tests/run.sh` 22/22.
- **Revert:** `git revert 0c1cd37`

## 7. Longer dodge cooldown, free basic attacks, slower punch

- **When:** 2026-10-09 10:15 UTC (Faisal 2026-10-09 09:14 "the dodge needs more
  of a cooldown"; 09:15 "the stamina for punch needs to be more and there needs
  to be slightly more of a cooldown"; 09:16 "the basic attack shouldn't drain
  your stamina or magika")
- **Commit:** `d0e572e`
- **What:** The dodge waits twice as long between uses (the HUD's dodge slot
  already shows the cooldown). Every class's basic attack (Punch, Sword
  Strike, arrows, bolts, Mend, every variant) now costs no stamina or mana;
  cooldowns alone pace it. The later "shouldn't drain" message overrides the
  punch costing more; asked Faisal whether the bare-handed punch should cost
  stamina after all. The punch's cooldown is a little longer.
- **Files:** `scripts/stats.gd` (`DODGE_COOLDOWN`, new `BASE_ATTACK_COST`,
  Punch cooldown), `scripts/unit.gd` (`attack_stats` applies
  `BASE_ATTACK_COST`), `docs/changelog/combat-balance.md`.
- **Tunables:** `DODGE_COOLDOWN` 2.0 → 4.0 s; basic attack cost per class
  7-16 → 0 (`BASE_ATTACK_COST` 0.0; table values kept but overridden);
  Punch `cooldown` 0.6 → 0.72 s (Punch table cost stays 8, unused).
- **Batches:** six Wildwood seeds 41-46, 4v4, before (`t4base`, at 0c1cd37)
  and after (`t4free`, at d0e572e):
  - before: Elves 5, Humans 1; caps E11 H2; kills E169 H114; avg 394 s.
  - after: Elves 4, Humans 2; caps E8 H5; kills E150 H106; avg 395 s.
  - 0 script errors in both. Match length unchanged; the Elf lean is a little
    smaller, within six-seed noise. (A first `t4base` run used a worktree with
    no imported assets and was thrown away.)
- **Revert:** `git revert d0e572e`

## 8. Every skill gets its own cast animation and particles; Fae Step dash

- **When:** 2026-10-09 11:30 UTC (Faisal 2026-10-09 09:17 "for the fae step add
  animations and unique animations for each skill. add particle effects. If
  there is no reference present for how the skills should look then change it")
- **Commit:** `c4e5054`
- **What:** All 50 abilities (both sides' kits and every promotion) now play
  their own body animation and their own particles when cast, on top of what
  the ability already drew. Looks only: no damage, cooldown, cost, reach or
  timing changed.
  - Reference followed (`game/reference-renders/skills-upgrades-target-2026-10-09.png`):
    Fae Step is a violet dash that leaves running afterimages along the path,
    violet streaks and sparkles, and the mage springs back into shape where
    they land. Thorn Bolt is now a glowing green thorned dart with a green
    streak (it was a purple orb). Bramble Burst is a spinning thorny seed-ball
    (it was drawn as a fireball) that bursts into a ring of brambles out of the
    ground.
  - No reference, designed to fit each side: Elves are leaf, bark, fae violet
    and moonlight (Wind Dash leaf-green afterimages and leaves, Barkskin bark
    chips and a green shell, Starfall a wheel of stars and silver arrows, Vine
    Snare, Spirit Bloom flowers opening round the healer, Lunar Lance a silver
    lance, Thorn Totem brambles, Tend petals). Humans are steel and holy light
    (Shield Bash lunge and sparks, Shield Wall a steel shell, Bulwark gold,
    Heavy Bolt recoil and muzzle sparks, Blessing gold swirl, rays and falling
    feathers, Holy Bubble rays, Smite rays, hammer sparks for turrets). Shared
    promotions get their own too (Cleave body spin, Inferno, Ice Burst, Snipe
    tracer, Shadow Step and Backstab shadow afterimages, Vanish, Curse spiral).
- **Files:** `scripts/skill_fx.gd` (new: per-skill animation table and looks),
  `scripts/fx.gd` (new pieces: `petals`, `swirl`, `afterimage`,
  `trail_ghosts`, `thorns`, `dome`, `rays`; nature blasts grow brambles),
  `scripts/unit.gd` (`use_ability` calls `SkillFx.cast`/`land`; the ability
  body moved to `_ability_effect` unchanged; Bramble Burst no longer flagged
  fire for looks; nature spell colour), `scripts/projectile.gd` (`look`:
  thorn, star, moon), `tests/combat_test.gd` (casts every ability on both
  sides and checks the body returns to shape and effects clean up),
  `tests/fx_showcase.gd` (`--skills=<class>` and `--at=x,z` capture mode).
- **Tunables:** none.
- **Checks:** `tools/tests/run.sh` 25/25; a 150 s Wildwood bot match with 0
  script errors.
- **Revert:** `git revert c4e5054`

## 9. Grab (F / RB) reaches out and answers with a pop or a whiff

- **When:** 2026-10-09 12:20 UTC (Faisal 2026-10-09 09:23 "i also want the grab
  to actually do something like feel like it does something, (the f key or the
  rb key) maybe add a slight grab animation")
- **Commit:** `e80690e` (its message reads "docs: changelog hash for" by mistake; it holds the whole grab change)
- **What:** Every press of grab now plays a quick reach animation, with a lean
  forward and a small sweep of the hand. When it takes hold (a class hat, the
  crown, the guide, a barricade), you get a pop and sparkle on the object, a
  light grab sound, a small tug on the body and a short pad buzz. When there
  is nothing in reach, you get a soft whiff sound and a puff of air. Bots retry the
  crown every frame at a locked vault, so a reach shows at most every 0.4 s.
  Looks only: what grab does is unchanged.
- **Hook for other groups:** `SkillFx.grab(u)` (the reach),
  `SkillFx.grab_hit(u, where, colour, big)` and `SkillFx.grab_miss(u)` in
  `scripts/skill_fx.gd`; `game.try_interact` calls them.
- **Files:** `scripts/skill_fx.gd` (grab section), `scripts/game.gd`
  (`try_interact` calls the hooks), `tools/make_sounds.py` + `assets/sfx/grab.wav`,
  `assets/sfx/grab_miss.wav` (new sounds, generated by the script),
  `tests/combat_test.gd` (grab checks), `tests/fx_showcase.gd` (`--grab`).
- **Tunables:** none.
- **Checks:** `tools/tests/run.sh` 27/27.
- **Revert:** `git revert e80690e`

## 10. Hit reactions, camera kick, death fling, buffered skill and dodge presses

- **When:** 2026-10-09 12:50 UTC (Faisal 2026-10-09 11:33 "begin upgrading the
  combat and icons and general game feel"; coordinator: hit weight,
  responsiveness, enemy reactions, death and knockback feel, camera punch)
- **Commit:** `24d9aa9`
- **What:**
  - Flinches come from the side the blow landed on (Hit_A or Hit_B). A heavy
    blow (2+ hearts) cuts into whatever the body was doing and lifts it off its
    feet a little.
  - Camera kick: the view jolts the way you were pushed when you are hit,
    leans into the blow when your swing lands, and kicks toward the victim on
    a kill, then springs back. It is off when screen shake is off in Settings.
  - Death fling: the killing blow throws the body back about a metre in a
    short arc and it lands in a puff of dust as it falls. The unit itself
    doesn't move; the model is reset on respawn.
  - Responsiveness: a skill or dodge pressed up to 0.25 s before it is ready
    (cooldown or energy) now fires the moment it can, instead of being lost.
    Players only, so bot batches are unaffected.
- **Files:** `scripts/unit.gd` (`take_damage` flinch + kick, `_death_fling`,
  `input_buffer`/`INPUT_BUFFER`, kick on landed swings and kills),
  `scripts/game.gd` (`kick_cam`, `cam_kick` in `_update_camera`),
  `scripts/character_model.gd` (`revive` resets the model transform),
  `tests/combat_test.gd` (death fling and reset checks).
- **Tunables:** new `INPUT_BUFFER` 0.25 s (unit.gd); kick sizes 0.12 (landed
  swing), 0.18 / 0.3 (hit / heavy hit), 0.22 (kill), springs back at 10/s,
  capped at 0.5.
- **Checks:** `tools/tests/run.sh` 29/29; an Ember Pass bot match with 0 script
  errors. No batch: nothing a bot does changes.
- **Revert:** `git revert 24d9aa9`

## 11. Hit sounds with weight; kill sting; last-heart heartbeat

- **When:** 2026-10-09 13:05 UTC (same standing task as entry 10)
- **Commit:** `007a834`
- **What:** Landed blows now sound like what hit you. Heavy blows (2+ hearts,
  or a heavy weapon) add a deep crunch under the hurt sound. Spells (arcane,
  frost, holy, dark, nature, fire) add a crackle. Your own kills play a short
  low boom with a bright chime. On your last heart you hear a soft heartbeat
  until you are healed or fall. Sound only.
- **Files:** `tools/make_sounds.py` (new `hit_heavy`, `hit_magic`, `kill`,
  `heartbeat`), `assets/sfx/hit_heavy.wav`, `hit_magic.wav`, `kill.wav`,
  `heartbeat.wav` (generated by the script), `scripts/unit.gd`
  (`take_damage` sound layer, kill sting, `heartbeat_timer`).
- **Tunables:** none (volumes: crunch -2 dB on 2-heart hits / -7 dB on light
  heavy-weapon hits, crackle -6 dB, kill -4 dB, heartbeat -9 dB every 0.95 s).
- **Checks:** `tools/tests/run.sh` 29/29.
- **Revert:** `git revert 007a834`

## 12. Balance patch 1

- **When:** 2026-10-09 13:55 UTC (Faisal 2026-10-09 11:38 "lets start building
  balance patches with test runs as well")
- **Commit:** `b25c80f`
- **What:** Five tunables, measured before and after on 12 seeds across both
  maps on the combined build; full write-up in `docs/balance/patch-1.md`.
  Also `a1bc130`: agg.py prints melee/ranged/support K/D and downed/revive
  rates, and the death tests finish off a downed unit.
- **Files:** `scripts/stats.gd`, `docs/balance/patch-1.md`.
- **Tunables:** Humans `regen_mult` 1.06 → 1.15; Knight `speed` 1.06 → 1.10;
  Warden `range` 2.0 → 2.2; Human Crossbow `cooldown` 0.75 → 0.68; Elf Grove
  Mend `heal_radius` 6.0 → 5.0.
- **Batches:** p1w0/p1w1 Wildwood 51-56: Humans 4-2 → Elves 5-1; p1e0/p1e1
  Ember Pass 51-56: Elves 5-1 → 3-3. Human melee K/D 0.39-0.51 → 0.70-0.83,
  Elf support 2.1-2.9 → 0.8-1.3.
- **Revert:** `git revert b25c80f`
