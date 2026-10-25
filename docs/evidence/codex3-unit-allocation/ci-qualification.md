# Unit allocation CI qualification

Agent: Codex-faisal3/crowns-ci-verify. 2026-10-25.

Scope: independent remote engine regression for PR #69, following the owner's WAVE 3 Crowns performance request. No local Godot process, runtime changes, generated assets or merge.

Reuse inspected: repository `AGENTS.md`, `ORY_WORKFLOW.md`, memory and board; README headless bot invocation; `tools/tests/isolated.sh` and `.gd`; existing `tools/unit_allocation_test.gd`; Prince `c2-recovery.yml`; central framework Crowns application and Tools recipe register. Crowns had no `.github` directory. This small workflow reuses the existing guarded throwaway-user runner for every engine process and preserves the pinned Godot 4.3 engine.

The workflow downloads the [official 4.3-stable Linux release](https://github.com/godotengine/godot-builds/releases/tag/4.3-stable), verifies its SHA-512 against both the official manifest and a pinned value, and retains actual stdout/stderr logs on failure. A fresh checkout must have no `.godot` cache before import. Import script errors fail independently of Godot's exit code. The isolated regression must exit successfully and print `UNIT_ALLOCATION_RESULT assertions=<positive integer> failures=0`; the full seed-7 bot match must print `RESULT` and `STAT` records before the frame/time limit. This is native headless coverage; the regression's web-policy simulation is not an exported browser test.

CI execution: pending first pushed workflow run. Record exact candidate, run URL, markers, errors and limitations here after inspecting the actual logs.

Qualification remains incomplete until measured before/after local rendered profiling and matching built-game/reference screenshots are recorded. A green code-regression workflow does not mark this PR READY or prove rendering performance.
