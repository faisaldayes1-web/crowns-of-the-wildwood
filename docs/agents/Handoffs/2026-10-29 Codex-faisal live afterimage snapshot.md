# Live afterimage snapshots

Agent: Codex-faisal. Pre-edit claim ff5d5ab; direct Faisal finish/bug-fix request and Claude1 material lane. Only `fx.gd` afterimage snapshot production source changed. Assets, shaders, renderer, caches, backend, gameplay durations, networking and peer bug scopes are preserved.

## Problem and repair

Actual rendered FX-overlap reduction reproduced the same MaterialStorage null-material failures as the stopped match. Omitting only afterimages avoided the error; delaying the third ghost did not. Both existing official and approved same-source MSVC Godot4.3 runtimes failed. The exact offending RID was not logged; this is not a compiler-only or queued-old-rig-only diagnosis.

Afterimages now reject a retiring source, prune queued and nonvisual simulation/effect descendants from the off-tree clone, and clear clone-only material overlays/surface overrides behind the existing monochrome material. Live mesh/rig pose, fade, scale, lifetime and network recording stay intact. Pairing accounts for duplicate(0)'s omitted script-constructor children and validated names, including internal rig nodes; it does not free Skeleton3D's cached simulator. Ambiguous unmatched hierarchies fail closed.

## Actual evidence

The original three-ghost overlap and all effect retirement checks pass in Forward+/Vulkan. Then 24 new actual CharacterModel→Fx.afterimage cases cover both teams, six combat roles and ranks1/4. All27 ghosts are visible, contain no unwanted effect descendants and retire. Visible mesh resource/world transforms match source within1e-5 for the24 appearance cases. Six own-viewport source/ghost PNGs were reviewed. Actual engine97320 exited0, no raw errors,42 source pins unchanged. The metadata observer is capped384rows and dropped2177 noncritical events; critical matrix records remain mandatory. This is not an exhaustive GPU RID trace or animation-track comparison.

## Remaining qualification

This narrow native regression does not clear the prior105s full match or the original eight serial performance slots. One changed-source rendered whole match, exact-head CI and review, final native export and actual packaged qualification remain separate. No performance claim, physical-controller acceptance, perfect reference fidelity or final completion is inferred. All failed evidence is retained.

Local required import passed, engine97268 exit0/no raw errors. Complete seeded headless bot match30396 exit0/no raw errors: RESULT Humans score1-1 t626 overtime, eight STAT rows. Exact42 input hashes unchanged. This adds actual whole-bot rule execution, not native renderer acceptance.
