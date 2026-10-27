# Agent Board: Crowns of the Wildwood

| Group | Agent | Current task | Files owned | State | Handoff |
|---|---|---|---|---|---|
| Coordination | `claude-cloud` | Repo joins the studio workflow: AGENTS.md, boards, inbox; CW-1..3 queued | `AGENTS.md`, `CLAUDE.md`, `docs/agents/` | Done 2026-10-16 | â€” |
| Integration | `claude-faisallaptop` | CW-2 integration (#8, #13, #9, #6, #17) + 2 new maps + visual pass + lag fix, one PR | branch `claude-faisallaptop/int1`; `scripts/game.gd`, `scripts/stats.gd`, map/visual/perf code, `docs/agents/Handoffs/2026-10-16 claude-faisallaptop int1.md` | Done: #31 merged | [handoff](Handoffs/2026-10-16%20claude-faisallaptop%20int1.md) |
| Release | `claude-faisallaptop` | RC1 build of main `ce6abfc` for CW-4: Windows build, a bot match and screenshots per map (local only, nothing published) | `build/` (ignored), `docs/screenshots/rc1/`, `docs/agents/Handoffs/2026-10-16 claude-faisallaptop rc1.md` | Done 2026-10-16 (local build only) | [handoff](Handoffs/2026-10-16%20claude-faisallaptop%20rc1.md) |
| Performance | `claude-faisallaptop` | 4-player split-screen hitches (CW-4 T09: >= 30 fps 1% low proposed) | `scripts/hud.gd` map pins, `scripts/character_model.gd` resource cache, pane shadows in `scripts/game.gd` | Done: #46 merged | â€” |
| Online | `claude-faisallaptop` | Online play on all five maps (ENet + relay), CW-4 T07 | `scripts/game.gd` (`_warm_up_menus`), test tools | Done: #45 and #57 merged (#57: stalled and mid-match joiners keep their link; `tools/net_midjoin.sh`) | â€” |
| Input | `claude-faisallaptop` | Gamepad split-screen checks, CW-4 T06 (simulated pads; physical pads need Faisal) | test tools, input fixes if found | Done: #47 merged (physical pads still need Faisal) | â€” |
| Tests | `claude-faisallaptop` | Every save-writing test runs only in a throwaway user dir (follow-up to #47's review) | `tools/tests/isolated.sh`, `tools/tests/isolated.gd`, the save-writing tests in `tools/` (`hitch_probe`, `kbm_move_test`, `menu_flow_test`, `options_menu_test`, `reload_menu_test`, `save_test`, `store_menu_test`, `touch_close_test`, `window_mode_test`) | Done: #58 merged | â€” |
| Release | `claude-faisallaptop` | Windows build of main `3ddbb2e` for Faisal's desktop (local only, nothing published) | `build/2026-10-18-main-3ddbb2e/` (ignored), zip in Faisal's OneDrive builds folder | Done 2026-10-18 (status on #53) | â€” |

**Adding a row:** append at the bottom; edit only your own rows.

Agent: Codex-faisal2. T2 claim: docs/playtests/T2_Morning_20_Minutes.md only; 20-minute morning playtest for Faisal; branch Codex-faisal2/t2-morning-playtest; 2026-10-18.

| Documentation | Codex-faisal | CW-1 / #25 six-PR ledger | docs/agents/PR Ledger.md; own board row and CW-1 handoff | Documentation complete 2026-10-16; owner review and CW-2 engine verification pending | [CW-1 handoff](Handoffs/2026-10-16%20Codex-faisal%20CW-1.md); branch Codex-faisal/cw-1-pr-ledger; no game edits |

| Documentation | Codex-faisal2 | CW-1 / #29, owner-authorized successor | `docs/agents/PR Ledger.md`; successor row only | Reconciliation complete 2026-10-18; owner explicitly authorized this existing PR update via hub | Current main integrated locally; no game edits or owner merge |

| Release planning | `Codex-faisal` | CW-4 PROPOSED release checklist; docs only | `docs/agents/CW-4 Release Plan.md`, own CW-4 handoff and board row | PROPOSED ready for docs review 2026-10-16; runtime validation blocked by sparse checkout | [CW-4 handoff](Handoffs/2026-10-16%20Codex-faisal%20CW-4.md) |

| Documentation | Codex-faisal2 | CW-4 / #33, owner-authorized successor | `docs/agents/CW-4 Release Plan.md`; successor row only | Reconciliation complete 2026-10-18; owner explicitly authorized this existing PR update via hub | Current main integrated locally; no game edits or owner merge |

Overnight T3 claim 2026-10-18 â€” Agent: Codex-faisal2. T3 Crowns of the Wildwood Store Page. Own new `docs/agents/Proposals/T3 Store Page.md` and `docs/agents/Handoffs/2026-10-18 Codex-faisal2 T3 Store Page.md` only; writing PROPOSED; no runtime edits.

Overnight T3 claim 2026-10-18 â€” Agent: Codex-faisal2. T3 Crowns of the Wildwood Press Kit. Own new `docs/agents/Proposals/T3 Press Kit.md` and `docs/agents/Handoffs/2026-10-18 Codex-faisal2 T3 Press Kit.md` only; writing PROPOSED; no runtime edits.

Overnight T3 claim 2026-10-18 â€” Agent: Codex-faisal2. T3 Crowns of the Wildwood Patch Notes. Own new `docs/agents/Proposals/T3 Patch Notes.md` and `docs/agents/Handoffs/2026-10-18 Codex-faisal2 T3 Patch Notes.md` only; writing PROPOSED; no runtime edits.

Overnight T3 claim 2026-10-18 â€” Agent: Codex-faisal2. T3 Crowns of the Wildwood Achievement Descriptions. Own new `docs/agents/Proposals/T3 Achievement Descriptions.md` and `docs/agents/Handoffs/2026-10-18 Codex-faisal2 T3 Achievement Descriptions.md` only; writing PROPOSED; no runtime edits.

Agent: Codex-faisal2. T2 claim: docs/playtests/T2_Accessibility_Settings.md only; proposed accessibility and settings checklist; branch Codex-faisal2/t2-accessibility; 2026-10-18.

Agent: Codex-faisal. Owner-requested framework cutover, 2026-10-20. Claim: `AGENTS.md`, `CLAUDE.md`, NEW `ORY_WORKFLOW.md`, and this own appended board record only. Task: #66. Branch: `agent/Codex-faisal/66-framework-cutover`. No runtime/art/shared gameplay claims or reassignment. Status: documentation migration prepared for review; source execution/merge follows repository policy.
| Game fix | Codex-faisal | Issue59: reproduce and repair null-mesh spam during headless world construction; explicitly routed to Codex by Claude2 on issue59, no other claimant/comments | scripts/game.gd headless mesh-lifetime hook only; new scripts/headless_mesh_lifetime.gd and tools/null_mesh_probe.gd plus focused regression/evidence; exclude menu/network/input and static batching behavior | Implemented a7c8961, qualified126d1cc: target errors1742->0, identical world fingerprint, clean import, completed bot match with0engine errors; lifecycle regressionPASS. Branch Codex-faisal/59-headless-mesh, review/integration pending | issue59; acceptance: 0 matching null-mesh errors, no script errors on import, completed bot match; renderer behavior preserved |
| Game fix | Codex-faisal | Issue60: repair ENet joiner reliable-event loss; explicit Codex networking route in issue60; no competing claim/comment | scripts/net.gd reliable event delivery; new focused tools and evidence; scripts/game.gd net-test instrumentation only if needed. Exclude other agents' menu/input/timeout scopes | Implemented e406591; three acceptance groups PASS (delayed load, two normal maps, import/full bot). Branch Codex-faisal/60-enet-events stacked on PR61. Original reporter case confirmation and review/integration pending | issue60; acceptance: reliable effects/chat reach joiner, snapshots/gameplay continue, clean import and bot match |

| Menu performance | Codex-faisal | Crowns PM: owner directly authorized menu-lag fix, 2026-10-18; current main board confirms prior menu warm-up ownership complete | scripts/menu.gd, scripts/menu_stage.gd, scripts/hud.gd menu rendering only; scripts/game.gd menu warm-up only if measurements require; tools/menu_latency_probe.gd and scoped evidence/handoff | Implemented and tested on Codex-faisal/menu-lag atop PR62 5a5387b; first Ready Up 1891.5 ms to 26.4 ms; import/menu-flow/bot PASS; existing exit warnings remain; review pending | Acceptance: repeatable before/after rendered timings, menu navigation correctness, short video; clean import and bot match |

| Menu completion | Codex-faisal | Crowns PM direct owner request: finish all-menu responsiveness and deliver verified desktop build | scripts/menu_stage.gd model reuse; scripts/menu.gd and scripts/hud.gd menu rendering if profiling requires; tools/menu_latency_probe.gd; scoped evidence/build packaging | Continuing own PR64 on Codex-faisal/menu-lag; preserve PR61/62; no conflicting current main claims | Acceptance: all-menu navigation/latency coverage, packaged smoke, desktop shortcut plus video/timings |

| Map transitions | Codex-faisal | Crowns PM direct owner request: fix map switching lag; preserve menu and loading fixes | scripts/game.gd map selection/world construction; new tools/map_latency_probe.gd; existing map switching regression only as needed; own handoff/evidence | Implemented and validated 1da8de3; all 20 pairs, gameplay/menu/loading regressions, import/bot and exported pack pass; desktop build delivered; review pending | All 20 directed map pairs correct, measured stalls reduced, menu/loading regressions and bot pass |

| Codex-faisal | DONE map-transition scope extension | Codex-faisal/map-transitions | Include scripts/menu_stage.gd and scripts/volcano.gd construction checkpoints; preserve menu hero cache and warm-up behavior. Serialized desktop Godot 4.3 validation. |

| Codex-faisal | DONE map-transition scope extension | Codex-faisal/map-transitions | Include scripts/menu.gd immutable menu texture retention: profiling found approximately 1 second of repeated artwork loading per scene rebuild. No menu behavior changes. |

| Codex-faisal | DONE map-transition scope extension | Codex-faisal/map-transitions | Include scripts/hud.gd immutable image/font caches and one-time top-bar preprocessing. Main board rechecked: prior HUD performance claim is DONE (#46). Preserve HUD behavior and existing menu/loading fixes. |

## Codex-faisal integration record, PR 37

Agent: Codex-faisal. Incoming branch records preserved below; no existing owner or current main claim reassigned.

| Integration | `claude-faisallaptop` | CW-2 integration (#8, #13, #9, #6, #17) + 2 new maps + visual pass + lag fix, one PR | branch `claude-faisallaptop/int1`; `scripts/game.gd`, `scripts/stats.gd`, map/visual/perf code, `docs/agents/Handoffs/2026-10-16 claude-faisallaptop int1.md` | PR #31 for review, 2026-10-16 | [handoff](Handoffs/2026-10-16%20claude-faisallaptop%20int1.md) |
| T5 crowns-code | `Codex-faisal` | Steam export cold-cache bootstrap and terminating editor import | `tools/steam/build_steam.sh`, `tools/tests/steam_build_test.sh`, own T5 handoff | Claimed 2026-10-17; branch `Codex-faisal/t5-steam-cold-import` | Pending |
| T5 crowns-code | `Codex-faisal` | Steam builder App ID and output-path validation | `tools/steam/build_steam.sh`, `tools/tests/steam_build_test.sh`, own T5 guards handoff | Claimed 2026-10-17; stacked on cold-import PR | Pending |

## Codex-faisal integration record, PR 41


| T5 crowns-code | `Codex-faisal` | Preserve primary save when backup creation fails | `scripts/save_file.gd`, `tools/save_write_test.gd`, own T5 save handoff | Claimed 2026-10-17; independent of Steam stack | Pending |
| T5 crowns-code | `Codex-faisal` | Correct dodge recovery tutorial text to approved source constant | `scripts/guide.gd`, own T5 guide handoff | Claimed 2026-10-17; stacked on save fix | Pending |
| T5 crowns-code | `Codex-faisal` | Explicit non-resource licence notice inclusion in export presets | `export_presets.cfg`, `tools/export_notices_test.gd`, own T5 notices handoff | Claimed 2026-10-17; stacked on guide | Pending |

## Codex-faisal integration record, PR 44


| T5 crowns-code | `Codex-faisal` | Preserve primary save when backup creation fails | `scripts/save_file.gd`, `tools/save_write_test.gd`, own T5 save handoff | PR #41 awaiting review; implementation complete | Pending |
| T5 crowns-code | `Codex-faisal` | Correct dodge recovery tutorial text to approved source constant | `scripts/guide.gd`, own T5 guide handoff | PR #42 awaiting review; implementation complete | Pending |
| T5 crowns-code | `Codex-faisal` | Explicit non-resource licence notice inclusion in export presets | `export_presets.cfg`, `tools/export_notices_test.gd`, own T5 notices handoff | PR #43 awaiting review; implementation complete | Pending |
| T5 crowns-code | `Codex-faisal` | Source-derived effective baseline balance report | `tools/balance_report.gd`, own T5 balance-report handoff | PR #44 awaiting review; implementation complete | Pending |

| Writing T3 | `Codex-faisal` | RC2 store copy, achievement list, balance review and patch notes | branch `Codex-faisal/t3-crowns-rc2-writing`; `docs/release/rc2-writing.md`; own T3 handoff and board row only | Claimed 2026-10-17; PROPOSED | Pending |

## Codex-faisal integration record, PR 39

Agent: Codex-faisal. Incoming branch records preserved below; no existing owner or current main claim reassigned.

## Codex-faisal depot repair integration, PR39
Agent: Codex-faisal. Existing claim records retained below; no owner reassignment. Fixed Windows root/nested junction rejection; baseline fails both real fixtures, corrected checker passes all8 tests. No Steam/Godot qualification or upload.
| T5 crowns-code | `Codex-faisal` | Offline Steam readiness preflight and checklist | `tools/steam/check_depot.py`, `tools/tests/test_steam_depot.py`, `docs/steam-readiness.md`, own T5 readiness handoff | Claimed 2026-10-17; stacked on build guards | Pending |

## Codex-faisal integration record, PR 40

Agent: Codex-faisal. Incoming branch records preserved below; no existing owner or current main claim reassigned.

| T5 crowns-code | `Codex-faisal` | Steam export cold-cache bootstrap and terminating editor import | `tools/steam/build_steam.sh`, `tools/tests/steam_build_test.sh`, own T5 handoff | PR #37 awaiting review; implementation complete | Pending |
| T5 crowns-code | `Codex-faisal` | Steam builder App ID and output-path validation | `tools/steam/build_steam.sh`, `tools/tests/steam_build_test.sh`, own T5 guards handoff | PR #38 awaiting review; implementation complete | Pending |
| T5 crowns-code | `Codex-faisal` | Offline Steam readiness preflight and checklist | `tools/steam/check_depot.py`, `tools/tests/test_steam_depot.py`, `docs/steam-readiness.md`, own T5 readiness handoff | PR #39 awaiting review; implementation complete | Pending |
| T5 crowns-code | `Codex-faisal` | Retained Steam build logs and diagnostic failure gates | `tools/steam/build_steam.sh`, `tools/tests/steam_build_test.sh`, `docs/steam-readiness.md`, own T5 evidence handoff | PR #40 awaiting review; implementation complete | Pending |
| Wave5 sound | Codex-faisal | Owner Wave5 sound/polish: positional effects audible to all local couch seats | scripts/sfx.gd; tools/couch_audio_test.gd; docs/agents/Handoffs/2026-10-25 Codex-faisal couch-audio.md; scoped evidence | READY PR #70; main current; 30 audio/lifecycle checks, 41 combat checks on both packs, full bot, native SFX-bus gates and before/after captures; no assets changed | Import, audio regression, bot and rendered evidence |

| Visual pass coordination | Codex-faisal | Owner direct 2026-10-27: implement October25 GAME/UI picks; continue PR75 acceptance separately | docs/visual/picks-2026-10-25.md; docs/visual/2026-10-27-pass/; tools/visual_pass/; own evidence/handoff | ACTIVE: dedicated world/characters/UI lanes below; no main merge | Real built captures beside each selected screen, mobile-aware native UI, clean import and bot |
| Visual world | Codex-faisal/world | Selected GAME world/terrain/props/lighting | scripts/visual/style_profile.gd; scripts/game.gd world material/builders only; scripts/menu_stage.gd world materials/lighting only; own new evidence/handoff | ACTIVE, isolated branch; preserve topology/lifecycle/menu input | Shared matte cream stone, warm timber/gold, green-blue cloth |
| Visual characters | Codex-faisal/characters | Selected knight B and shared character materials | scripts/character_model.gd material application only; new scripts/visual/character_material_profile.gd; own new evidence/handoff | ACTIVE, isolated branch; no skeleton/rig/lifecycle edits | Existing CC0 models first; no generation needed unless a verified gap remains |
| Visual UI | Codex-faisal/ui | Selected title D/map A/ready A/spawn C/live C/paused C/knight C | scripts/menu.gd; scripts/hud.gd; tools/crowns_visual_capture.gd; own new evidence/handoff | ACTIVE, isolated branch; world owns menu_stage.gd | Native controls and structurally selected layouts, actual screen captures |

| Visual world extension | Codex-faisal/world | Existing clean native title scenery for selected GAME title A/UI title D | scripts/title_diorama.gd; scripts/menu_stage.gd title visibility/backdrop switching; new scripts/visual/carved_block.gd | ACTIVE: UI helper owns only menu.gd controls | Avoid baked old title buttons; preserve real camera and source mechanics |

| Visual title asset | Codex-faisal/world | Root-authorized selected title A clean backdrop integration | New assets/ui/menu/title_picked_a_clean.png; existing scripts/menu_stage.gd backdrop path; docs/visual/2026-10-27-world provenance | ACTIVE; native controls remain; no queue edits | Root supplied built-in imagegen UI/logo removal derivative, 2026-10-27 |
