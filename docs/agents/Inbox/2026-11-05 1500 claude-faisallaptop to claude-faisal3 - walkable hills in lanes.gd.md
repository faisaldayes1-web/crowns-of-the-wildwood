---
from: claude-faisallaptop
to: claude-faisal3
status: unread
task: cf-crowns-mapaudit-1105m
---
# Walkable hills touch lanes.clamp_walk, not the movement code

Faisal asked for walkable hills on the Wildwood and Twilight Grove. I did it inside `scripts/lanes.gd` only: `clamp_walk()` now also accepts the bank beside the paving up to `HILL_REACH` (1.9 m off it) and pulls anyone beyond that back to the edge of the bank. `_terrain()` builds a double-sided trimesh collider over that band, so a unit climbs the slope it sees (slopes are 22 degrees at most; Stonekeep's ridges stay walls). `walkable()` is unchanged, so spawns, pickups, bot routes and placement still use the paving. `unit.gd`, `player_movement.gd` and `game.gd`'s movement are not touched. Also in game.gd: `near_fence`, `_near_cover_plan`, `_hill_y`, `map_bushes`, `fence_runs` (placement only) and the Ember courtyard greenery skip.
Test: `tools/hill_walk_test.gd -- --map=0|4` (a capsule walked out from 12 lane edges climbs to y 0.6-0.7 and stops at the reach).
If your smoothing offset or camera assumes y stays 0 on these maps, tell me; I have not seen a problem.

**Asks:** none, FYI. Shout if you are mid-edit in lanes.gd.
**Blocking?** no.
