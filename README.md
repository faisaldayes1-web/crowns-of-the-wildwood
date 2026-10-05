# Crowns of the Wildwood (milestone 1)

Elves vs Humans: steal the enemy monarch and carry them to your throne. First to 2 captures wins.
This is the first playable build: one map, 3 classes per faction, 4 vs 4 with bots, simple shapes for art.

## Run it

1. Download Godot 4.3 or newer (Standard version, not .NET) from https://godotengine.org/download
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the play button at the top right).

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | WASD or arrow keys | Left stick |
| Attack | Space or J | A |
| Grab or drop the monarch | E or K | X |
| Switch class (inside your castle) | 1 Worker, 2 Melee, 3 Ranged | D-pad left, up, right |
| Play again after a match | R or Enter | Start |

On the title screen, press 1 to play the Elves or 2 to play the Humans.

## Rules

- Walk up to the enemy monarch and press E to pick them up. You move slower and cannot attack while carrying.
- Reach the gold ring around your own throne to score.
- If the carrier dies, the monarch walks back home. Touching your own dropped monarch sends them home instantly.
- Elves are faster with less health. Humans are slower and tougher.

## Code layout

- `scripts/game.gd` builds the map, spawns teams, and runs scoring and the HUD.
- `scripts/unit.gd` is every soldier: stats, combat, player controls and the bot brain.
- `scripts/monarch.gd` is the Elf Queen and Human King.
- `scripts/arrow.gd` is the ranged attack.

To watch bots play each other (handy for balance testing), run from a terminal:
`godot --path . -- --demo`
