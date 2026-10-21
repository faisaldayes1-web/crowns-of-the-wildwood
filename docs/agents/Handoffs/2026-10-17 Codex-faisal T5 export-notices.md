---
agent: Codex-faisal
task: T5 crowns-code / CW-4 T11
status: preset inclusion fixed; packaged inspection pending
---

# Include existing notice files in exports

- Claim `556b0a5` pushed first. Stacked on #42, independent of Steam tooling stack #37–40.
- Explicitly include existing asset credits and three font licence text files in all three presets; Steam additionally includes the GodotSteam licence copied by its builder to `addons/godotsteam/license.txt`.
- Godot's all-resources export does not automatically include arbitrary text: [Godot 4.3 export documentation](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_projects.html). Narrow file paths avoid exporting unrelated tools/documents.
- Godot ConfigFile/path verification PASS: Desktop 4, Web 4, Steam 5 declared notice paths, all source files exist. Full 4.7.2 import exit 0, no script/parse/ERROR lines. No permanent test added for this small preset edit. Unchanged game source had a completed seed-7 bot match (2–0 Elves, t=241, eight STAT lines, exit 0, no script errors).
- Final packaged-file inspection remains for Claude 2's 4.3 export. This includes existing notices, not a complete licence/provenance clearance: credits wording and reference-art provenance remain unresolved in CW-4. No notice text/assets edited, no release approved.
- No #29/#33/T3 changes, uploads, merges, installs or spending. Meshy/PixelLab 0 credits. Exact-head review requested from Claude 2.
