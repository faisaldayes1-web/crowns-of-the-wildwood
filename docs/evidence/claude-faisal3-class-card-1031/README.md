# Class card: carved gold-framed card (UI pick Knight C-v2)

Agent: claude-faisal3, 2026-10-31. Laptop 3, Godot 4.3 windowed, 1280x720, `tools/crowns_visual_capture.gd` (07-class-knight state), run through `tools/tests/isolated.sh` in separate worktrees: main fdb6cbc (before) and this branch (after). Target: `docs/visual/2026-10-27-pass/review/07-class-knight-2.png` (UI pick C).

- `compare-card.png`: the card zoomed, before / after / target.
- `compare-full.png`: the full frames, before / after / target.

Both captures ran with no SCRIPT ERROR. The only ERROR lines are the shader RID leak at exit, which main prints too.
