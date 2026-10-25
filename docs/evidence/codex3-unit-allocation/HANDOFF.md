# Crowns unit allocation maintenance

Agent: Codex-faisal3. Owner request: WAVE 3 chat, 2026-10-25. Engine/dimension: Godot 4.3 / 3D. Implementation owner: Codex-faisal3; independent regression owner: helper `prince_ci`.

Runtime source: `2fe1479`, based on main `87df448`. Branch `agent/Codex-faisal3/crowns-performance-20261025`. Board claim was pushed as `670d24c` before source edits.

`attack_stats()` already starts with a private shallow dictionary copy. Ranged cooldown and active Might damage now edit that private copy directly, eliminating two redundant copies in the combined case without changing combat values or nested-resource sharing. The initial copy and ranked-stat behavior remain intact.

Native bot ticks no longer duplicate and strip a plan that is only consumed by the web-only alternate-tick branch. Web retains its original copy, removal of the one-off ability, repeat and cache clear behavior. No AI decisions, timing, input, rendering or balance settings change.

## Verification and limits

- `git diff --check`: clean for runtime patch.
- Independent focused regression is being prepared against actual `unit.gd`; its result must be recorded before acceptance.
- No local Godot command has run for this candidate. Current shared queue has no Codex3 task/slot for Prince or Crowns. Its CLI restricts admission/reservation to the coordinator. Local isolated-check authorization was requested from Faisal; report `1792912521-599bd3` also gives the hub concrete scope and the completed Rampart/Idle results under the owner reporting rule.
- This is an allocation-count reduction visible in source, not a measured FPS or frame-time improvement. Import, full bot match, browser export, native before/after profiles and built-game screenshot comparison are pending. Keep any PR DRAFT.
- Existing issue #68 Skeleton3D disconnect errors and #60 ENet reliability are separate scopes; neither is claimed fixed.

## Prepared qualification

Use a unique worktree and marked disposable save root under `C:/Temp/`, with APPDATA and CROWNS_TEST_USER_BASE pointed there. Preserve the real save. Reserve the applicable engine job or obtain explicit owner authorization; serialize native rendered runs across the laptop and record concurrent process/load conditions.

Run headless import, `tools/unit_allocation_test.gd` and the existing seed7 full bot match; use the same Godot 4.3 executable for baseline and candidate. Profile baseline `87df448` and runtime `2fe1479` with existing `tools/match_profile.gd`, identical seed/map/gfx/resolution/warmup/duration, native solo and two-player split. Capture actual baseline and candidate frames beside the existing game reference; report any Skeleton3D errors and leaks accurately. Only claim a frame-time gain if the repeated measured evidence supports it. Hub review precedes merge.
