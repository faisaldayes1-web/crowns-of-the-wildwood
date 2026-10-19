# Crowns PM: first-entry menu stall

Agent: Codex-faisal

Owner request: fix menu lag first, check claims, preserve loading fixes, provide timings and video.
Current main Agent Board marked prior menu warm-up work complete; repository discussions were empty. This isolated branch starts at PR62 `5a5387b`, including PR61. Claim `a21b347` was pushed before implementation. No other checkout or agent row changed.

## Change

`scripts/game.gd::_warm_up_menus` now includes Ready Up, waits for drawing, and holds the loading fade during warm-up. Lobby selections/readiness are saved and restored. Previously the first Ready Up click built the fighters and pedestals on demand. This moves that work into startup; it does not reduce total asset construction time. Network and headless-mesh repair sources remain identical to PR62.

## Measured rendered runs

Godot 4.7.2, Windows, RTX 4090, Forward+, same project/settings and separate throwaway saves. Three navigation cycles per run. Measurements span the action dispatch to the next `frame_post_draw`; they are not physical mouse-to-display latency. Before then after runs share driver caches, so the comparison is not a controlled cold-cache benchmark.

| Action | Before first visit (ms) | After first visit (ms) |
|---|---:|---:|
| Ready Up | 1891.504 | 26.431 |
| Play / map screen | 26.619 | 26.125 |
| Customize | 46.065 | 45.514 |
| Store | 57.667 | 47.282 |

Ready Up repeat visits: before 31.665 / 29.102 ms; after 26.490 / 26.407 ms. Its handler itself was only 0.146 / 0.139 ms. The large first-entry stall is removed in these runs; smaller character/store transition costs remain. No zero-lag or map-loading improvement claim.

A subsequent baseline rerun with warmed driver caches still measured 1523.936 ms on first Ready Up entry. This supports the first-use construction diagnosis; it is not an estimate of all hardware performance.

## Acceptance

1. Rendered navigation: completed all 42 actions before and after; no script errors in the corrected rendered run.
2. Menu-flow regression: zero failures, including split-screen readiness and match start. Existing Control size warnings and exit resource warnings remain. Headless bot match completed: Humans 2–0 at simulation t=159, no logged errors.
3. Visual capture: separate fixed-30-fps Movie Maker navigation using the HUD hit-test/cursor path, all 14 navigation actions completed. AVI contains 326 decodable JPEG frames (10.87 s); Ready Up still visually inspected. Recorder exited 1 after navigation, so graceful shutdown is not claimed. Fixed-rate video is a demonstration, not timing evidence. Final headless editor import exited 0 without logged errors after rerunning outside the sandbox save restriction.

Local CSV and video are in this PM chat's outputs directory. No merge, build publication, dependency changes or paid generation. Meshy/PixelLab spend: 0.
