# Current-main Skeleton68 candidate package

Agent: Codex-faisal/crowns. October 27, 2026.

This packages main `9b985b200f5ae4c59ef128cb405ea2db6c37cd1b`, including merged world PR #76, with the previously qualified same-version Godot 4.3 MSVC release runtime. Earlier rendered and animation acceptance used main `0963f03`; those frames are not relabelled as acceptance of these world changes.

The new local package is `C:/ORY-Cache/qa/crowns-68-package-20261027/CrownsCandidate.exe` plus adjacent `CrownsCandidate.pck`. Keep both files together. This is an opt-in test artifact, not the installed game or a changed export default. No upload, release replacement, engine-version change or asset generation occurred.

`provenance.json` binds the executable and PCK hashes. The executable is byte-identical to candidate template SHA256 `dba29f8fae628f56bf2155c7d79a6c9801fffaac799a936a3429edbc0d024d3a`; the new PCK SHA256 is `336de1f62a28406c32403d95b5675ae598ed1f3dc5cdfb9991bd7d05cc340e77`. Branch commit `e3a657f` adds only the claim to the game source. Export uses the unchanged Windows Desktop preset's resource filters through `--export-pack`; it does not modify `export_presets.cfg` or global templates.

## Validation

Fresh headless import exited 0 with no logged script/parse errors on this desktop. This does **not** resolve portable-import issue #80: existing absolute QA helper paths happen to be available here. PR #81 owns that separate archived-script exclusion fix.

Export-pack exited 0 in 11.23 s with no errors. The package runs from its artifact directory without `--path` or `--main-pack`, proving discovery of the adjacent PCK. Menu checks pass 25/25 and movement checks 10/10 with zero Skeleton errors. Their shutdown logs still contain ObjectDB warnings and respectively 11/10 resources still in use. These runs are not overall-clean runtime passes.

The natural seed-7 bot match completes Humans 0–2 at simulation t=218, no overtime, exit 0, zero engine errors and zero Skeleton disconnects. Wall time 56.05 s is not an FPS measurement or a balance/determinism claim.

The exact runner, fixtures, original stdout, result counts and natural seed7 match result are retained alongside this report. All match/test processes use separate disposable APPDATA and marker directories. Menu/movement fixtures verify their actual user paths; a separate read-only package probe verifies the actual natural-match user path under its disposable directory. The path probe is after the match was launched, not a claimed preflight. GDScript archives use `.gd.txt` so Godot cannot import them as game scripts.

## Remaining gates

No current-package rendered screenshots, animation smoothness, frame-time distributions, physical controllers, online, all-map or mobile qualification. Previous rendered 56-check and animation 41-check evidence remains bound to its original unchanged pack. Character #77, UI #78 and visual evidence #79 review lanes remain separate; this package includes merged world #76 only. Resource shutdown errors and issue #80 remain visible; issue #68 stays open until the runtime/package acceptance decision.

No game code/art changes. No paid API calls; Meshy/PixelLab credits 0.

Archived log line endings and trailing blank lines are normalized for Git; original process output remains in the local artifact directory.
