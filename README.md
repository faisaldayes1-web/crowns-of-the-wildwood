# Crowns of the Wildwood (work in progress)

Elves vs Humans: steal the enemy monarch and carry them to your throne. First to 2 captures wins, or the higher score when the 10 minute clock runs out.
Everything is still simple shapes; the rules and feel come first, art comes later.

## Run it

1. Download Godot 4.3 or newer (Standard version, not .NET) from https://godotengine.org/download
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the play button at the top right).

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | WASD or arrow keys | Left stick |
| Aim | Mouse | Right stick |
| Attack / heal | Left click, Space or J | A or right trigger |
| Ability 1 / Ability 2 | Q / E | X / Y |
| Dodge (3 second recharge) | Shift, L or right click | B |
| Grab or drop the monarch | F or K | Right bumper |
| Play again after a match | R or Enter | Start |

On the title screen, press 1 (D-pad left) to play the Elves or 2 (D-pad right) to play the Humans.

## Rules

- **Hearts.** Everyone has 4 hearts. Every hit takes one heart. Healers give hearts back.
- **Dodge.** A quick dash in the direction you are moving. Nothing can hit you during it. It recharges in 3 seconds (the ring in the bottom panel shows when it is ready). You cannot dodge while carrying the monarch.
- **Aiming.** You aim with the mouse (or the right stick) and walk with WASD, so you never have to line up by walking. The yellow pointer at your feet shows your aim; the ring shows where the cursor is.
- **Healing orbs.** Glowing green orbs sit at fixed spots: the middle of the road, both flanks of the field, and one in each castle yard. Walk over one when hurt to get 2 hearts back. It returns 25 seconds later.
- **Classes and movesets.** You spawn as a plain Elf or Human with no gear. Step onto a class station in your castle to transform. Every class has a basic attack (left click) and two abilities on Q and E with cooldowns:
  - **Knight** (stamina): sword swings, the best at breaking doors. **Q Shield Bash** (6 s): dash forward, hitting and shoving everyone in the way. **E Shield Wall** (10 s): block all damage for 2 seconds, at half speed.
  - **Ranger** (stamina): long-range arrows. **Q Volley** (6 s): five arrows in a fan. **E Snare Trap** (10 s): drop a trap; the first enemy to step on it takes a hit and is rooted for 2 seconds.
  - **Mage** (mana): spell orbs that splash everyone near where they land. **Q Fireball** (8 s): a slow, big orb that does 2 hearts in a wide splash and wrecks doors. **E Blink** (7 s): teleport 6 units in the aim direction.
  - **Healer** (mana): heals every teammate nearby by one heart; bonks with the staff when nobody needs healing. **Q Blessing** (12 s): heal everyone nearby by 2 hearts and speed them up for 4 seconds. **E Smite** (4 s): a fast holy bolt, 1 heart.
  - Step onto a different station to switch. Dying returns you to the plain form.
- **Stamina and mana.** Every attack costs some. Stamina refills fast, mana slowly. Humans refill both faster; Elves move faster.
- **Castles.** Each castle is an outer castle wall ringing a yard, with the keep (the building holding the throne and class stations) standing inside at the back. The wall's one wooden door only blocks the enemy team, breaks after enough hits (Knights and Mages break it fastest; a Fireball is worth four hits), and rebuilds itself 30 seconds later once no enemy is left inside. Ramps in the yard at both ends of the front wall lead up to the ramparts: from up there Rangers and Mages shoot down at anyone outside, and arrows from the ground cannot reach them. Mage splash still can. The keep has an open archway facing the door.
- **Cover.** Barricades, boulders and trees in the middle stop arrows and spells. Duck behind them.
- **Monarch.** Walk up to the enemy monarch and press F to pick them up. You move slower and cannot attack while carrying. Reach the gold ring around your own throne to score. If the carrier dies, the monarch walks back home; touching your own dropped monarch sends them home instantly.

## The look

Everything is still built from primitive shapes in code, so there are no art files to manage yet:

- `scripts/character_builder.gd` builds the chibi characters: big heads, class gear (helmet, sword and shield; hood, bow and quiver; wizard hat and crystal staff; veil and healing staff), faction looks (elves have pointed ears and blond hair, humans brown hair and a plume) and the two monarchs. They walk, swing and bob.
- `scripts/hud.gd` draws the whole interface after the UI mockup: logo, hexagonal score tabs, roster cards with portraits, the player panel with portrait, hearts, energy and four ability slots with key caps and cooldown sweeps, the objective card, the title screen with faction cards, and the victory ribbon.
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
- `scripts/hud.gd` the on-screen HUD, title and end screens.
- `scripts/character_builder.gd` the character and monarch models.
- `tools/showcase.gd` renders all characters to a PNG.
- `scripts/monarch.gd` the Elf Queen and Human King.

To watch bots play each other (handy for balance testing), run from a terminal:
`godot --path . -- --demo`
