# Crowns of the Wildwood (work in progress)

Elves vs Humans: steal the enemy monarch and carry them to your throne. First to 2 captures wins, or the higher score when the 10 minute clock runs out.
Real low-poly models and textures (all CC0, see `assets/CREDITS.md`), with every rule and number in plain GDScript.

## Run it

1. Download Godot 4.3 or newer (Standard version, not .NET) from https://godotengine.org/download
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the play button at the top right).

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | WASD or arrow keys | Left stick |
| Aim | Mouse | Right stick |
| Base attack (every class has one) | Left click or J | A or right trigger |
| Block (Knight's shield, hold) | Right click, Shift or K | Left bumper or left trigger |
| Ability Q / Ability E | Q / E | X / Y |
| Dodge (2 second recharge, costs 10 stamina) | Space or L | B |
| Grab or drop the monarch | F | Right bumper |
| Perk menu (spend experience, pick a promotion) | R, then 1-4 (5 / 6 for a promotion) | Right stick click, then D-pad |
| Scoreboard | Hold Tab | Hold Back |
| Chat (team by default, `/all` for everyone) | Enter, type, Enter | - |
| Pause menu (map, scoreboard, classes, upgrades, options) | Esc, arrows switch tabs | Start, bumpers switch tabs |
| Show / hide the chat log | H | - |
| Show / hide the side team rosters | N | - |
| Talk to the Wildwood Guide (next line) / close | F / Esc, 1-6 pick a topic | Right bumper |
| Pick a class from the Academy panel (in your courtyard) | 1-4 or click | - |
| Play again after a match | R or Enter | Start |

Every row above except movement by stick and aiming can be rebound: open **Controls** (Esc in a match, or O / the Options button on the title screen), click a row and press the key, mouse button or gamepad button you want. Bindings are saved to `user://controls.cfg`; **Reset to defaults** puts them back.

On the title screen, press 1 (D-pad left) or click the Elves card to play the Elves, 2 (D-pad right) or the Humans card for the Humans. Left/Right (or the buttons) set the bot difficulty: **Easy** (bots aim badly, rarely use abilities, never chase), **Normal**, **Hard** (sharp aim, more abilities, chase bounties from far away). The **Your Hero** panel sets your name, hair colour and trim colour; they are painted into the skin of every class you take and saved with your settings.

## Rules

- **Hearts.** Everyone has 4 hearts. Every hit takes one heart. Healers give hearts back.
- **Dodge.** Space: a quick dash in the direction you are moving. Nothing can hit you during it. It recharges in 2 seconds and costs a little stamina or mana. You cannot dodge while carrying the monarch.
- **Block.** Shield classes (the Knight) hold right click to raise the shield: hits from the front do nothing, but each blocked hit costs 18 stamina, holding it drains stamina, you walk at half speed and cannot attack. Run out of stamina and the shield drops.
- **Hits have weight.** Every hit shoves the target (fireballs shove hardest), attackers lunge or recoil, the camera kicks when you are hit or something explodes nearby, and sparks, splinters and damage numbers show what happened.
- **Walls.** Ramps in your yard lead up to the walkway on the front wall. Walk off the front edge to drop straight down into the field.
- **Aiming.** You aim with the mouse (or the right stick) and walk with WASD, so you never have to line up by walking. The yellow pointer at your feet shows your aim; the ring shows where the cursor is.
- **Health potions.** Green bottles on stone slabs sit at fixed spots: the middle of the road, both flanks of the field, and one in each castle yard. Walk over one when hurt to get 2 hearts back. It returns 25 seconds later. They are dots on the minimap.
- **Blessings of Light.** Every 35 to 60 seconds a glowing pillar appears somewhere in the field (never inside a castle) and the HUD announces it. Whoever reaches it first gets a 10-second buff: **Regeneration** (a heart back every 2.5 s), **Swiftness** (30% faster) or **Might** (every attack takes an extra heart). A badge over your panel counts it down; the blessing fades after 25 seconds if nobody takes it. Bots go for them too.
- **Friend or foe.** Enemies have a dark red outline, a red shadow and a red name; teammates dark green. Whoever is under your cursor (or in your aim cone on a pad) glows bright red or bright green.
- **Classes and movesets.** You spawn as a plain Elf or Human with no gear. Step onto a class station in your castle to transform. Every class has a base ability on left click (cheap, short cooldown) and two bigger abilities on Q and E that cost a lot more stamina or mana:
  - **Knight** (stamina): **Sword Strike**, the best at breaking doors; **Block** on right click. **Q Shield Bash** (5 s, 30): dash forward, hitting and shoving everyone in the way. **E Shield Wall** (10 s, 35): nothing gets through for 1.8 seconds, from any side.
  - **Ranger** (stamina): **Quick Shot**, a fast arrow. **Q Volley** (6 s, 40): five arrows in a fan. **E Snare Trap** (8 s, 30): drop a low ring of teeth, hard to spot in the grass; the first enemy to step on it takes a hit and is rooted for 2 seconds. Traps stop at the first wall or crate between you and the spot, so they never land inside one.
  - **Mage** (mana): **Arcane Bolt**, a fast bolt with a small splash. **Q Fireball** (7 s, 55): a big ball of fire, 2 hearts in a wide splash, four hits to a door. **E Blink** (6 s, 25): teleport 6 units in the aim direction.
  - **Healer** (mana): **Mend** heals every hurt teammate around you, yourself included; with nobody to heal, the same click fires a holy bolt instead. **Q Blessing** (12 s, 60): heal everyone nearby by 2 hearts and speed them up for 3 seconds. **E Smite** (3.5 s, 25): a fast holy bolt.
  - Step onto a different station to switch. Dying returns you to the plain form.
- **Stamina and mana.** Every attack costs some, and both refill slowly (11 stamina or 7 mana a second), so the Q and E abilities are a budget, not a rotation. Humans refill faster; Elves move faster.
- **Experience, per life.** Hitting (10 a heart), killing (40, with a KILL popup), healing a teammate (8 a heart), hitting the door, grabbing the monarch (25) and capturing (100) earn experience. Levels come at 40, 100, 180, 280 and 400 and each gives one rank point. Press R for the perk menu: three ranks each in your base attack, Q, E and Vigor. Rank 1 cuts the cooldown 15% and the cost 12%, rank 2 widens the effect (range, radius, duration, two more arrows), rank 3 adds a heart of damage or healing; each Vigor rank is +7% speed, +15 max energy, +20% regen. Dying wipes it all, so staying alive is how you get strong. Bots rank up too.
- **Promotions (class variants).** Every rank point you spend counts towards your *total upgrades* for the match, per class, and those are kept across lives. Spend 3 in a class and its two variants unlock in the perk menu (press 5 or 6, or click): the pick is kept for the rest of the match and you can switch any time. Like Fat Princess's upgraded hat machines, a promotion changes the base attack, Q and E, and the look:
  - **Knight → Vanguard** (greatsword, no shield): **Q Cleave** spins and hits everyone around you, **E Charge** is a long knockdown dash. **Knight → Warden** (tower shield, mace): **Q Shield Slam** pins everyone it hits for 1.5 s, **E Bulwark** is a 3 s shield wall that also shields teammates within 4 m.
  - **Ranger → Sharpshooter** (longbow, 20 m range): **Q Piercing Shot** flies through everyone in line, **E Snipe** takes two hearts. **Ranger → Trapper**: poison arrows slow, **Q Trap Line** plants three traps in a row, **E Smoke Bomb** hides you from bots and speeds you up for 3 s.
  - **Mage → Pyromancer**: burning bolts that splash, **Q Inferno** is a huge fireball, **E Flame Wave** burns everyone in a cone in front. **Mage → Frostweaver**: frost bolts slow, **Q Ice Burst** freezes everyone near the blast for 1.3 s, **E Blink** goes 8 m.
  - **Healer → Cleric**: wider Mend, **Q Sanctuary** heals, speeds and shields the group, **E Radiance** is a bursting bolt. **Healer → Dark Priest**: drain bolts heal you a heart per hit, **Q Curse** hurts and slows every enemy around you, **E Smite** takes two hearts.
- **Teams and scoreboard.** Your team's roster sits on the left of the screen and the enemy's on the right (portrait, class, hearts, energy, class emblem; N hides them). Hold Tab for the full scoreboard: both teams with everyone's class, hearts (or respawn countdown), blessing, level, score, kills, deaths, captures, hearts healed, damage and total upgrades, score = kills ×10 + assists ×4 + captures ×100 + heals ×5 + damage ×2 + upgrades ×3. Hitting someone a teammate then kills within 8 seconds is an assist (15 XP). Enter opens team chat (`/all` for both teams); bots answer and call out captures, broken doors and kills, and the log doubles as an event feed. Bots have names.
- **Balance notes (latest pass).** Base attacks are cheap and quick (Knight sword 0.55 s, Ranger shot 12 stamina, Mage bolt 0.65 s with a small splash), the big Q abilities cost more and come back slower (Fireball 7 s / 55 mana, Volley 6 s, Shield Bash 5 s), the escapes are cheaper (Blink 25 mana, Dodge 12), every rank cuts cooldowns 12%, kills are worth 40 XP, and the promotion abilities were tuned the same way (Cleave 6 s, Snipe 10 s, Inferno 8 s / 60 mana, Ice Burst 6 s with a 1 s freeze, Curse 10 s, Dark Smite 7 s / 45 mana). Everything lives in `scripts/stats.gd`.
- **Castles, in layers.** From the back: the **spawn cellar** (a protected sanctuary under the keep: you respawn there, the four class stations, the Upgrade Station pad that opens your perks, and the Wildwood Guide live there; enemies, their shots and their spells can never enter, and a flight of stairs plus a sealed back arch are its exits), the **keep** with the throne and the **Crown Vault**, the **yard** with breakable wooden fences and ramps up to the walls, and the **door** at the front. Each castle is an outer castle wall ringing a yard, with the keep standing inside at the back. The wall's one wooden door only blocks the enemy team, breaks after enough hits (Knights and Mages break it fastest; a Fireball is worth four hits), and rebuilds itself 30 seconds later once no enemy is left inside. Ramps in the yard at both ends of the front wall lead up to the ramparts: from up there Rangers and Mages shoot down at anyone outside, and arrows from the ground cannot reach them. Mage splash still can. The keep has an open archway facing the door.
- **Cover.** Barricades, boulders and trees in the middle stop arrows and spells. Duck behind them. Rangers (and Ranger bots) tuck in behind them.
- **Fences.** The wooden fences in each yard and beside each Crown Vault stop everyone, but the enemy can smash them (4 hits; a Fireball counts for four) and they fall over; the castle rebuilds them 45 seconds later once no enemy is inside.
- **Spawn protection.** For 3 seconds after you spawn (and the whole time you stand in your own cellar) nothing can hurt you: a SPAWN PROTECTED plate shows, and hits read PROTECTED. It ends when the timer runs out or you leave the cellar.
- **Defender zone.** Inside your own castle you get DEFENDING HOME: +10% damage resistance (every tenth hit is shrugged off as FORTIFIED), +10% healing received, +10% regeneration and 15% faster door repairs. Attackers never get it, and it stops at the castle wall. Values are in `Stats.DEFENDER`.
- **Crown Vault.** The enemy monarch sits inside a barred vault in the keep. Its lock gate only blocks the enemy; attackers have to break the lock (12 hits, `Stats.VAULT_HITS`; a Fireball is four) before they can grab the monarch, which takes a Knight about 6 seconds. The lock shows its hits left, sparks on every hit, swings open with a flash, and locks again 30 seconds after the keep is clear and the monarch is home. Breakable fences flank it for defenders.
- **CROWN STOLEN.** When the monarch is grabbed, a red card under the clock names the thief with a minimap inset, the carrier gets a golden glow and a trail, and the carrier always shows on the minimap.
- **Veterans and bounties.** 5 kills without dying makes you a VETERAN (announced, a gold ring). 10 makes you an ELITE VETERAN: a bounty is announced to the enemy, you are revealed on their minimap with a pulsing ring and a beacon over your head, and you get an extra heart and 25% faster regeneration. Whoever kills an elite earns 80 XP and the whole team gets a 10-second Blessing of Might. Dying ends the streak.
- **Death.** Respawn takes 7 seconds plus 1 per level you had (up to 13), and you come back as a plain Elf or Human at level 1 with no perks: you relevel, promotions excepted.
- **Wildwood Guide.** A friendly NPC in each cellar near the stations. Walk up (a speech bubble greets you), press F to talk: a dialogue box with a big portrait walks you through the game, then a topic menu (objective, fighting, classes, upgrades, the Crown, where to go; press 1-6 or click). Esc closes. The **HOW TO WIN** checklist on the right ticks off your first leave-castle, fight-the-centre, break-the-gate, reach-the-vault, open-the-chest, steal and return steps and folds away after your first capture.
- **Bots.** Bots play the objective: a squad planner hands out jobs every second (recover our stolen crown, escort our carrier, defend the castle when the gate is hurt or the keep breached, otherwise attack), Knights frontline and cover healers, Rangers keep range and use cover, Mages save Fireballs for groups, Healers stick with the carrier or the most hurt and back off from melee, and anyone outnumbered and hurt falls back to a teammate.
- **Monarch.** Walk up to the enemy monarch and press F to pick them up. You move slower and cannot attack while carrying. Reach the gold ring around your own throne to score. If the carrier dies, the monarch walks back home; touching your own dropped monarch sends them home instantly.

## The look

Real models and textures, all CC0 (attributions in `assets/CREDITS.md`):

- **Characters** are the KayKit Adventurers models (Knight, Rogue, Hooded Rogue, Mage, Barbarian) with their own animations: idle, run, sword swings, crossbow shots, spellcasting, blocking, dodging, hit reactions and deaths. `scripts/character_model.gd` picks the model and gear per class, applies a team-colour skin (made by `tools/recolor_skins.py` from the pack's palette textures: green and blond for Elves, blue for Humans, white robes for Healers), adds elf ears and the monarchs' crowns, and runs the animation state machine.
- **World**: hand-styled cream ashlar, sandstone flagstone, cobble, plank, bark, grass and sandy road textures with normal maps, generated by `tools/make_textures.py` and applied triplanar so every wall and floor tiles cleanly. Both castles are built from one kit (`_add_wall`, `_add_tower`, `_add_stairs`, `_add_railing`, `_add_banner`, `_add_rug` in `scripts/game.gd`): cream ashlar walls with merlons, square corner towers and a gatehouse with pyramid roofs in the team colour, a timber rampart with a railing, timber stairs along the side walls, a banded double door, flagstone yards, team rugs and banners, and the same timber fence everywhere. Elves add greenery and crystals, Humans braziers and shields. Every prop is placed with clearance from the walls, and `--audit` (`godot --headless -- --audit`) lists any prop that still overlaps a wall, fence, gate or another prop; a river with a shader-animated surface cuts the field in two, crossed by three bridges; cobbled roads with dirt verges run gate to gate. Elven trees are procedural: twisted trunks, roots, layered canopies with a wind-swaying leaf shader, glowing blossoms and autumn variants; the human side mixes in KayKit oaks and pines. Mossy faceted boulders, bushes, fireflies, ruins, and thousands of MultiMesh flowers, grass tufts, stones, mushrooms and fallen leaves (kept off the lanes) fill the ground. The Crown Shrine sits on a stone island in the river with steps from both banks. Characters get a dark outline and rim light so they read against the ground. KayKit Medieval Hexagon and Dungeon props still provide crates, barrels, racks, targets, banners, torches, columns and the class stations' gear, repainted to the same warm palette (`tools/recolor_palette.py`, and the dungeon stone textures tinted to the castle's sandstone).
- **Effects**: every attack and ability has its own projectile model and trail (arrows, spinning arcane orbs, fireballs, holy bolts), burst rings, light flashes, particle splashes, knockback, recoil, camera shake, damage numbers and level-up pillars; all built in `scripts/game.gd` (`spawn_splash`, `spawn_ring`, `spawn_pillar`, `spawn_flash`) and `scripts/projectile.gd`.
- `assets/ui/logo.png` is the game's logo, `assets/ui/cards/` holds the Elves and Humans faction logos, crests and the ten class portraits (used on the title screen, the score tabs, the Tab panel, the player panel and the class menus), and `assets/ui/icons/` holds the painted icon set (every attack and ability, dodge, block, grab, potion, blessings, class emblems and the Forest and Kingdom crests) drawn by `tools/make_icons.py`. `scripts/hud.gd` draws everything else after the UI references: score tabs with the faction crests, the Tab teams panel, class emblems and levels, the minimap, the player panel (portrait with level badge, hearts, energy, a glowing experience bar that pulses when a rank point is waiting, slots for the base attack, Q, E, dodge, block and grab), the objective card, the rank menu, the game menu (overview map, class cards, controls), the title screen and the victory ribbon.
- `tools/showcase.gd` renders every character to a PNG for a quick art check:

```
godot --path . --rendering-driver opengl3 --resolution 1600x700 --script tools/showcase.gd -- --out=showcase.png
```

## Tuning the game

All the numbers are in one file: `scripts/stats.gd`. Hearts per player, damage per hit, stamina and mana costs, every ability's cooldown and cost, ranges, door strength, health potion value and respawn, blessing timings, respawn time, match length, captures to win. Change a number, press F5, and it is live.

## Code layout

- `scripts/stats.gd` every balance number, the class table, the eight promotions and the score weights.
- `scripts/game.gd` builds the map, spawns teams, runs scoring, the timer and the match flow.
- `scripts/unit.gd` is every soldier: classes, combat, player controls and the bot brain.
- `scripts/gate.gd` the breakable castle gate; `scripts/vault.gd` the Crown Vault lock; `scripts/barricade.gd` the breakable fences; `scripts/guide.gd` the Wildwood Guide NPC.
- `scripts/projectile.gd` arrows, spells and bolts.
- `scripts/heal_orb.gd` the health potions on the map.
- `scripts/blessing.gd` the Blessings of Light that spawn in the field.
- `scripts/trap.gd` the Ranger's snare trap.
- `scripts/hud.gd` the on-screen HUD, minimap, chat, scoreboard, perk and pause menus (with control remapping), title and end screens.
- `scripts/character_model.gd` the animated characters and monarchs built from the KayKit models.
- `tools/showcase.gd` renders all characters to a PNG; `tools/recolor_skins.py` makes the team skins; `tools/make_textures.py`, `tools/make_icons.py` and `tools/recolor_palette.py` generate the textures, HUD icons and prop palette.
- `assets/` models, textures, skins, logo and `CREDITS.md`.
- `scripts/monarch.gd` the Elf Queen and Human King.

To watch bots play each other (handy for balance testing), run from a terminal:
`godot --path . -- --demo` (add `--play` instead to jump straight into a match as the Elves).
