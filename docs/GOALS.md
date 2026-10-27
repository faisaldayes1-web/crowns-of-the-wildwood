# Crowns goals

Agent: Codex-faisal/crowns. Updated 2026-10-27 against main `0963f03bc52f7dcca786e2a3bc3703a74b7edde2`.

These are acceptance goals for the owner's October 27 desktop assignment. Existing issue ownership remains authoritative; this document does not reassign another agent's work.

| Goal | Current evidence | Remaining acceptance |
|---|---|---|
| Resolve exported Skeleton3D disconnects ([#68](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/issues/68)) | Same-version unmodified Godot 4.3 MSVC optimized release candidate passes minimal teardown, 378 headless map lifecycle checks and a natural seed7 bot match. [Rendered solo/split map and class route](evidence/issue68-rendered-20261027/README.md): 56 checks, zero errors versus official release's 1,987 Skeleton disconnects, identical pack. | Qualify complete animation and measured performance; investigate broader resource shutdown diagnostics; review candidate packaging before replacing a runtime. |
| Implement the approved visual picks | Local gallery `C:/ORY-Cache/style-options/crowns-goals/index.html` has 56 proposals. Its handoff explicitly says PROPOSED; this audit has not verified an approved per-screen selection. | Record Faisal's actual GAME/UI picks and source; create side-by-side gaps from current real screenshots; implement selected changes, re-screenshot and review. Do not infer approval from existing option files. |
| Establish real before/after references | Dated October 24 screenshots and same-pack October 27 runtime comparison are available. | Capture each selected screen after its actual visual implementation, beside its approved reference. Runtime comparison is not an art upgrade. |
| Qualify couch-play performance | Existing source and headless checks establish behavior, not measured FPS. | Repeat representative 2-player and 4-player rendered measurements with exact resolution, graphics settings, hardware, frame-time distributions and a coordinated GPU lane. |
| Deliver a small reviewable release change | Runtime template candidate and local provenance exist; no release replacement is asserted. | Keep the same engine version; bind package, source, template hashes and checks to a reviewed PR. Preserve attachments and error visibility; avoid speculative lifecycle patches. |

When these goals are accepted, add five concrete next goals based on the resulting build and playtest findings. Do not mark proposals, generated options, or headless-only evidence as completed visual acceptance.
