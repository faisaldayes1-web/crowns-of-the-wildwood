# Dedicated Crowns visual pass handoff

Agent: Codex-faisal. Evidence refresh: Codex-faisal/bugtest, 2026-10-27. Not a final visual-acceptance claim.

## Reviewable delivery

- World and title: PR76, `Codex-faisal/world/crowns-picked-pass`.
- Character materials: PR77, `Codex-faisal/characters/crowns-picked-pass`.
- Menus/HUD: draft PR78, `Codex-faisal/ui/crowns-picked-pass`.
- Tooling and evidence: draft PR79, `Codex-faisal/crowns-visual-evidence`.
- Skeleton runtime evidence PR75 merged on 2026-10-27 at 08:36:49Z; issue68 remains open. No runtime replacement or visual implementation merge is claimed.

The original PRs targeted main0963f03. PR79 now includes main e7ae8b2 (merged PR75); its append-only Agent Board conflict was resolved preserving all rows from both parents. PR76-78 were reconciled with main by their owners: world35bea91, charactersff37a0c and UIb1da57d. World precedes UI because the new title controls require its clean backdrop. The combined integration is `Codex-faisal/crowns-visual-pass` at C:/ORY-Cache/worktrees/crowns-visual-pass. The evidence branch contains no combined gameplay implementation; it has tools, records, screenshots and the actual map export.

Read COMPARISONS.md, MOBILE.md and REVIEW.md for seven screens, source revisions and remaining target gaps. The final capture refresh uses3c83b96; prior images and logs remain explicitly historical. No picks were marked accepted or vaulted.

## Final exact-source evidence

Agent: Codex-faisal/bugtest. Final integrated source: `3c83b964c0216b3c73a6a4acbda5e384295a6e0c`, pushed on `Codex-faisal/crowns-visual-pass`. Desktop `checks/d-final` and phone `checks/mobile-final-v2-20261027` each contain seven capture records with exit0, zero errors, clean working diff and identical before/after source. `checks/touch-final-v2-20261027` passes23 assertions on the same source. Current gallery and mobile manifests record SHA256 hashes; original/reference image bytes are unchanged and displaced current images are archived.

Menu25 and bounded encounter results remain at earlier bb55342; the full natural bot match remains at659ab86. They were not silently relabelled as final-source tests. Changes after bb55342 are touch onboarding text/type/wrapping only. No full-game, physical-device or sustained-FPS acceptance is claimed.

## Historical validation

Clean import; seven desktop captures; seven phone-size captures; 25 menu-flow assertions; 16 character-material checks; actual4096px clean/labelled map export plus bounds; stable full bot match completed naturally Elves2–0 at simulated375 with zero errors. Raw logs/results are retained. Existing menu-anchor warnings are visible in the raw menu log.

The first rendered touch fixture passed23 assertions but logged a finished-Tween startup error. The test used a five-frame startup guess; a bounded readiness wait was subsequently committed. The fresh bb55342 touch run passed23 with zero errors; the original failing run remains history and must not be described as clean. The follow-up instructional-copy correction is now captured and qualified at final3c83b96.

## Renderer validation update

Agent: Codex-faisal/bugtest. The prior reservation blocker is superseded: the parent coordinator is running serial validation in the reserved renderer lane. Its previous gate record is preserved in [history](history/reservation-before-push.md). No engine was launched by the evidence reviewer.

Fresh desktop/mobile captures and menu/touch checks at `bb5534219626e46417f6eb9c2c1595d8e2a5b688` completed with unchanged source, empty working diffs, exit zero and zero engine/script errors. Menu passed 25 assertions; touch passed 23. This supersedes the earlier touch startup error for that exact source. The earlier checks remain source-bound history; final captures use3c83b96.

Independent mobile review found tiny keyboard-specific instructional copy in the touch fixture. PR78 corrected it with larger touch-specific instructions; final3c83b96 images are independently reviewed. The follow-up uses ordinary spacing and native wrapping; visual fidelity still has the documented environment and geometry gaps. The bounded natural-combat fixture completed at bb55342: exit0, zero errors,100.33 seconds including setup. Its enemy-proximity frame and60-second gathering frame are retained under checks/combat-push-20261027. No hit or crown capture is proven; visible_carrier_observed=false.

Final acceptance remains open. PR78/79 stay draft while visual gaps remain; no automatic merge or picked-set vault move is authorized by these checks. Physical mobile performance and native input still require device testing.

## Shader-cache path failures

Agent: Codex-faisal/bugtest. Desktop final-v2 and final-v3 at unchanged3c83b96 produced all seven frames but logged a shader-cache save error (`f.is_null`, shader_rd.cpp474). They are failed runs, regardless of process exit zero. Their logs/results are preserved under checks. The parent observed successful cache paths reaching259 characters and tested a shorter isolated user-data directory at identical source/settings; this is an environment-path diagnosis, not a source fix or waived error gate. The longest successful d-final cache filename is242 characters; substituting desktop-final-v3-20261027 produces260 characters. This supports, without proving universally, the path-length diagnosis. The identical-source/settings rerun in shorter isolated path `C:/Temp/cwv-crowns-final/d-final` completed cleanly:20.75 seconds, seven frames, zero errors. Current desktop images come from this run. No cache option or test/error gate was disabled.

## Rejected touch-copy candidate

Agent: Codex-faisal/bugtest. The first touch-copy candidate6ad7085 failed the full HUD parse during mobile capture:6 errors,4 script errors, process stopped, no captures. [Raw failure result](checks/mobile-touchfix-20261027/result.json) is retained. The inferred Variant for touch_hint requires an explicit bool. This failed candidate is not acceptance evidence. The explicit-bool correction is included in3c83b96, whose final renderer results are separately recorded.

## Goal progress

Agent: Codex-faisal/bugtest. Read docs/GOALS.md and the current Agent Board. The parent confirmed Codex-faisal/crowns is this team's owned scope and its helper relinquished active work; docs/GOALS.md now records genuine progress under the parent's scoped assignment. No other team's goals were changed.

The approved-picks goal now has implemented world/character/UI PRs and actual before/reference/current comparisons. Before/after evidence exists for seven screens, with final exact-source3c83b96 captures. Neither goal has final visual acceptance. Skeleton issue68 remains open despite merged evidence PR75; this pass does not qualify a replacement runtime. Couch performance has no measured frame-time acceptance, and a reviewable evidence PR is not release approval. No goal was marked accepted and no five successor goals were added.

## Costs and provenance

No paid API, Meshy, PixelLab or ComfyUI generation. One built-in imagegen precise-object edit removes UI/logo from selected titleA. Generated file copied to C:/ORY-Cache/style-options/crowns-clean-title-Codex-faisal/title-a-clean-v1.png, then integrated separately as assets/ui/menu/title_picked_a_clean.png. Full prompt/source/hash is in world PR's title-backdrop-provenance.json. External generation credit spend: zero.

Reports to claude-faisal were sent throughout the run, most recently with PR76–79, the exact reservation paths, and zero active Godot processes. Continue hourly while actively running.
