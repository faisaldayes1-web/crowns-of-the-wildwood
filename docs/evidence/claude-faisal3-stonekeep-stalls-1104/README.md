# Stonekeep stall breakdown (claude-faisal3, 2026-11-04)

Task `cf-crowns-steam-1104n` item 1. Base: main dcebd5c (after the GPU-particle, pool, warm-up and shadow PRs #176-#191).
Machine: Core Ultra 7 155H, Intel Arc iGPU, Windows 11, Godot 4.3 Forward+, Medium-High preset (`--gfx=2`), `--demo --seed=7`, vsync off, nothing else heavy running.

## What I could and could not establish

**The 1% low >= 45 target cannot be checked on this machine.** Even at 960x540 the iGPU runs ~14-18 ms GPU time per frame (1% low 22-33 fps on *both* maps), so a "good PC" number needs a good PC. The 71-79 frames over 16.7 ms quoted in the task did not come from this box, and over 16.7 ms is nearly every frame here (2,222 of 2,251 at 1080p), so that count cannot discriminate.

**Stonekeep has more GPU-side stalls than Wildwood here, but I did not isolate the cause.** In all three paired 90 s runs at 960x540 Stonekeep is worse (frames over 25 ms, 1% low): 629 / 22.1 fps against 193 / 31.4; 400 / 27.8 against 143 / 32.5; 673 / 22.7 against 144 / 34.8. The excess is GPU-side (338 vs 87 frames in the second pair). Stonekeep is also noisy: five further 60 s Stonekeep runs gave 59, 123, 128, 131 and 251 frames over 25 ms (`ab-*`, `--prof-secs=60`, so not directly comparable with the 90 s counts). Ruled out by whole-run A/B (below): snowfall, snow ground textures, sun elevation. No game change is made.

What the data does show:

| 960x540, 90 s | frames > 25 ms | CPU-side (frame > GPU + 8 ms) | GPU-side | 1% low |
|---|---|---|---|---|
| Stonekeep (map 3) | 400 | 62 | 338 | 27.8 fps |
| Wildwood (map 0) | 143 | 56 | 87 | 32.5 fps |

* **CPU-side stalls are the same on both maps (~60 per 90 s, mean ~30 ms) and are runtime node creation**: in those frames, per map, MeshInstance3D x1219-1749, GPUParticles3D x330-367, BoneAttachment3D x177-237, Label3D x53-66, OmniLight3D x52-57, PhysicalBoneSimulator3D x25-28. That is hit effects, projectiles, tags and ragdolls being built mid-fight. It belongs to the spawn/pool work claude-faisal already has open (`crowns-spawn`), so I did not touch it.
* **GPU-side time is view-dependent plateaus, not random hitches**: GPU time sits at one value (e.g. 23.7 ms, then 17.2, then 32.1) for 0.1-1 s while the camera looks at one area. Stonekeep near the player castle (camera x -60..-100) is 17-24 ms against Wildwood's 14 ms there; at map centre it is 12 ms.
* **Not the cause (measured):** the 1,600-particle snowfall (two 60 s runs each: snow on median GPU 13.9 and 14.7 ms, 1% low 27.3 and 30.9; snow off 14.9 and 14.9 ms, 1% low 31.4 and 28.2); the snow ground textures (swap off: 123 frames over 25 ms against 128 and 251 for the baseline); sun elevation -34 vs -46 degrees (131 and 59 frames over 25 ms against 128 and 251 for the baseline). Total static triangles are *lower* on Stonekeep (4.6 M vs 5.4 M), though primitives in view near the castle are higher (12.7-19 M vs 9.5 M, including shadow passes).
* From `gfx_cost_probe` on Stonekeep (noisy, base-to-base drift up to 7 ms): sun shadow ~8.6 ms, SSAO ~5 ms, SSIL ~2.7 ms, DoF ~3 ms, omni lights ~1.9 ms, glow ~1.6 ms, ink ~1.6 ms. SSAO/SSIL/ink/DoF are already High-only since #190.

## What this PR changes

Only `tools/match_profile.gd`: it now prints a `PROF stalls` line (approximate: the GPU time is the last finished frame's) that splits frames over 25 ms into CPU-side and GPU-side and lists what was created in the CPU-side ones, so the next run on a faster PC shows the cause directly:

`godot --path . --resolution 1920x1080 --script tools/match_profile.gd -- --demo --seed=7 --gfx=2 --map=3 --prof-secs=90`

## Needed to finish item 1

Run that command on the target PC for `--map=3` and `--map=0` (three runs each, to see the noise) and send the `PROF frames`, `PROF gpu` and `PROF stalls` lines. If GPU-side stalls dominate on Stonekeep there, the next candidate is the sun shadow (largest single cost) with per-map cascade distance.
