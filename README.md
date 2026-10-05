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
| Attack / heal | Space or J | A |
| Dodge (3 second recharge) | Shift or L | B |
| Grab or drop the monarch | E or K | X |
| Play again after a match | R or Enter | Start |

On the title screen, press 1 (D-pad left) to play the Elves or 2 (D-pad right) to play the Humans.

## Rules

- **Hearts.** Everyone has 4 hearts. Every hit takes one heart. Healers give hearts back.
- **Dodge.** A quick dash in the direction you are moving. Nothing can hit you during it. It recharges in 3 seconds (the ring in the bottom panel shows when it is ready). You cannot dodge while carrying the monarch.
- **Classes.** You spawn as a plain Elf or Human with no gear. Step onto a class station in your castle to transform:
  - **Knight**: sword swings, the best class for breaking gates. Uses stamina.
  - **Ranger**: long-range arrows. Uses stamina.
  - **Mage**: spell orbs that splash everyone near where they land. Uses mana.
  - **Healer**: heals every teammate nearby by one heart; bonks with the staff when nobody needs healing. Uses mana.
  - Step onto a different station to switch. Dying returns you to the plain form.
- **Stamina and mana.** Every attack costs some. Stamina refills fast, mana slowly. Humans refill both faster; Elves move faster.
- **Castles.** Each castle is a walled courtyard with one wooden door. The door only blocks the enemy team, breaks after enough hits (Knights and Mages break it fastest), and rebuilds itself 30 seconds later once no enemy is left inside. Ramps at both ends of the front wall lead up to a walkway: from up there Rangers and Mages shoot down at anyone outside, and arrows from the ground cannot reach them. Mage splash still can.
- **Cover.** Barricades, boulders and trees in the middle stop arrows and spells. Duck behind them.
- **Monarch.** Walk up to the enemy monarch and press E to pick them up. You move slower and cannot attack while carrying. Reach the gold ring around your own throne to score. If the carrier dies, the monarch walks back home; touching your own dropped monarch sends them home instantly.

## Tuning the game

All the numbers are in one file: `scripts/stats.gd`. Hearts per player, damage per hit, stamina and mana costs, cooldowns, ranges, gate strength, respawn time, match length, captures to win. Change a number, press F5, and it is live.

## Code layout

- `scripts/stats.gd` every balance number and the class table.
- `scripts/game.gd` builds the map, spawns teams, runs scoring, the timer and the match flow.
- `scripts/unit.gd` is every soldier: classes, combat, player controls and the bot brain.
- `scripts/gate.gd` the breakable castle gate.
- `scripts/projectile.gd` arrows and spells.
- `scripts/hud.gd` the on-screen HUD: score, timer, team rosters, hearts and stamina or mana.
- `scripts/monarch.gd` the Elf Queen and Human King.

To watch bots play each other (handy for balance testing), run from a terminal:
`godot --path . -- --demo`
