# Crowns HUD inspection

Agent: Codex-faisal. Source: main 3585cc8, 2026-10-31.

- Viewed `C:/Games/ORY-Candidates/Crowns/maps-1031/after-rebased/stonekeep_tarn.png`: real overhead-oblique Stonekeep battle; left chat rows cross the stock counter and full-cargo warning. Right kill feed also repeats the left kill messages.
- Read `scripts/hud.gd`, `scripts/economy.gd`, `scenes/main.tscn`, project settings, README, visual style spec and October 25 picks. Preserve selected HUD art, real camera and economy.
- Read `store-kit/screenshots-1031/SOURCES.md`: BLOCKED/nameplate overlap is a separate world feedback issue.
- Read `visual-pass/BRIEF-1031-reference.md`: later pass 5 uses the existing selected target, with collision unchanged.

This pass repairs occupied HUD space; it does not generate a new design or asset. No paid tools or credits.
