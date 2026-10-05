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
| Rank menu (spend experience) | Tab, then 1-4 | Back, then D-pad |
| Game menu (map, classes, controls; pauses) | Esc, arrows switch tabs | Start, bumpers switch tabs |
| Play again after a match | R or Enter | Start |

On the title screen, press 1 (D-pad left) to play the Elves or 2 (D-pad right) to play the Humans.

## Rules

- **Hearts.** Everyone has 4 hearts. Every hit takes one heart. Healers give hearts back.
- **Dodge.** Space: a quick dash in the direction you are moving. Nothing can hit you during it. It recharges in 2 seconds and costs a little stamina or mana. You cannot dodge while carrying the monarch.
- **Block.** Shield classes (the Knight) hold right click to raise the shield: hits from the front do nothing, but each blocked hit costs 18 stamina, holding it drains stamina, you walk at half speed and cannot attack. Run out of stamina and the shield drops.
- **Hits have weight.** Every hit shoves the target (fireballs shove hardest), attackers lunge or recoil, the camera kicks when you are hit or something explodes nearby, and sparks, splinters and damage numbers show what happened.
- **Walls.** Ramps in your yard lead up to the walkway on the front wall. Walk off the front edge to drop straight down into the field.
- **Aiming.** You aim with the mouse (or the right stick) and walk with WASD, so you never have to line up by walking. The yellow pointer at your feet shows your aim; the ring shows where the cursor is.
- **Healing orbs.** Glowing green orbs sit at fixed spots: the middle of the road, both flanks of the field, and one in each castle yard. Walk over one when hurt to get 2 hearts back. It returns 25 seconds later.
- **Classes and movesets.** You spawn as a plain Elf or Human with no gear. Step onto a class station in your castle to transform. Every class has a base ability on left click (cheap, short cooldown) and two bigger abilities on Q and E that cost a lot more stamina or mana:
  - **Knight** (stamina): **Sword Strike**, the best at breaking doors; **Block** on right click. **Q Shield Bash** (4 s, 35): dash forward, hitting and shoving everyone in the way. **E Shield Wall** (8 s, 30): nothing gets through for 2 seconds, from any side.
  - **Ranger** (stamina): **Quick Shot**, a fast arrow. **Q Volley** (4 s, 45): five arrows in a fan. **E Snare Trap** (7 s, 35): drop a trap; the first enemy to step on it takes a hit and is rooted for 2 seconds.
  - **Mage** (mana): **Arcane Bolt**, a fast bolt with a small splash. **Q Fireball** (5 s, 50): a big ball of fire, 2 hearts in a wide splash, four hits to a door. **E Blink** (5 s, 30): teleport 6 units in the aim direction.
  - **Healer** (mana): **Mend** heals every hurt teammate around you, yourself included; with nobody to heal, the same click fires a holy bolt instead. **Q Blessing** (9 s, 60): heal everyone nearby by 2 hearts and speed them up for 4 seconds. **E Smite** (3 s, 30): a fast holy bolt.
  - Step onto a different station to switch. Dying returns you to the plain form.
- **Stamina and mana.** Every attack costs some, and both refill slowly (11 stamina or 7 mana a second), so the Q and E abilities are a budget, not a rotation. Humans refill faster; Elves move faster.
- **Experience, per life.** Hitting (10 a heart), killing (30), healing a teammate (8 a heart), hitting the door, grabbing the monarch (25) and capturing (100) earn experience. Levels come at 40, 100, 180, 280 and 400 and each gives one rank point. Press Tab for the rank menu: three ranks each in your base attack, Q, E and Vigor. Rank 1 cuts the cooldown 15% and the cost 12%, rank 2 widens the effect (range, radius, duration, two more arrows), rank 3 adds a heart of damage or healing; each Vigor rank is +7% speed, +15 max energy, +20% regen. Dying wipes it all, so staying alive is how you get strong. Bots rank up too.
- **Castles.** Each castle is an outer castle wall ringing a yard, with the keep (the building holding the throne and class stations) standing inside at the back. The wall's one wooden door only blocks the enemy team, breaks after enough hits (Knights and Mages break it fastest; a Fireball is worth four hits), and rebuilds itself 30 seconds later once no enemy is left inside. Ramps in the yard at both ends of the front wall lead up to the ramparts: from up there Rangers and Mages shoot down at anyone outside, and arrows from the ground cannot reach them. Mage splash still can. The keep has an open archway facing the door.
- **Cover.** Barricades, boulders and trees in the middle stop arrows and spells. Duck behind them.
- **Monarch.** Walk up to the enemy monarch and press F to pick them up. You move slower and cannot attack while carrying. Reach the gold ring around your own throne to score. If the carrier dies, the monarch walks back home; touching your own dropped monarch sends them home instantly.

## The look

Real models and textures, all CC0 (attributions in `assets/CREDITS.md`):

- **Characters** are the KayKit Adventurers models (Knight, Rogue, Hooded Rogue, Mage, Barbarian) with their own animations: idle, run, sword swings, crossbow shots, spellcasting, blocking, dodging, hit reactions and deaths. `scripts/character_model.gd` picks the model and gear per class, applies a team-colour skin (made by `tools/recolor_skins.py` from the pack's palette textures: green and blond for Elves, blue for Humans, white robes for Healers), adds elf ears and the monarchs' crowns, and runs the animation state machine.
- **World**: ambientCG grass, stone and wood PBR textures (triplanar, so every wall and floor tiles cleanly), a procedural sky, and KayKit Medieval Hexagon and Dungeon props for trees, rocks, crates, barrels, tents, banners, torches, pillars and the class stations' gear.
- `assets/ui/logo.png` is the game's logo. `scripts/hud.gd` draws everything else after the UI references: score tabs with the realm names, team rosters with portraits and levels, the minimap, the player panel (portrait with level badge, hearts, energy, experience bar, slots for the base attack, Q, E, dodge, block and grab), the objective card, the rank menu, the game menu (overview map, class cards, controls), the title screen and the victory ribbon.
- `tools/showcase.gd` renders every character to a PNG for a quick art check:

```
godot --path . --rendering-driver opengl3 --resolution 1600x700 --script tools/showcase.gd -- --out=showcase.png
```

## Tuning the game

All the numbers are in one file: `scripts/stats.gd`. Hearts per player, damage per hit, stamina and mana costs, every ability's cooldown and cost, ranges, door strength, healing orb value and respawn, respawn time, match length, captures to win. Change a number, press F5, and it is live.

## Code layout

- `scripts/stats.gd` every balance number and the class table.
- `scripts/game.gd` builds the map, spawns teams, runs scoring, the timer and the match flow.
- `scripts/unit.gd` is every soldier: classes, combat, player controls and the bot brain.
- `scripts/gate.gd` the breakable castle gate.
- `scripts/projectile.gd` arrows, spells and bolts.
- `scripts/heal_orb.gd` the healing orbs on the map.
- `scripts/trap.gd` the Ranger's snare trap.
- `scripts/hud.gd` the on-screen HUD, minimap, rank and game menus, title and end screens.
- `scripts/character_model.gd` the animated characters and monarchs built from the KayKit models.
- `tools/showcase.gd` renders all characters to a PNG; `tools/recolor_skins.py` makes the team skins.
- `assets/` models, textures, skins, logo and `CREDITS.md`.
- `scripts/monarch.gd` the Elf Queen and Human King.

To watch bots play each other (handy for balance testing), run from a terminal:
`godot --path . -- --demo` (add `--play` instead to jump straight into a match as the Elves).
