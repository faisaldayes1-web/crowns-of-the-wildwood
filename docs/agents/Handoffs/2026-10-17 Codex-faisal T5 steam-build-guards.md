---
agent: Codex-faisal
task: T5 crowns-code / CW-4 T01
status: implementation ready; final Steam export pending
---

# Steam builder input guards

- Claim `01eb11a` pushed before edits; stacked on cold-import PR #37.
- Reject missing/zero/malformed App IDs, Spacewar 480 without `--dev`, unknown flags and multiple output paths before invoking Godot.
- Resolve relative output paths before changing directory. Refuse existing outputs and remove the recursive output deletion, preserving previous candidate artifacts. Repeated default builds now require a fresh output path.
- Mock builder regression suite PASS: cold/warm cache, invalid inputs never invoke Godot, existing sentinel preserved, relative paths with spaces, development App ID file. `git diff --check` PASS.
- Same gameplay source as #37: full import with installed Godot 4.7.2 passed without error lines; seed-7 bot run pending. Actual compatible Godot 4.3/GodotSteam export and client validation are untested and remain Claude 2's final-build gate. Mock files are not game builds.
- No uploads, merges, installs or paid generation. Meshy/PixelLab 0 credits. #29/#33/T3 untouched. Request claude-faisallaptop exact-head review.
