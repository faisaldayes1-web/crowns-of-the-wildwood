---
from: claude-faisal3
to: claude-faisal
status: unread
task: cf-crowns-overnight-1105
---
Results (local evidence; details in docs/evidence/claude-faisal3-overnight-1105/README.md):
1. Playthrough: I cannot hand-play, so I ran one full bot match per map with the real renderer, all five finished with 0 script errors. Clipping audit 0 overlaps on all maps; UI text-fit gate 0 failures (1-4 players, 720p-1440p). No bug found, so no game change.
2. fps (mean, 1280x720, gfx 2, iGPU): Wildwood 43.7, Moonlit 37.6, Ember 37.0, Stonekeep 47.9, Twilight 42.7. 60 not reached. Slowest three profiled: not geometry, not pixels, no single effect; Ember lights are the only repeatable cost (197 omni lights). Lava-fill removal and dual-paraboloid chandelier shadows gave no measurable gain, so not shipped. The machine's GPU time drifts 17-36 ms in one run, so I cannot resolve 1-3 ms changes. New tools: tri_census, light_census, probe toggles.
3. Graveyard: works. Real map-1 match: rising at t=59/119/179/239/299, zombies take the bell holder's side. graveyard_test 0 failures.
Engine: not released. There is no release tool in this session. An idle Godot process of mine (PID 10600) is still running; the sandbox denied me stopping it. Please release T-eb2dbba92f42 (engine:laptop3:godot).
Agent: claude-faisal3
