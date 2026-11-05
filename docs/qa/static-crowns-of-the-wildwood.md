Codex-faisal2 · cf-qa-static-1105g: static/headless QA — crowns-of-the-wildwood

Date: 2026-11-05. Owner: claude-faisal3.
Fresh remote `main` clone tested at **`a93e5b47d2f093554c8f28548e2011598fdb53eb`**. QA branch: `qa/cf-qa-static-1105g`.
Engine: Godot `4.3.stable.official.77dcf97d8`, Windows, headless/Dummy audio. Crowns is 3D; Chief mixes 2D UI and 3D scenes; Prince is 2D HD pixel art.

Authority: current user task, “Analysis only; no game-code edits.” Coordinator mail `1793902635-e5af84` says to retain existing card `T-e2e8657e7019` and record own task log/milestones because a second card cannot be assigned. Static dispatch binding requested in mail `1793906917-78ebf2`; no queue state is fabricated. Scratch headless exemption is from the current user request.

## Verified results

| Check | Result |
|---|---|
| Completed headless resource import | Exit 0; raw warnings/errors retained and distinguished from subsequent boot |
| Post-import `--headless --quit` with isolated profile | Exit 0, 0 raw script/engine errors |
| Explicit standalone `--check-only --script` | 171 files; 3 diagnostic failures before context classification |
| Contextual deferred script loading | 171 files; 3 failures, classified below |
| Original gameplay/script/scene/asset bytes | Unchanged; 0 substantive input changes |
| Scratch `.import` metadata churn | 0 tracked metadata files changed by import; retained locally, excluded from commits |

Raw receipts, exact argv/profile paths, per-script results, source hashes and rejected attempts: [evidence/cf-qa-static-1105g](evidence/cf-qa-static-1105g/README.md). See `verification-summary.json`, `qualified-quit.log`, `contextual-parse.log`, `qualified-script-checks.json`, and `SHA256.json`.

Cold-clone failures (missing imported fonts/textures/classes) are not labeled missing shipped assets. `--editor --quit` was insufficient to finish scanning; the later explicit `--import` completed. Standalone script checks in Chief/Prince can fail on autoload identifiers before those singletons initialize; contextual loading resolves that distinction. An exit code alone is never treated as proof of a clean boot.

## Findings

### CW-01 — P0 release blocker reported by coordinator; bare self `free()` confirmed in source

- Location: `scripts/projectile.gd:169`, `_park()` fallback when `game` is invalid.
- Source has exactly one executable bare/self `free()` call. The editor binary's check-only and contextual loads accept this script; local source boot also succeeds. These checks **do not independently reproduce or clear the export failure**.
- Coordinator `claude-faisal`, ORY mail `1793903290-2046be`, 2026-11-05 18:28:10 UTC: fresh-profile export gate caught main `a93e5b4` (`projectile.gd free()`), and current export remains the older 0649 build until fixed. Earlier mail `1793902973-15a2b8` assigns the fix to claude-faisal3.
- Action for owner: supply the fixed export with source SHA, then rerun fresh-profile boot and the `--smoke-match` hook if present. No replacement of this call is made by this QA task.

### CW-02 — Low, historical fixture is not portable

- Location: `docs/evidence/issue68-followup-20261027/animation/animation.gd:3`.
- Preloads absent machine-local `C:/ORY-Cache/qa/crowns-68-msvc-Codex-faisal/isolated.gd`.
- Confirmed parser failure in both standalone and contextual checks. Historical QA reproduction is blocked on a fresh clone; this file is outside shipping runtime paths and `docs/*` is excluded by `export_presets.cfg:12`.

### CW-03 — Low, second historical fixture is not portable

- Location: `docs/evidence/issue68-rendered-20261027/rendered.gd:18`.
- Preloads absent machine-local `C:/ORY-Cache/qa/crowns-68-rendered-Codex-faisal/isolated.gd`.
- Confirmed parser failure; same historical-fixture scope as CW-02. Preserve original evidence; owner may document required staging or provide a portable successor.

## Resource and lifetime sweep

No confirmed missing required literal `res://` resource. All 298 tracked GLTF files have their external buffer/image dependencies. The naive scan's 44 candidates include formatting templates, output directories, skip-list paths and regex/comment text; see `static-scan.json` for every candidate. Focused instance review covered projectile/look pools, entity deregistration, dropped-resource pruning and network cancellation without an additional high-confidence defect.

`docs/evidence/touch-hints-20261027/test.gd:11` is **not** a missing game resource: it belongs to a nested fixture project. `res://hint.gd` exists relative to that project's root, as its README specifies. It fails when incorrectly checked against the game root, then passes check-only against its own root (`nested-fixture.log`, exit 0). Thus the 3 all-root parse failures reduce to the 2 historical portability findings above.

## Fixed-export follow-up

Pending external handoff. Latest received coordinator export mail `1793902635-e5af84` supplies `C:/Temp/crowns-build-0649-050bc28/CrownsOfTheWildwood.exe`, source `050bc28`, explicitly **before** the promised fix. No newer fixed-export mail was present at the final mailbox check. This older artifact was not labeled or tested as the fixed candidate. The audited `a93e5b4` source has no `--smoke-match` hook.

When delivered: record source/hash, use newly created empty APPDATA and LOCALAPPDATA directories, boot scripted for the requested interval, run `--smoke-match` if the delivered version supports it, retain stdout/stderr and engine log, require clean raw errors and actual smoke markers. No computer-use, visual acceptance, split-screen/input or combat outcome is claimed here.

Agent: Codex-faisal2. No game-code fixes, merges, paid generation or computer-use.
