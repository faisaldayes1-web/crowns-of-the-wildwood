# Crowns HUD inspection

Agent: Codex-faisal. Source: main 3585cc8, 2026-10-31.

- Viewed `C:/Games/ORY-Candidates/Crowns/maps-1031/after-rebased/stonekeep_tarn.png`: real overhead-oblique Stonekeep battle; left chat rows cross the stock counter and full-cargo warning. Right kill feed also repeats the left kill messages.
- Read `scripts/hud.gd`, `scripts/economy.gd`, `scenes/main.tscn`, project settings, README, visual style spec and October 25 picks. Preserve selected HUD art, real camera and economy.
- Read `store-kit/screenshots-1031/SOURCES.md`: BLOCKED/nameplate overlap is a separate world feedback issue.
- Read `visual-pass/BRIEF-1031-reference.md`: later pass 5 uses the existing selected target, with collision unchanged.

This pass repairs occupied HUD space; it does not generate a new design or asset. No paid tools or credits.

## November 1 follow-up — Codex-faisal

- Viewed the actual main Stonekeep capture above and the approved `GAME-04-match-spawn-D-v2.png`.
- Viewed fresh native Forward+ 1280x720 spawn captures with full cargo, busy chat and typing chat. The first idle capture expired during slow rendering and is not acceptance evidence; the fixture now refreshes staged event timestamps each frame.
- Viewed `before-final/busy-chat.png`: original HUD demonstrably draws chat across the minimap, defense badge, stock and full-cargo warning. The staged five-row kill feed starts immediately beneath the top bar.
- Read the actual block path in `unit.gd`: shield sparks, hit animation, sound, hitstop, stamina cost and knockback already communicate blocking. Remove only the stray word at the nameplate; retain combat behavior.
- Camera, geometry, art assets and map topology are unchanged. These are functional overlap fixes to the selected HUD, not new design options or map generation.
- Viewed final candidate `after-final/busy-chat.png` and `after-final/typing-chat.png`: readable stock/full-cargo with clear space above chat; the five-row kill feed sits below the scoreboard. Compared directly against `before-final/busy-chat.png`.
