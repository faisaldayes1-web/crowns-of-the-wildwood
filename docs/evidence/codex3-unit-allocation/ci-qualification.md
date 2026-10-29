# Unit allocation CI qualification

Agent: Codex-faisal3/crowns-ci-verify. 2026-10-25.

Scope: independent remote engine regression for PR #69, following the owner's WAVE 3 Crowns performance request. No local Godot process, runtime changes, generated assets or merge.

Reuse inspected: repository `AGENTS.md`, `ORY_WORKFLOW.md`, memory and board; README headless bot invocation; `tools/tests/isolated.sh` and `.gd`; existing `tools/unit_allocation_test.gd`; Prince `c2-recovery.yml`; central framework Crowns application and Tools recipe register. Crowns had no `.github` directory. This small workflow reuses the existing guarded throwaway-user runner for every engine process and preserves the pinned Godot 4.3 engine.

The workflow downloads the [official 4.3-stable Linux release](https://github.com/godotengine/godot-builds/releases/tag/4.3-stable), verifies its SHA-512 against both the official manifest and a pinned value, and retains actual stdout/stderr logs on failure. A fresh checkout must have no `.godot` cache before import. Import script errors fail independently of Godot's exit code. The isolated regression must exit successfully and print `UNIT_ALLOCATION_RESULT assertions=<positive integer> failures=0`; the full seed-7 bot match must print `RESULT` and `STAT` records before the frame/time limit. This is native headless coverage; the regression's web-policy simulation is not an exported browser test.

## Actual remote qualification

[PR run 40172468082](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/actions/runs/40172468082) passed at 2026-10-25 07:25:46 UTC. Source head: `bc1404bb9f9103ab50378925b98d61b8ad093d13`; base: `87df44898dd45850654ea73dca2a18eafdc432ca`. Checkout tested GitHub's synthetic merge `7f56c979f612d94900bb384e47cd31ff551124b9`. Its tree `520ebad374c28c182e583969004e6c09129a68b8` exactly equals the source head tree, verified using the GitHub commit API and local `git rev-parse HEAD^{tree}`.

| Check | Observed result |
| --- | --- |
| Workflow static validation | actionlint 1.7.12 with `-shellcheck=` and `git diff --check`: pass; no local engine launched |
| Engine | `4.3.stable.official.77dcf97d8`; official release manifest and pinned SHA-512 match; archive check `OK` |
| Fresh headless import | Pass, 45 seconds; `import.log` 182 bytes; zero script or engine error/warning lines |
| Isolated allocation regression | `UNIT_ALLOCATION_RESULT assertions=969 failures=0`; `unit-allocation.log` 564 bytes; zero error/warning/leak lines |
| Full seeded bot match | Pass, 191 seconds wall time; `RESULT winner=Humans score=0-1 t=600 overtime=false turrets=1/1 turret_kills=2/1 raid_deaths=1/6`; all eight unit `STAT` records; `bot-match.log` 45,286 bytes; zero error/warning/leak lines |

The full logs were downloaded and inspected under `C:/Temp/crowns-ci-40172468082/crowns-unit-allocation-pull_request-40172468082-1/`. A case-insensitive scan across retained logs for `error`, `warning`, `leak`, `orphan`, `failed`, and `fail ` found zero matching diagnostic lines. [Artifact 12590976628](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/actions/runs/40172468082/artifacts/12590976628), name `crowns-unit-allocation-pull_request-40172468082-1`, retains all eight actual log files for 14 days. The redundant same-head push run `40172465933` was cancelled; it is not qualification evidence. This documentation-only follow-up does not change the tested workflow, runtime or regression script and does not rerun the gate.

Qualification remains incomplete until measured before/after local rendered profiling and matching built-game/reference screenshots are recorded. A green code-regression workflow does not mark this PR READY or prove rendering performance.
