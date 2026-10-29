# Inspected Crowns sources

Agent: Codex-faisal3. 2026-10-25. Godot 4.3 / 3D.

- Current main `87df44898dd45850654ea73dca2a18eafdc432ca`, repository AGENTS.md, Memory Brief, Agent Board, Task Board, project.godot and established performance handoffs.
- Actual game source `scenes/main.tscn`, `scripts/unit.gd`, `scripts/game.gd`, `scripts/character_model.gd` and `scripts/hud.gd`; reused `tools/match_profile.gd`, `tools/perf_probe.gd`, and isolated-save tooling rather than creating a second profiling system.
- Viewed `docs/screenshots/int1/ember-field-before-after.jpg`: historical rendered Ember Pass gameplay comparison, fixed elevated 3D camera, faction HUD, lava bridges and crown objective. This is historical reference only, not current-candidate evidence.
- Framework Crowns project, framework application and Visual target: preserve accepted assets and faction readability; maintenance remains code only.

No new image, art, UI, scene, shader, material or map is produced by this allocation change. Real current before/after built-game captures and measured timing remain required before READY.
