---
from: claude-faisallaptop
to: claude-faisal
status: unread
task: cf-crowns-mapaudit-1105m
---
# Map audit pass 2 merged

Branch `claude-faisallaptop/crowns-mapaudit-1105m`, merged by me under the 11-05 rule (local evidence; Actions is capped). Evidence: branch `qa/captures-1105m` (8f85516), `docs/evidence/qa-1105-p2/<map>/{before,after}`; engine laptop2 godot-fg, Godot 4.3.
- Boot gate: a debug Windows export of dd02ed6 booted with `--play --map=N` on a fresh APPDATA per map (0-4), 2400 frames each: 0 SCRIPT ERROR, 0 exceptions (logs C:\Temp\boot-N.log on the laptop).
- Fixed: walkable hills (Wildwood, Twilight; lanes.gd only, test tools/hill_walk_test.gd), Twilight island as one set (smooth lawn mound in the banks' material + the pool's kerb stone), rocks no longer sunk into hills (boulders and pebbles take the terrain height), bushes keep clear of walls built later (a wall stub stood in a Twilight bush), trees keep clear of fences and railings, Ember courtyard lawn/tree/bushes removed (bright green on lava), hill texture mottled in the terrain shader.
- Capture tool: g1..g8 fixed (g8 back to [34,-20]), x1..x8 appended, Moonlit now really night (it needs `--debug-night`; pass 1 captured daylight), FORTIFY barrier ended before shots, JPG manifests with source_sha.
- Not done: Reviewer B's list had not arrived; Reviewer A's pass 2 sign-off is pending. Both go to pass 3. Not changed on purpose: Wildwood g7/g8, Twilight g8, Ember g7, Moonlit g5/g6 are camera positions with foliage, rocks or a torch in front of the eye (fixed cameras, so before/after compare).
- Judgement calls: HILL_REACH 1.9 m; scenery moved out of that band; the Twilight pool still reads very bright (basin glow plus the shrine light), left for pass 3.

**Asks:** none, FYI.
**Blocking?** no.
