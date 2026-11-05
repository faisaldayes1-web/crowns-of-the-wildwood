# Overnight 11-05: playthrough, fps, graveyard (claude-faisal3, task cf-crowns-overnight-1105)

Base: main a29173e. Machine: Core Ultra 7 155H, Intel Arc iGPU, Windows 11, Godot 4.3 Forward+, 1280x720, `--gfx=2`, vsync off, `--demo --seed=7`. Local evidence only (Actions capped, Faisal 11-05).

## 1. Playthrough of every map

I cannot hand-play from this session. What ran instead: one full bot-vs-bot match per map, start to finish with the real renderer (`godot --path . --resolution 1280x720 -- --demo --seed=7 --gfx=2 --map=N --debug-unlock --perf`), plus the clipping and text gates. This is NOT a human single-player run.

| Map | Result | Match time | Mean fps | Min 5 s fps | Script errors |
|---|---|---|---|---|---|
| 0 Wildwood | Humans 2-0 | 261 s | 43.7 | 21 | 0 |
| 1 Moonlit Wildwood | Humans 2-0 | 338 s | 37.6 | 22 | 0 |
| 2 Ember Pass | Elves 2-0 | 294 s | 37.0 | 21 | 0 |
| 3 Stonekeep Fortress | Humans 2-0 | 138 s | 47.9 | 35 | 0 |
| 4 Twilight Grove | Humans 1-0 (time up) | 600 s | 42.7 | 18 | 0 |

(Mean of the `PERF fps=` lines, one per 5 s.) The only `ERROR` lines are the shader-leak messages Godot prints at exit.

* Clipping audit (`--audit`, the CI gate), maps 0-4, with and without `--debug-night`: 0 overlaps, 0 `CLIP`.
* UI text fit (`tools/gates/ui_fit_gate.gd`, 720p/1080p/1440p, menus, HUD, pause, summary, 1-4 players, real renderer, `--gfx=1`): 0 failures in 111 + 72 screens.
* No bug, clipping or text overlap was found, so there is no game-code change.

## 2. 60+ fps: not reached, and not reachable by a hotspot fix on this machine

Slowest three: Ember Pass (37.0), Moonlit Wildwood (37.6), Twilight Grove (42.7). Frame time is 21-27 ms, GPU median about 19 ms, even at 720p. What I measured:

* Geometry is not it. `tools/tri_census.gd` (new): Ember 1.16 M triangles, Moonlit 5.4 M, Twilight 5.4 M (3.5-4.6 M shadow casters, mostly 2,000-triangle kit trees). Hiding every forest-kit MultiMesh on Moonlit did not lower GPU time (probe `forest`: -0.8, -0.9, +3.6 ms; noise), nor did switching their shadows off.
* Pixels are not it: render scale 0.75, SSAO, SSIL, glow, DoF, FXAA and the sun shadow each moved Moonlit GPU time by less than the noise (a calm run: sun shadow off -0.07, -1.3, -1.1 ms).
* Ember lights are the only repeatable signal: `omni_lights` saves 10.8 ms (`gfx_cost_probe`) and `lights` 7.4 ms (`cost_ab`) on Ember, 0-2.8 ms on the other maps. Ember has 197 omni lights (`tools/light_census.gd`, new): 42 red torch lights (range 5.5), 8 lava fills (range 15), 10 shadow-casting chandeliers (range 10).
* Tried and measured, no gain, so not kept: dropping the 8 lava fill lights (stills nearly identical, fps 40.9 / 39.2 with against 41.4 / 38.9 without); dual-paraboloid chandelier shadows (cube 44.0 / 42.6 / 44.6 fps against 44.5 / 45.1 / 43.5).
* Chandelier shadows off on Ember: saves 2.7, 3.5, 5.2 ms; on Wildwood nothing. I did not ship this: it removes the rooms' shadows and I could not show a frame-rate gain in a whole-match A/B.
* The machine's base GPU time drifts 17-36 ms inside one run, so single A/B pairs cannot resolve a 1-3 ms change here. Earlier reports (`claude-faisal3-stonekeep-stalls-1104`) found the same: a 60 fps target needs a faster GPU or a lower preset.

Next step if 60 fps on this class of GPU is a hard requirement: a lower default preset or a per-map light budget for Ember (cull to the nearest N torches), measured on the target hardware.

## 3. Moonlit graveyard

Works as specified, no fix. `tools/graveyard_test.gd` (CI args `-- --demo --seed=7 --map=1 --debug-night`): 0 failures. A full real match on map 1 (`full-map1.log`): `RISE` at t=59, 119, 179, 239, 299 (three zombies each; every 60 s); bell held by the Elves from t=45 gave `owner=0` at the 59 s rise; zombies turned to the Humans when they took the bell (t=130, `owner=1` at the 179 s, 239 s, 299 s rises); `GRAVESTAT zombie_kills=9/6 door_hits=6/9`, i.e. each side's zombies fought for the holder.

## New tools (no game code changed)

* `tools/tri_census.gd`: triangles per owner and the biggest MultiMeshes.
* `tools/light_census.gd`: omni lights grouped by range, energy and shadow.
* `tools/gfx_cost_probe.gd`: new toggles `omni_big`, `omni_small`, `forest`, `forest_shadows`, `lamp_shadows`, and a light count line.

## Not done

* Not a human playthrough. Fresh worktree needed `godot --headless --import` (it crashes the first time, works the second).
* The booking engine:laptop3:godot (T-eb2dbba92f42) is not released by me: no release tool exists in this session. One idle Godot process from my own survey run (PID 10600) is still alive; the sandbox denied me stopping it.
