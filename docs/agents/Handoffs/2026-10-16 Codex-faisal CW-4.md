---
agent: Codex-faisal
task: CW-4
status: PROPOSED — ready for documentation review
branch: Codex-faisal/cw4-release-plan
date: 2026-10-16
---
# CW-4 handoff

Agent: Codex-faisal.

- Added `docs/agents/CW-4 Release Plan.md`: Steam/itch/web gates, reproducible build records, pending acceptance matrix, proposed copy/screenshots, credits audit gaps and rating steps. Updated only Codex-faisal's own bottom Agent Board row.
- Verified PR #31 merged at `ce6abfcab3fe15a3682e956479983797c93c459a`; CW-2 test results remain attributed to claude-faisallaptop, not independently passed here. Read source via Git because checkout is sparse (`AGENTS.md`, `docs`). Read Memory Brief, inbox, boards, framework workflow and framework #30 comment 6222192392. Existing claim `dfc4793` was already pushed; branch pull was up to date.
- Validation: attempted required import with existing Godot 4.7.2 (`--headless --path . --import --editor --quit`), which reported missing splash/autoloads/main scene despite exit 0. Attempted README bot command (`--headless --path . --fixed-fps 60 --quit-after 45000 -- --demo --seed=7`); no match started because those sparse-excluded resources were missing. These are BLOCKED validation, not game regression findings or passing tests. No checkout expansion or installation. Import created only ignored local cache/import metadata; no tracked game changes.
- Not tested: complete-game import, gameplay, exports, online/new maps, web/iPad, physical gamepads, cold cache, Steam integration or release packaging. Local 4.7.2 is not CW-2's reported 4.3 runtime. No candidate or release approval exists.
- Documentation checks: review changed-path scope, own-row-only board diff, local references and `git diff --check` before commit. Any CI state is reported on the PR separately.
- Next: Faisal assigns qualification/audit owners and decides platform/online scope, engine/performance targets, art provenance, Steam readiness, map unlocks and #4 castle work. Decisions are in the plan; other agents' boards, Needs Faisal and inbox were not edited under the narrower CW-4 scope.
- Spend: Meshy 0, PixelLab 0; no other paid generation, installs, game/code/assets/dependency edits, merges, deletes, uploads or publication. Sibling `crowns-cw1` was not edited. Standing instruction: NEVER MERGE.
